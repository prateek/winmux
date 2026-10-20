@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor final class ModeInputOrderTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    private func parsed(_ text: String) throws -> Config {
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
        let parsed = parseConfig(value)
        XCTAssertTrue(parsed.errors.isEmpty, "\(parsed.errors)")
        return parsed.config
    }

    func testTaskSpawnedByAQueuedActionWaitsForTheQueue() async throws {
        let engine = ModeEngine(liveModifiers: { [] })
        engine.execute = { _ in }
        let blocked = expectation(description: "later input started")
        var resume: CheckedContinuation<Void, Never>?
        var entered = false
        engine.enqueueInput {
            Task { try? await engine.enter("later", mode: .zero); entered = true }
        }
        engine.enqueueInput {
            blocked.fulfill()
            await withCheckedContinuation { resume = $0 }
        }
        await fulfillment(of: [blocked], timeout: 2)
        for _ in 0 ..< 20 { await Task.yield() }
        XCTAssertFalse(entered, "the spawned entry outlived its action, so its ready point queues behind later input")
        resume?.resume()
        await engine.waitForInput()
        for _ in 0 ..< 20 { await Task.yield() }
        XCTAssertTrue(entered)
    }

    func testInterruptKeepsTheQueueBusyUntilTheOldActionEnds() async throws {
        let engine = ModeEngine(liveModifiers: { .command })
        let started = expectation(description: "old action in flight")
        var resumeOld: CheckedContinuation<Void, Never>?
        let old = engine.enqueueInput {
            started.fulfill()
            await withCheckedContinuation { resumeOld = $0 }
        }
        await fulfillment(of: [started], timeout: 2)
        engine.interruptOpening {}
        await engine.waitForInput()
        XCTAssertFalse(engine.inputIsIdle, "the interrupted action still runs, so a key cannot be decided against state it may change")
        resumeOld?.resume()
        await old.value
        XCTAssertTrue(engine.inputIsIdle)
    }

    func testKeyBehindQueuedInputIsReplayedWhenItBelongsToTheEditor() async throws {
        let panel = SwitcherPalettePanel.shared
        panel.dismiss()
        enterModeForTests("search")
        await panel.openLens(name: "demo", settings: LensConfig(), entries: [], search: "abc", banner: nil, context: .null, ticket: panel.beginLens("demo", toggle: false)!)
        defer { panel.dismiss() }
        let started = expectation(description: "earlier input in flight")
        var resume: CheckedContinuation<Void, Never>?
        ModeEngine.shared.enqueueInput {
            started.fulfill()
            await withCheckedContinuation { resume = $0 }
        }
        await fulfillment(of: [started], timeout: 2)
        var replayed = 0
        XCTAssertTrue(handleModeKey(code: 9, flags: .command, characters: "v", replay: { replayed += 1 }))
        resume?.resume()
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(replayed, 1, "Cmd-V reaches the field editor's own paste")
        XCTAssertEqual(panel.session?.query, "abc", "and is not typed as a literal v")
    }

    func testEachContinuationOfAFastSequenceRegistersBeforeItsDispatch() throws {
        config = try parsed(#"{"mode":{"main":{},"sequence":{"binding":{"a b c":"focus left"}}}}"#)
        enterModeForTests("sequence")
        defer { resetHotKeys() }
        handleModeKey(code: 0, flags: [], characters: "a", carbon: true)
        handleModeKey(code: 11, flags: [], characters: "b", carbon: true)
        XCTAssertTrue(listeningHotkeyChords().contains(.init(keyCode: 8, modifiers: 0)))
    }

    func testCancelledOpeningOfALatchedModeReturnsToMain() async throws {
        enterModeForTests("browse")
        let owner = testLensLifecycle()
        let ticket = try XCTUnwrap(owner.begin("recent", toggle: false))
        owner.cancelOpening(ticket: ticket)
        for _ in 0 ..< 20 { await Task.yield() }
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(activeMode, mainModeId)
    }

    func testANewLensDropsKeysParkedForACancelledOpening() async throws {
        let engine = ModeEngine(liveModifiers: { .command })
        engine.execute = { _ in }
        let owner = testLensLifecycle(modeEngine: engine)
        var mode = Mode.zero; mode.lifetime = .held; mode.onRelease = ["focus left"]
        engine.replace("held", mode: mode, invocation: .init(keyCode: 48, invoking: .command))
        var actions: [String] = []
        let first = try XCTUnwrap(owner.begin("first", toggle: false))
        engine.whenLensReady { actions.append("stale") }
        owner.cancelOpening(ticket: first)
        _ = owner.begin("second", toggle: false)
        await engine.lensReady(show: {}, flags: .command)
        await engine.waitForInput()
        XCTAssertEqual(actions, [])
        XCTAssertEqual(engine.current, "held")
    }

    func testReleaseRegistersNoPlainChordOfTheHeldMode() async throws {
        config = try parsed(#"{"mode":{"main":{},"held":{"lifetime":"held","on-release":["lens focus"],"binding":{"w":"lens close-window"}}}}"#)
        enterModeForTests("held", gesture: .init(keyCode: 48, invoking: .command))
        defer { resetHotKeys() }
        var duringRelease: Set<SymbolicHotkeyChord> = []
        ModeEngine.shared.execute = { commands in
            guard commands.first?.args.description == "lens focus" else { return }
            reconcileModeContext()
            duringRelease = listeningHotkeyChords()
        }
        ModeEngine.shared.noteModifiers([])
        await ModeEngine.shared.waitForInput()
        XCTAssertFalse(duringRelease.contains(.init(keyCode: 13, modifiers: 0)), "plain w would be taken from every app")
    }

    func testSearchRowFallsBackToSearchWhenSlashChangesNoMode() async throws {
        config = try parsed(#"{"mode":{"main":{},"custom":{"binding":{"slash":"lens presentation list"}},"search":{"unbound":"type"}}}"#)
        enterModeForTests("custom")
        let model = LensSession(name: "demo", settings: LensConfig(), items: [], search: "")
        model.enterSearch()
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(activeMode, "search")
    }
}
