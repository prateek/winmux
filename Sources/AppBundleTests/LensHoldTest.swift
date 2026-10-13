@testable import AppBundle
import AppKit
import Clocks
import Common
import XCTest

@MainActor
final class LensHoldTest: SerialClockTestCase {
    override func setUp() async throws { setUpWorkspacesForTests(); _ = NSApplication.shared }

    private func key(_ code: UInt16, _ text: String, _ flags: NSEvent.ModifierFlags = .command) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                        windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text,
                        isARepeat: false, keyCode: code)!
    }

    func testPreservedHoldRoutingBeforeModalChange() {
        let hold = StripGesture(keyCode: 48, invoking: .command)
        let keys = [LensKeyBinding(name: "cmd-w", code: 13, modifiers: .command)]
        let cases: [(UInt16, String, NSEvent.ModifierFlags, LensKeyMeaning)] = [
            (48, "\t", .command, .step(1)),
            (48, "\t", [.command, .shift], .step(-1)),
            (50, "`", .command, .step(0)),
            (125, "", .command, .arrow(125)),
            (53, "", .command, .dismiss),
            (13, "w", .command, .command("cmd-w")),
            (4, "h", [.command, .option], .global),
        ]
        for (code, text, flags, expected) in cases {
            XCTAssertEqual(lensKeyMeaning(state: .hold, hold: hold, keys: keys, code: code, characters: text, flags: flags), expected)
        }
        let backtick = StripGesture(keyCode: 50, invoking: .command)
        XCTAssertEqual(lensKeyMeaning(state: .hold, hold: backtick, keys: [], code: 50, characters: "`", flags: .command), .step(1))
    }

    func testPreservedStripReleaseCommitsSelection() {
        let owner = testLensLifecycle()
        defer { owner.dismiss() }
        var settings = LensConfig(); settings.presentation = "strip"
        let model = LensSession(name: "release", settings: settings, items: [], search: "")
        let gesture = StripGesture(keyCode: 48, invoking: .command)
        owner.complete(model, ticket: owner.begin("release", toggle: false, strip: gesture)!)
        var actions: [String] = []
        model.onAction = { actions.append($0) }
        owner.stripFlagsChanged([], from: model)
        XCTAssertEqual(actions, ["enter"])
    }

    func testFirstLetterMakesStripModalAndReleaseCannotCommit() {
        let owner = testLensLifecycle()
        defer { owner.dismiss() }
        var settings = LensConfig(); settings.presentation = "strip"
        let items = (1...4).map { SwitcherPaletteItem(id: UInt32($0), title: "Safari \($0)", appName: "Safari", icon: nil, workspaceName: "1", isFocused: $0 == 1) }
        let model = LensSession(name: "modal", settings: settings, items: items, search: "")
        owner.complete(model, ticket: owner.begin("modal", toggle: false, strip: StripGesture(keyCode: 48, invoking: .command))!)
        var actions: [String] = []; model.onAction = { actions.append($0) }
        XCTAssertTrue(model.perform(model.meaning(for: key(38, "j"))))
        XCTAssertNil(model.hold)
        XCTAssertEqual(model.settings.presentation, "strip")
        XCTAssertEqual(model.query, "")
        owner.stripFlagsChanged([], from: model)
        XCTAssertEqual(actions, [])
        XCTAssertTrue(owner.session === model)
        model.startHold(StripGesture(keyCode: 48, invoking: .command))
        XCTAssertNil(model.hold)
    }

    func testTriggerAfterLetterUsesGlobalToggleAndCannotStartAnotherHold() async {
        let panel = SwitcherPalettePanel.shared
        defer { panel.dismiss() }
        for presentation in ["strip", "list", "grid", "miniatures"] {
            var settings = LensConfig(); settings.presentation = presentation == "strip" ? "list" : presentation
            if presentation == "strip" { settings.startsIn = "normal" }
            let gesture = StripGesture(keyCode: 48, invoking: .command)
            let ticket = panel.beginLens("trigger", toggle: true)!
            await panel.openLens(name: "trigger", settings: settings, entries: [], search: "", banner: nil, context: .null, ticket: ticket, invocation: gesture)
            if presentation == "strip" { panel.session!.changePresentation("strip") }
            panel.sendEvent(key(38, "j"))
            let model = panel.session!
            XCTAssertNil(model.hold)
            XCTAssertFalse(panel.handleStripHotkey(keyCode: 48, modifiers: .command, characters: "tab"))
            XCTAssertTrue(panel.session === model, "The global Trigger must see the open Lens to toggle it")
            XCTAssertNil(panel.beginLens("trigger", toggle: true, strip: presentation == "strip" ? gesture : nil))
            XCTAssertNil(panel.session)
        }
    }

    func testNormalGridRequiresSlashAndEscapeKeepsMatches() {
        var settings = LensConfig(); settings.presentation = "grid"
        let items = (1...3).map { SwitcherPaletteItem(id: UInt32($0), title: $0 < 3 ? "Safari" : "Other", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false) }
        let model = LensSession(name: "grid", settings: settings, items: items, search: "")
        let owner = ownLens(model); defer { owner.dismiss() }
        for (code, text) in [(UInt16(1), "s"), (0, "a"), (3, "f")] { XCTAssertTrue(model.perform(model.meaning(for: key(code, text, [])))) }
        XCTAssertEqual(model.query, "")
        XCTAssertTrue(model.perform(model.meaning(for: key(44, "/", []))))
        for (code, text) in [(UInt16(1), "s"), (0, "a"), (3, "f")] { XCTAssertTrue(model.perform(model.meaning(for: key(code, text, [])))) }
        XCTAssertEqual(model.query, "saf")
        XCTAssertEqual(model.results.count, 2)
        XCTAssertTrue(model.perform(model.meaning(for: key(53, "", []))))
        XCTAssertEqual(model.query, "saf")
        XCTAssertEqual(model.results.count, 2)
        XCTAssertEqual(model.meaning(for: key(38, "j", [])), .arrow(125))
        XCTAssertEqual(model.meaning(for: key(53, "", [])), .dismiss)
    }

    func testOptionReturnUsesReleaseMeaningBeforeAltEnterBinding() {
        let model = LensSession(name: "option", settings: LensConfig(), items: [], search: "")
        model.startHold(StripGesture(keyCode: 44, invoking: .option))
        XCTAssertEqual(model.meaning(for: key(36, "\r", .option)), .command("enter"))
        XCTAssertEqual(model.meaning(for: key(36, "\r", [.option, .shift])), .command("shift-enter"))
    }

    func testStartsInResolutionProfilesJSONAndPresentationChanges() {
        for presentation in ["list", "strip", "grid", "miniatures"] {
            for configured: String? in [nil, "normal", "search"] {
                var settings = LensConfig(); settings.presentation = presentation; settings.startsIn = configured
                let model = LensSession(name: "start", settings: settings, items: [], search: "saved")
                let expected: LensInputState = configured == "search" || (configured == nil && presentation == "list") ? .search : .normal
                XCTAssertEqual(model.inputState, expected)
                XCTAssertEqual(model.query, expected == .search ? "saved" : "")
                model.changePresentation(presentation == "list" ? "grid" : "list")
                XCTAssertEqual(model.inputState, expected)
                if expected == .normal {
                    model.enterSearch()
                    XCTAssertEqual(model.query, "saved")
                }
                XCTAssertFalse(model.searchEdited)
                model.perform(.text("x"))
                XCTAssertEqual(model.query, "x")
            }
        }
        let settings = LensConfig(.object(["starts-in": .string("search"), "when": .object(["default": .object(["starts-in": .string("normal")])])]))
        XCTAssertEqual(settings.startsIn, "normal")
        XCTAssertEqual(settings.json["starts-in"], .string("normal"))
        XCTAssertEqual(LensConfig().json["starts-in"], .null)
        let owner = testLensLifecycle(); defer { owner.dismiss() }
        var normal = LensConfig(); normal.startsIn = "normal"
        let model = LensSession(name: "saved", settings: normal, items: [], search: "remembered")
        owner.complete(model, ticket: owner.begin("saved", toggle: false)!)
        owner.dismiss()
        XCTAssertEqual(owner.search(for: "saved", override: nil), "remembered")
    }

    func testPlainBindingsWinInNormalAndAreTextInSearchAndHoldCommandsKeepHold() {
        var settings = LensConfig(); settings.presentation = "grid"; settings.keys["j"] = ["close"]
        let model = LensSession(name: "bound", settings: settings, items: [], search: "")
        var actions: [String] = []; model.onAction = { actions.append($0) }
        XCTAssertTrue(model.perform(model.meaning(for: key(38, "j", []))))
        XCTAssertEqual(actions, ["j"])
        model.startHold(StripGesture(keyCode: 48, invoking: .command))
        XCTAssertTrue(model.perform(model.meaning(for: key(13, "w"))))
        XCTAssertEqual(model.inputState, .hold)
        XCTAssertTrue(model.keepsOpen(after: "cmd-w"))
        XCTAssertFalse(model.keepsOpen(after: "enter"))
        XCTAssertEqual(actions, ["j", "cmd-w"])
        XCTAssertTrue(model.perform(model.meaning(for: key(38, "j"))))
        XCTAssertEqual(actions, ["j", "cmd-w", "j"])
        XCTAssertEqual(model.inputState, .normal)
        XCTAssertFalse(model.keepsOpen(after: "cmd-w"))
        model.enterSearch()
        XCTAssertEqual(model.meaning(for: key(38, "j", [])), .text("j"))
        XCTAssertTrue(model.perform(model.meaning(for: key(38, "j", []))))
        XCTAssertEqual(model.query, "j")
        XCTAssertEqual(model.meaning(for: key(0, "a")), .fieldEditor)
        XCTAssertEqual(model.meaning(for: key(9, "v")), .fieldEditor)
    }

    func testNormalAndHoldKeepPanelResponderAndSearchGivesItToEditor() async {
        let panel = SwitcherPalettePanel.shared; defer { panel.dismiss() }
        var settings = LensConfig(); settings.startsIn = "normal"
        let gesture = StripGesture(keyCode: 44, invoking: .option)
        await panel.openLens(name: "focus", settings: settings, entries: [], search: "remembered", banner: nil, context: .null, ticket: panel.beginLens("focus", toggle: false)!, invocation: gesture)
        XCTAssertEqual(panel.session?.inputState, .hold)
        XCTAssertFalse(panel.firstResponder is NSTextView)
        panel.sendEvent(key(38, "j", .option))
        XCTAssertEqual(panel.session?.inputState, .normal)
        XCTAssertFalse(panel.firstResponder is NSTextView)
        panel.session?.enterSearch()
        await Task.yield()
        XCTAssertEqual(panel.session?.inputState, .search)
        XCTAssertTrue(panel.firstResponder is NSTextView)
        panel.sendEvent(key(53, "", []))
        XCTAssertEqual(panel.session?.inputState, .normal)
        XCTAssertFalse(panel.firstResponder is NSTextView)
        XCTAssertEqual(panel.session?.query, "remembered")
    }

    func testPureMeaningTableOverThreeStates() {
        let hold = StripGesture(keyCode: 48, invoking: .command)
        let keys = [LensKeyBinding(name: "cmd-w", code: 13, modifiers: .command),
                    LensKeyBinding(name: "enter", code: 36, modifiers: []),
                    LensKeyBinding(name: "shift-enter", code: 36, modifiers: .shift)]
        let cases: [(LensInputState, UInt16, String, NSEvent.ModifierFlags, LensKeyMeaning)] = [
            (.hold, 13, "w", .command, .command("cmd-w")),
            (.hold, 36, "\r", .command, .command("enter")),
            (.hold, 36, "\r", [.command, .shift], .command("shift-enter")),
            (.hold, 48, "\t", .command, .step(1)),
            (.hold, 48, "\t", [.command, .shift], .step(-1)),
            (.hold, 50, "`", .command, .step(0)),
            (.hold, 5, "g", .command, .endHold(5, "g")),
            (.hold, 4, "H", [.command, .shift], .endHold(4, "H")),
            (.hold, 4, "h", [], .endHold(4, "h")),
            (.hold, 44, "/", .command, .endHold(44, "/")),
            (.hold, 51, "", .command, .dropped),
            (.hold, 18, "1", .command, .dropped),
            (.hold, 49, " ", .command, .dropped),
            (.hold, 47, ".", .command, .dropped),
            (.hold, 125, "", .command, .arrow(125)),
            (.hold, 53, "", .command, .dismiss),
            (.hold, 4, "h", [.command, .option], .global),
            (.hold, 122, "", .command, .dropped),
            (.hold, 117, "\u{F728}", .command, .dropped),
            (.hold, 116, "\u{F72C}", .command, .dropped),
            (.normal, 38, "j", [], .arrow(125)),
            (.normal, 4, "h", [], .arrow(123)),
            (.normal, 40, "k", [], .arrow(126)),
            (.normal, 37, "l", [], .arrow(124)),
            (.normal, 7, "x", [], .dropped),
            (.normal, 51, "", [], .dropped),
            (.normal, 44, "/", [], .enterSearch),
            (.normal, 53, "", [], .dismiss),
            (.normal, 38, "j", .command, .fieldEditor),
            (.search, 38, "j", [], .text("j")),
            (.search, 0, "a", .command, .fieldEditor),
            (.search, 9, "v", .command, .fieldEditor),
            (.search, 51, "", [], .backspace),
            (.search, 53, "", [], .leaveSearch),
        ]
        for (state, code, text, flags, expected) in cases {
            XCTAssertEqual(lensKeyMeaning(state: state, hold: state == .hold ? hold : nil, keys: keys, code: code, characters: text, flags: flags), expected, "\(state) \(text) \(flags)")
        }
        let alt = StripGesture(keyCode: 15, invoking: .option)
        XCTAssertEqual(lensKeyMeaning(state: .hold, hold: alt, keys: [], code: 4, characters: "h", flags: .option), .endHold(4, "h"))
        XCTAssertEqual(lensKeyMeaning(state: .hold, hold: alt, keys: [], code: 4, characters: "h", flags: .command), .global)
    }

    func testControlledLifecycleHoldEndsOnceAndSlashConvertsWithoutCommit() async {
        let clock = TestClock<Duration>()
        let owner = testLensLifecycle(clock: clock); defer { owner.dismiss() }
        var settings = LensConfig(); settings.presentation = "strip"; settings.keys["cmd-w"] = []
        let items = (1...3).map { SwitcherPaletteItem(id: UInt32($0), title: "Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: $0 == 1) }
        let model = LensSession(name: "hold", settings: settings, items: items, search: "")
        let gesture = StripGesture(keyCode: 48, invoking: .command, clock: clock)
        owner.complete(model, ticket: owner.begin("hold", toggle: false, strip: gesture)!)
        await clock.advance(by: .milliseconds(100))
        var actions: [String] = []; model.onAction = { actions.append($0) }
        XCTAssertTrue(model.perform(model.meaning(for: key(13, "w"))))
        XCTAssertNotNil(model.hold)
        XCTAssertEqual(actions, ["cmd-w"])
        XCTAssertTrue(model.perform(model.meaning(for: key(38, "j"))))
        XCTAssertEqual(model.selection, 2)
        XCTAssertEqual(model.query, "")
        XCTAssertEqual(model.settings.presentation, "strip")
        XCTAssertNil(model.hold)
        owner.stripFlagsChanged([], from: model)
        XCTAssertTrue(owner.session === model)
        XCTAssertEqual(actions, ["cmd-w"])
        model.startHold(gesture); XCTAssertNil(model.hold)
        let selected = model.selectedId
        XCTAssertTrue(model.perform(model.meaning(for: key(44, "/", []))))
        XCTAssertEqual(model.settings.presentation, "list")
        XCTAssertEqual(model.selectedId, selected)
        XCTAssertEqual(model.inputState, .search)
    }

    func testOpeningKeepsLetterAndFollowingKeysInTheirOriginalOrder() {
        let owner = testLensLifecycle(); defer { owner.dismiss() }
        let gesture = StripGesture(keyCode: 48, invoking: .command)
        let store = LensTraceStore()
        let trace = store.begin(presentation: "strip", origin: .init(start: 0, received: 0, source: "test"))
        let ticket = owner.begin("order", toggle: false, strip: gesture, trace: trace)!
        XCTAssertEqual(owner.openingStripKey(keyCode: 38, flags: .command, characters: "j"), .consumed)
        XCTAssertEqual(owner.openingStripKey(keyCode: 38, flags: [], characters: "j"), .consumed)
        var settings = LensConfig(); settings.presentation = "strip"
        let items = (1...3).map { SwitcherPaletteItem(id: UInt32($0), title: "Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: $0 == 1) }
        let model = LensSession(name: "order", settings: settings, items: items, search: "")
        owner.complete(model, ticket: ticket)
        XCTAssertEqual(model.query, "")
        XCTAssertEqual(model.selectedId, 1)
        XCTAssertEqual(model.inputState, .normal)
        XCTAssertEqual(trace.snapshot.keys.map(\.state), [.hold, .normal])
        XCTAssertTrue(trace.snapshot.keys[0].destination.contains("Hold ended by key"))
        XCTAssertEqual(trace.snapshot.session?.state, .normal)
    }

    func testShiftOnlyChordHasAHoldWithoutChangingStripCommitModifiers() {
        let owner = testLensLifecycle()
        let gesture = StripGesture(keyCode: 15, invoking: .shift)
        let model = LensSession(name: "shift", settings: LensConfig(), items: [], search: "")
        owner.complete(model, ticket: owner.begin("shift", toggle: false)!, invocation: gesture)
        owner.stripFlagsChanged(.shift, from: model)
        XCTAssertNotNil(model.hold)
        XCTAssertEqual(model.meaning(for: key(4, "H", .shift)), .endHold(4, "h"))
        XCTAssertTrue(model.perform(model.meaning(for: key(4, "H", .shift))))
        XCTAssertEqual(model.query, "h")
        owner.stripFlagsChanged([], from: model)
        XCTAssertNil(model.hold)
        XCTAssertTrue(owner.session === model)
        XCTAssertEqual(gesture.committingModifiers, [])
        owner.dismiss()
    }

    func testDirectListOpeningStepsAndUnmodifiedLeaderTyping() {
        for held in [true, false] {
            let owner = testLensLifecycle()
            let gesture = StripGesture(keyCode: 15, invoking: held ? .option : [])
            let ticket = owner.begin("direct", toggle: false, invocation: gesture)!
            XCTAssertEqual(owner.openingStripKey(keyCode: 15, flags: held ? .option : [], characters: "r"), held ? .consumed : nil)
            let items = (1...3).map { SwitcherPaletteItem(id: UInt32($0), title: "r Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: $0 == 1) }
            let model = LensSession(name: "direct", settings: LensConfig(), items: items, search: "")
            owner.complete(model, ticket: ticket)
            XCTAssertEqual(model.query, "")
            XCTAssertEqual(model.selectedId, held ? 3 : 2)
            owner.dismiss()
        }
    }

    func testReleaseDuringOpeningStartsDirectListWithoutHold() {
        let owner = testLensLifecycle()
        defer { owner.dismiss() }
        let gesture = StripGesture(keyCode: 15, invoking: .command)
        let ticket = owner.begin("direct", toggle: false, strip: gesture)!
        owner.openingFlagsChanged([])
        let model = LensSession(name: "direct", settings: LensConfig(), items: [], search: "")
        owner.complete(model, ticket: ticket, invocation: gesture)
        XCTAssertNil(model.hold)
        XCTAssertEqual(model.meaning(for: key(4, "h")), .fieldEditor)
    }

    func testOpeningLettersEndHoldBeforeAnyQueuedReleaseCommit() {
        for release in [false, true] {
            let owner = testLensLifecycle(); defer { owner.dismiss() }
            let ticket = owner.begin("queued", toggle: false, strip: StripGesture(keyCode: 48, invoking: .command))!
            XCTAssertEqual(owner.openingStripKey(keyCode: 5, flags: .command, characters: "g"), .consumed)
            XCTAssertEqual(owner.openingStripKey(keyCode: 4, flags: .command, characters: "h"), .consumed)
            if release { owner.openingFlagsChanged([]) }
            var settings = LensConfig(); settings.presentation = "strip"
            let model = LensSession(name: "queued", settings: settings, items: [], search: "")
            owner.complete(model, ticket: ticket)
            XCTAssertEqual(model.query, "")
            XCTAssertEqual(model.settings.presentation, "strip")
            XCTAssertNil(model.hold)
            XCTAssertTrue(model.holdEndedByKey)
            XCTAssertTrue(owner.session === model)
        }
    }

    func testCLIAndLeaderHaveNoHoldAndKeepOrdinaryCommandChords() {
        for invocation: StripGesture? in [nil, StripGesture(keyCode: 15, invoking: [])] {
            let owner = testLensLifecycle()
            let model = LensSession(name: "ordinary", settings: LensConfig(), items: [], search: "")
            owner.complete(model, ticket: owner.begin("ordinary", toggle: false)!, invocation: invocation)
            XCTAssertNil(model.hold)
            XCTAssertEqual(model.meaning(for: key(5, "g", [])), .text("g"))
            XCTAssertTrue(model.perform(model.meaning(for: key(5, "g", []))))
            XCTAssertEqual(model.meaning(for: key(4, "h")), .fieldEditor)
            XCTAssertEqual(model.meaning(for: key(13, "w")), .command("cmd-w"))
            owner.dismiss()
        }
    }

    func testHeldTypingReplacesARememberedSearchAsSelectAllWould() {
        for backspace in [false, true] {
            let owner = testLensLifecycle()
            let model = LensSession(name: "remembered", settings: LensConfig(), items: [], search: "foo")
            owner.complete(model, ticket: owner.begin("remembered", toggle: false)!, invocation: StripGesture(keyCode: 44, invoking: .option))
            XCTAssertNotNil(model.hold)
            XCTAssertFalse(model.searchEdited)
            if backspace {
                XCTAssertTrue(model.perform(model.meaning(for: key(51, "", .option))))
                XCTAssertEqual(model.query, "")
                XCTAssertNotNil(model.hold)
            }
            XCTAssertTrue(model.perform(model.meaning(for: key(11, "b", .option))))
            XCTAssertTrue(model.perform(model.meaning(for: key(0, "a", []))))
            XCTAssertEqual(model.query, "ba")
            XCTAssertTrue(model.searchEdited)
            owner.dismiss()
        }
    }

    func testOpeningWithoutHoldLeavesGlobalBindingsAlone() {
        let owner = testLensLifecycle()
        defer { owner.dismiss() }
        _ = owner.begin("leader", toggle: false, invocation: StripGesture(keyCode: 31, invoking: []))
        XCTAssertNil(owner.openingStripKey(keyCode: 4, flags: .option, characters: "h"))
        XCTAssertNil(owner.openingStripKey(keyCode: 4, flags: [], characters: "h"))
        guard case .opening = owner.state else { return XCTFail("the opening Lens was dismissed") }
    }

    func testListWithoutHoldLeavesSidewaysArrowsToTheFieldEditor() {
        let model = LensSession(name: "ordinary", settings: LensConfig(), items: [], search: "gh")
        let owner = ownLens(model)
        defer { owner.dismiss() }
        for flags: NSEvent.ModifierFlags in [[], .option, .shift] {
            XCTAssertFalse(model.perform(model.meaning(for: key(123, "", flags))))
            XCTAssertFalse(model.perform(model.meaning(for: key(124, "", flags))))
        }
        XCTAssertTrue(model.perform(model.meaning(for: key(125, "", []))))
    }

    func testGlobalBindingOnAListWithoutHoldIsNotTheLenss() async {
        let panel = SwitcherPalettePanel.shared
        defer { panel.dismiss() }
        let ticket = panel.beginLens("ordinary", toggle: false)!
        await panel.openLens(name: "ordinary", settings: LensConfig(), entries: [], search: "", banner: nil, context: .null, ticket: ticket)
        let model = try! XCTUnwrap(panel.session)
        for (code, text) in [(UInt16(48), "tab"), (53, "escape"), (125, "down")] {
            XCTAssertFalse(panel.handleStripHotkey(keyCode: code, modifiers: .command, characters: text))
            XCTAssertTrue(panel.session === model)
        }
    }

    func testModifierChangesWithoutHoldPreserveFieldEditorSelection() async {
        let panel = SwitcherPalettePanel.shared
        defer { panel.dismiss() }
        let ticket = panel.beginLens("ordinary-selection", toggle: false)!
        await panel.openLens(name: "ordinary-selection", settings: LensConfig(), entries: [], search: "gh", banner: nil, context: .null, ticket: ticket)
        let editor = NSTextView(frame: .zero)
        panel.contentView?.addSubview(editor)
        defer { editor.removeFromSuperview() }
        XCTAssertTrue(panel.makeFirstResponder(editor))
        editor.string = "gh"
        editor.setSelectedRange(NSRange(location: 0, length: 2))
        panel.stripFlagsChanged(.command)
        panel.stripFlagsChanged([])
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 0, length: 2))
        XCTAssertEqual(panel.session?.query, "gh")
    }

    func testPanelKeepsBothLettersAndBackspaceAcrossConversionAtBothEntryPoints() async {
        let panel = SwitcherPalettePanel.shared
        defer { panel.dismiss() }
        for equivalent in [false, true] {
            var settings = LensConfig(); settings.presentation = "list"; settings.startsIn = "search"
            let gesture = StripGesture(keyCode: 48, invoking: .command)
            let ticket = panel.beginLens("hold", toggle: false, strip: gesture)!
            await panel.openLens(name: "hold", settings: settings, entries: [], search: "", banner: nil, context: .null, ticket: ticket, invocation: gesture)
            let model = try! XCTUnwrap(panel.session)
            model.beginStrip(gesture)
            model.changePresentation("strip")
            for event in [key(5, "g"), key(4, "h", [])] {
                _ = panel.makeFirstResponder(panel)
                if equivalent { XCTAssertTrue(panel.performKeyEquivalent(with: event)) }
                else { panel.sendEvent(event) }
            }
            XCTAssertEqual(model.settings.presentation, "list")
            XCTAssertEqual(model.query, "gh")
            _ = panel.makeFirstResponder(panel)
            if equivalent { XCTAssertTrue(panel.performKeyEquivalent(with: key(51, "", []))) }
            else { panel.sendEvent(key(51, "", [])) }
            XCTAssertEqual(model.query, "g")
            panel.stripFlagsChanged([])
            panel.sendEvent(key(4, "h", .command))
            XCTAssertTrue(panel.session === model)
            XCTAssertEqual(model.query, "g")
            panel.dismiss()
        }
    }

    func testCarbonLetterAndForeignChordInListAndMiniatures() async {
        let panel = SwitcherPalettePanel.shared
        defer { panel.dismiss() }
        for presentation in ["list", "miniatures"] {
            var settings = LensConfig(); settings.presentation = presentation
            let gesture = StripGesture(keyCode: 48, invoking: .option)
            let ticket = panel.beginLens("direct", toggle: false, strip: gesture)!
            await panel.openLens(name: "direct", settings: settings, entries: [], search: "", banner: nil, context: .null, ticket: ticket, invocation: gesture)
            XCTAssertTrue(panel.handleStripHotkey(keyCode: 4, modifiers: .option, characters: "h"))
            XCTAssertEqual(panel.session?.query, presentation == "list" ? "h" : "")
            XCTAssertFalse(panel.handleStripHotkey(keyCode: 37, modifiers: [.option, .control], characters: "l"))
            XCTAssertNotNil(panel.session)
            panel.dismiss()
        }
    }

    func testLettersBeforeFieldEditorIsReadyAreRetainedWithoutModifiers() async {
        let panel = SwitcherPalettePanel.shared
        defer { panel.dismiss() }
        var settings = LensConfig(); settings.presentation = "list"; settings.startsIn = "search"
        let gesture = StripGesture(keyCode: 48, invoking: .command)
        let ticket = panel.beginLens("gap", toggle: false, strip: gesture)!
        await panel.openLens(name: "gap", settings: settings, entries: [], search: "", banner: nil, context: .null, ticket: ticket, invocation: gesture)
        panel.session!.beginStrip(gesture)
        panel.session!.changePresentation("strip")
        panel.sendEvent(key(5, "g"))
        panel.stripFlagsChanged([])
        _ = panel.makeFirstResponder(nil)
        panel.sendEvent(key(4, "h", []))
        panel.sendEvent(key(0, "a", []))
        XCTAssertEqual(panel.session?.query, "gha")
    }
}
