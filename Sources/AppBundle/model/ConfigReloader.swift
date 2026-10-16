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
    /// Returns nil when the server is disabled.
    var session: () -> (@MainActor (@MainActor () async throws -> Bool) async throws -> Bool)?
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
    private var waitingForIdle: [CheckedContinuation<Void, Never>] = []

    private struct Attempt {
        let dryRun: Bool
        let noGui: Bool
        let trigger: ConfigReloadTrigger
        let path: String
    }
    private struct Work {
        let attempt: Attempt
        let read: Result<Candidate, String>
        let completion: CheckedContinuation<ConfigReloadCompletion, Never>
    }
    private var work: [Int: Work] = [:]
    private var applications: [Int: Task<Void, Never>] = [:]

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
        let request = state.requested(dryRun: dryRun)
        if let id = request.superseded { supersede(id) }
        let read = await load(forceConfigUrl)
        if dryRun { return completeDryRun(attempt, read) }
        return await withCheckedContinuation { continuation in
            work[request.id] = Work(attempt: attempt, read: read, completion: continuation)
            switch state.loaded(request.id) {
                case .supersede: supersede(request.id)
                case .wait: break
                case .begin: start(request.id)
            }
        }
    }

    private func supersede(_ id: Int) {
        guard let work = work.removeValue(forKey: id) else { preconditionFailure("Missing reload attempt \(id)") }
        if case .success(let candidate) = work.read { helper.dispose(candidate) }
        work.completion.resume(returning: .init(result: .success(false), text: "A later reload replaced this one"))
    }

    private struct Reporting {
        var text = ""
        var path: String
        var error: String?
        var outcome = ConfigLoadOutcome.failed
    }

    private func start(_ id: Int) {
        guard let work = work[id] else { preconditionFailure("Missing reload attempt \(id)") }
        var reporting = prepare(work.attempt, work.read)
        guard case .success(let candidate) = work.read else {
            finish(id, work, reporting, result: .success(false))
            return
        }
        // Reserve and adopt without suspension; only application may yield to newer requests.
        helper.adopt(candidate)
        reporting.outcome = .loaded(imports: candidate.imports, library: candidate.library)
        applications[id] = Task { @MainActor in
            var result: Result<Bool, Error>
            do {
                try await ConfigReloadApplication.$current.withValue(.init(owner: ObjectIdentifier(self), attempt: id)) { @MainActor in
                    try await apply(candidate)
                }
                report.clear()
                notifications.loaded()
                report.log(.notice, "Loaded the config from \(reporting.path)")
                result = .success(true)
            } catch {
                failure("Loaded \(reporting.path), but applying it failed: \(error.localizedDescription)", work.attempt, &reporting)
                result = .failure(error)
            }
            finish(id, work, reporting, result: result)
        }
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

    private func finish(_ id: Int, _ work: Work, _ reporting: Reporting, result: Result<Bool, Error>) {
        watch(reporting.outcome)
        if let event = configReloadEvent(dryRun: false, error: reporting.error, configPath: reporting.path) { emit(event) }
        let next = state.applicationFinished(id)
        self.work.removeValue(forKey: id)
        applications.removeValue(forKey: id)
        work.completion.resume(returning: .init(result: result, text: reporting.text))
        if let next { start(next) } else { becameIdle() }
    }

    func fileChanged() async {
        guard saves.runtimeReady() else { savedDuringStartup = true; return }
        guard let session = saves.session() else { return }
        guard saves.fileExists() else {
            report.log(.notice, "The config file is gone, so the config in effect stays")
            return
        }
        do {
            _ = try await session { @MainActor in
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

    /// The shipped-default fallback has no helper or reload event, but shares application exclusion.
    func applyStartupFallback(_ application: @MainActor () async throws -> Void) async rethrows {
        while state.applying != nil {
            await withCheckedContinuation { waitingForIdle.append($0) }
        }
        let id = state.beginFallback()
        do {
            try await ConfigReloadApplication.$current.withValue(.init(owner: ObjectIdentifier(self), attempt: id)) { @MainActor in
                try await application()
            }
        } catch {
            finishFallback(id)
            throw error
        }
        finishFallback(id)
    }

    private func finishFallback(_ id: Int) {
        if let next = state.applicationFinished(id) { start(next) } else { becameIdle() }
    }

    private func becameIdle() {
        let waiters = waitingForIdle
        waitingForIdle.removeAll()
        for waiter in waiters { waiter.resume() }
    }
}
