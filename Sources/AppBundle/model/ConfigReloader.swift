import Common
import Foundation

/// Ordering only. Candidates, continuations and running effects belong to ConfigReloader.
struct ConfigReloadState: Equatable {
    enum LoadAction: Equatable { case supersede, wait, begin }
    private var nextID = 0
    private(set) var newest: Int?
    private(set) var applying: Int?
    private(set) var pending: Int?

    mutating func requested(dryRun: Bool) -> (id: Int, superseded: Int?) {
        nextID += 1
        guard !dryRun else { return (nextID, nil) }
        newest = nextID
        let superseded = pending
        pending = nil
        return (nextID, superseded)
    }

    mutating func loaded(_ id: Int) -> LoadAction {
        guard id == newest else { return .supersede }
        if applying != nil {
            pending = id
            return .wait
        }
        applying = id
        return .begin
    }

    mutating func pendingDeparted(_ id: Int) {
        if pending == id { pending = nil }
    }

    mutating func applicationFinished(_ id: Int) -> Int? {
        precondition(applying == id)
        applying = pending
        pending = nil
        return applying
    }

    mutating func beginFallback() -> Int {
        precondition(applying == nil && pending == nil)
        nextID += 1
        applying = nextID
        return nextID
    }
}

@MainActor
protocol ConfigReloadCandidate {
    var url: URL { get }
    var warnings: [String] { get }
    var imports: [URL] { get }
    var library: URL? { get }
}

@MainActor
struct ConfigReloadHelper<Candidate> {
    var adopt: (Candidate) -> Void
    var dispose: (Candidate) -> Void
    var recordFailure: (String) -> Void
}

@MainActor
struct ConfigReloadReport {
    enum Level { case notice, warning, error }
    var show: (String) -> Void
    var clear: () -> Void
    var log: (Level, String) -> Void
}

@MainActor
struct ConfigReloadSaves {
    var runtimeReady: () -> Bool
    var fileExists: () -> Bool
    var serverEnabled: @MainActor () -> Bool
    /// Runs a save's reload inside the session a save runs in.
    var session: @MainActor (@MainActor () async throws -> Bool) async throws -> Bool
}

struct ConfigReloadCompletion {
    let result: Result<Bool, Error>
    let text: String
}

private enum ConfigReloadApplication {
    struct Context: Sendable {
        let owner: ObjectIdentifier
        let attempt: Int
    }
    @TaskLocal static var current: Context?
}

@MainActor
final class ConfigReloader<Candidate: ConfigReloadCandidate> {
    private let load: @MainActor (URL?) async -> Result<Candidate, String>
    private let helper: ConfigReloadHelper<Candidate>
    private let apply: @MainActor (Candidate) async throws -> Void
    private let report: ConfigReloadReport
    private let watch: (ConfigLoadOutcome) -> Void
    private let emit: (ServerEvent) -> Void
    private let saves: ConfigReloadSaves
    private let configPath: () -> String
    private var state = ConfigReloadState()
    private var notifications = ConfigReloadNotifications()
    private var savedDuringStartup = false
    /// Whether any attempt has applied a candidate. Startup's fallback to the shipped defaults
    /// does not replace a config a later reload put in effect.
    private var hasApplied = false
    private var waitingForIdle: [CheckedContinuation<Void, Never>] = []
    /// The pending attempt of `state`, waiting for its turn: resumed with true to apply, or false
    /// when a newer request supersedes it.
    private var waitingToApply: (id: Int, turn: CheckedContinuation<Bool, Never>)?

    private var attempts: [Int: Attempt] = [:]
    /// Work an ordinary request displaced, retained until a successor begins application.
    private var supersededWork: Attempt?

    private struct Attempt {
        let dryRun: Bool
        let noGui: Bool
        let trigger: ConfigReloadTrigger
        let path: String
    }

    init(
        load: @escaping @MainActor (URL?) async -> Result<Candidate, String>,
        helper: ConfigReloadHelper<Candidate>,
        apply: @escaping @MainActor (Candidate) async throws -> Void,
        report: ConfigReloadReport,
        watch: @escaping (ConfigLoadOutcome) -> Void,
        emit: @escaping (ServerEvent) -> Void,
        saves: ConfigReloadSaves,
        configPath: @escaping () -> String,
    ) {
        self.load = load
        self.helper = helper
        self.apply = apply
        self.report = report
        self.watch = watch
        self.emit = emit
        self.saves = saves
        self.configPath = configPath
    }

    /// The application runs in the caller's task, with the caller's task-locals and cancellation.
    func request(
        forceConfigUrl: URL? = nil,
        dryRun: Bool = false,
        noGui: Bool = false,
        trigger: ConfigReloadTrigger = .command,
    ) async -> ConfigReloadCompletion {
        if !dryRun, let current = ConfigReloadApplication.current,
           current.owner == ObjectIdentifier(self), current.attempt == state.applying {
            let message = "Cannot reload config from its own application"
            report.log(.error, message)
            return .init(result: .success(false), text: message)
        }
        let attempt = Attempt(dryRun: dryRun, noGui: noGui, trigger: trigger, path: forceConfigUrl?.path ?? configPath())
        if !dryRun, let newest = state.newest, newest != state.applying,
           let displaced = attempts[newest] {
            supersededWork = supersededWork ?? displaced
        }
        let request = state.requested(dryRun: dryRun)
        attempts[request.id] = attempt
        defer { attempts[request.id] = nil }
        if let id = request.superseded { takeWaiter(id).resume(returning: false) }
        let read = await load(forceConfigUrl)
        if dryRun { return completeDryRun(attempt, read) }
        if Task.isCancelled {
            if case .success(let candidate) = read { helper.dispose(candidate) }
            replaceCancelledNewest(request.id)
            return .init(result: .failure(CancellationError()), text: "")
        }
        let proceed: Bool
        switch state.loaded(request.id) {
            case .supersede: proceed = false
            case .begin: proceed = true
            case .wait:
                proceed = await withTaskCancellationHandler {
                    await withCheckedContinuation { waitingToApply = (request.id, $0) }
                } onCancel: {
                    Task { @MainActor in self.cancelWaiter(request.id) }
                }
        }
        if Task.isCancelled, !proceed {
            if case .success(let candidate) = read { helper.dispose(candidate) }
            replaceCancelledNewest(request.id)
            return .init(result: .failure(CancellationError()), text: "")
        }
        guard proceed else {
            if case .success(let candidate) = read { helper.dispose(candidate) }
            return .init(result: .success(false), text: "A later reload replaced this one")
        }
        return await run(request.id, attempt, read)
    }

    private func cancelWaiter(_ id: Int) {
        guard waitingToApply?.id == id else { return }
        state.pendingDeparted(id)
        takeWaiter(id).resume(returning: false)
    }

    private func replaceCancelledNewest(_ id: Int) {
        guard state.newest == id, let displaced = supersededWork else { return }
        Task { @MainActor in
            guard self.state.newest == id, self.supersededWork != nil else { return }
            self.supersededWork = nil
            _ = await self.request(noGui: displaced.noGui, trigger: displaced.trigger)
        }
    }

    private struct Reporting {
        var text = ""
        var path: String
        var error: String?
        var outcome = ConfigLoadOutcome.failed
    }

    private func run(_ id: Int, _ attempt: Attempt, _ read: Result<Candidate, String>) async -> ConfigReloadCompletion {
        // A caller cancelled before adoption, as while it waited for its turn, adopts nothing.
        if Task.isCancelled {
            if case .success(let candidate) = read { helper.dispose(candidate) }
            applicationFinished(id)
            replaceCancelledNewest(id)
            return .init(result: .failure(CancellationError()), text: "")
        }
        if id == state.newest { supersededWork = nil }
        var reporting = prepare(attempt, read)
        var result: Result<Bool, Error> = .success(false)
        if case .success(let candidate) = read {
            // Adopt without suspending; only application may yield to newer requests.
            helper.adopt(candidate)
            reporting.outcome = .loaded(imports: candidate.imports, library: candidate.library)
            do {
                try await ConfigReloadApplication.$current.withValue(.init(owner: ObjectIdentifier(self), attempt: id)) { @MainActor in
                    try await apply(candidate)
                }
                hasApplied = true
                report.clear()
                notifications.loaded()
                report.log(.notice, "Loaded the config from \(reporting.path)")
                result = .success(true)
            } catch {
                failure("Loaded \(reporting.path), but applying it failed: \(error.localizedDescription)", attempt, &reporting)
                result = .failure(error)
            }
        }
        watch(reporting.outcome)
        if let event = configReloadEvent(dryRun: false, error: reporting.error, configPath: reporting.path) { emit(event) }
        applicationFinished(id)
        return .init(result: result, text: reporting.text)
    }

    private func applicationFinished(_ id: Int) {
        if let next = state.applicationFinished(id) {
            takeWaiter(next).resume(returning: true)
        } else {
            becameIdle()
        }
    }

    private func takeWaiter(_ id: Int) -> CheckedContinuation<Bool, Never> {
        guard let waiter = waitingToApply, waiter.id == id else { preconditionFailure("Reload attempt \(id) is not waiting for its turn") }
        waitingToApply = nil
        return waiter.turn
    }

    private func failure(_ message: String, _ attempt: Attempt, _ reporting: inout Reporting) {
        reporting.text += message
        reporting.error = message
        if !attempt.dryRun {
            helper.recordFailure(message)
            report.log(.error, "The config failed to load: \(message)")
        }
        if !attempt.noGui && notifications.shouldNotify(message, trigger: attempt.trigger) { report.show(message) }
    }

    private func prepare(_ attempt: Attempt, _ read: Result<Candidate, String>) -> Reporting {
        var reporting = Reporting(path: attempt.path)
        switch read {
            case .failure(let message): failure(message, attempt, &reporting)
            case .success(let candidate):
                reporting.path = candidate.url.path
                for warning in candidate.warnings {
                    reporting.text += "warning: \(warning)\n"
                    report.log(.warning, warning)
                }
        }
        return reporting
    }

    private func completeDryRun(_ attempt: Attempt, _ read: Result<Candidate, String>) -> ConfigReloadCompletion {
        let reporting = prepare(attempt, read)
        if case .success(let candidate) = read { helper.dispose(candidate) }
        return .init(result: .success(reporting.error == nil), text: reporting.text)
    }

    func fileChanged() async {
        guard saves.runtimeReady() else { savedDuringStartup = true; return }
        guard saves.serverEnabled() else { return }
        guard saves.fileExists() else {
            report.log(.notice, "The config file is gone, so the config in effect stays")
            return
        }
        do {
            _ = try await saves.session { @MainActor in
                try await self.request(trigger: .fileChange).result.get()
            }
        } catch {
            report.log(.error, "A reload after a save failed: \(error.localizedDescription)")
        }
    }

    func startupFinished() async {
        guard savedDuringStartup else { return }
        savedDuringStartup = false
        await fileChanged()
    }

    /// Applies the shipped defaults when startup's own load did not put a config in effect. It
    /// waits for an application under way, and does nothing once any reload has applied a
    /// candidate: a reload that replaced startup's own wins over the defaults.
    func applyStartupFallback(_ application: @MainActor () async throws -> Void) async rethrows {
        while state.applying != nil {
            await withCheckedContinuation { waitingForIdle.append($0) }
        }
        if hasApplied { return }
        let id = state.beginFallback()
        defer { applicationFinished(id) }
        try await ConfigReloadApplication.$current.withValue(.init(owner: ObjectIdentifier(self), attempt: id)) { @MainActor in
            try await application()
        }
    }

    private func becameIdle() {
        let waiters = waitingForIdle
        waitingForIdle.removeAll()
        for waiter in waiters { waiter.resume() }
    }
}
