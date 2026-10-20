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

    func testCancelledOpeningEndsOnlyTheModeThatOpenedTheLens() async throws {
        config = try parsed(#"{"mode":{"main":{},"opener":{"on-enter":["lens recent"]},"resize":{}}}"#)
        for (mode, expected) in [("opener", mainModeId), ("resize", "resize")] {
            let owner = testLensLifecycle()
            let ticket = try XCTUnwrap(owner.begin("recent", toggle: false))
            enterModeForTests(mode)
            owner.cancelOpening(ticket: ticket)
            await ModeEngine.shared.waitForInput()
            XCTAssertEqual(activeMode, expected, mode)
        }
    }

    func testAnInterruptedDrainLeavesALaterLensItsParkedKeys() async throws {
        let engine = ModeEngine(liveModifiers: { .command })
        let owner = testLensLifecycle(modeEngine: engine)
        var held = Mode.zero; held.lifetime = .held
        engine.replace("held", mode: held, invocation: .init(keyCode: 48, invoking: .command))
        let first = try XCTUnwrap(owner.begin("first", toggle: false))
        engine.whenLensReady {}
        owner.cancelOpening(ticket: first)
        engine.interruptOpening {}
        await engine.waitForInput()
        var actions: [String] = []
        engine.execute = { commands in
            guard commands.first?.args.description == "lens recent" else { return }
            engine.whenLensReady { actions.append("key") }
            engine.lensOpening()
        }
        var opener = Mode.zero; opener.onEnter = ["lens recent"]
        try await engine.enter("opener", mode: opener)
        await engine.waitForInput()
        XCTAssertEqual(actions, ["key"])
    }

    func testAKeyThatLatchesIntoTheEditorIsReplayed() async throws {
        config = try parsed(#"{"mode":{"main":{},"lat":{"unbound":"latch","latch-to":"search"},"search":{"unbound":"type"}}}"#)
        let panel = SwitcherPalettePanel.shared
        panel.dismiss()
        enterModeForTests("lat")
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
        XCTAssertTrue(handleModeKey(code: 38, flags: [], characters: "j", composing: true, replay: { replayed += 1 }))
        resume?.resume()
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(activeMode, "search")
        XCTAssertEqual(replayed, 1, "the input method keeps its composition")
        XCTAssertEqual(panel.session?.query, "abc")
    }

    func testAFailedReleaseStillReconcilesRegistration() async throws {
        var held = Mode.zero; held.lifetime = .held; held.unbound = .consume; held.onRelease = ["lens focus"]
        config.modes["held"] = held
        let panel = SwitcherPalettePanel.shared
        panel.dismiss()
        enterModeForTests("main")
        await panel.openLens(name: "demo", settings: LensConfig(), entries: [], search: "", banner: nil, context: .null, ticket: panel.beginLens("demo", toggle: false)!)
        defer { panel.dismiss() }
        enterModeForTests("held", gesture: .init(keyCode: 48, invoking: .command))
        var changes: [Bool] = []
        ModeEngine.shared.changed = { changes.append(ModeEngine.shared.releasing) }
        ModeEngine.shared.execute = { _ in changes = []; throw ModeConfigError("on-release failed") }
        ModeEngine.shared.noteModifiers([])
        await ModeEngine.shared.waitForInput()
        XCTAssertFalse(ModeEngine.shared.releasing)
        XCTAssertEqual(activeMode, mainModeId)
        XCTAssertFalse(panel.isLensOpen)
        XCTAssertEqual(changes, [false], "registration is reconciled once the release has ended")
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

    func testCancelledLatchedOpeningDrainsKeysInTheCurrentMode() async throws {
        let engine = ModeEngine(liveModifiers: { [] })
        let owner = testLensLifecycle(modeEngine: engine)
        engine.replace("window", mode: .zero)
        let ticket = try XCTUnwrap(owner.begin("windows", toggle: false))
        var seen: [String?] = []
        engine.whenLensReady { seen.append(engine.current) }
        engine.replace("resize", mode: .zero)
        engine.whenLensReady { seen.append(engine.current) }
        owner.cancelOpening(ticket: ticket)
        await engine.waitForInput()
        XCTAssertEqual(seen, ["resize", "resize"])
        XCTAssertEqual(engine.current, "resize")
    }

    func testRejectedNamedLensKeepsBrowseAndItsLens() async throws {
        let panel = SwitcherPalettePanel.shared
        defer { panel.dismiss() }
        var disabled = LensConfig(); disabled.enabled = false
        config.lenses["disabled"] = disabled
        var browse = Mode.zero; browse.unbound = .consume
        config.modes["browse"] = browse
        for name in ["nonexistent", "disabled"] {
            panel.dismiss()
            await ModeEngine.shared.waitForInput()
            await panel.openLens(name: "demo", settings: LensConfig(), entries: [], search: "", banner: nil, context: .null, ticket: panel.beginLens("demo", toggle: false)!)
            enterModeForTests("browse")
            let result = try await parseCommand("lens \(name)").cmdOrDie.run(.defaultEnv, .emptyStdin)
            await ModeEngine.shared.waitForInput()
            XCTAssertEqual(result.exitCode, 2)
            XCTAssertTrue(panel.isLensOpen)
            XCTAssertEqual(activeMode, "browse")
        }
    }

    func testCancelledOpeningLeavesNoLensDependentMode() async throws {
        for policy in [Mode.Unbound.consume, .type, .latch] {
            let engine = ModeEngine(liveModifiers: { [] })
            engine.execute = { _ in }
            let owner = testLensLifecycle(modeEngine: engine)
            var mode = Mode.zero; mode.unbound = policy
            let ticket = try XCTUnwrap(owner.begin("windows", toggle: false))
            engine.replace("lens-only", mode: mode)
            var seen: String?
            engine.whenLensReady { seen = engine.current }
            owner.cancelOpening(ticket: ticket)
            await engine.waitForInput()
            XCTAssertEqual(seen, "lens-only", "parked keys run before cleanup")
            XCTAssertEqual(engine.current, mainModeId, "\(policy)")
        }
    }

    func testUnownedCancelledOpeningKeepsTheLensDependentMode() async throws {
        for policy in [Mode.Unbound.consume, .type, .latch] {
            let engine = ModeEngine(liveModifiers: { [] })
            let owner = testLensLifecycle(modeEngine: engine)
            var mode = Mode.zero; mode.unbound = policy
            engine.replace("lens-only", mode: mode)
            let ticket = try XCTUnwrap(owner.begin("windows", toggle: false))
            var seen: String?
            engine.whenLensReady { seen = engine.current }
            owner.cancelOpening(ticket: ticket)
            await engine.waitForInput()
            XCTAssertEqual(seen, "lens-only")
            XCTAssertEqual(engine.current, "lens-only", "\(policy)")
        }
    }

    func testCancelledCLICmdTabOpeningDrainsBeforeReturningToMain() async throws {
        let engine = ModeEngine(liveModifiers: { [] })
        engine.execute = { _ in }
        let owner = testLensLifecycle(modeEngine: engine)
        var mode = Mode.zero; mode.lifetime = .held; mode.onEnter = ["lens recent"]
        let ticket = try XCTUnwrap(owner.begin("other", toggle: false))
        engine.replace("cmd-tab", mode: mode, cli: true)
        var seen: String?
        engine.whenLensReady { seen = engine.current }
        owner.cancelOpening(ticket: ticket)
        await engine.waitForInput()
        XCTAssertEqual(seen, "cmd-tab")
        XCTAssertEqual(engine.current, mainModeId)
    }

    func testCancelledHeldOpeningDrainsReleaseThenKeepsNewSearchMode() async throws {
        let engine = ModeEngine(liveModifiers: { [] })
        let owner = testLensLifecycle(modeEngine: engine)
        var held = Mode.zero; held.lifetime = .held; held.onRelease = ["mode search"]
        var search = Mode.zero; search.unbound = .type
        var seen: [String] = []
        engine.execute = { commands in
            if commands.first?.args.description == "mode search" {
                seen.append("release")
                try await engine.enter("search", mode: search)
            }
        }
        engine.replace("search-hold", mode: held, invocation: .init(keyCode: 44, invoking: .option))
        let ticket = try XCTUnwrap(owner.begin("windows", toggle: false))
        engine.whenLensReady { seen.append("key") }
        engine.noteModifiers([])
        owner.cancelOpening(ticket: ticket)
        await engine.waitForInput()
        XCTAssertEqual(seen, ["key", "release"])
        XCTAssertEqual(engine.current, "search")
    }

    func testCancelledOpeningDrainsReleaseIntoTheCurrentHeldMode() async throws {
        let engine = ModeEngine(liveModifiers: { .command })
        let owner = testLensLifecycle(modeEngine: engine)
        var held = Mode.zero; held.lifetime = .held; held.onRelease = ["focus left"]
        engine.replace("first", mode: held, invocation: .init(keyCode: 48, invoking: .command))
        let ticket = try XCTUnwrap(owner.begin("windows", toggle: false))
        var seen: [String] = []
        engine.execute = { commands in seen += commands.map { $0.args.description } }
        engine.whenLensReady { seen.append("key before release") }
        engine.noteModifiers([])
        held.onRelease = ["focus right"]
        engine.replace("current", mode: held, invocation: .init(keyCode: 48, invoking: .command))
        engine.whenLensReady { seen.append("key after release: \(engine.current ?? "nil")") }
        owner.cancelOpening(ticket: ticket)
        await engine.waitForInput()
        XCTAssertEqual(seen, ["key before release", "focus right", "key after release: main"])
        XCTAssertEqual(engine.current, mainModeId)
    }

    func testCancelledHeldOpeningPreservesTypingModifiersAtReady() async throws {
        let engine = ModeEngine(liveModifiers: { .option })
        engine.execute = { _ in }
        let owner = testLensLifecycle(modeEngine: engine)
        var held = Mode.zero; held.lifetime = .held
        var typing = Mode.zero; typing.unbound = .type
        engine.replace("search-hold", mode: held, invocation: .init(keyCode: 44, invoking: .option))
        let ticket = try XCTUnwrap(owner.begin("windows", toggle: false))
        var observed: NSEvent.ModifierFlags = []
        engine.whenLensReady {
            try? await engine.enter("search", mode: typing)
            engine.lensOpening()
        }
        engine.changed = { if engine.current == "search" { observed = engine.textModifiers } }
        owner.cancelOpening(ticket: ticket)
        await engine.waitForInput()
        XCTAssertEqual(observed, .option)
        XCTAssertEqual(engine.textModifiers, .option)
    }

    private func checkDismiss(keyWaitsForEarlierInput: Bool = true, _ between: (ModeEngine) -> Void) async throws {
        let engine = ModeEngine.shared
        engine.execute = { _ in }
        let owner = testLensLifecycle(modeEngine: engine)
        var browse = Mode.zero; browse.unbound = .consume
        _ = owner.begin("windows", toggle: false)
        engine.replace("browse", mode: browse)
        let started = expectation(description: "slow input started")
        var resume: CheckedContinuation<Void, Never>?
        let slow = engine.enqueueInput {
            started.fulfill()
            await withCheckedContinuation { resume = $0 }
        }
        await fulfillment(of: [started], timeout: 2)
        owner.dismiss()
        between(engine)
        var modeAtKey: String?
        engine.enqueueInput { modeAtKey = engine.current }
        for _ in 0 ..< 20 { await Task.yield() }
        let modeBeforeSlowEnds = engine.current
        if keyWaitsForEarlierInput { XCTAssertNil(modeAtKey, "a later key still waits for the input before it") }
        resume?.resume()
        await slow.value
        await engine.waitForInput()
        XCTAssertEqual(modeBeforeSlowEnds, mainModeId)
        XCTAssertEqual(modeAtKey, mainModeId)
        XCTAssertEqual(engine.current, mainModeId)
    }

    func testDismissReturnsToMainAcrossReload() async throws {
        try await checkDismiss { $0.reconfigure($0.properties) }
    }

    func testDismissReturnsToMainAcrossInterrupt() async throws {
        try await checkDismiss(keyWaitsForEarlierInput: false) { $0.interruptOpening {} }
    }

    func testDismissReturnsBeforeSlowInputEndsAndLaterKeyDispatches() async throws {
        try await checkDismiss { _ in }
    }

    func testKeysQueuedAcrossADismissKeepTheirOrder() async throws {
        let engine = ModeEngine(liveModifiers: { [] })
        engine.execute = { _ in }
        let owner = testLensLifecycle(modeEngine: engine)
        var browse = Mode.zero; browse.unbound = .consume
        _ = owner.begin("windows", toggle: false)
        engine.replace("browse", mode: browse)
        let started = expectation(description: "slow input in flight")
        var resume: CheckedContinuation<Void, Never>?
        engine.enqueueInput {
            started.fulfill()
            await withCheckedContinuation { resume = $0 }
        }
        await fulfillment(of: [started], timeout: 2)
        var keys: [String] = []
        engine.enqueueInput { keys.append("before") }
        owner.dismiss()
        engine.enqueueInput { keys.append("after") }
        for _ in 0 ..< 20 { await Task.yield() }
        XCTAssertEqual(engine.current, mainModeId)
        resume?.resume()
        await engine.waitForInput()
        XCTAssertEqual(keys, ["before", "after"])
    }

    func testDismissDoesNotEndANewerMode() async throws {
        let engine = ModeEngine.shared
        var browse = Mode.zero; browse.unbound = .consume
        let owner = testLensLifecycle()
        _ = owner.begin("windows", toggle: false)
        engine.replace("browse", mode: browse)
        owner.dismiss()
        engine.replace("window", mode: .zero)
        await engine.waitForInput()
        XCTAssertEqual(engine.current, "window")
    }

    func testCancelledDrainDoesNotReleaseAfterTaskCancellation() async throws {
        let engine = ModeEngine(liveModifiers: { [] })
        engine.execute = { _ in XCTFail("a cancelled ready action must not run on-release") }
        var held = Mode.zero; held.lifetime = .held; held.onRelease = ["lens focus"]
        engine.replace("held", mode: held, invocation: .init(keyCode: 48, invoking: .command))
        let owner = testLensLifecycle(modeEngine: engine)
        let ticket = try XCTUnwrap(owner.begin("windows", toggle: false))
        engine.whenLensReady { withUnsafeCurrentTask { $0?.cancel() } }
        owner.cancelOpening(ticket: ticket)
        await engine.waitForInput()
        XCTAssertEqual(engine.current, "held")
        XCTAssertEqual(engine.entryModifiers, .command)
    }

    func testCancelledOnEnterDrainsBeforeLeavingALensDependentMode() async throws {
        let engine = ModeEngine(liveModifiers: { [] })
        let owner = testLensLifecycle(modeEngine: engine)
        var mode = Mode.zero; mode.onEnter = ["lens recent"]
        var seen: [String?] = []
        engine.execute = { commands in
            if commands.first?.args.description == "lens recent" {
                let ticket = try XCTUnwrap(owner.begin("recent", toggle: false))
                engine.whenLensReady { seen.append(engine.current) }
                owner.cancelOpening(ticket: ticket)
            }
        }
        try await engine.enter("opener", mode: mode)
        await engine.waitForInput()
        XCTAssertEqual(seen, ["opener"])
        XCTAssertEqual(engine.current, mainModeId)
    }

    func testQueuedHeldLatchToPassConsumesTheStrippedKeyLikeIdleInput() async throws {
        config = try parsed(#"{"mode":{"main":{},"lat":{"lifetime":"held","unbound":"latch","latch-to":"window"},"window":{}}}"#)
        for busy in [false, true] {
            enterModeForTests("lat", gesture: .init(keyCode: 44, invoking: .option))
            var resume: CheckedContinuation<Void, Never>?
            if busy {
                let started = expectation(description: "earlier input in flight")
                ModeEngine.shared.enqueueInput {
                    started.fulfill()
                    await withCheckedContinuation { resume = $0 }
                }
                await fulfillment(of: [started], timeout: 2)
            }
            var replayed = 0
            XCTAssertTrue(handleModeKey(code: 7, flags: .option, characters: "x", replay: { replayed += 1 }))
            resume?.resume()
            await ModeEngine.shared.waitForInput()
            XCTAssertEqual(activeMode, "window")
            XCTAssertEqual(replayed, 0, "busy=\(busy)")
        }
    }

    func testQueuedHeldLatchTypesStrippedLetterWithoutReplayingOption() async throws {
        config = try parsed(#"{"mode":{"main":{},"lat":{"lifetime":"held","unbound":"latch","latch-to":"search"},"search":{"unbound":"type"}}}"#)
        let panel = SwitcherPalettePanel.shared
        panel.dismiss()
        enterModeForTests("lat")
        await panel.openLens(name: "demo", settings: LensConfig(), entries: [], search: "", banner: nil, context: .null, ticket: panel.beginLens("demo", toggle: false)!)
        enterModeForTests("lat", gesture: .init(keyCode: 44, invoking: .option))
        defer { panel.dismiss() }
        let editor = NSTextView(frame: .zero)
        panel.contentView?.addSubview(editor)
        defer { editor.removeFromSuperview() }
        XCTAssertTrue(panel.makeFirstResponder(editor))
        let started = expectation(description: "earlier input in flight")
        var resume: CheckedContinuation<Void, Never>?
        ModeEngine.shared.enqueueInput {
            started.fulfill()
            await withCheckedContinuation { resume = $0 }
        }
        await fulfillment(of: [started], timeout: 2)
        var replayed = 0
        XCTAssertTrue(handleModeKey(code: 7, flags: .option, characters: "x", replay: { replayed += 1 }))
        resume?.resume()
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(activeMode, "search")
        XCTAssertEqual(replayed, 0)
        XCTAssertEqual(panel.session?.query, "x")
    }
}
