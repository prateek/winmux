import Clocks
import Foundation
import XCTest
@testable import AppBundle

private enum ReloadCaller {
    @TaskLocal static var name: String?
}

private enum ReloadTestError: LocalizedError {
    case apply
    var errorDescription: String? { "test application failed" }
}

@MainActor
final class ConfigReloaderTest: SerialClockTestCase {
    private func request(_ owner: ConfigReloader<ReloadCandidate>, _ name: String, dry: Bool = false, noGui: Bool = false, trigger: ConfigReloadTrigger = .command) async -> ConfigReloadCompletion {
        await owner.request(forceConfigUrl: URL(filePath: "/config/\(name).ncl"), dryRun: dry, noGui: noGui, trigger: trigger)
    }

    private func assertEvent(_ event: ServerEvent, path: String, error: String? = nil, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(event.eventType, .configReloaded, file: file, line: line)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any])
        XCTAssertEqual(payload["configPath"] as? String, path, file: file, line: line)
        XCTAssertEqual(payload["ok"] as? Bool, error == nil, file: file, line: line)
        if let error { XCTAssertEqual(payload["error"] as? String, error, file: file, line: line) }
        else { XCTAssertTrue(payload["error"] is NSNull, file: file, line: line) }
    }

    private func assertServing(_ probe: ReloadProbe, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(probe.activeConfig, name, file: file, line: line)
        XCTAssertEqual(probe.activeHelper, name, file: file, line: line)
        XCTAssertEqual(probe.watchedImports, [URL(filePath: "/imports/\(name).ncl")], file: file, line: line)
    }

    private func assertSuperseded(firstFinishesBeforeSecond: Bool, olderFailure: Bool = false) async throws {
        let probe = ReloadProbe()
        let owner = probe.owner()
        let aGate = ReloadGate(), bGate = ReloadGate()
        probe.loadGates = ["a": aGate, "b": bGate]
        probe.warnings["a"] = ["superseded warning must be silent"]
        if olderFailure { probe.failures["a"] = "old error" }
        let a = Task { await self.request(owner, "a") }
        await aGate.entered.wait()
        let b = Task { await self.request(owner, "b") }
        await bGate.entered.wait()
        if firstFinishesBeforeSecond {
            aGate.release()
            let completion = await a.value
            XCTAssertFalse(try completion.result.get())
            assertServing(probe, "serving")
            XCTAssertTrue(probe.events.isEmpty, "superseded reload must not emit")
            XCTAssertEqual(probe.watches, 0, "superseded reload must not sync the watcher")
            bGate.release()
        } else {
            bGate.release()
            let completion = await b.value
            XCTAssertTrue(try completion.result.get())
            aGate.release()
        }
        let aResult = await a.value, bResult = await b.value
        XCTAssertFalse(try aResult.result.get())
        XCTAssertEqual(aResult.text, "A later reload replaced this one")
        XCTAssertTrue(try bResult.result.get())
        XCTAssertEqual(bResult.text, "")
        assertServing(probe, "b")
        XCTAssertEqual(probe.adopted, ["b"])
        XCTAssertEqual(probe.disposed, olderFailure ? [] : ["a"])
        XCTAssertEqual(probe.events.count, 1, "superseded reload must not emit")
        try assertEvent(probe.events[0], path: "/config/b.ncl")
        XCTAssertEqual(probe.watches, 1, "superseded reload must not sync the watcher")
        XCTAssertTrue(probe.shown.isEmpty)
        XCTAssertTrue(probe.recordedFailures.isEmpty)
    }

    func testSupersededReloadEmitsNothingAfterNewerReloadCompletes() async throws {
        try await assertSuperseded(firstFinishesBeforeSecond: false)
    }
    func testSupersededReloadEmitsNothingWhileNewerReloadIsLoading() async throws {
        try await assertSuperseded(firstFinishesBeforeSecond: true)
    }
    func testOlderFailureCannotReplaceNewerSuccessInEitherCompletionOrder() async throws {
        for olderFirst in [true, false] { try await assertSuperseded(firstFinishesBeforeSecond: olderFirst, olderFailure: true) }
    }

    func testDryRunDoesNotOvertakeSuspendedReload() async throws {
        let probe = ReloadProbe(), gate = ReloadGate()
        let owner = probe.owner()
        probe.loadGates["ordinary"] = gate
        probe.warnings["dry"] = ["one", "two"]
        let ordinary = Task { await self.request(owner, "ordinary") }
        await gate.entered.wait()
        let dry = await request(owner, "dry", dry: true)
        XCTAssertTrue(try dry.result.get())
        XCTAssertEqual(dry.text, "warning: one\nwarning: two\n")
        assertServing(probe, "serving")
        XCTAssertTrue(probe.events.isEmpty)
        XCTAssertEqual(probe.watches, 0)
        gate.release()
        let result = await ordinary.value
        XCTAssertTrue(try result.result.get())
        XCTAssertEqual(result.text, "")
        assertServing(probe, "ordinary")
        XCTAssertEqual(probe.adopted, ["ordinary"])
        XCTAssertEqual(probe.disposed, ["dry"])
        XCTAssertEqual(probe.events.count, 1)
        try assertEvent(probe.events[0], path: "/config/ordinary.ncl")
    }

    func testSuspendedDryRunIsNotOvertakenByOrdinaryReload() async throws {
        let probe = ReloadProbe(), gate = ReloadGate()
        let owner = probe.owner()
        probe.loadGates["dry"] = gate
        let dry = Task { await self.request(owner, "dry", dry: true) }
        await gate.entered.wait()
        let ordinary = await request(owner, "ordinary")
        XCTAssertTrue(try ordinary.result.get())
        gate.release()
        let result = await dry.value
        XCTAssertTrue(try result.result.get())
        XCTAssertEqual(result.text, "")
        assertServing(probe, "ordinary")
        XCTAssertEqual(probe.adopted, ["ordinary"])
        XCTAssertEqual(probe.disposed, ["dry"])
        XCTAssertEqual(probe.watches, 1)
        XCTAssertEqual(probe.events.count, 1)
        try assertEvent(probe.events[0], path: "/config/ordinary.ncl")
    }

    func testOrdinarySuccessAndLoadFailureEmitAndSyncOnce() async throws {
        for succeeds in [true, false] {
            let probe = ReloadProbe()
            let owner = probe.owner()
            if !succeeds { probe.failures["loaded"] = "failed to load" }
            probe.warnings["loaded"] = ["first warning", "second warning"]
            probe.nextSave = "loaded"
            let result = await owner.request()
            XCTAssertEqual(try result.result.get(), succeeds)
            XCTAssertEqual(result.text, succeeds ? "warning: first warning\nwarning: second warning\n" : "failed to load")
            assertServing(probe, succeeds ? "loaded" : "serving")
            XCTAssertEqual(probe.adopted, succeeds ? ["loaded"] : [])
            XCTAssertTrue(probe.disposed.isEmpty)
            XCTAssertEqual(probe.watches, 1)
            XCTAssertEqual(probe.events.count, 1)
            try assertEvent(probe.events[0], path: succeeds ? "/config/loaded.ncl" : "/config/requested.ncl", error: succeeds ? nil : "failed to load")
            XCTAssertEqual(probe.shown, succeeds ? [] : ["failed to load"])
            XCTAssertEqual(probe.recordedFailures, succeeds ? [] : ["failed to load"])
            XCTAssertEqual(probe.clears, succeeds ? 1 : 0)
            if succeeds { XCTAssertEqual(probe.watchedLibrary, URL(filePath: "/library")) }
        }
    }

    func testThrowingApplicationEmitsAndSyncsBeforeReturningError() async throws {
        let probe = ReloadProbe()
        let owner = probe.owner()
        probe.applyFailure = ReloadTestError.apply
        probe.warnings["loaded"] = ["warning before error"]
        let result = await request(owner, "loaded")
        let diagnostic = "Loaded /config/loaded.ncl, but applying it failed: test application failed"
        XCTAssertEqual(result.text, "warning: warning before error\n" + diagnostic)
        do { _ = try result.result.get(); XCTFail("expected apply error") } catch ReloadTestError.apply {}
        assertServing(probe, "loaded")
        XCTAssertEqual(probe.adopted, ["loaded"])
        XCTAssertTrue(probe.disposed.isEmpty)
        XCTAssertEqual(probe.watchedLibrary, URL(filePath: "/library"))
        XCTAssertEqual(probe.events.count, 1)
        try assertEvent(probe.events[0], path: "/config/loaded.ncl", error: diagnostic)
        XCTAssertEqual(probe.recordedFailures, [diagnostic])
        XCTAssertEqual(probe.shown, [diagnostic])
        probe.applyFailure = nil
        let recovered = await request(owner, "recovered")
        XCTAssertTrue(try recovered.result.get())
        XCTAssertEqual(recovered.text, "")
        assertServing(probe, "recovered")
        XCTAssertNil(probe.notification)
        XCTAssertEqual(probe.events.count, 2)
    }

    func testRequestDuringSuspendedApplicationCompletesInRequestOrder() async throws {
        let probe = ReloadProbe(), gate = ReloadGate()
        let owner = probe.owner()
        probe.applyGates["a"] = gate
        let a = Task { await self.request(owner, "a") }
        await gate.entered.wait()
        let b = Task { await self.request(owner, "b") }
        await probe.loadsFinished.wait(for: 2)
        await TestClock<Duration>().advance()
        XCTAssertEqual(probe.adopted, ["a"], "B must remain pending until A completes")
        XCTAssertEqual(probe.activeHelper, "a")
        XCTAssertEqual(probe.activeConfig, "serving")
        XCTAssertTrue(probe.events.isEmpty)
        gate.release()
        let aResult = await a.value, bResult = await b.value
        XCTAssertTrue(try aResult.result.get())
        XCTAssertTrue(try bResult.result.get())
        XCTAssertEqual([aResult.text, bResult.text], ["", ""])
        XCTAssertFalse(probe.overlapped, "applications must never overlap")
        assertServing(probe, "b")
        XCTAssertEqual(probe.adopted, ["a", "b"])
        XCTAssertTrue(probe.disposed.isEmpty)
        XCTAssertEqual(probe.watches, 2)
        XCTAssertEqual(probe.events.count, 2)
        try assertEvent(probe.events[0], path: "/config/a.ncl")
        try assertEvent(probe.events[1], path: "/config/b.ncl")
    }

    func testNewestRequestSupersedesPendingCandidateEvenWhileItIsStillLoading() async throws {
        let probe = ReloadProbe(), applyGate = ReloadGate(), loadGate = ReloadGate()
        let owner = probe.owner()
        probe.applyGates["a"] = applyGate
        probe.loadGates["c"] = loadGate
        let a = Task { await self.request(owner, "a") }
        await applyGate.entered.wait()
        let b = Task { await self.request(owner, "b") }
        await probe.loadsFinished.wait(for: 2)
        let c = Task { await self.request(owner, "c") }
        await loadGate.entered.wait()
        let bResult = await b.value
        XCTAssertFalse(try bResult.result.get())
        XCTAssertEqual(bResult.text, "A later reload replaced this one")
        XCTAssertEqual(probe.disposed, ["b"])
        XCTAssertEqual(probe.adopted, ["a"])
        XCTAssertTrue(probe.events.isEmpty)
        applyGate.release()
        let aResult = await a.value
        XCTAssertTrue(try aResult.result.get())
        assertServing(probe, "a")
        loadGate.release()
        let cResult = await c.value
        XCTAssertTrue(try cResult.result.get())
        XCTAssertEqual(cResult.text, "")
        assertServing(probe, "c")
        XCTAssertEqual(probe.adopted, ["a", "c"])
        XCTAssertEqual(probe.events.count, 2)
        try assertEvent(probe.events[0], path: "/config/a.ncl")
        try assertEvent(probe.events[1], path: "/config/c.ncl")
        XCTAssertEqual(probe.watches, 2)
        XCTAssertFalse(probe.overlapped)
    }

    func testNewerLoadedCandidateReplacesPendingFailureWhileApplicationIsSuspended() async throws {
        let probe = ReloadProbe(), gate = ReloadGate()
        let owner = probe.owner()
        probe.applyGates["a"] = gate
        probe.failures["b"] = "pending error must stay silent"
        let a = Task { await self.request(owner, "a") }
        await gate.entered.wait()
        let b = Task { await self.request(owner, "b") }
        await probe.loadsFinished.wait(for: 2)
        let c = Task { await self.request(owner, "c") }
        await probe.loadsFinished.wait(for: 3)
        let bResult = await b.value
        XCTAssertFalse(try bResult.result.get())
        XCTAssertEqual(bResult.text, "A later reload replaced this one")
        XCTAssertEqual(probe.adopted, ["a"])
        XCTAssertTrue(probe.shown.isEmpty)
        XCTAssertTrue(probe.recordedFailures.isEmpty)
        XCTAssertTrue(probe.events.isEmpty)
        gate.release()
        let aResult = await a.value, cResult = await c.value
        XCTAssertTrue(try aResult.result.get())
        XCTAssertTrue(try cResult.result.get())
        XCTAssertEqual([aResult.text, cResult.text], ["", ""])
        assertServing(probe, "c")
        XCTAssertEqual(probe.adopted, ["a", "c"])
        XCTAssertTrue(probe.disposed.isEmpty)
        XCTAssertEqual(probe.watches, 2)
        XCTAssertEqual(probe.events.count, 2)
        try assertEvent(probe.events[0], path: "/config/a.ncl")
        try assertEvent(probe.events[1], path: "/config/c.ncl")
        XCTAssertFalse(probe.overlapped)
    }

    func testFailedNewestLoadWaitsForApplicationButDryRunsDoNot() async throws {
        let probe = ReloadProbe(), gate = ReloadGate()
        let owner = probe.owner()
        probe.applyGates["a"] = gate
        probe.failures["bad"] = "broken"
        probe.failures["dryBad"] = "dry error"
        let a = Task { await self.request(owner, "a") }
        await gate.entered.wait()
        let bad = Task { await self.request(owner, "bad") }
        await probe.loadsFinished.wait(for: 2)
        let dry = await request(owner, "dry", dry: true)
        let dryBad = await request(owner, "dryBad", dry: true)
        XCTAssertTrue(try dry.result.get())
        XCTAssertFalse(try dryBad.result.get())
        XCTAssertEqual(dryBad.text, "dry error")
        XCTAssertEqual(probe.shown, ["dry error"])
        XCTAssertTrue(probe.recordedFailures.isEmpty)
        XCTAssertEqual(probe.disposed, ["dry"])
        XCTAssertTrue(probe.events.isEmpty)
        XCTAssertEqual(probe.watches, 0)
        gate.release()
        let aResult = await a.value, badResult = await bad.value
        XCTAssertTrue(try aResult.result.get())
        XCTAssertFalse(try badResult.result.get())
        XCTAssertEqual(badResult.text, "broken")
        assertServing(probe, "a")
        XCTAssertEqual(probe.shown, ["dry error", "broken"])
        XCTAssertEqual(probe.recordedFailures, ["broken"])
        XCTAssertEqual(probe.adopted, ["a"])
        XCTAssertEqual(probe.watches, 2)
        XCTAssertEqual(probe.events.count, 2)
        try assertEvent(probe.events[0], path: "/config/a.ncl")
        try assertEvent(probe.events[1], path: "/config/bad.ncl", error: "broken")
    }

    func testIdenticalFailedSavesDeduplicateNotificationAndSuccessResetsIt() async throws {
        let probe = ReloadProbe()
        let owner = probe.owner()
        probe.failures["bad"] = "closure@0xabc failure"
        let first = await request(owner, "bad", trigger: .fileChange)
        probe.failures["bad"] = "closure@0xdef failure"
        let second = await request(owner, "bad", trigger: .fileChange)
        XCTAssertFalse(try first.result.get())
        XCTAssertFalse(try second.result.get())
        XCTAssertEqual(first.text, "closure@0xabc failure")
        XCTAssertEqual(second.text, "closure@0xdef failure")
        XCTAssertEqual(probe.shown, [first.text])
        XCTAssertEqual(probe.recordedFailures, [first.text, second.text])
        assertServing(probe, "serving")
        XCTAssertEqual(probe.watches, 2)
        XCTAssertEqual(probe.events.count, 2)
        try assertEvent(probe.events[0], path: "/config/bad.ncl", error: first.text)
        try assertEvent(probe.events[1], path: "/config/bad.ncl", error: second.text)
        let good = await request(owner, "good")
        XCTAssertTrue(try good.result.get())
        XCTAssertNil(probe.notification)
        assertServing(probe, "good")
        _ = await request(owner, "bad", trigger: .fileChange)
        XCTAssertEqual(probe.shown, [first.text, second.text])
        _ = await request(owner, "bad", noGui: true)
        XCTAssertEqual(probe.shown.count, 2)
        _ = await request(owner, "bad")
        XCTAssertEqual(probe.shown, [first.text, second.text, second.text], "explicit commands always notify")
        XCTAssertEqual(probe.events.count, 6)
        XCTAssertEqual(probe.watches, 6)
        XCTAssertEqual(probe.adopted, ["good"])
        XCTAssertTrue(probe.disposed.isEmpty)
    }

    func testReloadRequestedFromItsOwnApplicationIsRejectedWithoutStrandingEitherCaller() async throws {
        let probe = ReloadProbe(), gate = ReloadGate()
        let owner = probe.owner()
        var nested: ConfigReloadCompletion?
        var nestedTask: Task<Void, Never>?
        probe.duringApply = { candidate in
            if candidate.name != "a" { return }
            nestedTask = Task { @MainActor in nested = await self.request(owner, "nested") }
            await gate.hold()
        }
        let a = Task { await self.request(owner, "a") }
        await gate.entered.wait()
        await TestClock<Duration>().advance()
        XCTAssertNotNil(nested, "a hook must not wait for its own application's completion")
        XCTAssertEqual(probe.adopted, ["a"])
        gate.release()
        let aResult = await a.value
        await nestedTask?.value
        XCTAssertTrue(try aResult.result.get())
        let rejected = try XCTUnwrap(nested)
        XCTAssertFalse(try rejected.result.get())
        XCTAssertEqual(rejected.text, "Cannot reload config from its own application")
        XCTAssertTrue(probe.logs.contains(rejected.text))
        assertServing(probe, "a")
        XCTAssertEqual(probe.adopted, ["a"])
        XCTAssertTrue(probe.disposed.isEmpty)
        XCTAssertTrue(probe.shown.isEmpty)
        XCTAssertEqual(probe.watches, 1)
        XCTAssertEqual(probe.events.count, 1)
        try assertEvent(probe.events[0], path: "/config/a.ncl")
    }

    func testDryRunFromAnApplyingHookRemainsIndependent() async throws {
        let probe = ReloadProbe()
        let owner = probe.owner()
        var dry: ConfigReloadCompletion?
        probe.duringApply = { candidate in
            if candidate.name == "a" { dry = await self.request(owner, "dry", dry: true) }
        }
        let a = await request(owner, "a")
        XCTAssertTrue(try a.result.get())
        let checked = try XCTUnwrap(dry)
        XCTAssertTrue(try checked.result.get())
        XCTAssertEqual(checked.text, "")
        assertServing(probe, "a")
        XCTAssertEqual(probe.adopted, ["a"])
        XCTAssertEqual(probe.disposed, ["dry"])
        XCTAssertTrue(probe.shown.isEmpty)
        XCTAssertEqual(probe.events.count, 1)
        try assertEvent(probe.events[0], path: "/config/a.ncl")
        XCTAssertEqual(probe.watches, 1)
    }

    func testStartupFallbackDoesNotReplaceAReloadThatReplacedStartup() async throws {
        let probe = ReloadProbe(), startupGate = ReloadGate(), gate = ReloadGate()
        let owner = probe.owner()
        probe.loadGates["startup"] = startupGate
        probe.applyGates["a"] = gate
        let startup = Task { await self.request(owner, "startup") }
        await startupGate.entered.wait()
        let a = Task { await self.request(owner, "a") }
        await gate.entered.wait()
        startupGate.release()
        let startupResult = await startup.value
        XCTAssertFalse(try startupResult.result.get())
        XCTAssertEqual(startupResult.text, "A later reload replaced this one")
        var fallbackRan = false
        let fallback = Task { await owner.applyStartupFallback { fallbackRan = true } }
        await TestClock<Duration>().advance()
        XCTAssertFalse(fallbackRan, "the fallback waits for the application under way")
        gate.release()
        await fallback.value
        let aResult = await a.value
        XCTAssertTrue(try aResult.result.get())
        XCTAssertFalse(fallbackRan, "the shipped defaults must not replace the reload that replaced startup's")
        assertServing(probe, "a")
        XCTAssertEqual(probe.disposed, ["startup"])
        XCTAssertEqual(probe.events.count, 1)
        try assertEvent(probe.events[0], path: "/config/a.ncl")
    }

    func testStartupFallbackAppliesAfterAFailedLoadAndSerializesReloadStartedDuringIt() async throws {
        let probe = ReloadProbe(), fallbackGate = ReloadGate()
        let owner = probe.owner()
        probe.failures["startup"] = "broken"
        let startup = await request(owner, "startup")
        XCTAssertFalse(try startup.result.get())
        let fallback = Task {
            await owner.applyStartupFallback {
                await fallbackGate.hold()
                probe.activeConfig = "defaults"
            }
        }
        await fallbackGate.entered.wait()
        let b = Task { await self.request(owner, "b") }
        await probe.loadsFinished.wait(for: 2)
        await TestClock<Duration>().advance()
        XCTAssertTrue(probe.adopted.isEmpty, "a reload waits for the fallback's application")
        XCTAssertEqual(probe.activeConfig, "serving")
        fallbackGate.release()
        await fallback.value
        let bResult = await b.value
        XCTAssertTrue(try bResult.result.get())
        assertServing(probe, "b")
        XCTAssertEqual(probe.events.count, 2)
        try assertEvent(probe.events[0], path: "/config/startup.ncl", error: "broken")
        try assertEvent(probe.events[1], path: "/config/b.ncl")
    }

    func testEachApplicationRunsInItsOwnCallersTask() async throws {
        let probe = ReloadProbe(), gate = ReloadGate()
        let owner = probe.owner()
        probe.applyGates["a"] = gate
        var callers: [String: String] = [:]
        var cancelled: [String: Bool] = [:]
        probe.duringApply = { candidate in
            callers[candidate.name] = ReloadCaller.name
            cancelled[candidate.name] = Task.isCancelled
        }
        let a = Task { await ReloadCaller.$name.withValue("A") { await self.request(owner, "a") } }
        await gate.entered.wait()
        let b = Task { await ReloadCaller.$name.withValue("B") { await self.request(owner, "b") } }
        await probe.loadsFinished.wait(for: 2)
        a.cancel()
        gate.release()
        _ = await a.value
        _ = await b.value
        XCTAssertEqual(callers, ["a": "A", "b": "B"], "a waiting attempt applies in its own caller's task, not the one before it")
        XCTAssertEqual(cancelled, ["a": true, "b": false], "cancelling a caller reaches its own application only")
        assertServing(probe, "b")
    }

    func testCallerCancelledWhileWaitingForItsTurnAdoptsNothing() async throws {
        let probe = ReloadProbe(), gate = ReloadGate()
        let owner = probe.owner()
        probe.applyGates["a"] = gate
        let a = Task { await self.request(owner, "a") }
        await gate.entered.wait()
        let b = Task { await self.request(owner, "b") }
        await probe.loadsFinished.wait(for: 2)
        b.cancel()
        gate.release()
        let aResult = await a.value, bResult = await b.value
        XCTAssertTrue(try aResult.result.get())
        XCTAssertThrowsError(try bResult.result.get()) { XCTAssertTrue($0 is CancellationError) }
        assertServing(probe, "a")
        XCTAssertEqual(probe.adopted, ["a"])
        XCTAssertEqual(probe.disposed, ["b"])
        XCTAssertEqual(probe.events.count, 1)
        try assertEvent(probe.events[0], path: "/config/a.ncl")
        let c = await request(owner, "c")
        XCTAssertTrue(try c.result.get(), "the cancelled caller releases its turn")
        assertServing(probe, "c")
    }

    func testStartupFallbackAppliesWhenTheReloadThatReplacedStartupFailedToApply() async throws {
        let probe = ReloadProbe(), startupGate = ReloadGate()
        let owner = probe.owner()
        probe.loadGates["startup"] = startupGate
        probe.applyFailure = ReloadTestError.apply
        let startup = Task { await self.request(owner, "startup") }
        await startupGate.entered.wait()
        let a = await request(owner, "a")
        XCTAssertThrowsError(try a.result.get())
        startupGate.release()
        let startupResult = await startup.value
        XCTAssertFalse(try startupResult.result.get())
        var fallbackRan = false
        await owner.applyStartupFallback { fallbackRan = true }
        XCTAssertTrue(fallbackRan, "a reload that failed to apply leaves startup's fallback to the shipped defaults")
    }
    func testCancelledWaiterReturnsBeforeApplicationAheadIsReleased() async throws {
        let probe = ReloadProbe(), gate = ReloadGate(), clock = TestClock<Duration>()
        let owner = probe.owner()
        probe.applyGates["a"] = gate
        let a = Task { await self.request(owner, "a") }
        await gate.entered.wait()
        var returned = false
        let b = Task { let result = await self.request(owner, "b"); returned = true; return result }
        await probe.loadsFinished.wait(for: 2)
        await clock.advance()
        b.cancel()
        await clock.advance()
        XCTAssertTrue(returned, "a cancelled waiter must return before the applying caller is released")
        XCTAssertEqual(probe.disposed, ["b"])
        XCTAssertEqual(probe.adopted, ["a"])
        let c = Task { await self.request(owner, "c") }
        await probe.loadsFinished.wait(for: 3)
        gate.release()
        _ = await a.value
        let cancelled = await b.value
        XCTAssertThrowsError(try cancelled.result.get()) { XCTAssertTrue($0 is CancellationError) }
        let next = await c.value
        XCTAssertTrue(try next.result.get())
        XCTAssertEqual(probe.adopted, ["a", "c"])
    }

    func testCancelledNewestReplacesSupersededSaveOnceEvenAcrossTwoCancellations() async throws {
        for cancelledCount in [1, 2] {
            let probe = ReloadProbe(), applyGate = ReloadGate(), clock = TestClock<Duration>()
            let owner = probe.owner()
            probe.applyGates["a"] = applyGate
            let a = Task { await self.request(owner, "a") }
            await applyGate.entered.wait()
            let save = Task { await owner.request(noGui: true, trigger: .fileChange) }
            await probe.loadsFinished.wait(for: 2)
            await clock.advance()
            var tasks: [Task<ConfigReloadCompletion, Never>] = []
            var gates: [ReloadGate] = []
            for index in 0 ..< cancelledCount {
                let gate = ReloadGate(), name = "new\(index)"
                gates.append(gate)
                probe.loadGates[name] = gate
                let task = Task { await self.request(owner, name) }
                tasks.append(task)
                await gate.entered.wait()
            }
            let superseded = await save.value
            XCTAssertFalse(try superseded.result.get())
            for task in tasks { task.cancel() }
            for gate in gates { gate.release() }
            for task in tasks { _ = await task.value }
            await clock.advance()
            applyGate.release()
            _ = await a.value
            await clock.advance()
            XCTAssertEqual(probe.adopted, ["a", "save"], "owner reloads current content once after the newest cancellation")
            XCTAssertEqual(probe.events.count, 2)
            XCTAssertEqual(probe.sessions, 1, "the replacement runs in the session a save runs in")
            XCTAssertEqual(probe.disposed.sorted(), (["save"] + (0 ..< cancelledCount).map { "new\($0)" }).sorted())
        }
    }

    func testReplacementIsSkippedWhileTheServerIsDisabled() async throws {
        let probe = ReloadProbe(), applyGate = ReloadGate(), newGate = ReloadGate(), clock = TestClock<Duration>()
        let owner = probe.owner()
        probe.applyGates["a"] = applyGate
        let a = Task { await self.request(owner, "a") }
        await applyGate.entered.wait()
        let save = Task { await owner.request(noGui: true, trigger: .fileChange) }
        await probe.loadsFinished.wait(for: 2)
        await clock.advance()
        probe.loadGates["new"] = newGate
        let newer = Task { await self.request(owner, "new") }
        await newGate.entered.wait()
        let superseded = await save.value
        XCTAssertFalse(try superseded.result.get())
        probe.enabled = false
        newer.cancel()
        newGate.release()
        _ = await newer.value
        await clock.advance()
        applyGate.release()
        _ = await a.value
        await clock.advance()
        XCTAssertEqual(probe.adopted, ["a"], "a disabled server takes no replacement reload, as it takes no save")
        XCTAssertEqual(probe.sessions, 0)
        XCTAssertEqual(probe.events.count, 1)
    }

    func testCancelledAttemptThatSupersededNothingStartsNoReplacement() async throws {
        let probe = ReloadProbe(), gate = ReloadGate(), clock = TestClock<Duration>()
        let owner = probe.owner()
        probe.loadGates["a"] = gate
        let a = Task { await self.request(owner, "a") }
        await gate.entered.wait()
        a.cancel()
        gate.release()
        let result = await a.value
        XCTAssertThrowsError(try result.result.get()) { XCTAssertTrue($0 is CancellationError) }
        await clock.advance()
        XCTAssertEqual(probe.disposed, ["a"])
        XCTAssertTrue(probe.adopted.isEmpty)
        XCTAssertTrue(probe.events.isEmpty)
    }

    func testApplicationCancellationAfterAdoptionReportsPartialFailureAndNextProceeds() async throws {
        let probe = ReloadProbe(), gate = ReloadGate()
        let owner = probe.owner()
        probe.applyGates["a"] = gate
        probe.duringApply = { candidate in if candidate.name == "a" { try Task.checkCancellation() } }
        let a = Task { await self.request(owner, "a") }
        await gate.entered.wait()
        a.cancel()
        gate.release()
        let result = await a.value
        XCTAssertThrowsError(try result.result.get()) { XCTAssertTrue($0 is CancellationError) }
        XCTAssertEqual(probe.activeHelper, "a")
        XCTAssertEqual(probe.watchedImports, [URL(filePath: "/imports/a.ncl")])
        XCTAssertEqual(probe.recordedFailures.count, 1)
        XCTAssertEqual(probe.shown.count, 1)
        XCTAssertEqual(probe.events.count, 1)
        XCTAssertTrue(probe.disposed.isEmpty)
        let next = await request(owner, "b")
        XCTAssertTrue(try next.result.get())
        XCTAssertEqual(probe.adopted, ["a", "b"])
    }

    func testReplacementReadsCurrentFileAndReportsItsOwnFailureWithSupersededSaveOptions() async throws {
        for noGui in [false, true] {
            let probe = ReloadProbe(), applying = ReloadGate(), loading = ReloadGate(), clock = TestClock<Duration>()
            let owner = probe.owner()
            probe.applyGates["a"] = applying
            let a = Task { await self.request(owner, "a") }
            await applying.entered.wait()
            let save = Task { await owner.request(noGui: noGui, trigger: .fileChange) }
            await probe.loadsFinished.wait(for: 2)
            await clock.advance()
            probe.loadGates["new"] = loading
            let newest = Task { await self.request(owner, "new") }
            await loading.entered.wait()
            _ = await save.value
            probe.nextSave = "latest"
            probe.failures["latest"] = "replacement load failed"
            newest.cancel()
            loading.release()
            _ = await newest.value
            await clock.advance()
            applying.release()
            _ = await a.value
            await clock.advance()
            XCTAssertEqual(probe.adopted, ["a"])
            XCTAssertEqual(probe.recordedFailures, ["replacement load failed"])
            XCTAssertEqual(probe.shown, noGui ? [] : ["replacement load failed"])
            XCTAssertTrue(probe.logs.contains { $0.contains("The config failed to load: replacement load failed") })
            XCTAssertEqual(probe.events.count, 2)
            try assertEvent(probe.events[1], path: "/config/requested.ncl", error: "replacement load failed")
        }
    }

    func testNewerOrdinaryRequestPreventsCancelledOlderFromStartingReplacement() async throws {
        let probe = ReloadProbe(), gate = ReloadGate(), clock = TestClock<Duration>()
        let owner = probe.owner()
        probe.loadGates["a"] = gate
        let a = Task { await self.request(owner, "a") }
        await gate.entered.wait()
        let newer = await request(owner, "b")
        XCTAssertTrue(try newer.result.get())
        a.cancel(); gate.release()
        _ = await a.value
        await clock.advance()
        XCTAssertEqual(probe.adopted, ["b"])
        XCTAssertEqual(probe.events.count, 1)
    }

    func testCancelledFailedLoadDoesNotReportOrNotify() async throws {
        let probe = ReloadProbe(), gate = ReloadGate()
        let owner = probe.owner()
        probe.loadGates["a"] = gate
        probe.failures["a"] = "deadline"
        let a = Task { await self.request(owner, "a") }
        await gate.entered.wait()
        a.cancel(); gate.release()
        let result = await a.value
        XCTAssertThrowsError(try result.result.get()) { XCTAssertTrue($0 is CancellationError) }
        XCTAssertTrue(probe.events.isEmpty)
        XCTAssertTrue(probe.recordedFailures.isEmpty)
        XCTAssertTrue(probe.shown.isEmpty)
    }

    func testCancelledNewestWhileWaitingStartsOneReplacementBeforeApplicationFinishes() async throws {
        let probe = ReloadProbe(), gate = ReloadGate(), clock = TestClock<Duration>()
        let owner = probe.owner()
        probe.applyGates["a"] = gate
        let a = Task { await self.request(owner, "a") }
        await gate.entered.wait()
        let save = Task { await owner.request(trigger: .fileChange) }
        await probe.loadsFinished.wait(for: 2)
        await clock.advance()
        var returned = false
        let newest = Task { let result = await self.request(owner, "new"); returned = true; return result }
        await probe.loadsFinished.wait(for: 3)
        await clock.advance()
        _ = await save.value
        newest.cancel()
        await clock.advance()
        XCTAssertTrue(returned)
        XCTAssertEqual(probe.disposed, ["save", "new"])
        gate.release()
        _ = await a.value
        _ = await newest.value
        await clock.advance()
        XCTAssertEqual(probe.adopted, ["a", "save"])
        XCTAssertEqual(probe.events.count, 2)
    }

}
