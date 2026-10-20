@testable import AppBundle
import AppKit
import XCTest
import Clocks

final class StripLayoutTest: SerialClockTestCase {
    func testAllEntriesUseTheGridStripSizing() {
        let layout = GridLayout(sections: [.init(label: nil, current: false, entries: Array(repeating: .init(aspect: 1.5, realSize: CGSize(width: 1200, height: 800), kind: .card), count: 14))], visibleSize: CGSize(width: 1920, height: 1080), tileSize: "real", sizing: .strip)
        XCTAssertEqual(layout.tiles.count, 14)
        XCTAssertEqual(Set(layout.tiles.map { $0.frame.minY }).count, 2)
    }
    @MainActor
    func testStripAndMiniaturesUseOnscreenSnapshotForFullscreenThumbnails() {
        for presentation in ["strip", "miniatures"] {
            let onscreen = lensOnscreenWindows(drawsPictures: LensSession.drawsPictures(settings: { var settings = LensConfig(); settings.presentation = presentation; return settings }())) { [42] }
            XCTAssertFalse(miniatureIsFrozen(tray: false, fullscreen: !onscreen.contains(42), workspaceVisible: onscreen.contains(42), parked: false))
            XCTAssertTrue(miniatureIsFrozen(tray: false, fullscreen: !onscreen.contains(43), workspaceVisible: onscreen.contains(43), parked: false))
        }
        XCTAssertTrue(lensOnscreenWindows(drawsPictures: false) { XCTFail("List does not capture thumbnails"); return [42] }.isEmpty)
    }
}

@MainActor
final class StripSessionTest: SerialClockTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }
    private func model(count: Int = 3) -> LensSession {
        var settings = LensConfig(); settings.presentation = "strip"
        return LensSession(name: "recent", settings: settings, items: (0..<count).map { i in
            SwitcherPaletteItem(id: UInt32(i + 1), title: "Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: i == 0)
        }, search: "")
    }
    func testEnlargedAccessoryPictureUsesLayoutSizeEvenForATinyWindow() {
        var settings = LensConfig(); settings.presentation = "strip"
        let entry = TileEntry(title: "Utility", appName: "Utility", aspect: 1.5, realSize: CGSize(width: 30, height: 20), accessory: true)
        let size = CGSize(width: 285, height: 190)
        let view = TileView(entry: entry, kind: .picture, presentation: "strip", metrics: TileMetrics(scale: 1), size: size,
                            settings: settings, selected: true, marked: false, hint: nil, pictureSize: size)
        XCTAssertEqual(view.fittedPicture(in: size), size)
    }

    func testLayoutDoesNotChangeWhileSteppingHoveringOrHoldingSummon() {
        let session = model(count: 14)
        session.miniatureSize = CGSize(width: 1920, height: 1080)
        let frames = session.stripSnapshot.layout.tiles.map(\.frame)
        for _ in 0..<14 {
            session.cycleStripSelection(1)
            XCTAssertEqual(session.stripSnapshot.layout.tiles.map(\.frame), frames)
        }
        session.hover(8)
        session.updateHintModifiers(.option)
        XCTAssertEqual(session.stripSnapshot.layout.tiles.map(\.frame), frames)
    }


    func testRemovingTwelfthEntryRepacksToOneRowAndKeepsSelectedWindow() {
        let session = model(count: 12)
        session.miniatureSize = CGSize(width: 1920, height: 1080)
        session.hover(5)
        XCTAssertEqual(Set(session.stripSnapshot.layout.tiles.map { $0.frame.minY }).count, 2)
        session.removeStripItems([12])
        XCTAssertEqual(session.selectedId, 5)
        XCTAssertEqual(Set(session.stripSnapshot.layout.tiles.map { $0.frame.minY }).count, 1)
    }

    func testSingleRowArrowsCycleAndWrappedVerticalArrowsStayAtEdges() {
        let single = model(count: 3)
        single.miniatureSize = CGSize(width: 1920, height: 1080)
        single.send(.selectionChanged(0)); single.step("up")
        XCTAssertEqual(single.selection, 2)
        single.step("down"); XCTAssertEqual(single.selection, 0)
        let wrapped = model(count: 14)
        wrapped.miniatureSize = CGSize(width: 1920, height: 1080)
        wrapped.send(.selectionChanged(0)); wrapped.step("up")
        XCTAssertEqual(wrapped.selection, 0)
        let layout = wrapped.stripSnapshot.layout
        let below = layout.nearest(from: 0, direction: .down)!
        wrapped.step("down"); XCTAssertEqual(wrapped.selection, below)
        wrapped.step("down"); XCTAssertEqual(wrapped.selection, below)
        let firstSecondRow = layout.tiles.firstIndex { $0.frame.minY > layout.tiles[0].frame.minY }!
        wrapped.send(.selectionChanged(firstSecondRow - 1)); wrapped.step("right")
        XCTAssertEqual(wrapped.selection, firstSecondRow)
        wrapped.send(.selectionChanged(13)); wrapped.step("right"); XCTAssertEqual(wrapped.selection, 0)
    }

    func testEveryStripPictureRefreshesAndFrozenPicturesDoNot() {
        var settings = LensConfig(); settings.presentation = "strip"
        let items = (1...14).map { id in
            let window = TestWindow.new(id: UInt32(id), parent: focus.workspace.rootTilingContainer)
            return SwitcherPaletteItem(id: window.windowId, title: "Window", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false,
                miniature: MiniatureWindow(workspace: "1", frame: .zero, tray: false, frozen: id == 14, accessory: false, floating: false, window: window))
        }
        let session = LensSession(name: "recent", settings: settings, items: items, search: "")
        var requests: [UInt32] = []
        session.refreshThumbnails(lens: 1) { window, _, _ in requests.append(window.windowId) }
        XCTAssertEqual(requests, Array(1...13).map(UInt32.init))
    }

    func testUnrelatedGlobalBindingClosesStripBeforeYielding() async {
        _ = NSApplication.shared
        let panel = SwitcherPalettePanel.shared
        defer { panel.dismiss() }
        var settings = LensConfig(); settings.presentation = "strip"
        let gesture = ModeInvocation(keyCode: 48, invoking: .command)
        enterModeForTests("cmd-tab", gesture: gesture)
        let ticket = panel.beginLens("global-handoff", toggle: false)!
        await panel.openLens(name: "global-handoff", settings: settings, entries: [], search: nil, banner: nil, context: .null, ticket: ticket)
        enterModeForTests("cmd-tab", gesture: gesture)
        XCTAssertTrue(handleModeKey(code: 37, flags: [.command, .control], characters: "l", carbon: true))
        await ModeEngine.shared.waitForInput()
        XCTAssertNil(panel.session)
        XCTAssertFalse(panel.isVisible)
    }

    func testUnrelatedGlobalBindingDropsAnOpeningStrip() async {
        _ = NSApplication.shared
        let panel = SwitcherPalettePanel.shared
        defer { panel.dismiss() }
        var settings = LensConfig(); settings.presentation = "strip"
        let gesture = ModeInvocation(keyCode: 48, invoking: .command)
        enterModeForTests("cmd-tab", gesture: gesture)
        let ticket = panel.beginLens("opening", toggle: true)!
        XCTAssertTrue(handleModeKey(code: 48, flags: .command, characters: "\t", carbon: true))
        XCTAssertTrue(handleModeKey(code: 37, flags: [.command, .control], characters: "l", carbon: true))
        await ModeEngine.shared.waitForInput()
        await panel.openLens(name: "opening", settings: settings, entries: [], search: nil, banner: nil, context: .null, ticket: ticket)
        XCTAssertNil(panel.session)
    }




    func testNoFocusedCandidateStartsAtPreviousWindow() {
        var settings = LensConfig(); settings.presentation = "strip"
        let items = (1...3).map { SwitcherPaletteItem(id: UInt32($0), title: "Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false) }
        let model = LensSession(name: "recent", settings: settings, items: items, search: "")
        model.enterHeldModeForTests(ModeInvocation(keyCode: 48, invoking: .command))
        XCTAssertEqual(model.selectedId, 1)
        model.enterHeldModeForTests(ModeInvocation(keyCode: 48, invoking: [.command, .shift]))
        model.step("prev")
        XCTAssertEqual(model.selectedId, 3)
    }

    func testRemovingEarlierWindowsKeepsSelectedWindow() {
        let model = model(count: 5)
        model.enterHeldModeForTests(ModeInvocation(keyCode: 48, invoking: .command))
        model.hover(4)
        model.removeStripItems([2])
        XCTAssertEqual(model.selectedId, 4)
        model.removeStripItems([4])
        XCTAssertEqual(model.selectedId, 5)
        model.removeStripItems([5])
        XCTAssertEqual(model.selectedId, 3)
        let batch = self.model(count: 6)
        batch.hover(4)
        batch.removeStripItems([2, 4])
        XCTAssertEqual(batch.selectedId, 5)
    }


    func testClickUsesReleaseBindingWhileInvokingModifiersAreHeld() throws {
        let model = model()
        model.enterHeldModeForTests(ModeInvocation(keyCode: 48, invoking: .command))
        for (flags, expected): (NSEvent.ModifierFlags, String) in [(.command, "enter"), ([.command, .option], "alt-enter")] {
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            XCTAssertEqual(model.key(for: event, click: true), expected)
        }
    }

    func testInitialSelectionForwardReverseWrapAndOnlyInvokingKeyCycles() {
        let model = model()
        model.enterHeldModeForTests(ModeInvocation(keyCode: 48, invoking: [.command]))
        XCTAssertEqual(model.selectedId, 2)
        XCTAssertTrue(model.cycleStripForTests(keyCode: 48, flags: [.command]))
        XCTAssertEqual(model.selectedId, 3)
        model.cycleStripForTests(keyCode: 48, flags: [.command])
        XCTAssertEqual(model.selectedId, 1)
        model.cycleStripForTests(keyCode: 48, flags: [.command, .shift])
        XCTAssertEqual(model.selectedId, 3)
        XCTAssertTrue(model.cycleStripForTests(keyCode: 50, flags: [.command]))
        let reversed = self.model()
        reversed.enterHeldModeForTests(ModeInvocation(keyCode: 48, invoking: [.command, .shift]))
        reversed.step("prev"); reversed.step("prev")
        XCTAssertEqual(reversed.selectedId, 3)
        let one = self.model(count: 1); one.enterHeldModeForTests(ModeInvocation(keyCode: 50, invoking: [.command]))
        one.cycleStripForTests(keyCode: 50, flags: [.command]); XCTAssertEqual(one.selectedId, 1)
        let empty = self.model(count: 0); empty.enterHeldModeForTests(ModeInvocation(keyCode: 48, invoking: [.command]))
        empty.cycleStripForTests(keyCode: 48, flags: [.command]); XCTAssertNil(empty.selectedId)
    }

}
