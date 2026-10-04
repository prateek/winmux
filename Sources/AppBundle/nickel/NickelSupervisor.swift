import Common
import Foundation
import os

/// A helper that has loaded a config and passed its smoke run, not yet serving WinMux's requests.
struct LoadedNickelConfig: Sendable {
    let process: NickelHelperProcess
    /// The file that was loaded, or nil for the shipped defaults.
    let path: URL?
    /// The config's settings, without its functions.
    let settings: JSONValue
    /// The config file and every file it imports.
    let imports: [URL]
    /// The directory of the shipped library, which the config imports `winmux/` files from.
    let library: URL?
    var warnings: [String] = []
}

struct NickelStatus: Equatable, Sendable {
    enum State: String, Sendable { case ready, restarting, failed }
    let state: State
    let pid: Int32?
    let rss: Int
    let recycles: Int
    let lastError: String?
    let configPath: String?
}

/// Owns the one `winmux-nickel` that answers WinMux's requests: replaces it on reload and when
/// its memory grows, restarts it when it dies, and stops restarting it when it keeps dying.
@MainActor
final class NickelSupervisor {
    struct Settings: Sendable {
        var executable: @Sendable () -> URL? = { nickelHelperUrl() }
        var loadTimeout: Duration = .seconds(2)
        var filterTimeout: Duration = .milliseconds(100)
        var hookTimeout: Duration = .milliseconds(50)
        /// The helper leaks on almost every call, so it is replaced once it has grown this large.
        var rssLimit: Int = 256 * 1024 * 1024
        var minIntervalBetweenRecycles: Duration = .seconds(10)
        /// Waits before the second, third and later restarts of a crashing helper double from here.
        var firstRestartDelay: Duration = .seconds(1)
        var maxRestartDelay: Duration = .seconds(30)
        var breakerCrashCount: Int = 3
        var breakerWindow: Duration = .seconds(60)
        /// A helper that has stayed up this long starts a fresh run of restart delays.
        var crashStreakReset: Duration = .seconds(300)
    }

    static let shared = NickelSupervisor()

    private let settings: Settings
    /// Called when the breaker opens, with what to tell the user.
    var onBreakerOpened: @MainActor (String) -> Void = { _ in }

    private var current: NickelHelperProcess?
    private var loadedPath: URL?
    private var hasLoaded = false
    private var rss = 0
    private var recycles = 0
    private var lastError: String?
    private var crashes: [ContinuousClock.Instant] = []
    private var crashStreak = 0
    private var restart: Task<Void, Never>?
    private var restartIsImmediate = false
    private var recycle: Task<Void, Never>?
    private var lastRecycleAttempt: ContinuousClock.Instant?

    init(settings: Settings = Settings()) {
        self.settings = settings
    }

    var status: NickelStatus {
        NickelStatus(
            state: current != nil ? .ready : (restart != nil ? .restarting : .failed),
            pid: current?.pid,
            rss: rss,
            recycles: recycles,
            lastError: lastError,
            configPath: loadedPath?.path,
        )
    }

    // MARK: - Loading

    /// Spawns a fresh helper and has it load `path`, or the shipped defaults when `path` is nil.
    /// The helper WinMux is using keeps serving until the result is passed to `adopt`.
    func load(_ path: URL?) async -> Result<LoadedNickelConfig, NickelFailure> {
        guard let executable = settings.executable() else {
            return .failure(.unavailable("The config helper winmux-nickel was not found"))
        }
        let process: NickelHelperProcess
        do {
            process = try NickelHelperProcess(executable: executable) { [weak self] pid in
                Task { @MainActor in self?.helperCrashed(pid: pid) }
            }
        } catch {
            return .failure(.unavailable("Cannot start \(executable.path): \(error.localizedDescription)"))
        }
        let request: [String: JSONValue] = ["op": .string("load"), "path": path.map { .string($0.path) } ?? .null]
        switch await process.send(request, timeout: settings.loadTimeout) {
            case .success(let reply):
                rss = reply.rss
                let imports = reply.result["imports"]?.arrayOrNil?.compactMap(\.stringOrNil).map { URL(filePath: $0) } ?? []
                return .success(LoadedNickelConfig(
                    process: process,
                    path: path,
                    settings: reply.result["config"] ?? .object([:]),
                    imports: imports,
                    library: reply.result["library"]?.stringOrNil.map { URL(filePath: $0) },
                    warnings: reply.result["warnings"]?.arrayOrNil?.compactMap(\.stringOrNil) ?? [],
                ))
            case .failure(let failure):
                await process.kill()
                // With a helper serving, a failed load is the caller's to report. With none, it is
                // why nothing is serving.
                if current == nil, restart == nil { lastError = failure.message }
                return .failure(failure)
        }
    }

    /// Makes `loaded` the helper that answers requests. Requests in flight finish on the old one.
    func adopt(_ loaded: LoadedNickelConfig) {
        restart?.cancel()
        restart = nil
        recycle?.cancel()
        recycle = nil
        install(loaded)
        // A reload the user asked for clears the breaker and the crash history.
        crashes = []
        crashStreak = 0
        lastError = nil
    }

    /// Records why a reload failed while this helper kept serving, as the status's last error. A
    /// later crash, or a load that succeeds, replaces it.
    func recordFailedReload(_ message: String) {
        lastError = message
    }

    func recordHookFailure(_ message: String) {
        lastError = message
        configLog.error("Policy hook failed: \(message, privacy: .public)")
    }

    func discard(_ loaded: LoadedNickelConfig) {
        Task { await loaded.process.close() }
    }

    private func install(_ loaded: LoadedNickelConfig) {
        if let old = current {
            Task { await old.close() }
        }
        if hasLoaded { recycles += 1 }
        hasLoaded = true
        current = loaded.process
        loadedPath = loaded.path
    }

    // MARK: - Requests

    /// One match bit per window for the Lens's Filter.
    func filter(lens: String, context: JSONValue, windows: [JSONValue]) async -> Result<[Bool], NickelFailure> {
        let request: [String: JSONValue] = ["op": .string("filter"), "lens": .string(lens), "ctx": context, "windows": .array(windows)]
        return await send(request, timeout: settings.filterTimeout).flatMap(matchBits)
    }

    /// One match bit per window for a Filter given as text, which may call the named Filters.
    func evalFilter(_ filter: String, context: JSONValue, windows: [JSONValue]) async -> Result<[Bool], NickelFailure> {
        let request: [String: JSONValue] = ["op": .string("eval-filter"), "filter": .string(filter), "ctx": context, "windows": .array(windows)]
        return await send(request, timeout: settings.filterTimeout).flatMap(matchBits)
    }

    func checkFilter(_ filter: String) async -> Result<JSONValue, NickelFailure> {
        await send(["op": .string("check-filter"), "filter": .string(filter)], timeout: settings.filterTimeout)
    }

    func hook(_ hook: String, args: [JSONValue]) async -> Result<JSONValue, NickelFailure> {
        await send(["op": .string("hook"), "hook": .string(hook), "args": .array(args)], timeout: settings.hookTimeout)
    }

    private func send(_ request: [String: JSONValue], timeout: Duration) async -> Result<JSONValue, NickelFailure> {
        if current == nil, restartIsImmediate, let restart {
            await restart.value
        }
        guard let process = current else {
            return .failure(.unavailable(lastError ?? "The config helper is not running"))
        }
        let result = await process.send(request, timeout: timeout)
        switch result {
            case .success(let reply):
                rss = reply.rss
                if reply.rss > settings.rssLimit { recycleInBackground() }
                return .success(reply.result)
            case .failure(.timedOut):
                lastError = NickelFailure.timedOut.message
                if current === process {
                    current = nil
                    restartHelper(after: .zero)
                }
                return .failure(.timedOut)
            case .failure(let failure):
                return .failure(failure)
        }
    }

    // MARK: - Replacing the helper

    private func recycleInBackground() {
        let now = ContinuousClock.now
        if recycle != nil { return }
        if let last = lastRecycleAttempt, now - last < settings.minIntervalBetweenRecycles { return }
        lastRecycleAttempt = now
        recycle = Task {
            let result = await load(loadedPath)
            if Task.isCancelled {
                if case .success(let loaded) = result { discard(loaded) }
                return
            }
            recycle = nil
            switch result {
                case .success(let loaded): install(loaded)
                // The helper in use keeps serving. The next oversized reply tries again.
                case .failure(let failure): lastError = failure.message
            }
        }
    }

    private func helperCrashed(pid: Int32) {
        guard current?.pid == pid else { return }
        current = nil
        lastError = "The config helper exited unexpectedly"
        recordCrashAndRestart()
    }

    private func recordCrashAndRestart() {
        let now = ContinuousClock.now
        if let last = crashes.last, now - last > settings.crashStreakReset { crashStreak = 0 }
        crashStreak += 1
        crashes = crashes.filter { now - $0 <= settings.breakerWindow } + [now]
        if crashes.count >= settings.breakerCrashCount {
            restart = nil
            let message = "The config helper crashed \(crashes.count) times within a minute and was not restarted. "
                + "The settings already loaded stay in effect. Run 'winmux reload-config' to start it again."
            lastError = message
            onBreakerOpened(message)
            return
        }
        // The first crash restarts at once. Later ones wait 1, 2, 4 seconds and so on.
        let delay: Duration = crashStreak == 1
            ? .zero
            : min(settings.firstRestartDelay * (1 << min(crashStreak - 2, 16)), settings.maxRestartDelay)
        restartHelper(after: delay)
    }

    private func restartHelper(after delay: Duration) {
        restart?.cancel()
        restartIsImmediate = delay == .zero
        restart = Task {
            if delay > .zero { try? await Task.sleep(for: delay) }
            if Task.isCancelled { return }
            let result = await load(loadedPath)
            if Task.isCancelled {
                if case .success(let loaded) = result { discard(loaded) }
                return
            }
            restart = nil
            switch result {
                case .success(let loaded): install(loaded)
                case .failure(.unavailable(let reason)) where settings.executable() != nil:
                    lastError = reason
                    recordCrashAndRestart()
                case .failure(let failure): lastError = failure.message
            }
        }
    }
}

private func matchBits(_ result: JSONValue) -> Result<[Bool], NickelFailure> {
    guard let values = result.arrayOrNil else { return .failure(.diagnostic("The config helper did not return match bits")) }
    return .success(values.map { $0 == .bool(true) })
}
