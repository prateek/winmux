@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor
final class LensPeekTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    private func key(_ code: UInt16, _ text: String = "", _ flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                        context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)!
    }
    private func model(_ settings: LensConfig = LensConfig(), search: String = "") -> LensSession {
        LensSession(name: "peek", settings: settings, items: (1...3).map {
            SwitcherPaletteItem(id: UInt32($0), title: $0 == 3 ? "Notes" : "Safari \($0)", appName: "Demo", icon: nil, workspaceName: "1", isFocused: $0 == 1)
        }, search: search)
    }

    func testPreservedSearchSpaceWithTextAndFreedSpace() {
        let typed = model(search: "saf")
        XCTAssertEqual(typed.meaning(for: key(49, " ")), .text(" "))
        typed.perform(.text(" "))
        XCTAssertEqual(typed.query, " ", "Untouched recalled text is replaced on its first edit")
        let edited = model()
        for text in ["s", "a", "f"] { edited.perform(.text(text)) }
        edited.perform(edited.meaning(for: key(49, " ")))
        XCTAssertEqual(edited.query, "saf ")
        var settings = LensConfig(); settings.keys["space"] = []
        let freed = model(settings)
        XCTAssertEqual(freed.meaning(for: key(49, " ")), .text(" "))
        freed.perform(freed.meaning(for: key(49, " ")))
        XCTAssertEqual(freed.query, " ")
        freed.leaveSearch()
        freed.perform(freed.meaning(for: key(49, " ")))
        XCTAssertEqual(freed.query, " ")
    }

    func testPreservedSearchAndNormalEscapeAndUnboundHoldSpace() {
        let session = model()
        XCTAssertEqual(session.meaning(for: key(53)), .leaveSearch)
        session.perform(.leaveSearch)
        XCTAssertEqual(session.meaning(for: key(53)), .dismiss)
        var settings = LensConfig(); settings.keys["space"] = []
        let held = model(settings)
        held.startHold(StripGesture(keyCode: 48, invoking: .command))
        XCTAssertEqual(held.meaning(for: key(49, " ", .command)), .dropped)
    }

    func testPreservedHoldReleaseEnterSummonAndClose() {
        var settings = LensConfig(); settings.presentation = "strip"
        let session = model(settings)
        let owner = testLensLifecycle(); defer { owner.dismiss() }
        let gesture = StripGesture(keyCode: 48, invoking: .command)
        owner.complete(session, ticket: owner.begin("peek", toggle: false, strip: gesture)!)
        XCTAssertEqual(session.meaning(for: key(36, "\r", .command)), .command("enter"))
        XCTAssertEqual(session.meaning(for: key(36, "\r", [.command, .option])), .command("alt-enter"))
        XCTAssertEqual(session.meaning(for: key(13, "w", .command)), .command("cmd-w"))
        var actions: [String] = []
        session.onAction = { actions.append($0) }
        owner.stripFlagsChanged([], from: session)
        XCTAssertEqual(actions, ["enter"])
    }

    func testPeekInEveryPresentationFollowsSelectionAndEscapeConsumesOnlyPeek() {
        for presentation in ["list", "strip", "grid", "miniatures"] {
            var settings = LensConfig(); settings.presentation = presentation
            let session = model(settings)
            var actions: [String] = []; session.onAction = { actions.append($0) }
            session.perform(session.meaning(for: key(49, " ")))
            XCTAssertEqual(session.peekedId, session.selectedId, presentation)
            session.moveSelection(1)
            XCTAssertEqual(session.peekedId, session.selectedId)
            session.perform(session.meaning(for: key(53)))
            XCTAssertNil(session.peekedId)
            XCTAssertEqual(session.inputState, settings.startingInputState)
            XCTAssertTrue(actions.isEmpty, "peek must never reach the command runner")
        }
    }

    func testEmptySearchOnlyAndHoldSubtractsInvokingModifiersForPeekOnly() {
        let empty = model()
        XCTAssertEqual(empty.meaning(for: key(49, " ")), .command("space"))
        let recalled = model(search: "saf")
        XCTAssertEqual(recalled.meaning(for: key(49, " ")), .text(" "))
        var shifted = LensConfig(); shifted.keys["shift-p"] = ["peek"]
        XCTAssertEqual(model(shifted).meaning(for: key(35, "P", .shift)), .text("P"), "Only an unmodified peek binding may interrupt empty Search typing")
        let held = model(); held.startHold(StripGesture(keyCode: 48, invoking: .command))
        XCTAssertEqual(held.meaning(for: key(49, " ", .command)), .command("space"))
        XCTAssertEqual(held.meaning(for: key(16, "y", .command)), .command("cmd-y"))
        held.perform(.command("space"))
        held.perform(held.meaning(for: key(53, "", .command)))
        XCTAssertNil(held.peekedId)
        XCTAssertEqual(held.inputState, .hold)
        XCTAssertNotNil(held.hold)
    }

    func testCustomPeekKeysAndOpeningBindings() {
        var settings = LensConfig(); settings.keys["space"] = []; settings.keys["cmd-y"] = []; settings.keys["cmd-p"] = ["peek"]
        for presentation in ["list", "strip", "grid", "miniatures"] {
            settings.presentation = presentation
            XCTAssertTrue(LensSession.openingBindings(settings).contains { $0.name == "cmd-p" })
            let session = model(settings)
            session.perform(.command("cmd-y")); XCTAssertNil(session.peekedId)
            session.perform(.command("cmd-p")); XCTAssertEqual(session.peekedId, session.selectedId)
            session.perform(.command("cmd-p")); XCTAssertNil(session.peekedId)
        }
    }

    func testPeekFollowsSearchRegroupRemovalAndBlocksPointerUntilItEnds() {
        let session = model()
        session.perform(.command("space"))
        let selected = session.selectedId
        session.hover(1, at: CGPoint(x: 10000, y: 10000))
        XCTAssertEqual(session.selectedId, selected)
        session.send(.searchChanged("Notes")); XCTAssertEqual(session.peekedId, 3)
        session.changeSections("app"); XCTAssertEqual(session.peekedId, 3)
        session.send(.itemsRemoved([3])); XCTAssertNil(session.peekedId)
        session.send(.searchChanged("")); XCTAssertNil(session.peekedId, "No selection ends the zoom")
    }

    func testFollowStartsAtSelectionIgnoresPeekKeyAndMiniaturesUsesZoom() {
        var settings = LensConfig(); settings.peek = "follow"; settings.presentation = "strip"
        let session = model(settings)
        XCTAssertEqual(session.peekedId, session.selectedId)
        session.perform(.command("space")); XCTAssertEqual(session.peekedId, session.selectedId)
        session.moveSelection(1); XCTAssertEqual(session.peekedId, session.selectedId)
        session.changePresentation("miniatures"); XCTAssertNil(session.peekedId)
        session.perform(.command("space")); XCTAssertEqual(session.peekedId, session.selectedId)
        session.apply(.dismissed); XCTAssertNil(session.peekedId)
    }

    func testPeekPreservesFocusAndWorkspaceThroughLifecycleAndDismissal() {
        let current = Workspace.get(byName: "1"), other = Workspace.get(byName: "2")
        let focused = TestWindow.new(id: 10, parent: current.rootTilingContainer)
        _ = focused.focusWindow()
        let target = TestWindow.new(id: 2, parent: other.rootTilingContainer)
        let session = model()
        let owner = testLensLifecycle(); defer { owner.dismiss() }
        owner.complete(session, ticket: owner.begin("peek", toggle: false)!)
        for action in ["space", "space", "cmd-y"] {
            session.perform(.command(action))
            XCTAssertEqual(focus.windowOrNil, focused)
            XCTAssertEqual(focus.workspace, current)
            XCTAssertEqual(target.nodeWorkspace, other)
        }
        session.perform(session.meaning(for: key(53)))
        owner.dismiss()
        XCTAssertNil(session.peekedId)
        XCTAssertEqual(focus.windowOrNil, focused)
        XCTAssertEqual(focus.workspace, current)
    }

    func testAppPeekTargetsFocusRepresentativeAndIgnoresMarks() {
        var settings = LensConfig(); settings.entries = "app"
        let items = [
            SwitcherPaletteItem(id: 1, title: "Old", appName: "Editor", icon: nil, workspaceName: "1", appIdentity: "editor", lastFocusedSeq: 1, isFocused: false),
            SwitcherPaletteItem(id: 2, title: "New", appName: "Editor", icon: nil, workspaceName: "2", appIdentity: "editor", lastFocusedSeq: 9, isFocused: false),
            SwitcherPaletteItem(id: 3, title: "Other", appName: "Mail", icon: nil, workspaceName: "1", appIdentity: "mail", isFocused: false),
        ]
        let session = LensSession(name: "apps", settings: settings, items: items, search: "")
        session.hover(3); session.toggleMark(); session.hover(2)
        session.perform(.command("space"))
        XCTAssertEqual(session.peekedId, 2)
        XCTAssertEqual(session.targets(forCommand: "focus"), [2])
    }

    func testOpeningHoldQueuesAndReplaysPeekThenEscapeWithoutDismissing() {
        for presentation in ["grid", "strip", "list", "miniatures"] {
            var settings = LensConfig(); settings.presentation = presentation
            let owner = testLensLifecycle(); defer { owner.dismiss() }
            let gesture = StripGesture(keyCode: 48, invoking: .command)
            let ticket = owner.begin("peek", toggle: false, strip: presentation == "strip" ? gesture : nil,
                                     keys: LensSession.openingBindings(settings), invocation: gesture, settings: settings)!
            XCTAssertEqual(owner.openingStripKey(keyCode: 49, flags: .command, characters: " ", source: .panel), .consumed)
            let session = model(settings)
            owner.complete(session, ticket: ticket)
            XCTAssertEqual(session.peekedId, session.selectedId, presentation)
            session.perform(session.meaning(for: key(53, "", .command)))
            XCTAssertNil(session.peekedId)
            XCTAssertTrue(owner.session === session)
        }
    }

    func testEscapeQueuedAfterPeekDoesNotCancelOpeningHold() {
        let settings = LensConfig()
        let owner = testLensLifecycle(); defer { owner.dismiss() }
        let gesture = StripGesture(keyCode: 48, invoking: .command)
        let ticket = owner.begin("peek", toggle: false, keys: LensSession.openingBindings(settings), invocation: gesture, settings: settings)!
        XCTAssertEqual(owner.openingStripKey(keyCode: 49, flags: .command, characters: " ", source: .panel), .consumed)
        XCTAssertEqual(owner.openingStripKey(keyCode: 53, flags: .command, source: .panel), .consumed)
        let session = model(settings)
        owner.complete(session, ticket: ticket)
        XCTAssertNil(session.peekedId)
        XCTAssertEqual(session.inputState, .hold)
        XCTAssertTrue(owner.session === session)
    }

    func testPeekPanelCannotTakeFocusOrMouse() {
        let controller = LensPeekController()
        XCTAssertFalse(controller.panel.canBecomeKey)
        XCTAssertFalse(controller.panel.canBecomeMain)
        XCTAssertTrue(controller.panel.ignoresMouseEvents)
        XCTAssertFalse(controller.panel.hasShadow)
        XCTAssertEqual(controller.panel.frame, .zero)
    }

    func testFollowPeekKeyLeavesArmedPointerUntouched() {
        var settings = LensConfig(); settings.presentation = "grid"; settings.peek = "follow"
        var pointer = CGPoint.zero
        let items = (1...3).map { SwitcherPaletteItem(id: UInt32($0), title: "Window", appName: "Demo", icon: nil, workspaceName: "1", isFocused: $0 == 1) }
        let session = LensSession(name: "follow", settings: settings, items: items, search: "", pointerLocation: { pointer })
        pointer.x = 2
        session.hover(2, at: pointer)
        session.perform(.command("space"))
        pointer.x = 2.2
        session.hover(3, at: pointer)
        XCTAssertEqual(session.peekedId, 3, "A no-op peek key must not re-arm hover's movement threshold")
    }

    func testFollowProfileAndLegendWithSpaceFreed() {
        let settings = LensConfig(.object(["peek": .string("zoom"), "when": .object(["default": .object(["peek": .string("follow")])])]))
        XCTAssertEqual(settings.peek, "follow")
        XCTAssertEqual(settings.json["peek"], .string("follow"))
        let shipped = model().hintLegend
        XCTAssertEqual(shipped.map(\.phrase), ["focus", "summon here", "send to workspace", "close", "peek", "group"])
        XCTAssertEqual(shipped.first { $0.phrase == "peek" }?.chords, ["Space", "⌘Y"])
        var freed = LensConfig(); freed.keys["space"] = []
        XCTAssertEqual(model(freed).hintLegend.first { $0.phrase == "peek" }?.chords, ["⌘Y"])
    }

    func testZoomPointerCannotChangeHoveredTileButFollowPointerChangesPicture() {
        var settings = LensConfig(); settings.presentation = "grid"
        let session = model(settings)
        let target = session.gridLayout.tiles[2].frame
        session.perform(.command("space"))
        let selected = session.selectedId
        session.hoverTile(at: CGPoint(x: target.midX, y: target.midY), pointerLocation: CGPoint(x: 10000, y: 10000))
        XCTAssertEqual(session.selectedId, selected)
        XCTAssertNil(session.hoveredTileId)
        settings.peek = "follow"
        let follow = model(settings)
        follow.hover(3, at: CGPoint(x: 10000, y: 10000))
        XCTAssertEqual(follow.peekedId, 3)
    }

    func testListOriginUsesMeasuredRowAndMissingRowFades() {
        let session = model()
        let id = session.selectedId!
        XCTAssertNil(session.peekTileRect())
        let row = CGRect(x: 20, y: 120, width: 400, height: 40)
        session.listRowRects[id] = row
        XCTAssertEqual(session.peekTileRect(), row)
        session.listRowRects[id] = nil
        XCTAssertNil(session.peekTileRect())
    }

    func testWindowCloseInMiniaturesEndsPeekAndKeepsCells() async throws {
        let current = Workspace.get(byName: "1"), other = Workspace.get(byName: "2")
        _ = TestWindow.new(id: 10, parent: current.rootTilingContainer).focusWindow()
        _ = TestWindow.new(id: 1, parent: other.rootTilingContainer)
        _ = TestWindow.new(id: 2, parent: other.rootTilingContainer)
        let entries = try await lensWindows(popups: []).filter { $0.record.id != 10 }
        var settings = LensConfig(); settings.presentation = "miniatures"
        let panel = SwitcherPalettePanel(emit: { _ in }); defer { panel.dismiss() }
        let ticket = panel.beginLens("closed", toggle: false, settings: settings)!
        await panel.openLens(name: "closed", settings: settings, entries: entries, search: "", banner: nil, context: .null, ticket: ticket)
        let session = try XCTUnwrap(panel.session)
        session.perform(.command("space"))
        let first = try XCTUnwrap(session.peekedId)
        let count = session.results.count
        panel.stripWindowClosed(first)
        XCTAssertNil(session.peekedId, "Closing the peeked window ends the zoom")
        XCTAssertEqual(session.selectedId, first, "Miniatures keeps a closed window's cell and selection")
        XCTAssertEqual(session.results.count, count)
        XCTAssertTrue(panel.session === session, "Losing the peeked window ends peek, not the Lens")
    }

    func testFollowPictureCannotAppearBeforeItsLensIsVisible() {
        let window = TestWindow.new(id: 1, parent: Workspace.get(byName: "2").rootTilingContainer)
        var entry = TileEntry(title: "Window", appName: "Demo"); entry.frozen = true
        let item = SwitcherPaletteItem(id: window.windowId, title: "Window", appName: "Demo", icon: nil, workspaceName: "2", isFocused: false, tile: entry)
        var settings = LensConfig(); settings.presentation = "strip"; settings.peek = "follow"
        let session = LensSession(name: "delayed", settings: settings, items: [item], search: "")
        let lens = NSPanelHud()
        let controller = LensPeekController(); defer { controller.hide() }
        controller.update(session, relativeTo: lens)
        XCTAssertFalse(controller.panel.isVisible, "A ready strip inside its display delay must not flash a follow picture")
    }

    func testFollowListPictureStaysBelowItsSeparateLegendPanel() async throws {
        let current = Workspace.get(byName: "1"), other = Workspace.get(byName: "2")
        _ = TestWindow.new(id: 10, parent: current.rootTilingContainer).focusWindow()
        _ = TestWindow.new(id: 1, parent: other.rootTilingContainer)
        let entries = try await lensWindows(popups: []).filter { $0.record.id == 1 }
        var settings = LensConfig(); settings.presentation = "list"; settings.peek = "follow"; settings.hints = "always"
        let panel = SwitcherPalettePanel(emit: { _ in }); defer { panel.dismiss() }
        let ticket = panel.beginLens("follow-list", toggle: false, settings: settings)!
        await panel.openLens(name: "follow-list", settings: settings, entries: entries, search: "", banner: nil, context: .null, ticket: ticket)
        let legendWindow = try XCTUnwrap(NSApp.windows.first { $0.identifier?.rawValue == "WinMux.lensLanding" && $0.isVisible })
        let pictureWindow = try XCTUnwrap(NSApp.windows.first { $0.identifier?.rawValue == "WinMux.lensPeek" && $0.isVisible })
        let expected = Set([panel.windowNumber, legendWindow.windowNumber, pictureWindow.windowNumber])
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { @Sendable _, _ in
            let rows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
            let onscreen = Set(rows.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue })
            return expected.isSubset(of: onscreen)
        }, object: nil)
        await fulfillment(of: [visible], timeout: 2)
        let rows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        let order = rows.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue }
        let lens = try XCTUnwrap(order.firstIndex(of: panel.windowNumber))
        let legend = try XCTUnwrap(order.firstIndex(of: legendWindow.windowNumber))
        let picture = try XCTUnwrap(order.firstIndex(of: pictureWindow.windowNumber))
        XCTAssertLessThan(lens, legend)
        XCTAssertLessThan(legend, picture, "The follow picture belongs below all Lens content, including the separate legend")
    }

    func testClickDuringZoomOnlyEndsTheZoom() {
        var settings = LensConfig(); settings.presentation = "grid"
        let session = model(settings)
        var actions: [String] = []; session.onAction = { actions.append($0) }
        let selected = session.selectedId
        session.perform(.command("space"))
        XCTAssertTrue(session.endZoomForClick())
        XCTAssertNil(session.peekedId)
        XCTAssertEqual(session.selectedId, selected, "Nothing under the picture is selected")
        XCTAssertTrue(actions.isEmpty, "Nothing under the picture is focused")
        XCTAssertFalse(session.endZoomForClick(), "Without a zoom, a click acts as before")
    }

    func testPeekPanelEatsEveryButtonsWholeClickWhileZoomed() throws {
        let panel = PeekPanel()
        var downs = 0; panel.onMouseDown = { downs += 1; panel.takesMouse = false }
        panel.takesMouse = false
        XCTAssertTrue(panel.ignoresMouseEvents, "Without a zoom the panel ignores the mouse")
        panel.takesMouse = true
        XCTAssertFalse(panel.ignoresMouseEvents)
        func event(_ type: NSEvent.EventType) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber,
                                             context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        }
        panel.sendEvent(try event(.rightMouseDown))
        XCTAssertEqual(downs, 1)
        XCTAssertFalse(panel.ignoresMouseEvents, "The zoom ended, but the panel keeps the mouse until the button is up")
        panel.sendEvent(try event(.leftMouseDown))
        panel.sendEvent(try event(.leftMouseDragged))
        panel.sendEvent(try event(.leftMouseUp))
        XCTAssertFalse(panel.ignoresMouseEvents, "The right button is still down")
        panel.sendEvent(try event(.rightMouseUp))
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertEqual(downs, 2)
        panel.sendEvent(try event(.leftMouseDown))
        panel.forgetButtons()
        XCTAssertTrue(panel.ignoresMouseEvents, "A panel hidden mid-click lets go of the mouse")
    }

    func testTheLensEndsAZoomOnAClickWhereThePeekPanelIsNot() async throws {
        let current = Workspace.get(byName: "1"), other = Workspace.get(byName: "2")
        _ = TestWindow.new(id: 10, parent: current.rootTilingContainer).focusWindow()
        _ = TestWindow.new(id: 1, parent: other.rootTilingContainer)
        _ = TestWindow.new(id: 2, parent: other.rootTilingContainer)
        let entries = try await lensWindows(popups: [])
        var settings = LensConfig(); settings.presentation = "grid"
        let panel = SwitcherPalettePanel(emit: { _ in }); defer { panel.dismiss() }
        let ticket = panel.beginLens("click", toggle: false, settings: settings)!
        await panel.openLens(name: "click", settings: settings, entries: entries, search: "", banner: nil, context: .null, ticket: ticket)
        let session = try XCTUnwrap(panel.session)
        var actions: [String] = []; session.onAction = { actions.append($0) }
        let selected = session.selectedId
        session.perform(.command("space"))
        func event(_ type: NSEvent.EventType) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: CGPoint(x: 10, y: 10), modifierFlags: [], timestamp: 0,
                                             windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        }
        panel.sendEvent(try event(.rightMouseDown))
        panel.sendEvent(try event(.leftMouseDown))
        panel.sendEvent(try event(.leftMouseUp))
        XCTAssertTrue(panel.eatsClicks, "The right button is still down, so the left click went the same way")
        panel.sendEvent(try event(.rightMouseUp))
        XCTAssertFalse(panel.eatsClicks)
        XCTAssertNil(session.peekedId)
        XCTAssertEqual(session.selectedId, selected)
        XCTAssertTrue(actions.isEmpty)
        XCTAssertTrue(panel.session === session)
    }

    func testEveryKeyGoesToTheInputMethodWhileComposing() {
        let session = model()
        for (code, text) in [(UInt16(49), " "), (36, "\r"), (125, ""), (53, "")] {
            XCTAssertEqual(session.meaning(for: key(code, text), composing: true), .fieldEditor)
        }
        XCTAssertEqual(session.meaning(for: key(49, " ")), .command("space"))
        session.leaveSearch()
        XCTAssertEqual(session.meaning(for: key(49, " "), composing: true), .command("space"), "Only Search composes")
    }

    func testAClosedMiniatureIsNotPeekedAgain() {
        var settings = LensConfig(); settings.presentation = "miniatures"
        let session = model(settings)
        session.perform(.command("space"))
        let closed = try! XCTUnwrap(session.peekedId)
        session.peekedWindowClosed(closed)
        XCTAssertNil(session.peekedId)
        session.perform(.command("space"))
        XCTAssertNil(session.peekedId)
        XCTAssertFalse(session.zoomPeeking)
        session.moveSelection(1)
        XCTAssertNotEqual(session.selectedId, closed)
        session.perform(.command("space"))
        XCTAssertEqual(session.peekedId, session.selectedId)
        session.moveSelection(-1)
        XCTAssertEqual(session.selectedId, closed)
        XCTAssertNil(session.peekedId, "A closed cell has nothing to show")
        session.moveSelection(1)
        XCTAssertEqual(session.peekedId, session.selectedId, "Passing over a closed cell does not end the zoom")
    }

    func testOpeningCountsSpaceInAnEmptySearchAsPeekAndTextAfterTyping() {
        let settings = LensConfig()
        let gesture = StripGesture(keyCode: 48, invoking: .command)
        do {
            let owner = testLensLifecycle(); defer { owner.dismiss() }
            let ticket = owner.begin("peek", toggle: false, keys: LensSession.openingBindings(settings), invocation: gesture, settings: settings)!
            XCTAssertEqual(owner.openingStripKey(keyCode: 44, flags: .command, characters: "/", source: .panel), .consumed)
            XCTAssertEqual(owner.openingStripKey(keyCode: 49, flags: [], characters: " ", source: .panel), .consumed)
            XCTAssertEqual(owner.openingStripKey(keyCode: 53, flags: [], source: .panel), .consumed)
            let session = model(settings)
            owner.complete(session, ticket: ticket)
            XCTAssertNil(session.peekedId)
            XCTAssertEqual(session.inputState, .search, "The Escape ended the peek, as the replay does, and stayed in Search")
        }
        do {
            let owner = testLensLifecycle(); defer { owner.dismiss() }
            let ticket = owner.begin("peek", toggle: false, keys: LensSession.openingBindings(settings), invocation: gesture, settings: settings)!
            XCTAssertEqual(owner.openingStripKey(keyCode: 44, flags: .command, characters: "/", source: .panel), .consumed)
            XCTAssertEqual(owner.openingStripKey(keyCode: 0, flags: [], characters: "a", source: .panel), .consumed)
            XCTAssertEqual(owner.openingStripKey(keyCode: 49, flags: [], characters: " ", source: .panel), .consumed)
            XCTAssertEqual(owner.openingStripKey(keyCode: 53, flags: [], source: .panel), .consumed)
            let session = model(settings)
            owner.complete(session, ticket: ticket)
            XCTAssertNil(session.peekedId)
            XCTAssertEqual(session.inputState, .normal, "After typing, Space is text and the Escape leaves Search")
        }
    }

    func testPresentationChangeEndsAZoom() {
        var settings = LensConfig(); settings.peek = "follow"; settings.presentation = "miniatures"
        let session = model(settings)
        session.perform(.command("space"))
        XCTAssertTrue(session.zoomPeeking)
        session.changePresentation("list")
        XCTAssertFalse(session.zoomPeeking)
        session.changePresentation("miniatures")
        XCTAssertNil(session.peekedId, "A zoom does not come back by itself")
        var strip = LensConfig(); strip.presentation = "strip"
        let held = model(strip)
        held.perform(.command("cmd-y"))
        held.changePresentation("list")
        XCTAssertTrue(held.zoomPeeking, "A strip that becomes a list keeps its zoom")
    }

    func testConfigAcceptsPeekAloneAndNamesMixedListError() throws {
        let good: JSONValue = .object(["lenses": .object(["demo": .object(["keys": .object(["space": .string("peek")])])])])
        XCTAssertTrue(parseConfig(good).errors.isEmpty)
        if case .cmd = parseCommand("peek") { XCTFail("peek must stay Lens-only") }
        let profile: JSONValue = .object(["lenses": .object(["demo": .object(["when": .object(["travel": .object(["keys": .object(["cmd-p": .array([.string("focus"), .string("peek")])])])])])])])
        XCTAssertTrue(parseConfig(profile).errors.contains { $0.description.contains("lenses.demo.keys.cmd-p: peek runs alone") })
        let bad: JSONValue = .object(["lenses": .object(["demo": .object(["keys": .object(["space": .array([.string("peek"), .string("close")])])])])])
        XCTAssertTrue(parseConfig(bad).errors.contains { $0.description.contains("lenses.demo.keys.space: peek runs alone") })
    }
}
