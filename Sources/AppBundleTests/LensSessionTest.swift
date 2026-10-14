@testable import AppBundle
import XCTest
import AppKit

@MainActor
final class LensSessionTest: XCTestCase {
    private func item(_ id: UInt32, focused: Bool = false) -> SwitcherPaletteItem {
        SwitcherPaletteItem(id: id, title: "Window \(id)", appName: "Demo", icon: nil, workspaceName: "1", isFocused: focused)
    }

    func testHintsSubtractHoldModifiersExceptStripInEveryPresentation() {
        for presentation in ["list", "grid", "miniatures", "strip"] {
            for invoking: NSEvent.ModifierFlags in [.option, [.option, .shift]] {
                var settings = LensConfig(); settings.presentation = presentation
                settings.hintsKey = "ctrl"
                let session = LensSession(name: "demo", settings: settings, items: [item(1)], search: "")
                let gesture = StripGesture(keyCode: 31, invoking: invoking)
                session.startHold(gesture)
                if presentation == "strip" { session.stripGesture = gesture }
                for flags in [invoking, NSEvent.ModifierFlags.option] {
                    session.updateHintModifiers(flags)
                    XCTAssertFalse(session.hintsShown, "\(presentation), \(invoking), \(flags)")
                }
                session.updateHintModifiers(invoking.union(.control))
                XCTAssertTrue(session.hintsShown, "Control is an additional Summon modifier outside the Hold")
                session.endHold(flags: [])
                session.updateHintModifiers(.control)
                XCTAssertTrue(session.hintsShown)
            }
        }
    }

    func testHintsReinterpretStillHeldModifiersWhenLetterEndsHold() {
        for presentation in ["list", "grid", "miniatures", "strip"] {
            var settings = LensConfig(); settings.presentation = presentation
            let session = LensSession(name: "hints", settings: settings, items: [item(1)], search: "")
            session.startHold(StripGesture(keyCode: 44, invoking: .option))
            session.updateHintModifiers(.option)
            XCTAssertEqual(session.hintsShown, presentation == "strip")
            session.endHoldByKey()
            XCTAssertTrue(session.hintsShown)
            session.updateHintModifiers([])
            XCTAssertFalse(session.hintsShown)
        }
    }

    func testStationaryPointerCannotReplaceDefaultOrKeyboardSelection() {
        for presentation in ["strip", "grid", "list", "miniatures"] {
            var settings = LensConfig(); settings.presentation = presentation
            var pointer = CGPoint(x: 100, y: 100)
            let session = LensSession(name: "demo", settings: settings, items: [item(1, focused: true), item(2), item(3)], search: "",
                                      pointerLocation: { pointer })
            session.hover(1, at: pointer)
            XCTAssertEqual(session.selectedId, 2, presentation)
            session.moveSelection(1)
            session.hover(2, at: pointer)
            XCTAssertEqual(session.selectedId, 3)
            pointer.x += 1
            session.hover(1, at: pointer)
            XCTAssertEqual(session.selectedId, 3, "Exactly one point does not arm hover")
            pointer.x += 0.1
            session.hover(1, at: pointer)
            XCTAssertEqual(session.selectedId, 1)
            session.moveSelection(1)
            session.hover(3, at: pointer)
            XCTAssertEqual(session.selectedId, 2, "A Tile sliding under the still pointer after a key does not select")
            pointer.x += 0.8; pointer.y += 0.8
            session.hover(3, at: pointer)
            XCTAssertEqual(session.selectedId, 3, "The threshold is Euclidean")
            pointer.x -= 0.1
            session.hover(1, at: pointer)
            XCTAssertEqual(session.selectedId, 1, "Once armed, a move smaller than a point selects")
            session.hover(3, at: pointer)
            XCTAssertEqual(session.selectedId, 1, "Repeated callbacks at the same point do not select")
        }
    }

    func testPrefilledSearchSelectsAVisibleRowEvenWhenTheUnfilteredFirstWindowIsFocused() {
        let session = LensSession(name: "demo", settings: LensConfig(), items: [item(1, focused: true), item(2)], search: "Window 2")
        XCTAssertEqual(session.selectedId, 2)
        XCTAssertEqual(session.targets(for: "shift-enter"), [2])
    }

    func testCommandKeyEquivalentRunsLensActionOnSelectionBeforeFieldEditing() throws {
        var settings = LensConfig()
        settings.keys["cmd-x"] = ["move-node-to-workspace 2"]
        let session = LensSession(name: "demo", settings: settings, items: [item(1), item(2)], search: "Window 2")
        var actions: [(String, [UInt32])] = []
        session.onAction = { key in actions.append((key, session.targets(for: key))) }
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command], timestamp: 0, windowNumber: 0, context: nil, characters: "x", charactersIgnoringModifiers: "x", isARepeat: false, keyCode: 7))
        XCTAssertTrue(session.performKeyAction(event))
        XCTAssertEqual(actions.map { $0.0 }, ["cmd-x"])
        XCTAssertEqual(actions.first?.1, [2])
        XCTAssertEqual(session.query, "Window 2")
    }

    func testCustomKeyModifierOrderAndSpecialKeysUseConfigNotation() throws {
        var settings = LensConfig()
        settings.keys["cmd-shift-enter"] = ["close"]
        settings.keys["ctrl-space"] = ["summon"]
        let session = LensSession(name: "demo", settings: settings, items: [item(1)], search: "")
        let enter = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command, .shift], timestamp: 0, windowNumber: 0, context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        let space = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.control], timestamp: 0, windowNumber: 0, context: nil, characters: " ", charactersIgnoringModifiers: " ", isARepeat: false, keyCode: 49))
        XCTAssertEqual(session.key(for: enter), "cmd-shift-enter")
        XCTAssertEqual(session.key(for: space), "ctrl-space")
        XCTAssertEqual(session.key(for: enter, click: true), "cmd-shift-enter")
    }

    func testSelectionMarksAndActionsUseSnapshotInMarkOrder() {
        let session = LensSession(name: "demo", settings: LensConfig(), items: [item(1, focused: true), item(2), item(3)], search: "")
        XCTAssertEqual(session.selectedId, 2)
        session.toggleMark()
        session.moveSelection(1)
        session.toggleMark()
        session.moveSelection(-2)
        session.toggleMark()
        XCTAssertEqual(session.targets(for: "shift-enter"), [2, 3, 1])
        XCTAssertEqual(session.targets(for: "enter"), [1])
        XCTAssertEqual(session.commands(for: "cmd-1"), ["move-node-to-workspace 1"])
        session.toggleMark()
        XCTAssertEqual(session.targets(for: "shift-enter"), [2, 3])
    }

    func testSearchClearAndInlineFailureKeepLastGoodRows() {
        let session = LensSession(name: "demo", settings: LensConfig(), items: [item(3), item(1), item(2)], search: "")
        session.send(.searchChanged("Window 2"))
        XCTAssertEqual(session.results.map(\.id), [2])
        session.send(.searchChanged(""))
        XCTAssertEqual(session.results.map(\.id), [3, 1, 2])
        session.send(.searchChanged("= true"))
        session.acceptInlineResult([1])
        session.send(.searchChanged("= w."))
        session.rejectInlineResult("parse failed\nmore detail")
        XCTAssertEqual(session.results.map(\.id), [1])
        XCTAssertEqual(session.searchError, "parse failed")
    }

    func testHalfTypedInlineKeepsTextSearchRowsAndReturningToTextClearsError() {
        let session = LensSession(name: "demo", settings: LensConfig(), items: [item(1), item(2)], search: "Window 2")
        session.send(.searchChanged("= w."))
        session.rejectInlineResult("parse error")
        XCTAssertEqual(session.results.map(\.id), [2])
        session.send(.searchChanged("Window"))
        XCTAssertNil(session.searchError)
    }

    func testPresentationChangeDoesNotResetSelectionMarksOrSearch() {
        let session = LensSession(name: "demo", settings: LensConfig(), items: [item(1), item(2)], search: "Window")
        session.moveSelection(1)
        session.toggleMark()
        session.changePresentation("list")
        XCTAssertEqual(session.selectedId, 2)
        XCTAssertEqual(session.marks, [2])
        XCTAssertEqual(session.query, "Window")
    }
}

@MainActor
final class LensActionTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testMarkOrderSummonFocusAndCustomActionUseRealCommands() async throws {
        let current = Workspace.get(byName: "1")
        let other = Workspace.get(byName: "2")
        _ = TestWindow.new(id: 10, parent: current.rootTilingContainer).focusWindow()
        let windows = [1, 2, 3].map { TestWindow.new(id: UInt32($0), parent: other.rootTilingContainer) }
        let items = windows.map { SwitcherPaletteItem(id: $0.windowId, title: "Window", appName: "Demo", icon: nil, workspaceName: "2", isFocused: false) }
        let session = LensSession(name: "demo", settings: LensConfig(), items: items, search: "")
        session.hover(3); session.toggleMark()
        session.hover(1); session.toggleMark()
        session.hover(2); session.toggleMark()
        let io = CmdIo(stdin: .emptyStdin)
        _ = try await runLensAction(session.commands(for: "shift-enter"), session: session, io: io)
        XCTAssertEqual(current.rootTilingContainer.allLeafWindowsRecursive.map(\.windowId), [10, 3, 1, 2])
        session.hover(1)
        _ = try await runLensAction(["focus"], session: session, io: io)
        XCTAssertEqual(focus.windowOrNil?.windowId, 1)
        _ = try await runLensAction(["close"], session: session, io: io)
        XCTAssertTrue(windows.allSatisfy { !$0.isBound })
    }

    func testCloseTargetsMinimizedAndPopupEntriesWithoutMovingThem() async throws {
        let minimized = TestWindow.new(id: 1, parent: macosMinimizedWindowsContainer)
        let popup = TestWindow.new(id: 2, parent: macosPopupWindowsContainer)
        for window in [minimized, popup] {
            let item = SwitcherPaletteItem(id: window.windowId, title: "Demo", appName: "Demo", icon: nil, workspaceName: "", isFocused: false)
            let session = LensSession(name: "demo", settings: LensConfig(), items: [item], search: "")
            let success = try await runLensAction(["close"], session: session, io: CmdIo(stdin: .emptyStdin))
            XCTAssertTrue(success)
            XCTAssertFalse(window.isBound)
        }
    }

    func testExplicitWindowActionClosesOnlyItsTargetAndFailureLeavesOtherWindows() async throws {
        let workspace = Workspace.get(byName: "1")
        let windows = (1...3).map { TestWindow.new(id: UInt32($0), parent: workspace.rootTilingContainer) }
        let io = CmdIo(stdin: .emptyStdin)
        let closed = try await runLensWindowAction("close", windowId: 1, io: io)
        XCTAssertTrue(closed)
        XCTAssertFalse(windows[0].isBound)
        XCTAssertTrue(windows[1].isBound)
        XCTAssertTrue(windows[2].isBound)
        let failed = try await runLensWindowAction("close", windowId: 99, io: io)
        XCTAssertFalse(failed)
        XCTAssertTrue(windows[1].isBound)
        XCTAssertTrue(windows[2].isBound)
    }

    func testExplicitWindowActionTogglesOnlyItsTargetsNativeFullscreen() async throws {
        let workspace = Workspace.get(byName: "1")
        let target = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let other = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        let io = CmdIo(stdin: .emptyStdin)
        let entered = try await runLensWindowAction("macos-native-fullscreen", windowId: 1, io: io)
        XCTAssertTrue(entered)
        XCTAssertTrue(target.nativeIsMacosFullscreen)
        XCTAssertFalse(other.nativeIsMacosFullscreen)
        let exited = try await runLensWindowAction("macos-native-fullscreen", windowId: 1, io: io)
        XCTAssertTrue(exited)
        XCTAssertFalse(target.nativeIsMacosFullscreen)
        XCTAssertTrue(other.isBound)
    }

    func testCmdOneMovesInsteadOfQuickSelectingAndCustomKeyUsesSelection() async throws {
        let current = Workspace.get(byName: "1")
        let other = Workspace.get(byName: "2")
        _ = TestWindow.new(id: 10, parent: current.rootTilingContainer).focusWindow()
        let window = TestWindow.new(id: 1, parent: other.rootTilingContainer)
        var settings = LensConfig()
        settings.keys["cmd-x"] = ["close"]
        let item = SwitcherPaletteItem(id: 1, title: "Demo", appName: "Demo", icon: nil, workspaceName: "2", isFocused: false)
        let session = LensSession(name: "demo", settings: settings, items: [item], search: "")
        let io = CmdIo(stdin: .emptyStdin)
        _ = try await runLensAction(session.commands(for: "cmd-1"), session: session, io: io)
        XCTAssertEqual(window.nodeWorkspace, scopedAutomaticDisplayWorkspaces(current: other).first)
        _ = try await runLensAction(session.commands(for: "cmd-x"), session: session, io: io)
        XCTAssertFalse(window.isBound)
    }
}

@MainActor
final class LensAppEntriesTest: XCTestCase {
    func testAppEntryFocusUsesMostRecentlyFocusedEligibleWindow() {
        var settings = LensConfig()
        settings.entries = "app"
        let items = [
            SwitcherPaletteItem(id: 1, title: "A", appName: "Editor", icon: nil, workspaceName: "1", appIdentity: "editor", lastFocusedSeq: 2, isFocused: false),
            SwitcherPaletteItem(id: 2, title: "B", appName: "Editor", icon: nil, workspaceName: "1", appIdentity: "editor", lastFocusedSeq: 8, isFocused: false),
            SwitcherPaletteItem(id: 3, title: "C", appName: "Mail", icon: nil, workspaceName: "1", appIdentity: "mail", lastFocusedSeq: 1, isFocused: false),
        ]
        let session = LensSession(name: "apps", settings: settings, items: items, search: "")
        XCTAssertEqual(session.results.map(\.id), [2, 3])
        XCTAssertEqual(session.targets(for: "enter"), [2])
    }
}
