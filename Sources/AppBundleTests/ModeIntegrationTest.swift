@testable import AppBundle
import AppKit
import Clocks
import Common
import XCTest

@MainActor final class ModeIntegrationTest: SerialClockTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }
    private func keymap(_ body: String) throws -> [KeymapBlock] {
        let value = try JSONDecoder().decode(JSONValue.self, from: Data("{\"keymap\":{\(body)}}".utf8))
        let parsed = parseConfig(value)
        XCTAssertTrue(parsed.errors.isEmpty, "\(parsed.errors)")
        return parsed.config.keymap
    }
    func testRegistrationTracksAppPassHeldEntryPendingAndSpace() throws {
        let map = try keymap(#""keys":{"context":"mode == window","priority":0,"bindings":{"ctrl-u":"focus right","g t":"focus left","space":"lens peek"}},"terminal":{"context":"mode == window && app == terminal","bindings":{"ctrl-u":"pass"}}"#)
        let plain = modeRegistrationChords(keymap: map, context: .init(mode: "window"), mode: .zero)
        XCTAssertEqual(plain, [.init(code: 32, modifiers: .control), .init(code: 5)])
        let terminal = modeRegistrationChords(keymap: map, context: .init(mode: "window", app: "terminal"), mode: .zero)
        XCTAssertEqual(terminal, [.init(code: 5)])
        let pending = modeRegistrationChords(keymap: map, context: .init(mode: "window"), mode: .zero, entryModifiers: .command, pending: [.init(code: 5)])
        XCTAssertFalse(pending.contains(.init(code: 17)))
        XCTAssertTrue(pending.contains(.init(code: 17, modifiers: .command)))
        XCTAssertFalse(pending.contains { $0.code == 49 })
        XCTAssertTrue(modeRegistrationChords(keymap: map, context: .init(mode: "main"), mode: .zero).isEmpty)
    }
    func testHeldReturnDiscountsFullEntryChordAndPeekPrefersDiscountedBinding() throws {
        let map = try keymap(#""keys":{"context":"mode == held","bindings":{"enter":"lens focus","shift-enter":"lens summon","y":"lens peek","cmd-y":"focus right"}}"#)
        var mode = Mode.zero; mode.lifetime = .held
        let enter = resolveModeKey(keymap: map, context: .init(mode: "held"), mode: mode, chord: .init(code: 36, modifiers: [.command, .shift]), entryModifiers: .command, entryChordModifiers: [.command, .shift])
        XCTAssertEqual(enter.commands.map { $0.args.description }, ["lens focus"])
        let peek = resolveModeKey(keymap: map, context: .init(mode: "held"), mode: mode, chord: .init(code: 16, modifiers: .command), entryModifiers: .command)
        XCTAssertEqual(peek.commands.map { $0.args.description }, ["lens peek"])
    }
    func testCompositionAndPeekEscapeOwnTheirKeysBeforeBindings() throws {
        let map = try keymap(#""keys":{"context":"mode == search","bindings":{"esc":"lens close","a":"lens mark"}}"#)
        var mode = Mode.zero; mode.unbound = .type
        XCTAssertTrue(resolveModeKey(keymap: map, context: .init(mode: "search"), mode: mode, chord: .init(code: 0), composing: true).editorOwned)
        XCTAssertEqual(resolveModeKey(keymap: map, context: .init(mode: "search"), mode: mode, chord: .init(code: 53), peeking: true).commands.map { $0.args.description }, ["lens peek"])
    }
    func testConsumeDiscountsEntryModifiersAndLatchedLatchYieldsForeignChord() {
        var mode = Mode.zero; mode.unbound = .consume
        XCTAssertEqual(resolveModeKey(keymap: [], context: .init(mode: "held"), mode: mode, chord: .init(code: 0, modifiers: .command), entryModifiers: .command).kind, .consume)
        mode.unbound = .latch
        XCTAssertEqual(resolveModeKey(keymap: [], context: .init(mode: "latched"), mode: mode, chord: .init(code: 0, modifiers: .command), characters: "a").kind, .global)
    }
    func testOpeningLatchBeforeReleaseCancelsCommitButReleaseBeforeLatchCommits() async throws {
        for latchFirst in [true, false] {
            let engine = ModeEngine(liveModifiers: { .command })
            var actions: [String] = []
            engine.execute = { actions += $0.map { $0.args.description } }
            var mode = Mode.zero; mode.lifetime = .held; mode.onRelease = ["lens focus"]
            try await engine.enter("held", mode: mode, invocation: .init(keyCode: 48, invoking: .command))
            engine.lensOpening()
            let latch: @MainActor () async -> Void = { try! await engine.enter("browse", mode: .zero); actions.append("latch") }
            if latchFirst { engine.whenLensReady(latch) }
            engine.noteModifiers([])
            if !latchFirst { engine.whenLensReady(latch) }
            await engine.lensReady(show: {}, flags: [])
            XCTAssertEqual(actions, latchFirst ? ["latch"] : ["lens focus", "latch"])
        }
    }
    func testLensVerbsWithoutLensFailOneAndPaneWithLensExplainsWhy() async throws {
        let panel = SwitcherPalettePanel.shared; panel.dismiss()
        for raw in ["step next", "focus", "summon", "peek", "close", "close-window", "sections next", "mark", "pane next", "presentation list", "caret left", "run close"] {
            let result = try await parseCommand("lens \(raw)").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(result.exitCode, 1, raw)
            XCTAssertEqual(result.stderr, ["No Lens is open"], raw)
        }
        enterModeForTests("browse")
        await panel.openLens(name: "demo", settings: LensConfig(), entries: [], search: "", banner: nil, context: .null, ticket: panel.beginLens("demo", toggle: false)!)
        defer { panel.dismiss() }
        let result = try await parseCommand("lens pane next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertEqual(result.stderr, ["The open Presentation has no panes"])
    }
    func testTransientEscapeReturnsToEnteringModeThroughPanelDispatch() async throws {
        config.modes["once"] = .zero
        config.modes["once"]!.lifetime = .transient
        enterModeForTests("browse")
        try await activateMode("once")
        XCTAssertTrue(handleModeKey(code: 53, flags: [], characters: ""))
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(activeMode, "browse")
    }
    func testTypingUsesSearchSelectionAndCaretRatherThanAppending() async throws {
        let panel = SwitcherPalettePanel.shared; panel.dismiss()
        enterModeForTests("search")
        await panel.openLens(name: "demo", settings: LensConfig(), entries: [], search: "abc", banner: nil, context: .null, ticket: panel.beginLens("demo", toggle: false)!)
        defer { panel.dismiss() }
        for _ in 0..<20 { await Task.yield() }
        let editor = try XCTUnwrap(panel.firstResponder as? NSTextView)
        editor.setSelectedRange(NSRange(location: 1, length: 1))
        panel.typeModeKey(code: 6, characters: "z")
        XCTAssertEqual(editor.string, "azc")
        XCTAssertEqual(panel.session?.query, "azc")
        panel.moveSearchCaret("left")
        panel.typeModeKey(code: 7, characters: "x")
        XCTAssertEqual(editor.string, "axzc")
        XCTAssertFalse(handleModeKey(code: 0, flags: [], characters: "a"), "Ordinary typing stays with the native field editor")
    }
    func testCountRepeatsFocusAndTransientRunsExactlyOneKey() async throws {
        let root = focus.workspace.rootTilingContainer
        let first = TestWindow.new(id: 1, parent: root)
        TestWindow.new(id: 2, parent: root)
        TestWindow.new(id: 3, parent: root)
        XCTAssertTrue(first.focusWindow())
        config.keymap = try keymap(#""counted":{"context":"mode == counted","bindings":{"l":"focus right"}},"once":{"context":"mode == once","bindings":{"h":"focus left"}}"#)
        config.modes["counted"] = .zero; config.modes["counted"]!.count = true
        config.modes["once"] = .zero; config.modes["once"]!.lifetime = .transient; config.modes["once"]!.unbound = .consume
        try await activateMode("counted")
        handleModeKey(code: 19, flags: [], characters: "2")
        handleModeKey(code: 37, flags: [], characters: "l")
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(focus.windowOrNil?.windowId, 3)
        XCTAssertNil(ModeEngine.shared.count)
        try await activateMode("once")
        handleModeKey(code: 4, flags: [], characters: "h")
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(focus.windowOrNil?.windowId, 2)
        XCTAssertEqual(activeMode, "counted")
        try await activateMode("once")
        handleModeKey(code: 6, flags: [], characters: "z")
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(focus.windowOrNil?.windowId, 2)
        XCTAssertEqual(activeMode, "counted")
    }
    func testLensVerbsUseSelectionAndMarksInMarkOrderAndClosingReportsMain() async throws {
        let panel = SwitcherPalettePanel.shared; panel.dismiss()
        let root = focus.workspace.rootTilingContainer
        let first = TestWindow.new(id: 1, parent: root)
        TestWindow.new(id: 2, parent: root); TestWindow.new(id: 3, parent: root)
        XCTAssertTrue(first.focusWindow())
        await panel.openLens(name: "demo", settings: LensConfig(), entries: try await lensWindows(popups: [:]), search: "", banner: nil, context: .null, ticket: panel.beginLens("demo", toggle: false)!)
        enterModeForTests("browse")
        defer { panel.dismiss() }
        let model = try XCTUnwrap(panel.session)
        for id: UInt32 in [3, 2] {
            model.hover(id)
            let marked = try await parseCommand("lens mark").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(marked.exitCode, 0)
        }
        XCTAssertEqual(model.marks, [3, 2])
        let moved = try await parseCommand("lens run move-node-to-workspace Target").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(moved.exitCode, 0, moved.stderr.joined(separator: "; "))
        let destination = try XCTUnwrap(Workspace.existing(byName: "Target"))
        XCTAssertEqual(destination.allLeafWindowsRecursive.map(\.windowId), [3, 2])
        XCTAssertTrue(panel.session === model)
        let current = try await parseCommand("list-modes --current").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(current.stdout, ["browse"])
        model.hover(1)
        let focused = try await parseCommand("lens focus").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(focused.exitCode, 0)
        XCTAssertEqual(focus.windowOrNil?.windowId, 1)
        XCTAssertEqual(activeMode, "main")
        XCTAssertNil(panel.session)
    }
    func testOpenPairGivesTheDrawnInertLensKeyFocusWhenItsModeEnters() async throws {
        let panel = SwitcherPalettePanel.shared; panel.dismiss()
        let activate = panel.activateInput
        var activations = 0
        panel.activateInput = { _ in activations += 1 }
        enterModeForTests("main")
        await panel.openLens(name: "demo", settings: LensConfig(), entries: [], search: "", banner: nil, context: .null, ticket: panel.beginLens("demo", toggle: false)!)
        defer { panel.dismiss(); panel.activateInput = activate }
        XCTAssertEqual(activations, 0)
        try await activateMode("search")
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(activations, 1)
        XCTAssertTrue(panel.firstResponder is NSTextView)
    }
    func testPendingSequenceNamesHudAndFreshKeyAndEscapeCancelOnlyPending() async throws {
        var labels: [String] = []
        BindingModeHud.shared = BindingModeHud(show: { text, _ in labels.append(text) }, hide: {})
        TrayMenuModel.shared.isEnabled = true
        config.modes["window"] = .zero
        config.keymap = try keymap(#""sequence":{"context":"mode == window","bindings":{"g t":"workspace 1","l":"workspace 1"}}"#)
        try await activateMode("window")
        handleModeKey(code: 5, flags: [], characters: "g")
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(labels.last, "window  g")
        handleModeKey(code: 37, flags: [], characters: "l")
        await ModeEngine.shared.waitForInput()
        XCTAssertTrue(ModeEngine.shared.pending.isEmpty)
        XCTAssertEqual(labels.last, "window")
        handleModeKey(code: 5, flags: [], characters: "g")
        handleModeKey(code: 53, flags: [], characters: "")
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(activeMode, "window")
        XCTAssertTrue(ModeEngine.shared.pending.isEmpty)
    }
    func testConfigReloadKeepsHeldEntryWithoutRunningOnEnterAgain() async throws {
        var mode = Mode.zero; mode.lifetime = .held; mode.onEnter = ["lens recent"]
        config.modes["held"] = mode
        var commands: [String] = []
        ModeEngine.shared.execute = {
            commands += $0.map { $0.args.description }
            ModeEngine.shared.lensOpening()
            ModeEngine.shared.presentLens(show: {}, flags: .command)
        }
        try await ModeEngine.shared.enter("held", mode: mode, invocation: .init(keyCode: 48, invoking: .command))
        try await applyConfig(config, url: configUrl, readSidebarState: { WorkspaceSidebarState() }, synchronizeLogin: {})
        XCTAssertEqual(commands, ["lens recent"])
        XCTAssertEqual(ModeEngine.shared.entryModifiers, .command)
        XCTAssertEqual(activeMode, "held")
    }
    func testZeroCountRunsZeroCopiesOfTheBoundCommandList() throws {
        let map = try keymap(#""count":{"context":"mode == counting","bindings":{"h":"focus left"}}"#)
        var mode = Mode.zero; mode.count = true
        let zero = resolveModeKey(keymap: map, context: .init(mode: "counting"), mode: mode, chord: .init(code: 29), characters: "0")
        let action = resolveModeKey(keymap: map, context: .init(mode: "counting"), mode: mode, chord: .init(code: 4), characters: "h", count: zero.count)
        XCTAssertEqual(action.repetitions, 0)
    }
    func testTransientReturnBelongsToTheInjectedEngine() async throws {
        let engine = ModeEngine()
        engine.execute = { _ in }
        try await engine.enter("browse", mode: .zero)
        var once = Mode.zero; once.lifetime = .transient
        try await engine.enter("once", mode: once)
        try await engine.transientFinished("once")
        XCTAssertEqual(engine.current, "browse")
        XCTAssertEqual(activeMode, "main")
    }
    func testHeldFallbackRefreshesTapBindingsOfMain() async throws {
        let parsed = parseConfig("""
        [mode.main.binding-tap]
        right-alt = 'focus left'
        [mode.held]
        lifetime = 'held'
        """)
        XCTAssertTrue(parsed.errors.isEmpty)
        config = parsed.config
        defer { resetHotKeys() }
        try await $modeInvocation.withValue(.init(keyCode: 48, invoking: .command)) { try await activateMode("held") }
        await ModeEngine.shared.observeModifiers([])
        XCTAssertEqual(activeMode, "main")
        noteTapBindingFlagsChanged(keyCode: 61, modifierFlags: [.option, TapModifierKey.rightAlt.deviceSpecificModifierFlag])
        XCTAssertTrue(hasPendingTapBindingForTests())
    }
    func testBoundEscapeAfterSequenceMismatchRunsItsBinding() throws {
        let map = try keymap(#""keys":{"context":"mode == window","bindings":{"g t":"focus left","esc":"mode main"}}"#)
        let result = resolveModeKey(keymap: map, context: .init(mode: "window"), mode: .zero, chord: .init(code: 53), pending: [.init(code: 5)])
        XCTAssertEqual(result.commands.map { $0.args.description }, ["mode main"])
    }
    func testQuickReleaseCanFinishFocusAfterClosingWithoutCancellingItself() async throws {
        let engine = ModeEngine(liveModifiers: { .command })
        var mode = Mode.zero; mode.lifetime = .held; mode.onRelease = ["lens focus"]
        var committed = false
        engine.execute = { commands in
            if commands.contains(where: { $0.args.description == "lens focus" }) {
                engine.lensClosed()
                try Task.checkCancellation()
                committed = true
            }
        }
        try await engine.enter("held", mode: mode, invocation: .init(keyCode: 48, invoking: .command))
        engine.lensOpening(); engine.noteModifiers([])
        engine.presentLens(show: { XCTFail("Quick release must not draw") }, flags: [])
        await engine.waitForReadiness()
        XCTAssertTrue(committed)
        XCTAssertEqual(engine.current, "main")
    }
    func testReadinessActionsAndLaterInputKeepArrivalOrderAcrossAnAwait() async throws {
        let engine = ModeEngine()
        let reached = expectation(description: "first ready action")
        var finish: CheckedContinuation<Void, Never>?
        var actions: [Int] = []
        engine.lensOpening()
        engine.whenLensReady {
            actions.append(1); reached.fulfill()
            await withCheckedContinuation { finish = $0 }
            actions.append(2)
        }
        engine.presentLens(show: {}, flags: [])
        await fulfillment(of: [reached], timeout: 2)
        engine.enqueueInput { actions.append(3) }
        for _ in 0..<20 { await Task.yield() }
        finish?.resume()
        await engine.waitForReadiness(); await engine.waitForInput()
        XCTAssertEqual(actions, [1, 2, 3])
        engine.lensClosed()
    }
    func testForeignChordInterruptsOpeningAndDropsRemainingEntryCommands() async throws {
        let engine = ModeEngine.shared
        let panel = SwitcherPalettePanel.shared; panel.dismiss()
        config.keymap = try keymap(#""main":{"context":"mode == main","bindings":{"alt-tab":"mode held","ctrl-alt-h":"mode escaped"}}"#)
        var mode = Mode.zero; mode.lifetime = .held; mode.unbound = .latch; mode.onEnter = ["lens recent", "mode stale"]
        config.modes["held"] = mode; config.modes["escaped"] = .zero; config.modes["stale"] = .zero
        let reached = expectation(description: "opening awaits a result")
        var finish: CheckedContinuation<Void, Never>?
        var commandsRun: [String] = []
        engine.execute = { commands in
            for command in commands {
                commandsRun.append(command.args.description)
                if command.args.description == "lens recent" {
                    _ = panel.beginLens("recent", toggle: false)
                    reached.fulfill()
                    await withCheckedContinuation { finish = $0 }
                } else { _ = try await command.run(.defaultEnv, .emptyStdin) }
            }
        }
        handleModeKey(code: 48, flags: .option, characters: "", carbon: true)
        await fulfillment(of: [reached], timeout: 2)
        handleModeKey(code: 4, flags: [.control, .option], characters: "h", carbon: true)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(activeMode, "escaped")
        XCTAssertFalse(panel.isLensOpen)
        finish?.resume()
        await engine.waitForInput()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertFalse(commandsRun.contains("mode stale"))
        XCTAssertEqual(activeMode, "escaped")
        panel.dismiss()
    }
    func testCapturedChordFlagsEndHeldModeBeforeResolvingTheChord() async throws {
        config.keymap = try keymap(#""held":{"context":"mode == held","bindings":{"h":"mode held-key"}},"main":{"context":"mode == main","bindings":{"h":"mode main-key"}}"#)
        var held = Mode.zero; held.lifetime = .held
        config.modes["held"] = held
        enterModeForTests("held", gesture: .init(keyCode: 48, invoking: .command))
        handleModeKey(code: 4, flags: [], characters: "h", carbon: true)
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(activeMode, "main-key")
    }
    func testObservedForeignChordLeavesHeldModeBeforePanelCanTakeKeys() async throws {
        let panel = SwitcherPalettePanel.shared; panel.dismiss()
        config.keymap = try keymap(#""main":{"context":"mode == main","bindings":{"cmd-ctrl-h":"mode escaped"}}"#)
        var held = Mode.zero; held.lifetime = .held; held.unbound = .latch
        config.modes["held"] = held; config.modes["escaped"] = .zero
        enterModeForTests("held", gesture: .init(keyCode: 48, invoking: .command))
        _ = panel.beginLens("demo", toggle: false)
        observeUncapturedModeKey(code: 4, flags: [.command, .control], characters: "h")
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(activeMode, "escaped")
        XCTAssertFalse(panel.isLensOpen)
        panel.dismiss()
    }
    func testObservedUnboundKeyCancelsTransientSequenceAndCountOutsideLens() async throws {
        let panel = SwitcherPalettePanel.shared; panel.dismiss()
        config.keymap = try keymap(#""once":{"context":"mode == once","bindings":{"g t":"focus left"}}"#)
        var mode = Mode.zero; mode.lifetime = .transient; mode.count = true
        config.modes["once"] = mode
        try await activateMode("once")
        _ = ModeEngine.shared.resolve(.init(code: 19), characters: "2", keymap: config.keymap, context: .init(mode: "once"))
        _ = ModeEngine.shared.resolve(.init(code: 5), characters: "g", keymap: config.keymap, context: .init(mode: "once"))
        observeUncapturedModeKey(code: 6, flags: [], characters: "z")
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(activeMode, "main")
        XCTAssertNil(ModeEngine.shared.count)
        XCTAssertTrue(ModeEngine.shared.pending.isEmpty)
    }
    func testCarbonAndPanelKeysKeepModeAwareTraceRowsAfterDismissal() async throws {
        let store = LensTraceStore()
        let trace = store.begin(presentation: "list", origin: .internalNow())
        let panel = SwitcherPalettePanel.shared; panel.dismiss()
        enterModeForTests("browse")
        let ticket = panel.beginLens("demo", toggle: false, trace: trace)!
        await panel.openLens(name: "demo", settings: LensConfig(), entries: [], search: "", banner: nil, context: .null, ticket: ticket)
        handleModeKey(code: 48, flags: [], characters: "", carbon: true, origin: .init(start: LensTimebase.now(), received: LensTimebase.now(), source: "Carbon"))
        await ModeEngine.shared.waitForInput()
        let escape = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: LensTimebase.now(), windowNumber: panel.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 53))
        XCTAssertTrue(panel.performKeyEquivalent(with: escape))
        await ModeEngine.shared.waitForInput()
        let keys = trace.snapshot.keys.filter { $0.keyCode != 0 }
        XCTAssertEqual(keys.map(\.keyCode), [48, 53])
        XCTAssertEqual(keys.map(\.state), ["browse", "browse"])
        XCTAssertEqual(keys.map(\.path), ["Carbon", "performKeyEquivalent"])
        XCTAssertEqual(trace.snapshot.session?.active, false)
        XCTAssertEqual(activeMode, "main")
    }
    func testTriggerBindingUsesContextWinnerAndKeepsBaseBehaviorWithoutLens() async throws {
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"mode":{"main":{"binding":{"h":"focus left"}}},"keymap":{"in-lens":{"context":"mode == main && lens","bindings":{"h":"focus right"}}}}"#.utf8))
        let parsed = parseConfig(value)
        XCTAssertTrue(parsed.errors.isEmpty)
        config = parsed.config
        let root = focus.workspace.rootTilingContainer
        let first = TestWindow.new(id: 1, parent: root)
        TestWindow.new(id: 2, parent: root)
        XCTAssertTrue(first.focusWindow())
        let panel = SwitcherPalettePanel.shared; panel.dismiss()
        await panel.openLens(name: "demo", settings: LensConfig(), entries: [], search: "", banner: nil, context: .null, ticket: panel.beginLens("demo", toggle: false)!)
        let inside = try await parseCommand("trigger-binding --mode main h").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(inside.exitCode, 0)
        XCTAssertEqual(focus.windowOrNil?.windowId, 2)
        panel.dismiss()
        let outside = try await parseCommand("trigger-binding --mode main h").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(outside.exitCode, 0)
        XCTAssertEqual(focus.windowOrNil?.windowId, 1)
    }
    func testViewOnlyLensKeysAvoidNativeRefreshAndWindowActionsKeepIt() async throws {
        var refreshes = 0
        setScheduledRefreshOverrideForTests { _, _ in refreshes += 1 }
        defer { setScheduledRefreshOverrideForTests(nil) }
        let panel = SwitcherPalettePanel.shared; panel.dismiss()
        enterModeForTests("browse")
        await panel.openLens(name: "refresh", settings: LensConfig(), entries: [], search: "", banner: nil, context: .null, ticket: panel.beginLens("refresh", toggle: false)!)
        defer { panel.dismiss() }
        handleModeKey(code: 38, flags: [], characters: "j")
        await ModeEngine.shared.waitForInput()
        try await waitForScheduledRefreshForTests()
        XCTAssertEqual(refreshes, 0)
        handleModeKey(code: 13, flags: .command, characters: "w")
        await ModeEngine.shared.waitForInput()
        try await waitForScheduledRefreshForTests()
        XCTAssertEqual(refreshes, 1)
    }
    func testObservedUnboundMainKeyDoesNotReconcileUnchangedMode() async {
        SwitcherPalettePanel.shared.dismiss()
        var changes = 0
        ModeEngine.shared.changed = { changes += 1 }
        observeUncapturedModeKey(code: 0, flags: [], characters: "a")
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(changes, 0)
    }

    func testReconfigurationReconcilesRegistrationsEvenWithoutPendingInput() {
        let engine = ModeEngine()
        var reconciliations = 0
        engine.changed = { reconciliations += 1 }
        engine.reconfigure(.zero)
        XCTAssertEqual(reconciliations, 1)
    }
}
