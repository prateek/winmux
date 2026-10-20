@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor
final class LensPeekTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests(); enterModeForTests("browse") }

    private func key(_ code: UInt16, _ text: String = "", _ flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                        context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)!
    }
    private func model(_ settings: LensConfig = LensConfig(), search: String = "") -> LensSession {
        LensSession(name: "peek", settings: settings, items: (1...3).map {
            SwitcherPaletteItem(id: UInt32($0), title: $0 == 3 ? "Notes" : "Safari \($0)", appName: "Demo", icon: nil, workspaceName: "1", isFocused: $0 == 1)
        }, search: search)
    }

    func testSearchSpaceAlwaysTypesAndBrowseSpaceKeepsItsPeek() {
        enterModeForTests("search")
        let typed = model(search: "saf")
        XCTAssertEqual(typed.resolutionForTests(key(49, " ")).kind, .type)
        typed.typeKey(code: 0, characters: " ")
        XCTAssertEqual(typed.query, " ", "Untouched recalled text is replaced on its first edit")
        let edited = model()
        for text in ["s", "a", "f"] { edited.typeKey(code: 0, characters: text) }
        edited.pressForTests(key(49, " "))
        XCTAssertEqual(edited.query, "saf ")
        let settings = LensConfig()
        let freed = model(settings)
        XCTAssertEqual(freed.resolutionForTests(key(49, " ")).kind, .type)
        freed.pressForTests(key(49, " "))
        XCTAssertEqual(freed.query, " ")
        freed.enterBrowseForTests()
        freed.pressForTests(key(49, " "))
        XCTAssertEqual(freed.query, " ")
    }



    func testPeekInEveryPresentationFollowsSelectionAndEscapeConsumesOnlyPeek() {
        for presentation in ["list", "strip", "grid", "miniatures"] {
            var settings = LensConfig(); settings.presentation = presentation
            let session = model(settings)
            var actions: [String] = []; session.onAction = { actions.append($0) }
            session.pressForTests(key(49, " "))
            XCTAssertEqual(session.peekedId, session.selectedId, presentation)
            session.moveSelection(1)
            XCTAssertEqual(session.peekedId, session.selectedId)
            session.pressForTests(key(53))
            XCTAssertNil(session.peekedId)
            XCTAssertEqual(activeMode, "browse")
            XCTAssertTrue(actions.isEmpty, "peek must never reach the command runner")
        }
    }

    func testEveryKeyGoesToTheInputMethodWhileComposing() {
        enterModeForTests("search")
        let engine = ModeEngine.shared
        for code in UInt16(0)...127 {
            let result = resolveModeKey(keymap: resolvedModeKeymap(), context: .init(mode: "search"), mode: engine.properties,
                                        chord: .init(code: code), composing: true)
            XCTAssertTrue(result.editorOwned, "key code \(code)")
        }
        enterModeForTests("browse")
        let result = resolveModeKey(keymap: resolvedModeKeymap(), context: .init(mode: "browse"), mode: engine.properties,
                                    chord: .init(code: 49), composing: true)
        XCTAssertEqual(result.commands.map { $0.args.description }, ["lens peek"], "Only a typing mode composes")
    }

    func testOpeningHoldQueuesAndReplaysPeekThenEscapeWithoutDismissing() async {
        for presentation in ["grid", "strip", "list", "miniatures"] {
            config.modes["cmd-tab"] = defaultConfig.modes["cmd-tab"]
            config.modes["cmd-tab"]?.drawDelay = 0
            enterModeForTests("cmd-tab", gesture: .init(keyCode: 48, invoking: .command))
            var settings = LensConfig(); settings.presentation = presentation
            let owner = testLensLifecycle(); defer { owner.dismiss() }
            let ticket = owner.begin("peek", toggle: false, settings: settings)!
            let session = model(settings)
            ModeEngine.shared.whenLensReady { session.pressForTests(self.key(49, " ", .command)) }
            owner.complete(session, ticket: ticket)
            await ModeEngine.shared.waitForReadiness()
            XCTAssertEqual(session.peekedId, session.selectedId, presentation)
            session.pressForTests(key(53, "", .command))
            XCTAssertNil(session.peekedId)
            XCTAssertTrue(owner.session === session)
        }
    }

    func testEscapeQueuedAfterPeekDoesNotCancelOpeningHold() async {
        let liveModifiers = ModeEngine.shared.liveModifiers
        ModeEngine.shared.liveModifiers = { .command }
        defer { ModeEngine.shared.liveModifiers = liveModifiers }
        config.modes["cmd-tab"] = defaultConfig.modes["cmd-tab"]
        config.modes["cmd-tab"]?.drawDelay = 0
        enterModeForTests("cmd-tab", gesture: .init(keyCode: 48, invoking: .command))
        let owner = testLensLifecycle(); defer { owner.dismiss() }
        let ticket = owner.begin("peek", toggle: false)!
        let session = model()
        ModeEngine.shared.whenLensReady { session.pressForTests(self.key(49, " ", .command)) }
        ModeEngine.shared.whenLensReady { session.pressForTests(self.key(53, "", .command)) }
        owner.complete(session, ticket: ticket)
        await ModeEngine.shared.waitForReadiness()
        XCTAssertNil(session.peekedId)
        XCTAssertEqual(activeMode, "cmd-tab")
        XCTAssertFalse(ModeEngine.shared.entryModifiers.isEmpty)
        XCTAssertTrue(owner.session === session)
    }


    func testCustomPeekKeysAndOpeningBindings() {
        var settings = LensConfig(); testModeBindings["cmd-y"] = []; testModeBindings["cmd-p"] = ["peek"]
        for presentation in ["list", "strip", "grid", "miniatures"] {
            settings.presentation = presentation
            let session = model(settings)
            XCTAssertTrue(session.activeKeyBindings.contains { $0.name == "cmd-p" })
            session.performPeekAction("cmd-y"); XCTAssertNil(session.peekedId)
            session.performPeekAction("cmd-p"); XCTAssertEqual(session.peekedId, session.selectedId)
            session.performPeekAction("cmd-p"); XCTAssertNil(session.peekedId)
        }
    }

    func testPeekFollowsSearchRegroupRemovalAndBlocksPointerUntilItEnds() {
        let session = model()
        session.performPeekAction("space")
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
        session.performPeekAction("space"); XCTAssertEqual(session.peekedId, session.selectedId)
        session.moveSelection(1); XCTAssertEqual(session.peekedId, session.selectedId)
        session.changePresentation("miniatures"); XCTAssertNil(session.peekedId)
        session.performPeekAction("space"); XCTAssertEqual(session.peekedId, session.selectedId)
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
            session.performPeekAction(action)
            XCTAssertEqual(focus.windowOrNil, focused)
            XCTAssertEqual(focus.workspace, current)
            XCTAssertEqual(target.nodeWorkspace, other)
        }
        session.pressForTests(key(53))
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
        session.performPeekAction("space")
        XCTAssertEqual(session.peekedId, 2)
        XCTAssertEqual(session.targets(forCommand: "focus"), [2])
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
        session.performPeekAction("space")
        pointer.x = 2.2
        session.hover(3, at: pointer)
        XCTAssertEqual(session.peekedId, 3, "A no-op peek key must not re-arm hover's movement threshold")
    }

    func testFollowProfileAndLegendWithSpaceFreed() {
        let settings = LensConfig(.object(["peek": .string("zoom"), "when": .object(["default": .object(["peek": .string("follow")])])]))
        XCTAssertEqual(settings.peek, "follow")
        XCTAssertEqual(settings.json["peek"], .string("follow"))
        let shipped = model().hintLegend
        XCTAssertEqual(Array(shipped.prefix(6)).map(\.phrase), ["focus", "summon here", "send to workspace", "close", "peek", "group"])
        XCTAssertEqual(shipped.first { $0.phrase == "peek" }?.chords, ["Space", "⌘Y", "Y"])
        var freed = LensConfig(); testModeBindings["space"] = []
        XCTAssertEqual(model(freed).hintLegend.first { $0.phrase == "peek" }?.chords, ["⌘Y", "Y"])
    }

    func testZoomPointerCannotChangeHoveredTileButFollowPointerChangesPicture() {
        var settings = LensConfig(); settings.presentation = "grid"
        let session = model(settings)
        let target = session.gridLayout.tiles[2].frame
        session.performPeekAction("space")
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
        let entries = try await lensWindows(popups: [:]).filter { $0.record.id != 10 }
        var settings = LensConfig(); settings.presentation = "miniatures"
        let panel = SwitcherPalettePanel(emit: { _ in }); defer { panel.dismiss() }
        let ticket = panel.beginLens("closed", toggle: false, settings: settings)!
        await panel.openLens(name: "closed", settings: settings, entries: entries, search: "", banner: nil, context: .null, ticket: ticket)
        let session = try XCTUnwrap(panel.session)
        session.performPeekAction("space")
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
        let entries = try await lensWindows(popups: [:]).filter { $0.record.id == 1 }
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
        session.performPeekAction("space")
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
        let entries = try await lensWindows(popups: [:])
        var settings = LensConfig(); settings.presentation = "grid"
        let panel = SwitcherPalettePanel(emit: { _ in }); defer { panel.dismiss() }
        let ticket = panel.beginLens("click", toggle: false, settings: settings)!
        await panel.openLens(name: "click", settings: settings, entries: entries, search: "", banner: nil, context: .null, ticket: ticket)
        let session = try XCTUnwrap(panel.session)
        var actions: [String] = []; session.onAction = { actions.append($0) }
        let selected = session.selectedId
        session.performPeekAction("space")
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


    func testAClosedMiniatureIsNotPeekedAgain() {
        var settings = LensConfig(); settings.presentation = "miniatures"
        let session = model(settings)
        session.performPeekAction("space")
        let closed = try! XCTUnwrap(session.peekedId)
        session.peekedWindowClosed(closed)
        XCTAssertNil(session.peekedId)
        session.performPeekAction("space")
        XCTAssertNil(session.peekedId)
        XCTAssertFalse(session.zoomPeeking)
        session.moveSelection(1)
        XCTAssertNotEqual(session.selectedId, closed)
        session.performPeekAction("space")
        XCTAssertEqual(session.peekedId, session.selectedId)
        session.moveSelection(-1)
        XCTAssertEqual(session.selectedId, closed)
        XCTAssertNil(session.peekedId, "A closed cell has nothing to show")
        session.moveSelection(1)
        XCTAssertEqual(session.peekedId, session.selectedId, "Passing over a closed cell does not end the zoom")
    }


    func testPresentationChangeEndsAZoom() {
        var settings = LensConfig(); settings.peek = "follow"; settings.presentation = "miniatures"
        let session = model(settings)
        session.performPeekAction("space")
        XCTAssertTrue(session.zoomPeeking)
        session.changePresentation("list")
        XCTAssertFalse(session.zoomPeeking)
        session.changePresentation("miniatures")
        XCTAssertNil(session.peekedId, "A zoom does not come back by itself")
        var strip = LensConfig(); strip.presentation = "strip"
        let held = model(strip)
        held.performPeekAction("cmd-y")
        held.changePresentation("list")
        XCTAssertTrue(held.zoomPeeking, "A strip that becomes a list keeps its zoom")
    }

    func testConfigAcceptsPeekAloneAndNamesMixedListError() throws {
        func settings(_ commands: [String]) -> JSONValue {
            .object(["keymap": .object(["demo": .object(["context": .string("mode == browse"), "bindings": .object(["space": .array(commands.map(JSONValue.string))])])])])
        }
        XCTAssertTrue(parseConfig(settings(["lens peek"])).errors.isEmpty)
        if case .cmd = parseCommand("peek") { XCTFail("peek must stay a Lens verb") }
        for commands in [["lens peek", "lens focus"], ["lens focus", "lens peek"]] {
            XCTAssertTrue(parseConfig(settings(commands)).errors.contains { $0.description.contains("keymap.demo.space: lens peek runs alone") })
        }
    }

}
