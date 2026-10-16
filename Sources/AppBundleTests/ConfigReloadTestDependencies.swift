import Common
import Foundation
import XCTest
@testable import AppBundle

@MainActor
final class ReloadSignal {
    private var count = 0
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []
    func send() {
        count += 1
        let ready = waiters.filter { $0.0 <= count }
        waiters.removeAll { $0.0 <= count }
        for (_, waiter) in ready { waiter.resume() }
    }
    func wait(for target: Int = 1) async {
        if count >= target { return }
        await withCheckedContinuation { waiters.append((target, $0)) }
    }
}

@MainActor
final class ReloadGate {
    let entered = ReloadSignal()
    private var suspended: CheckedContinuation<Void, Never>?
    func hold() async {
        await withCheckedContinuation { suspended = $0; entered.send() }
    }
    func release() {
        guard let suspended else { return XCTFail("ReloadGate released without suspended work") }
        self.suspended = nil
        suspended.resume()
    }
}

@MainActor
struct ReloadCandidate: ConfigReloadCandidate {
    let name: String
    var url: URL { URL(filePath: "/config/\(name).ncl") }
    var warnings: [String] = []
    var imports: [URL] { [URL(filePath: "/imports/\(name).ncl")] }
    var library: URL? { URL(filePath: "/library") }
}

@MainActor
struct ReloadTestDependencies {
    var load: @MainActor (URL?) async -> Result<ReloadCandidate, String> = { _ in
        XCTFail("Unconfigured reload adapter: load"); return .failure("unconfigured load")
    }
    var helper = ConfigReloadHelper<ReloadCandidate>(
        adopt: { _ in XCTFail("Unconfigured reload adapter: helper.adopt") },
        dispose: { _ in XCTFail("Unconfigured reload adapter: helper.dispose") },
        recordFailure: { _ in XCTFail("Unconfigured reload adapter: helper.recordFailure") },
    )
    var apply: @MainActor (ReloadCandidate) async throws -> Void = { _ in XCTFail("Unconfigured reload adapter: apply") }
    var report = ConfigReloadReport(
        show: { _ in XCTFail("Unconfigured reload adapter: report.show") },
        clear: { XCTFail("Unconfigured reload adapter: report.clear") },
        log: { _, _ in XCTFail("Unconfigured reload adapter: report.log") },
    )
    var watch: (ConfigLoadOutcome) -> Void = { _ in XCTFail("Unconfigured reload adapter: watch") }
    var emit: (ServerEvent) -> Void = { _ in XCTFail("Unconfigured reload adapter: emit") }
    var saves = ConfigReloadSaves(
        runtimeReady: { XCTFail("Unconfigured reload adapter: saves.runtimeReady"); return false },
        fileExists: { XCTFail("Unconfigured reload adapter: saves.fileExists"); return false },
        session: { XCTFail("Unconfigured reload adapter: saves.session"); return nil },
    )
    var configPath: () -> String = { XCTFail("Unconfigured reload adapter: configPath"); return "/unconfigured" }

    func owner() -> ConfigReloader<ReloadCandidate> {
        ConfigReloader(load: load, helper: helper, apply: apply, report: report, watch: watch, emit: emit, saves: saves, configPath: configPath)
    }
}

@MainActor
final class ReloadProbe {
    let loadsStarted = ReloadSignal()
    let loadsFinished = ReloadSignal()
    let applications = ReloadSignal()
    let completions = ReloadSignal()
    var loadGates: [String: ReloadGate] = [:]
    var applyGates: [String: ReloadGate] = [:]
    var failures: [String: String] = [:]
    var warnings: [String: [String]] = [:]
    var applyFailure: Error?
    var duringApply: (@MainActor (ReloadCandidate) async throws -> Void)?
    var adopted: [String] = []
    var disposed: [String] = []
    var activeHelper = "serving"
    var activeConfig = "serving"
    var watchedImports = [URL(filePath: "/imports/serving.ncl")]
    var watchedLibrary: URL?
    var watches = 0
    var events: [ServerEvent] = []
    var shown: [String] = []
    var notification: String?
    var clears = 0
    var recordedFailures: [String] = []
    var logs: [String] = []
    var runtimeReady = true
    var enabled = true
    var exists = true
    var sessions = 0
    var nextSave = "save"
    var runningApplications = 0
    var overlapped = false

    func owner() -> ConfigReloader<ReloadCandidate> {
        var dependencies = ReloadTestDependencies()
        dependencies.load = { url in
            let name = url?.deletingPathExtension().lastPathComponent ?? self.nextSave
            self.loadsStarted.send()
            await self.loadGates[name]?.hold()
            self.loadsFinished.send()
            if let failure = self.failures[name] { return .failure(failure) }
            return .success(ReloadCandidate(name: name, warnings: self.warnings[name] ?? []))
        }
        dependencies.helper = .init(
            adopt: { self.adopted.append($0.name); self.activeHelper = $0.name },
            dispose: { self.disposed.append($0.name) },
            recordFailure: { self.recordedFailures.append($0) },
        )
        dependencies.apply = { candidate in
            self.runningApplications += 1
            self.overlapped = self.overlapped || self.runningApplications > 1
            self.applications.send()
            defer { self.runningApplications -= 1 }
            await self.applyGates[candidate.name]?.hold()
            try await self.duringApply?(candidate)
            self.activeConfig = candidate.name
            if let error = self.applyFailure { throw error }
        }
        dependencies.report = .init(
            show: { self.shown.append($0); self.notification = $0 },
            clear: { self.clears += 1; self.notification = nil },
            log: { _, text in self.logs.append(text) },
        )
        dependencies.watch = { outcome in
            self.watches += 1
            if case .loaded(let imports, let library) = outcome {
                self.watchedImports = imports
                self.watchedLibrary = library
            }
        }
        dependencies.emit = { self.events.append($0); self.completions.send() }
        dependencies.saves = .init(
            runtimeReady: { self.runtimeReady }, fileExists: { self.exists },
            session: {
                guard self.enabled else { return nil }
                return { operation in self.sessions += 1; return try await operation() }
            },
        )
        dependencies.configPath = { "/config/requested.ncl" }
        return dependencies.owner()
    }
}
