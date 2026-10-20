@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor
final class LensHoldTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests(); enterModeForTests("browse") }
    private func model(_ presentation: String = "list", search: String = "") -> LensSession {
        var settings = LensConfig(); settings.presentation = presentation
        let items = (1...4).map { SwitcherPaletteItem(id: UInt32($0), title: $0 < 4 ? "Safari \($0)" : "Notes", appName: "Demo", icon: nil, workspaceName: "1", isFocused: $0 == 1) }
        return LensSession(name: "demo", settings: settings, items: items, search: search)
    }
    private func key(_ code: UInt16, _ text: String = "", _ flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)!
    }
    func testBrowseConsumesPlainLettersAndSearchEscapeKeepsTextAndMatches() {
        let session = model("grid")
        for text in ["s", "a", "f"] { XCTAssertTrue(session.pressForTests(key(1, text))) }
        XCTAssertEqual(session.query, "")
        session.pressForTests(key(44, "/"))
        for text in ["s", "a", "f"] { session.pressForTests(key(1, text)) }
        XCTAssertEqual(session.query, "saf")
        XCTAssertEqual(session.results.count, 3)
        session.pressForTests(key(53))
        XCTAssertEqual(activeMode, "browse")
        XCTAssertEqual(session.query, "saf")
        XCTAssertEqual(session.results.count, 3)
    }
    func testEnteringRecalledSearchKeepsAnyMatchingSelectionInEveryPresentation() {
        for presentation in ["list", "grid", "strip", "miniatures"] {
            enterModeForTests("browse")
            let session = model(presentation, search: "saf")
            session.hover(3)
            session.enterSearchForTests()
            XCTAssertEqual(session.query, "saf")
            XCTAssertEqual(session.selectedId, 3, presentation)
            XCTAssertEqual(session.results.count, 3)
        }
    }
    func testFirstEditReplacesRecalledSearchAndKeepsSubsequentLettersAndBackspace() {
        enterModeForTests("search")
        let session = model(search: "saf")
        session.pressForTests(key(45, "n"))
        session.pressForTests(key(31, "o"))
        XCTAssertEqual(session.query, "no")
        session.pressForTests(key(51))
        XCTAssertEqual(session.query, "n")
        XCTAssertTrue(session.searchEdited)
    }
    func testExplicitSearchAppliesInBrowseAndPresentationChangeKeepsSelectionMarksAndSearch() {
        var settings = LensConfig(); settings.presentation = "grid"
        let session = LensSession(name: "explicit", settings: settings, items: model().itemsForTests, search: "saf", searchIsExplicit: true)
        session.hover(3); session.toggleMark()
        session.changePresentation("list")
        XCTAssertEqual(session.query, "saf")
        XCTAssertEqual(session.selectedId, 3)
        XCTAssertEqual(session.marks, [3])
        XCTAssertEqual(activeMode, "browse")
    }
    func testStayingHeldListTabStepsMatchesAndReleaseKeepsSelection() {
        enterModeForTests("search")
        let session = model(search: "saf")
        session.enterHeldModeForTests(ModeInvocation(keyCode: 44, invoking: .option), staying: true)
        session.pressForTests(key(48, "\t", .option))
        XCTAssertEqual(session.selectedId, 3)
        session.releaseModeForTests(flags: [])
        XCTAssertEqual(session.selectedId, 3)
        XCTAssertEqual(session.query, "saf")
    }
    func testNormalGridNavigationAndListSidewaysOverrides() {
        let grid = model("grid"); grid.miniatureSize = CGSize(width: 1280, height: 720)
        let before = grid.selectedId
        grid.pressForTests(key(37, "l"))
        XCTAssertNotEqual(grid.selectedId, before)
        let list = model(); let selected = list.selectedId
        list.pressForTests(key(4, "h")); list.pressForTests(key(37, "l"))
        XCTAssertEqual(list.selectedId, selected)
    }
    func testSearchClickNamesSearchAndBindingsHaveNoLensSpecificInputState() async throws {
        let session = model("grid")
        session.enterSearchForTests()
        XCTAssertEqual(activeMode, "search")
        XCTAssertTrue(session.isTyping)
        session.changePresentation("list")
        XCTAssertEqual(activeMode, "search")
        XCTAssertTrue(session.isTyping)
    }
    func testInertLensDoesNotChangeMainAndItsPlainKeysPass() async throws {
        enterModeForTests("main")
        let owner = testLensLifecycle(); defer { owner.dismiss() }
        let session = model()
        XCTAssertTrue(owner.complete(session, ticket: owner.begin("demo", toggle: false)!))
        XCTAssertEqual(activeMode, "main")
        XCTAssertFalse(session.pressForTests(key(1, "s")))
        XCTAssertEqual(session.query, "")
    }
    func testNoStackModeReplacementAndCLIClosingEndsMain() async throws {
        let panel = SwitcherPalettePanel.shared; defer { panel.dismiss() }
        let ticket = panel.beginLens("demo", toggle: false)!
        await panel.openLens(name: "demo", settings: LensConfig(), entries: [], search: "", banner: nil, context: .null, ticket: ticket)
        enterModeForTests("browse")
        let result = try await parseCommand("lens close").cmdOrDie.run(.defaultEnv, .emptyStdin)
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(activeMode, "main")
        XCTAssertNil(panel.session)
    }
    func testSelectionAndModifiersDoNotStealKeyboardOutsideModeChanges() async throws {
        enterModeForTests("browse")
        let panel = SwitcherPalettePanel.shared; defer { panel.dismiss() }
        await panel.openLens(name: "demo", settings: LensConfig(), entries: [], search: "", banner: nil, context: .null, ticket: panel.beginLens("demo", toggle: false)!)
        _ = panel.makeFirstResponder(panel)
        panel.session?.send(.selectionChanged(0)); panel.session?.send(.modifiersChanged(.option))
        XCTAssertTrue(panel.firstResponder === panel)
        try await activateMode("search")
        for _ in 0..<20 { await Task.yield() }
        XCTAssertTrue(panel.firstResponder is NSTextView)
    }

    func testHeldFirstSearchLetterKeepsCaretAtEndAfterEditorAppears() async throws {
        let panel = SwitcherPalettePanel.shared; defer { panel.dismiss() }
        await panel.openLens(name: "first-letter", settings: LensConfig(), entries: [], search: "", banner: nil, context: .null, ticket: panel.beginLens("first-letter", toggle: false)!)
        enterModeForTests("search-hold", gesture: .init(keyCode: 44, invoking: .option))
        panel.sendEvent(key(1, "s", .option))
        await ModeEngine.shared.waitForInput()
        for _ in 0..<20 { await Task.yield() }
        let editor = try XCTUnwrap(panel.firstResponder as? NSTextView)
        XCTAssertEqual(editor.string, "s")
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 1, length: 0))
    }

    func testRetainedMatchingLetterKeepsCaretThroughInitialFocusCallback() async throws {
        enterModeForTests("search")
        let panel = SwitcherPalettePanel.shared; defer { panel.dismiss() }
        await panel.openLens(name: "initial-same-letter", settings: LensConfig(), entries: [], search: "s", banner: nil, context: .null, ticket: panel.beginLens("initial-same-letter", toggle: false)!)
        XCTAssertFalse(panel.session!.searchEdited)
        _ = panel.makeFirstResponder(panel)
        panel.sendEvent(key(1, "s"))
        await ModeEngine.shared.waitForInput()
        for _ in 0..<20 { await Task.yield() }
        let editor = try XCTUnwrap(panel.firstResponder as? NSTextView)
        XCTAssertEqual(editor.string, "s")
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 1, length: 0))
        XCTAssertTrue(panel.session!.searchEdited)
    }

    func testStripSlashSelectsRecalledSearchForReplacement() async throws {
        let panel = SwitcherPalettePanel.shared; defer { panel.dismiss() }
        var settings = LensConfig(); settings.presentation = "strip"
        await panel.openLens(name: "strip-recall", settings: settings, entries: [], search: "s", banner: nil, context: .null, ticket: panel.beginLens("strip-recall", toggle: false)!)
        panel.sendEvent(key(44, "/"))
        await ModeEngine.shared.waitForInput()
        for _ in 0..<20 { await Task.yield() }
        let editor = try XCTUnwrap(panel.firstResponder as? NSTextView)
        XCTAssertEqual(editor.string, "s")
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 0, length: 1))
        XCTAssertFalse(panel.session!.searchEdited)
    }

    func testModifierChangesWithoutHoldPreserveFieldEditorSelection() async throws {
        enterModeForTests("search")
        let panel = SwitcherPalettePanel.shared; defer { panel.dismiss() }
        await panel.openLens(name: "ordinary-selection", settings: LensConfig(), entries: [], search: "gh", banner: nil, context: .null, ticket: panel.beginLens("ordinary-selection", toggle: false)!)
        let editor = NSTextView(frame: .zero)
        panel.contentView?.addSubview(editor)
        defer { editor.removeFromSuperview() }
        XCTAssertTrue(panel.makeFirstResponder(editor))
        editor.string = "gh"
        editor.setSelectedRange(NSRange(location: 0, length: 2))
        panel.modifiersChanged(.command); panel.modifiersChanged([])
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 0, length: 2))
        XCTAssertEqual(panel.session?.query, "gh")
    }

    func testPanelKeepsBothLettersAndBackspaceAcrossConversionAtBothEntryPoints() async throws {
        let panel = SwitcherPalettePanel.shared; defer { panel.dismiss() }
        for equivalent in [false, true] {
            enterModeForTests("browse")
            var settings = LensConfig(); settings.presentation = "strip"
            await panel.openLens(name: "conversion", settings: settings, entries: [], search: "", banner: nil, context: .null, ticket: panel.beginLens("conversion", toggle: false)!)
            let model = try XCTUnwrap(panel.session)
            enterModeForTests("cmd-tab", gesture: .init(keyCode: 48, invoking: .command))
            for event in [key(44, "/", .command), key(7, "x", .command), key(4, "h", .command)] {
                _ = panel.makeFirstResponder(panel)
                if !equivalent || !panel.performKeyEquivalent(with: event) { panel.sendEvent(event) }
            }
            await ModeEngine.shared.waitForInput()
            XCTAssertEqual(model.settings.presentation, "list")
            XCTAssertEqual(model.query, "xh")
            _ = panel.makeFirstResponder(panel)
            let backspace = key(51, "", .command)
            if !equivalent || !panel.performKeyEquivalent(with: backspace) { panel.sendEvent(backspace) }
            await ModeEngine.shared.waitForInput()
            XCTAssertEqual(model.query, "x")
            panel.modifiersChanged([])
            await ModeEngine.shared.waitForInput()
            XCTAssertTrue(panel.session === model)
            XCTAssertEqual(activeMode, "search")
            panel.dismiss()
        }
    }

    func testLettersBeforeFieldEditorIsReadyAreRetainedWithoutModifiers() async throws {
        let panel = SwitcherPalettePanel.shared; defer { panel.dismiss() }
        var settings = LensConfig(); settings.presentation = "strip"
        await panel.openLens(name: "gap", settings: settings, entries: [], search: "", banner: nil, context: .null, ticket: panel.beginLens("gap", toggle: false)!)
        enterModeForTests("cmd-tab", gesture: .init(keyCode: 48, invoking: .command))
        panel.sendEvent(key(44, "/", .command))
        panel.sendEvent(key(7, "x", .command))
        panel.modifiersChanged([])
        _ = panel.makeFirstResponder(nil)
        panel.sendEvent(key(4, "h")); panel.sendEvent(key(0, "a"))
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(panel.session?.query, "xha")
    }

    func testFirstLetterMatchingRecalledSearchStillCountsAsAnEdit() {
        enterModeForTests("search")
        let model = model(search: "s")
        model.typeKey(code: 1, characters: "s")
        XCTAssertTrue(model.searchEdited)
        model.typeKey(code: 0, characters: "a"); model.typeKey(code: 3, characters: "f")
        XCTAssertEqual(model.query, "saf")
    }

    func testPanelStripKeepsDormantRememberedSearchUntilSlash() async throws {
        let panel = SwitcherPalettePanel.shared; defer { panel.dismiss() }
        enterModeForTests("search")
        await panel.openLens(name: "remembered-strip", settings: LensConfig(), entries: [], search: "saf", banner: nil, context: .null, ticket: panel.beginLens("remembered-strip", toggle: false)!)
        panel.dismiss()
        enterModeForTests("browse")
        var settings = LensConfig(); settings.presentation = "strip"
        await panel.openLens(name: "remembered-strip", settings: settings, entries: [], search: nil, banner: nil, context: .null, ticket: panel.beginLens("remembered-strip", toggle: false)!)
        XCTAssertEqual(panel.session?.query, "")
        panel.sendEvent(key(44, "/"))
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(panel.session?.query, "saf")
        XCTAssertFalse(panel.session!.searchEdited)
    }
}

extension LensSession {
    var itemsForTests: [SwitcherPaletteItem] { results }
}
