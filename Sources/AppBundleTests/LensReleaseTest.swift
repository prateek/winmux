@testable import AppBundle
import AppKit
import Clocks
import Common
import XCTest

@MainActor
final class LensReleaseTest: SerialClockTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }
    private func held(delay: Int = 100) -> Mode {
        var mode = Mode.zero; mode.lifetime = .held; mode.unbound = .latch; mode.drawDelay = delay
        mode.onEnter = ["lens recent"]; mode.onRelease = ["lens focus", "mode main"]
        return mode
    }
    func testHeldReleaseRunsOnReleaseOnceAndReturnsMain() async throws {
        let engine = ModeEngine(liveModifiers: { .command }); var commands: [String] = []
        engine.execute = {
            commands += $0.map { $0.args.description }
            if $0.contains(where: { $0.args.description == "lens recent" }) { engine.lensOpening() }
        }
        try await engine.enter("cmd-tab", mode: held(delay: 0), invocation: .init(keyCode: 48, invoking: .command))
        await engine.lensReady(show: {}, flags: .command)
        await engine.observeModifiers([.command, .shift]); XCTAssertEqual(commands, ["lens recent"])
        await engine.observeModifiers(.shift); await engine.observeModifiers([])
        XCTAssertEqual(commands, ["lens recent", "lens focus", "mode main"])
        XCTAssertEqual(engine.current, "main")
    }
    func testLatchMakesLaterReleaseRunNothingAndNoStackIsRetained() async throws {
        let engine = ModeEngine(liveModifiers: { .command }); var commands: [String] = []
        engine.execute = { commands += $0.map { $0.args.description } }
        try await engine.enter("cmd-tab", mode: held(delay: 0), invocation: .init(keyCode: 48, invoking: .command))
        var browse = Mode.zero; browse.unbound = .consume
        try await engine.enter("browse", mode: browse)
        await engine.observeModifiers([])
        XCTAssertEqual(commands, ["lens recent"])
        XCTAssertEqual(engine.current, "browse")
    }
    func testQuickTapBeforeReadyNeverDrawsAndCommitsOnlyWhenReady() async throws {
        let clock = TestClock(); let engine = ModeEngine(clock: clock, liveModifiers: { .command })
        var commands: [String] = []; var shown = 0
        engine.execute = {
            commands += $0.map { $0.args.description }
            if $0.contains(where: { $0.args.description == "lens recent" }) { engine.lensOpening() }
            if $0.contains(where: { $0.args.description == "lens focus" }) { engine.lensClosed() }
        }
        try await engine.enter("cmd-tab", mode: held(), invocation: .init(keyCode: 48, invoking: .command))
        engine.lensOpening()
        await engine.observeModifiers([])
        XCTAssertEqual(commands, ["lens recent"])
        await engine.lensReady(show: { shown += 1 }, flags: [])
        XCTAssertEqual(commands, ["lens recent", "lens focus", "mode main"])
        XCTAssertEqual(shown, 0)
        await clock.advance(by: .seconds(1))
        XCTAssertEqual(shown, 0)
    }
    func testDrawDelayUsesInjectedClockAndReplacementCancelsOldDeadline() async throws {
        let clock = TestClock(); let engine = ModeEngine(clock: clock, liveModifiers: { .command })
        engine.execute = { _ in engine.lensOpening() }
        var shown = 0
        try await engine.enter("held", mode: held(), invocation: .init(keyCode: 48, invoking: .command))
        engine.lensOpening()
        await engine.lensReady(show: { shown += 1 }, flags: .command)
        await clock.advance(by: .milliseconds(99)); XCTAssertEqual(shown, 0)
        try await engine.enter("browse", mode: .zero)
        await clock.advance(by: .seconds(1)); XCTAssertEqual(shown, 0)
    }
    func testStayingReleaseAndCLIEntryHaveNoCommittingDelay() async throws {
        let engine = ModeEngine(liveModifiers: { .option }); var commands: [String] = []
        engine.execute = {
            commands += $0.map { $0.args.description }
            if $0.contains(where: { $0.args.description == "lens recent" }) { engine.lensOpening() }
        }
        var mode = held(delay: 0); mode.onRelease = ["mode search"]
        try await engine.enter("search-hold", mode: mode, invocation: .init(keyCode: 44, invoking: .option))
        await engine.lensReady(show: {}, flags: .option)
        await engine.observeModifiers([])
        XCTAssertEqual(commands, ["lens recent", "mode search"])
        commands = []
        try await engine.enter("cmd-tab", mode: held(), cli: true)
        XCTAssertTrue(engine.entryModifiers.isEmpty)
        await engine.observeModifiers([])
        XCTAssertEqual(commands, ["lens recent"])
    }
    func testShiftOnlyLifetimeWaitsForShiftAndMultiModifierWaitsForAll() async throws {
        for entry: NSEvent.ModifierFlags in [.shift, [.command, .option]] {
            let engine = ModeEngine(liveModifiers: { entry }); var releases = 0
            var mode = held(delay: 0); mode.onEnter = []
            engine.execute = { if !$0.isEmpty { releases += 1 } }
            try await engine.enter("held", mode: mode, invocation: .init(keyCode: 4, invoking: entry))
            await engine.observeModifiers(entry)
            XCTAssertEqual(releases, 0)
            if entry.contains(.command) { await engine.observeModifiers(.option); XCTAssertEqual(releases, 0) }
            await engine.observeModifiers([])
            XCTAssertEqual(releases, 1)
        }
    }
    func testOpeningQueuesActionsInOrderAndClosingDropsOnlyOldOpeningActions() async throws {
        let engine = ModeEngine(); var actions: [Int] = []
        engine.lensOpening()
        engine.whenLensReady { actions.append(1) }; engine.whenLensReady { actions.append(2) }
        XCTAssertTrue(actions.isEmpty)
        await engine.lensReady(show: { actions.append(3) }, flags: [])
        XCTAssertEqual(actions, [1,2,3])
        engine.lensOpening(); engine.whenLensReady { actions.append(4) }; engine.lensClosed()
        await engine.lensReady(show: {}, flags: [])
        XCTAssertEqual(actions, [1,2,3])
    }
    func testTransientReturnsToEnteringModeAfterOneBoundOrUnboundKey() async throws {
        enterModeForTests("browse")
        config.modes["once"] = .zero
        config.modes["once"]!.lifetime = .transient
        try await activateMode("once")
        XCTAssertEqual(activeMode, "once")
        try await ModeEngine.shared.transientFinished("once")
        XCTAssertEqual(activeMode, "browse")
    }
}
