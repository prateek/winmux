@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor final class ModePassTwoTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    private func parsed(_ text: String) throws -> Config {
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
        let parsed = parseConfig(value)
        XCTAssertTrue(parsed.errors.isEmpty, "\(parsed.errors)")
        return parsed.config
    }

    func testHeldRegistrationUsesOnlyEntryModifiedAliases() throws {
        let config = try parsed(#"{"mode":{"main":{},"held":{"lifetime":"held","binding":{"w":"lens close-window","slash":"lens close","enter":"lens focus"}}}}"#)
        let chords = modeRegistrationChords(keymap: config.keymap, context: .init(mode: "held"), mode: config.modes["held"]!, entryModifiers: .command)
        XCTAssertEqual(chords, Set([UInt16(13), 44, 36].map { ModeChord(code: $0, modifiers: .command) }))
    }

    func testOpenLensRetainsMainGlobalCommandsAfterLatch() throws {
        let config = try parsed(#"{"mode":{"main":{"binding":{"cmd-tab":"mode held","ctrl-u":"pass"}},"browse":{}}}"#)
        let chords = modeRegistrationChords(keymap: config.keymap, context: .init(mode: "browse", lensOpen: true), mode: .zero)
        XCTAssertTrue(chords.contains(.init(code: 48, modifiers: .command)))
        XCTAssertFalse(chords.contains(.init(code: 32, modifiers: .control)))
    }

    func testSequenceContinuationIsRegisteredBeforeFirstDispatch() async throws {
        config = try parsed(#"{"mode":{"main":{},"sequence":{"binding":{"g t":"focus left"}}}}"#)
        enterModeForTests("sequence")
        defer { resetHotKeys() }
        handleModeKey(code: 5, flags: [], characters: "g", carbon: true)
        XCTAssertTrue(listeningHotkeyChords().contains(.init(keyCode: 17, modifiers: 0)))
        await ModeEngine.shared.waitForInput()
    }

    func testKeyPanelLeavesPlainAndShiftChordsToComposition() throws {
        let config = try parsed(#"{"mode":{"main":{},"search":{"binding":{"enter":"lens focus","up":"lens step prev","esc":"mode browse","shift-tab":"lens mark","cmd-w":"lens close-window","alt-enter":"lens summon"}}}}"#)
        let chords = modeRegistrationChords(keymap: config.keymap, context: .init(mode: "search", lensOpen: true), mode: config.modes["search"]!, panelIsKey: true)
        XCTAssertEqual(chords, [.init(code: 13, modifiers: .command), .init(code: 36, modifiers: .option)])
        XCTAssertTrue(ModeChord(code: 36).carbonKeyCodes.contains(76))
        XCTAssertEqual(ModeChord(code: 76), ModeChord(code: 36))
    }

    func testHeldShowAndLatchDoNotActivateApplication() async throws {
        let panel = SwitcherPalettePanel(dependencies: .init(evaluate: { _, _, _ in .success([]) }, requestThumbnail: { _, _, _ in }, closeThumbnails: { _ in }, flags: { .command }), emit: { _ in })
        let activate = panel.activateInput
        var activations = 0
        panel.activateInput = { _ in activations += 1 }
        defer { panel.dismiss(); panel.activateInput = activate }
        config.modes["cmd-tab"] = defaultConfig.modes["cmd-tab"]
        config.modes["cmd-tab"]?.drawDelay = 0
        enterModeForTests("cmd-tab", gesture: .init(keyCode: 48, invoking: .command))
        await panel.openLens(name: "demo", settings: LensConfig(), entries: [], search: "", banner: nil, context: .null, ticket: panel.beginLens("demo", toggle: false)!)
        await ModeEngine.shared.waitForReadiness()
        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(activations, 0)
        enterModeForTests("browse")
        panel.currentModeChanged()
        XCTAssertEqual(activations, 0)
        panel.session?.changePresentation("grid")
        enterModeForTests("search")
        panel.currentModeChanged()
        XCTAssertEqual(activations, 0)
    }

    func testMissingAndLatchingLatchTargetsFailBothConfigPaths() throws {
        for target in ["missing", "recursive"] {
            let text = """
            {"mode":{"main":{},"held":{"unbound":"latch","latch-to":"\(target)"},"recursive":{"unbound":"latch","latch-to":"main"}}}
            """
            let value = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
            XCTAssertTrue(parseConfig(value).errors.contains { $0.description.contains("latch-to") })
            let fields = try JSONSerialization.jsonObject(with: Data(text.utf8)) as! [String: Any]
            XCTAssertTrue(compileModeKeymap(fields).errors.contains { $0.contains("latch-to") })
        }
    }

    func testSearchRowUsesConfiguredTargetsAndQueue() async throws {
        config = try parsed(#"{"mode":{"main":{},"custom":{"latch-to":"edit","binding":{"slash":"mode edit"}},"edit":{"unbound":"type","binding":{"esc":"mode custom"}}}}"#)
        enterModeForTests("custom")
        let model = LensSession(name: "demo", settings: LensConfig(), items: [], search: "")
        model.enterSearch()
        XCTAssertEqual(activeMode, "custom")
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(activeMode, "edit")
        model.leaveSearch()
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(activeMode, "custom")
    }

    func testParsedLensCommandsOwnDefaultsAndReverseSelection() throws {
        let config = try parsed(#"{"mode":{"main":{},"held":{"lifetime":"held","on-enter":["lens   recent","lens  step prev"],"on-release":["lens   focus"]}}}"#)
        XCTAssertEqual(config.modes["held"]?.unbound, .consume)
        XCTAssertEqual(config.modes["held"]?.drawDelay, 100)
        ModeEngine.shared.replace("held", mode: config.modes["held"]!)
        let model = LensSession(name: "recent", settings: LensConfig(), items: [
            .init(id: 1, title: "one", appName: "app", icon: nil, workspaceName: "1", isFocused: false),
            .init(id: 2, title: "two", appName: "app", icon: nil, workspaceName: "1", isFocused: true),
        ], search: "")
        XCTAssertEqual(model.selectedId, 2)
        ModeEngine.shared.replace("held", mode: config.modes["held"]!, invocation: .init(keyCode: 48, invoking: .command))
        let click = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: .zero, modifierFlags: [.command, .shift], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 0))
        modeBindingsForTests(["enter": ["lens focus"], "shift-enter": ["lens summon"]], mode: "held")
        ModeEngine.shared.replace("held", mode: config.modes["held"]!, invocation: .init(keyCode: 48, invoking: .command))
        XCTAssertEqual(model.key(for: click, click: true), "enter")
    }

    func testAdHocSearchParticipatesInToggleIdentity() {
        let owner = testLensLifecycle()
        let foo = LensAdHocIdentity(filter: "true", settings: LensConfig(), search: "foo")
        let bar = LensAdHocIdentity(filter: "true", settings: LensConfig(), search: "bar")
        let ticket = owner.begin("<ad-hoc>", toggle: false, identity: foo)!
        let model = LensSession(name: "<ad-hoc>", settings: LensConfig(), items: [], search: "foo")
        owner.complete(model, ticket: ticket)
        XCTAssertNotNil(owner.begin("<ad-hoc>", toggle: false, identity: bar))
        owner.dismiss()
        let implicit = LensAdHocIdentity(filter: "true", settings: LensConfig())
        let empty = LensAdHocIdentity(filter: "true", settings: LensConfig(), search: "")
        let recalled = owner.begin("<ad-hoc>", toggle: false, identity: implicit)!
        owner.complete(LensSession(name: "<ad-hoc>", settings: LensConfig(), items: [], search: "remembered"), ticket: recalled)
        XCTAssertNotNil(owner.begin("<ad-hoc>", toggle: false, identity: empty))
        owner.dismiss()
    }

    func testLensRunCloseTreatsCompanionMarkedWindowAsDone() async throws {
        let root = focus.workspace.rootTilingContainer
        let first = TestWindow.new(id: 1, parent: root)
        let second = TestWindow.new(id: 2, parent: root)
        first.onClose = { second.unbindFromParent() }
        let panel = SwitcherPalettePanel.shared; panel.dismiss()
        enterModeForTests("browse")
        let entries = try await lensWindows(popups: [:])
        await panel.openLens(name: "demo", settings: LensConfig(), entries: entries, search: "", banner: nil, context: .null, ticket: panel.beginLens("demo", toggle: false)!)
        defer { panel.dismiss() }
        let model = try XCTUnwrap(panel.session)
        model.hover(1); model.toggleMark()
        model.hover(2); model.toggleMark()
        XCTAssertEqual(model.marks, [1, 2])
        let result = try await parseCommand("lens run close").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stderr.isEmpty)
        XCTAssertEqual(first.closeAttempts, 1)
        XCTAssertEqual(second.closeAttempts, 0)
    }

    func testCommandCacheTracksModeContextAndReloadRevision() throws {
        config = try parsed(#"{"mode":{"main":{},"browse":{"binding":{"g":"lens sections next"}}}}"#)
        enterModeForTests("browse")
        let model = LensSession(name: "demo", settings: LensConfig(), items: [], search: "")
        XCTAssertEqual(model.sectionsKey, "g")
        _ = model.keyBindings; _ = model.modeCommandStrings; _ = model.commands(for: "g"); _ = model.isSectionsOnly("g")
        XCTAssertEqual(model.commandResolutionCount, 1)
        config.keymap = try parsed(#"{"mode":{"main":{},"browse":{"binding":{"y":"lens sections next"}}}}"#).keymap
        ModeEngine.shared.reconfigure(ModeEngine.shared.properties)
        XCTAssertEqual(model.sectionsKey, "y")
        XCTAssertTrue(model.commands(for: "g").isEmpty)
        XCTAssertTrue(model.isSectionsOnly("y"))
        XCTAssertEqual(model.commandResolutionCount, 2)
    }

    func testReconcileKeepsUnchangedCarbonRegistrationAndAddsKeypadEnter() throws {
        defer { resetHotKeys() }
        registerModeChords([.init(code: 36), .init(code: 4)])
        let enter = try XCTUnwrap(modeHotkeyForTests(code: 36))
        XCTAssertNotNil(modeHotkeyForTests(code: 76))
        registerModeChords([.init(code: 36), .init(code: 38)])
        XCTAssertTrue(enter === modeHotkeyForTests(code: 36))
        XCTAssertNil(modeHotkeyForTests(code: 4))
        XCTAssertNotNil(modeHotkeyForTests(code: 38))
    }

    func testInvalidRuntimeLatchTargetDoesNotEnterPhantomMode() async {
        config.modes["bad"] = .zero
        config.modes["bad"]!.unbound = .latch
        config.modes["bad"]!.latchTo = "missing"
        enterModeForTests("bad")
        handleModeKey(code: 0, flags: [], characters: "a")
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(activeMode, "bad")
        config.modes["carrier"] = .zero
        config.modes["carrier"]!.onEnter = ["mode latching"]
        config.modes["latching"] = .zero
        config.modes["latching"]!.unbound = .latch
        config.modes["latching"]!.latchTo = "main"
        config.modes["bad"]!.latchTo = "carrier"
        enterModeForTests("bad")
        handleModeKey(code: 0, flags: [], characters: "a")
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(activeMode, "latching", "on-enter can change the target's mode; never re-dispatch into its latching policy")
    }

    func testThrowingOpenerStillReachesReadyAndDrainsParkedInput() async {
        let engine = ModeEngine(liveModifiers: { .command })
        var mode = Mode.zero; mode.onEnter = ["lens missing"]
        var drained = false
        engine.execute = { _ in
            engine.whenLensReady { drained = true }
            throw ModeConfigError("failed Filter")
        }
        do { try await engine.enter("opening", mode: mode); XCTFail("Must propagate the failure") }
        catch { XCTAssertEqual(String(describing: error), "failed Filter") }
        XCTAssertTrue(drained)
        XCTAssertFalse(engine.isOpening)
    }

    func testCancelledLensPreparationPreservesOpeningKeysAndRelease() async throws {
        let engine = ModeEngine(liveModifiers: { .command })
        let owner = testLensLifecycle(modeEngine: engine)
        var mode = Mode.zero; mode.lifetime = .held; mode.onEnter = ["lens recent"]; mode.onRelease = ["focus left"]
        var actions: [String] = []
        engine.execute = { commands in
            if commands.first?.args.description == "lens recent" {
                let ticket = owner.begin("recent", toggle: false)!
                engine.whenLensReady { actions.append("key") }
                engine.noteModifiers([])
                owner.cancelOpening(ticket: ticket)
            } else { actions += commands.map { $0.args.description } }
        }
        try await engine.enter("held", mode: mode, invocation: .init(keyCode: 48, invoking: .command))
        XCTAssertEqual(actions, ["key", "focus left"])
        XCTAssertEqual(engine.current, "main")
        XCTAssertFalse(owner.isOpen)
    }

    func testCLIEntryReadinessOwnsQueueUntilParkedWorkFinishes() async throws {
        let engine = ModeEngine()
        let started = expectation(description: "parked work started")
        var finish: CheckedContinuation<Void, Never>?
        var actions: [Int] = []
        var mode = Mode.zero; mode.onEnter = ["lens missing"]
        engine.execute = { _ in
            engine.whenLensReady {
                actions.append(1); started.fulfill()
                await withCheckedContinuation { finish = $0 }
                actions.append(2)
            }
        }
        let entry = Task { try await engine.enter("opening", mode: mode) }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertFalse(engine.inputIsIdle)
        engine.enqueueInput { actions.append(3) }
        finish?.resume()
        try await entry.value
        await engine.waitForInput()
        XCTAssertEqual(actions, [1, 2, 3])
    }

    func testInterruptDropsEveryQueuedActionAndSerializesNewInput() async throws {
        let engine = ModeEngine(liveModifiers: { .command })
        let started = expectation(description: "in flight")
        let global = expectation(description: "global started")
        var resumeOld: CheckedContinuation<Void, Never>?
        var resumeGlobal: CheckedContinuation<Void, Never>?
        var actions: [String] = []
        let old = engine.enqueueInput {
            started.fulfill()
            await withCheckedContinuation { resumeOld = $0 }
        }
        await fulfillment(of: [started], timeout: 2)
        engine.enqueueInput { actions.append("stale key") }
        engine.enqueueInput { actions.append("stale deadline") }
        engine.enqueueInput { actions.append("stale release") }
        engine.interruptOpening {
            actions.append("global")
            global.fulfill()
            await withCheckedContinuation { resumeGlobal = $0 }
        }
        engine.enqueueInput { actions.append("new key") }
        await fulfillment(of: [global], timeout: 2)
        resumeOld?.resume()
        await old.value
        resumeGlobal?.resume()
        await engine.waitForInput()
        XCTAssertEqual(actions, ["global", "new key"])
    }

    func testFailedOpenerDrainsKeysAndReleaseBeforeAnotherLens() async throws {
        let engine = ModeEngine(liveModifiers: { .command })
        var mode = Mode.zero
        mode.lifetime = .held; mode.onEnter = ["lens missing"]; mode.onRelease = ["focus left"]
        var actions: [String] = []
        engine.execute = { commands in
            for command in commands {
                if command.args.description == "lens missing" {
                    engine.whenLensReady { actions.append("key") }
                    engine.noteModifiers([])
                } else { actions.append(command.args.description) }
            }
        }
        try await engine.enter("held", mode: mode, invocation: .init(keyCode: 48, invoking: .command))
        await engine.waitForInput()
        XCTAssertEqual(actions, ["key", "focus left"])
        XCTAssertEqual(engine.current, "main")
        XCTAssertFalse(engine.isOpening)
    }

    func testReadyReadsLiveReleaseForZeroDelayHeldModeWithoutLens() async throws {
        for lensAlreadyOpen in [false, true] {
            var reads = 0
            let engine = ModeEngine(liveModifiers: { reads += 1; return [] })
            if lensAlreadyOpen { engine.lensOpening(); await engine.lensReady(show: {}, flags: []) }
            var mode = Mode.zero; mode.lifetime = .held
            try await engine.enter("resize", mode: mode, invocation: .init(keyCode: 15, invoking: .option))
            XCTAssertEqual(engine.current, "main")
            XCTAssertEqual(reads, 1)
        }
    }

    func testQueuedEscapeThenLetterUsesBrowseInsteadOfSearchEditor() async throws {
        let panel = SwitcherPalettePanel.shared
        panel.dismiss()
        enterModeForTests("search")
        await panel.openLens(name: "demo", settings: LensConfig(), entries: [], search: "abc", banner: nil, context: .null, ticket: panel.beginLens("demo", toggle: false)!)
        defer { panel.dismiss() }
        XCTAssertTrue(handleModeKey(code: 53, flags: [], characters: ""))
        XCTAssertTrue(handleModeKey(code: 38, flags: [], characters: "j"))
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(activeMode, "browse")
        XCTAssertEqual(panel.session?.query, "abc")
    }
}
