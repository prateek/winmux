import Foundation
import XCTest
@testable import AppBundle

@MainActor
private final class ReloadLoadGate {
    private var suspended: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?

    func load() async {
        await withCheckedContinuation { continuation in
            suspended = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilLoading() async {
        if suspended != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func resume() {
        guard let suspended else { return XCTFail("resumed a load that is not suspended") }
        suspended.resume()
        self.suspended = nil
    }
}

private enum ReloadTestError: Error { case apply }

@MainActor
private final class ReloadAttemptRecorder {
    let path: String
    var events: [ServerEvent] = []
    var watched: [ConfigLoadOutcome] = []
    var overtaken = false
    var ranRest = false
    var diagnostic: String?
    var succeeds = true
    var throwsOnApply = false
    let imports = [URL(filePath: "/config/import.ncl")]
    let library = URL(filePath: "/config/library")

    init(_ path: String) { self.path = path }

    func run(_ sequence: ConfigReloadSequence, dryRun: Bool = false, gate: ReloadLoadGate? = nil) async throws -> Bool {
        try await sequence.run(
            dryRun: dryRun,
            configPath: "/config/requested.ncl",
            load: { await gate?.load() },
            overtaken: { _ in self.overtaken = true; return false },
            rest: { _, result in
                self.ranRest = true
                result.eventError = self.diagnostic
                if self.succeeds {
                    result.eventPath = self.path
                    if !dryRun { result.outcome = .loaded(imports: self.imports, library: self.library) }
                }
                if self.throwsOnApply { throw ReloadTestError.apply }
                return self.succeeds
            },
            syncWatcher: { self.watched.append($0) },
            emit: { self.events.append($0) },
        )
    }
}

@MainActor
final class ConfigReloadSequenceTest: SerialClockTestCase {
    func testCharacterizeApplicationOverlapOnBase() async throws {
        let sequence = ConfigReloadSequence()
        let gate = ReloadLoadGate()
        var adopted = ""
        var applied = ""
        var events: [String] = []
        func attempt(_ name: String, suspend: Bool) async throws -> Bool {
            try await sequence.run(dryRun: false, configPath: name, load: { name }, overtaken: { _ in false }, rest: { _, result in
                adopted = name
                if suspend { await gate.load() }
                applied = name
                return true
            }, syncWatcher: { _ in }, emit: { _ in events.append(name) })
        }
        let a = Task { try await attempt("A", suspend: true) }
        await gate.waitUntilLoading()
        let b = try await attempt("B", suspend: false)
        XCTAssertEqual(adopted, "B")
        XCTAssertEqual(applied, "B")
        gate.resume()
        let aResult = try await a.value
        XCTAssertTrue(aResult)
        XCTAssertTrue(b)
        XCTAssertEqual(adopted, "B")
        XCTAssertEqual(applied, "A")
        XCTAssertEqual(events, ["B", "A"])
        print("BASE CHARACTERIZATION: helper B adopted; application ends A; events B,A; callers A=true B=true")
    }

    private func assertEvent(_ attempt: ReloadAttemptRecorder, path: String, error: String? = nil, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(attempt.events.map(\.eventType), [.configReloaded], file: file, line: line)
        let event = try XCTUnwrap(attempt.events.first, file: file, line: line)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any])
        XCTAssertEqual(payload["configPath"] as? String, path, file: file, line: line)
        XCTAssertEqual(payload["ok"] as? Bool, error == nil, file: file, line: line)
        if let error {
            XCTAssertEqual(payload["error"] as? String, error, file: file, line: line)
        } else {
            XCTAssertTrue(payload["error"] is NSNull, file: file, line: line)
        }
    }

    private func assertSuperseded(firstFinishesBeforeSecond: Bool) async throws {
        let sequence = ConfigReloadSequence()
        let a = ReloadAttemptRecorder("/config/a.ncl")
        let b = ReloadAttemptRecorder("/config/b.ncl")
        let aGate = ReloadLoadGate()
        let bGate = ReloadLoadGate()
        let first = Task { try await a.run(sequence, gate: aGate) }
        await aGate.waitUntilLoading()
        let second = Task { try await b.run(sequence, gate: bGate) }
        await bGate.waitUntilLoading()
        if firstFinishesBeforeSecond {
            aGate.resume()
            let result = try await first.value
            XCTAssertFalse(result)
            bGate.resume()
        } else {
            bGate.resume()
            let result = try await second.value
            XCTAssertTrue(result)
            aGate.resume()
        }
        let aResult = try await first.value
        let bResult = try await second.value
        XCTAssertFalse(aResult)
        XCTAssertTrue(bResult)
        XCTAssertTrue(a.overtaken)
        XCTAssertFalse(a.ranRest)
        XCTAssertTrue(a.events.isEmpty, "superseded reload must not emit")
        XCTAssertTrue(a.watched.isEmpty, "superseded reload must not sync the watcher")
        XCTAssertFalse(b.overtaken)
        XCTAssertTrue(b.ranRest)
        try assertEvent(b, path: b.path)
        XCTAssertEqual(b.watched.count, 1)
    }

    func testSupersededReloadEmitsNothingAfterNewerReloadCompletes() async throws {
        try await assertSuperseded(firstFinishesBeforeSecond: false)
    }

    func testSupersededReloadEmitsNothingWhileNewerReloadIsLoading() async throws {
        try await assertSuperseded(firstFinishesBeforeSecond: true)
    }

    func testDryRunDoesNotOvertakeSuspendedReload() async throws {
        let sequence = ConfigReloadSequence()
        let ordinary = ReloadAttemptRecorder("/config/ordinary.ncl")
        let dry = ReloadAttemptRecorder("/config/dry.ncl")
        let gate = ReloadLoadGate()
        let task = Task { try await ordinary.run(sequence, gate: gate) }
        await gate.waitUntilLoading()
        let dryResult = try await dry.run(sequence, dryRun: true)
        XCTAssertTrue(dryResult)
        gate.resume()
        let result = try await task.value
        XCTAssertTrue(result)
        XCTAssertFalse(ordinary.overtaken)
        try assertEvent(ordinary, path: ordinary.path)
        XCTAssertTrue(dry.ranRest)
        XCTAssertTrue(dry.events.isEmpty)
        XCTAssertTrue(dry.watched.isEmpty)
    }

    func testSuspendedDryRunIsNotOvertakenByOrdinaryReload() async throws {
        let sequence = ConfigReloadSequence()
        let dry = ReloadAttemptRecorder("/config/dry.ncl")
        let ordinary = ReloadAttemptRecorder("/config/ordinary.ncl")
        let gate = ReloadLoadGate()
        let task = Task { try await dry.run(sequence, dryRun: true, gate: gate) }
        await gate.waitUntilLoading()
        let result = try await ordinary.run(sequence)
        XCTAssertTrue(result)
        gate.resume()
        let dryResult = try await task.value
        XCTAssertTrue(dryResult)
        XCTAssertFalse(dry.overtaken)
        XCTAssertTrue(dry.ranRest)
        XCTAssertTrue(dry.events.isEmpty)
        XCTAssertTrue(dry.watched.isEmpty)
        try assertEvent(ordinary, path: ordinary.path)
    }

    func testOrdinarySuccessAndLoadFailureEmitAndSyncOnce() async throws {
        for succeeds in [true, false] {
            let attempt = ReloadAttemptRecorder("/config/loaded.ncl")
            attempt.succeeds = succeeds
            attempt.diagnostic = succeeds ? nil : "failed to load"
            let result = try await attempt.run(ConfigReloadSequence())
            XCTAssertEqual(result, succeeds)
            try assertEvent(attempt, path: succeeds ? attempt.path : "/config/requested.ncl", error: attempt.diagnostic)
            XCTAssertEqual(attempt.watched.count, 1)
            switch try XCTUnwrap(attempt.watched.first) {
                case .loaded(let imports, let library):
                    XCTAssertTrue(succeeds)
                    XCTAssertEqual(imports, attempt.imports)
                    XCTAssertEqual(library, attempt.library)
                case .failed: XCTAssertFalse(succeeds)
            }
        }
    }

    func testThrowingRestEmitsAndSyncsBeforeRethrowing() async throws {
        let attempt = ReloadAttemptRecorder("/config/loaded.ncl")
        attempt.throwsOnApply = true
        attempt.diagnostic = "loaded, but applying failed"
        do {
            _ = try await attempt.run(ConfigReloadSequence())
            XCTFail("expected apply error")
        } catch ReloadTestError.apply {
            try assertEvent(attempt, path: attempt.path, error: attempt.diagnostic)
            XCTAssertEqual(attempt.watched.count, 1)
            guard case .loaded(let imports, let library) = attempt.watched[0] else { return XCTFail("must watch loaded helper after a throw") }
            XCTAssertEqual(imports, attempt.imports)
            XCTAssertEqual(library, attempt.library)
        }
    }
}
