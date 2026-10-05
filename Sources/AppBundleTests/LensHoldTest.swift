@testable import AppBundle
import AppKit
import Clocks
import XCTest

@MainActor
final class LensHoldTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests(); _ = NSApplication.shared }

    private func key(_ code: UInt16, _ text: String, _ flags: NSEvent.ModifierFlags = .command) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                        windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text,
                        isARepeat: false, keyCode: code)!
    }

    func testPureMeaningTable() {
        let hold = StripGesture(keyCode: 48, invoking: .command)
        let keys = [LensKeyBinding(name: "cmd-w", code: 13, modifiers: .command),
                    LensKeyBinding(name: "enter", code: 36, modifiers: []),
                    LensKeyBinding(name: "shift-enter", code: 36, modifiers: .shift)]
        let cases: [(UInt16, String, NSEvent.ModifierFlags, LensKeyMeaning)] = [
            (13, "w", .command, .command("cmd-w")),
            (36, "\r", .command, .command("enter")),
            (36, "\r", [.command, .shift], .command("shift-enter")),
            (48, "\t", .command, .step(1)),
            (48, "\t", [.command, .shift], .step(-1)),
            (50, "`", .command, .step(0)),
            (5, "g", .command, .text("g")),
            (4, "H", [.command, .shift], .text("H")),
            (4, "h", [], .text("h")),
            (51, "", .command, .backspace),
            (125, "", .command, .arrow(125)),
            (53, "", .command, .dismiss),
            (4, "h", [.command, .option], .global),
            (0, "a", .command, .dropped),
            (9, "v", .command, .dropped),
        ]
        for (code, text, flags, expected) in cases {
            XCTAssertEqual(lensKeyMeaning(hold: hold, keys: keys, code: code, characters: text, flags: flags), expected)
        }
        XCTAssertEqual(lensKeyMeaning(hold: nil, keys: keys, code: 4, characters: "h", flags: .command), .fieldEditor)
        XCTAssertEqual(lensKeyMeaning(hold: nil, keys: keys, code: 5, characters: "g", flags: []), .text("g"))
        let alt = StripGesture(keyCode: 15, invoking: .option)
        XCTAssertEqual(lensKeyMeaning(hold: alt, keys: [], code: 4, characters: "h", flags: .option), .text("h"))
        XCTAssertEqual(lensKeyMeaning(hold: alt, keys: [], code: 4, characters: "h", flags: .command), .global)
    }

    func testControlledLifecycleHoldSurvivesConversionAndEndsOnceWithoutCommit() async {
        let clock = TestClock<Duration>()
        let owner = testLensLifecycle(clock: clock)
        defer { owner.dismiss() }
        var settings = LensConfig(); settings.presentation = "strip"; settings.keys["cmd-w"] = []
        let items = (1...3).map { SwitcherPaletteItem(id: UInt32($0), title: "gh Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: $0 == 1) }
        let model = LensSession(name: "hold", settings: settings, items: items, search: "")
        let gesture = StripGesture(keyCode: 48, invoking: .command, clock: clock)
        let ticket = owner.begin("hold", toggle: false, strip: gesture)!
        owner.complete(model, ticket: ticket)
        await clock.advance(by: .milliseconds(100))
        var actions: [String] = []
        model.onAction = { actions.append($0) }
        for event in [key(5, "g"), key(4, "h")] { XCTAssertTrue(model.perform(model.meaning(for: event))) }
        XCTAssertEqual(model.query, "gh")
        XCTAssertEqual(model.settings.presentation, "list")
        XCTAssertNotNil(model.hold)
        XCTAssertTrue(model.perform(model.meaning(for: key(51, ""))))
        XCTAssertEqual(model.query, "g")
        XCTAssertTrue(model.perform(model.meaning(for: key(125, ""))))
        XCTAssertEqual(model.selection, 1)
        XCTAssertTrue(model.perform(model.meaning(for: key(13, "w"))))
        XCTAssertEqual(actions, ["cmd-w"])
        owner.stripFlagsChanged([], from: model)
        XCTAssertNil(model.hold)
        XCTAssertTrue(owner.session === model)
        XCTAssertEqual(actions, ["cmd-w"])
        owner.stripFlagsChanged(.command, from: model)
        XCTAssertNil(model.hold)
        model.startHold(gesture)
        XCTAssertNil(model.hold)
        XCTAssertEqual(model.meaning(for: key(4, "h")), .fieldEditor)
        XCTAssertFalse(model.perform(model.meaning(for: key(4, "h"))))
        XCTAssertEqual(model.query, "g")
    }

    func testOpeningKeepsLettersAndStepsInTheirOriginalOrder() {
        let owner = testLensLifecycle()
        let gesture = StripGesture(keyCode: 48, invoking: .command)
        let ticket = owner.begin("order", toggle: false, strip: gesture)!
        XCTAssertEqual(owner.openingStripKey(keyCode: 5, flags: .command, characters: "g"), .consumed)
        XCTAssertEqual(owner.openingStripKey(keyCode: 48, flags: [.command, .shift]), .consumed)
        var settings = LensConfig(); settings.presentation = "strip"
        let items: [SwitcherPaletteItem] = (1...3).map { id in
            let title = id == 1 ? "Other" : "g Demo"
            return SwitcherPaletteItem(id: UInt32(id), title: title, appName: "Demo", icon: nil, workspaceName: "1", isFocused: id == 1)
        }
        let model = LensSession(name: "order", settings: settings, items: items, search: "")
        owner.complete(model, ticket: ticket)
        XCTAssertEqual(model.query, "g")
        XCTAssertEqual(model.selectedId, 3)
        owner.dismiss()
    }

    func testShiftOnlyChordHasAHoldWithoutChangingStripCommitModifiers() {
        let owner = testLensLifecycle()
        let gesture = StripGesture(keyCode: 15, invoking: .shift)
        let model = LensSession(name: "shift", settings: LensConfig(), items: [], search: "")
        owner.complete(model, ticket: owner.begin("shift", toggle: false)!, invocation: gesture)
        owner.stripFlagsChanged(.shift, from: model)
        XCTAssertNotNil(model.hold)
        XCTAssertEqual(model.meaning(for: key(4, "H", .shift)), .text("H"))
        XCTAssertTrue(model.perform(model.meaning(for: key(4, "H", .shift))))
        XCTAssertEqual(model.query, "H")
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
            XCTAssertEqual(owner.openingStripKey(keyCode: 15, flags: held ? .option : [], characters: "r"), .consumed)
            let items = (1...3).map { SwitcherPaletteItem(id: UInt32($0), title: "r Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: $0 == 1) }
            let model = LensSession(name: "direct", settings: LensConfig(), items: items, search: "")
            owner.complete(model, ticket: ticket)
            XCTAssertEqual(model.query, held ? "" : "r")
            XCTAssertEqual(model.selectedId, held ? 3 : 1)
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

    func testOpeningLettersAreQueuedAndAppliedInOrderBeforeReleaseCommit() {
        for release in [false, true] {
            let owner = testLensLifecycle()
            let gesture = StripGesture(keyCode: 48, invoking: .command)
            let ticket = owner.begin("queued", toggle: false, strip: gesture)!
            XCTAssertEqual(owner.openingStripKey(keyCode: 5, flags: .command, characters: "g"), .consumed)
            XCTAssertEqual(owner.openingStripKey(keyCode: 4, flags: .command, characters: "h"), .consumed)
            if release { owner.openingFlagsChanged([]) }
            var settings = LensConfig(); settings.presentation = "strip"
            let model = LensSession(name: "queued", settings: settings, items: [], search: "")
            owner.complete(model, ticket: ticket)
            XCTAssertEqual(model.query, "gh")
            XCTAssertEqual(model.settings.presentation, "list")
            XCTAssertEqual(model.hold != nil, !release)
            XCTAssertTrue(owner.session === model)
            owner.dismiss()
        }
    }

    func testCLIAndLeaderHaveNoHoldAndKeepOrdinaryCommandChords() {
        for invocation: StripGesture? in [nil, StripGesture(keyCode: 15, invoking: [])] {
            let owner = testLensLifecycle()
            let model = LensSession(name: "ordinary", settings: LensConfig(), items: [], search: "")
            owner.complete(model, ticket: owner.begin("ordinary", toggle: false)!, invocation: invocation)
            XCTAssertNil(model.hold)
            XCTAssertEqual(model.meaning(for: key(5, "g", [])), .text("g"))
            XCTAssertFalse(model.perform(model.meaning(for: key(5, "g", []))))
            XCTAssertEqual(model.meaning(for: key(4, "h")), .fieldEditor)
            XCTAssertEqual(model.meaning(for: key(13, "w")), .command("cmd-w"))
            owner.dismiss()
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
            var settings = LensConfig(); settings.presentation = "list"
            let gesture = StripGesture(keyCode: 48, invoking: .command)
            let ticket = panel.beginLens("hold", toggle: false, strip: gesture)!
            await panel.openLens(name: "hold", settings: settings, entries: [], search: "", banner: nil, context: .null, ticket: ticket, invocation: gesture)
            let model = try! XCTUnwrap(panel.session)
            model.beginStrip(gesture)
            model.changePresentation("strip")
            for event in [key(5, "g"), key(4, "h")] {
                if equivalent { XCTAssertTrue(panel.performKeyEquivalent(with: event)) }
                else { panel.sendEvent(event) }
            }
            XCTAssertEqual(model.settings.presentation, "list")
            XCTAssertEqual(model.query, "gh")
            if equivalent { XCTAssertTrue(panel.performKeyEquivalent(with: key(51, ""))) }
            else { panel.sendEvent(key(51, "")) }
            XCTAssertEqual(model.query, "g")
            panel.stripFlagsChanged([])
            panel.sendEvent(key(4, "h"))
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
            XCTAssertEqual(panel.session?.query, "h")
            XCTAssertFalse(panel.handleStripHotkey(keyCode: 37, modifiers: [.option, .control], characters: "l"))
            XCTAssertNil(panel.session)
        }
    }

    func testLettersBeforeFieldEditorIsReadyAreRetainedWithoutModifiers() async {
        let panel = SwitcherPalettePanel.shared
        defer { panel.dismiss() }
        var settings = LensConfig(); settings.presentation = "list"
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
