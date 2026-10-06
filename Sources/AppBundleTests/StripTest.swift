@testable import AppBundle
import AppKit
import XCTest
import Clocks

final class StripLayoutTest: XCTestCase {
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
    func testInvokingModifiersDelayAndReleaseBinding() async {
        let clock = TestClock()
        let gesture = StripGesture(keyCode: 48, invoking: [.command, .shift], clock: clock)
        XCTAssertEqual(gesture.committingModifiers, [.command])
        await clock.advance(by: .milliseconds(99))
        XCTAssertFalse(gesture.shouldDisplay)
        await clock.advance(by: .milliseconds(1))
        XCTAssertTrue(gesture.shouldDisplay)
        XCTAssertFalse(gesture.shouldCommit(flags: [.command]))
        XCTAssertTrue(gesture.shouldCommit(flags: [.option, .shift]))
        XCTAssertEqual(gesture.releaseModifiers([.option, .shift]), [.option])
        XCTAssertTrue(StripGesture(keyCode: 48, invoking: []).shouldCommit(flags: []))
        XCTAssertTrue(gesture.shouldCommit(flags: []))
    }
}

@MainActor
final class StripSessionTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }
    private func model(count: Int = 3) -> LensSession {
        var settings = LensConfig(); settings.presentation = "strip"
        return LensSession(name: "recent", settings: settings, items: (0..<count).map { i in
            SwitcherPaletteItem(id: UInt32(i + 1), title: "Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: i == 0)
        }, search: "")
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
        session.updateSummonModifiers(.option)
        XCTAssertEqual(session.stripSnapshot.layout.tiles.map(\.frame), frames)
    }

    func testSingleRowArrowsCycleAndWrappedVerticalArrowsStayAtEdges() {
        let single = model(count: 3)
        single.miniatureSize = CGSize(width: 1920, height: 1080)
        single.send(.selectionChanged(0)); single.perform(.arrow(126))
        XCTAssertEqual(single.selection, 2)
        single.perform(.arrow(125)); XCTAssertEqual(single.selection, 0)
        let wrapped = model(count: 14)
        wrapped.miniatureSize = CGSize(width: 1920, height: 1080)
        wrapped.send(.selectionChanged(0)); wrapped.perform(.arrow(126))
        XCTAssertEqual(wrapped.selection, 0)
        let layout = wrapped.stripSnapshot.layout
        let below = layout.nearest(from: 0, direction: .down)!
        wrapped.perform(.arrow(125)); XCTAssertEqual(wrapped.selection, below)
        wrapped.perform(.arrow(125)); XCTAssertEqual(wrapped.selection, below)
        let firstSecondRow = layout.tiles.firstIndex { $0.frame.minY > layout.tiles[0].frame.minY }!
        wrapped.send(.selectionChanged(firstSecondRow - 1)); wrapped.perform(.arrow(124))
        XCTAssertEqual(wrapped.selection, firstSecondRow)
        wrapped.send(.selectionChanged(13)); wrapped.perform(.arrow(124)); XCTAssertEqual(wrapped.selection, 0)
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

    func testEveryStripPictureRefreshesAndFrozenPicturesDoNot() {
        var settings = LensConfig(); settings.presentation = "strip"
        let items = (1...14).map { id in
            let window = TestWindow.new(id: UInt32(id), parent: focus.workspace.rootTilingContainer)
            return SwitcherPaletteItem(id: window.windowId, title: "Window", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false,
                miniature: MiniatureWindow(workspace: "1", frame: .zero, tray: false, frozen: id == 14, accessory: false, floating: false, window: window))
        }
        let session = LensSession(name: "recent", settings: settings, items: items, search: "")
        var requests: [UInt32] = []
        session.refreshThumbnails(lens: 1) { window, _ in requests.append(window.windowId) }
        XCTAssertEqual(requests, Array(1...13).map(UInt32.init))
    }

    func testUnrelatedGlobalBindingClosesStripBeforeYielding() async {
        _ = NSApplication.shared
        let panel = SwitcherPalettePanel.shared
        defer { panel.dismiss() }
        let ticket = panel.beginLens("global-handoff", toggle: false)!
        await panel.openLens(name: "global-handoff", settings: LensConfig(), entries: [], search: nil, banner: nil, context: .null, ticket: ticket)
        panel.session?.changePresentation("strip")
        panel.session?.beginStrip(StripGesture(keyCode: 48, invoking: .command))
        XCTAssertFalse(panel.handleStripHotkey(keyCode: 37, modifiers: [.command, .control], characters: "l"))
        XCTAssertNil(panel.session)
        XCTAssertFalse(panel.isVisible)
    }

    func testUnrelatedGlobalBindingDropsAnOpeningStrip() async {
        _ = NSApplication.shared
        let panel = SwitcherPalettePanel.shared
        defer { panel.dismiss() }
        var settings = LensConfig(); settings.presentation = "strip"
        let gesture = StripGesture(keyCode: 48, invoking: .command)
        let ticket = panel.beginLens("opening", toggle: true, strip: gesture)!
        XCTAssertTrue(panel.handleStripHotkey(keyCode: 48, modifiers: .command, characters: "\t"))
        XCTAssertFalse(panel.handleStripHotkey(keyCode: 37, modifiers: [.command, .control], characters: "l"))
        await panel.openLens(name: "opening", settings: settings, entries: [], search: nil, banner: nil, context: .null, ticket: ticket, invocation: gesture)
        XCTAssertNil(panel.session)
    }

    func testEmptyBindingClosesOnlyAStripRelease() async {
        _ = NSApplication.shared
        let panel = SwitcherPalettePanel.shared
        defer { panel.dismiss() }
        var settings = LensConfig(); settings.keys["cmd-w"] = []
        let ticket = panel.beginLens("neutralised", toggle: false)!
        await panel.openLens(name: "neutralised", settings: settings, entries: [], search: nil, banner: nil, context: .null, ticket: ticket)
        panel.session?.onAction?("cmd-w")
        XCTAssertNotNil(panel.session)
        panel.session?.changePresentation("strip")
        panel.session?.onAction?("cmd-w")
        XCTAssertNotNil(panel.session)
    }

    func testTabAndBacktickWithOtherModifiersAreNotTheStrips() throws {
        let model = model()
        model.beginStrip(StripGesture(keyCode: 50, invoking: .command))
        func key(_ code: UInt16, _ flags: NSEvent.ModifierFlags) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code))
        }
        // cmd-tab inside a cmd-backtick strip does nothing; alt-tab is a global binding.
        XCTAssertEqual(model.stripInput(try key(48, .command)), .consumed)
        XCTAssertEqual(model.selectedId, 2)
        XCTAssertEqual(model.stripInput(try key(48, .option)), .ignored)
        XCTAssertEqual(model.stripInput(try key(50, [.command, .control])), .ignored)
        XCTAssertEqual(model.selectedId, 2)
        XCTAssertEqual(model.stripInput(try key(50, [.command, .shift])), .consumed)
        XCTAssertEqual(model.selectedId, 1)
    }

    func testReleaseWithoutEnterClosesEvenBeforePresentation() async {
        _ = NSApplication.shared
        let panel = SwitcherPalettePanel.shared
        defer { panel.dismiss() }
        var settings = LensConfig(); settings.presentation = "strip"; settings.keys = [:]
        let ticket = panel.beginLens("empty-action", toggle: false)!
        await panel.openLens(name: "empty-action", settings: settings, entries: [], search: nil, banner: nil, context: .null, ticket: ticket, invocation: StripGesture(keyCode: nil, invoking: []))
        XCTAssertNil(panel.session)
        XCTAssertFalse(panel.isVisible)
    }

    func testNoFocusedCandidateStartsAtPreviousWindow() {
        var settings = LensConfig(); settings.presentation = "strip"
        let items = (1...3).map { SwitcherPaletteItem(id: UInt32($0), title: "Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false) }
        let model = LensSession(name: "recent", settings: settings, items: items, search: "")
        model.beginStrip(StripGesture(keyCode: 48, invoking: .command))
        XCTAssertEqual(model.selectedId, 1)
        model.beginStrip(StripGesture(keyCode: 48, invoking: [.command, .shift]))
        XCTAssertEqual(model.selectedId, 3)
    }

    func testRemovingEarlierWindowsKeepsSelectedWindow() {
        let model = model(count: 5)
        model.beginStrip(StripGesture(keyCode: 48, invoking: .command))
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

    func testOtherGlobalLetterChordsAreNotSearchButLensKeysStillWin() throws {
        let model = model()
        model.beginStrip(StripGesture(keyCode: 48, invoking: .command))
        func key(_ flags: NSEvent.ModifierFlags) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, characters: "h", charactersIgnoringModifiers: "h", isARepeat: false, keyCode: 4))
        }
        for flags: NSEvent.ModifierFlags in [[.command, .control], .option] {
            XCTAssertEqual(model.stripInput(try key(flags)), .ignored)
            XCTAssertEqual(model.settings.presentation, "strip")
            XCTAssertEqual(model.query, "")
        }
        XCTAssertEqual(model.stripInput(try key([.command, .shift])), .list)
        let plain = self.model()
        plain.beginStrip(StripGesture(keyCode: 48, invoking: .command))
        XCTAssertEqual(plain.stripInput(try key([])), .list)
    }

    func testClickUsesReleaseBindingWhileInvokingModifiersAreHeld() throws {
        let model = model()
        model.beginStrip(StripGesture(keyCode: 48, invoking: .command))
        for (flags, expected): (NSEvent.ModifierFlags, String) in [(.command, "enter"), ([.command, .option], "alt-enter")] {
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            XCTAssertEqual(model.key(for: event, click: true), expected)
        }
    }

    func testInitialSelectionForwardReverseWrapAndOnlyInvokingKeyCycles() {
        let model = model()
        model.beginStrip(StripGesture(keyCode: 48, invoking: [.command]))
        XCTAssertEqual(model.selectedId, 2)
        XCTAssertTrue(model.cycleStrip(keyCode: 48, flags: [.command]))
        XCTAssertEqual(model.selectedId, 3)
        model.cycleStrip(keyCode: 48, flags: [.command])
        XCTAssertEqual(model.selectedId, 1)
        model.cycleStrip(keyCode: 48, flags: [.command, .shift])
        XCTAssertEqual(model.selectedId, 3)
        XCTAssertFalse(model.cycleStrip(keyCode: 50, flags: [.command]))
        let reversed = self.model()
        reversed.beginStrip(StripGesture(keyCode: 48, invoking: [.command, .shift]))
        XCTAssertEqual(reversed.selectedId, 3)
        let one = self.model(count: 1); one.beginStrip(StripGesture(keyCode: 50, invoking: [.command]))
        one.cycleStrip(keyCode: 50, flags: [.command]); XCTAssertEqual(one.selectedId, 1)
        let empty = self.model(count: 0); empty.beginStrip(StripGesture(keyCode: 48, invoking: [.command]))
        empty.cycleStrip(keyCode: 48, flags: [.command]); XCTAssertNil(empty.selectedId)
    }
    func testCarbonAndLocalInputsShareNavigationActionAndHandOff() throws {
        let model = model()
        model.beginStrip(StripGesture(keyCode: 48, invoking: .command))
        func key(_ code: UInt16, _ text: String, flags: NSEvent.ModifierFlags = .command) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
        }
        XCTAssertEqual(model.stripInput(try key(50, "`")), .consumed)
        XCTAssertEqual(model.selectedId, 2)
        XCTAssertEqual(model.stripInput(try key(124, "")), .consumed)
        XCTAssertEqual(model.selectedId, 3)
        XCTAssertEqual(model.stripInput(try key(48, "\t")), .consumed)
        XCTAssertEqual(model.selectedId, 1)
        XCTAssertEqual(model.stripInput(try key(53, "")), .cancel)
        var action: String?
        model.onAction = { action = $0 }
        XCTAssertEqual(model.stripInput(try key(13, "w")), .consumed)
        XCTAssertEqual(action, "cmd-w")
        XCTAssertEqual(model.stripInput(try key(2, "d")), .list)
        XCTAssertEqual(model.query, "d")
    }

    func testReleaseChoosesEnterBindingWithoutShiftAndLetterBindingWins() throws {
        let model = model()
        model.beginStrip(StripGesture(keyCode: 48, invoking: [.command]))
        XCTAssertNil(model.stripReleaseKey(flags: [.command]))
        XCTAssertEqual(model.stripReleaseKey(flags: [.shift]), "enter")
        XCTAssertEqual(model.stripReleaseKey(flags: [.option, .shift]), "alt-enter")
        let close = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: 0, context: nil, characters: "w", charactersIgnoringModifiers: "w", isARepeat: false, keyCode: 13))
        var action: String?
        model.onAction = { action = $0 }
        XCTAssertTrue(model.handleStripLetter(close))
        XCTAssertEqual(action, "cmd-w")
        XCTAssertEqual(model.settings.presentation, "strip")
        let search = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: 0, context: nil, characters: "d", charactersIgnoringModifiers: "d", isARepeat: false, keyCode: 2))
        XCTAssertTrue(model.handleStripLetter(search))
        XCTAssertEqual(model.settings.presentation, "list")
        XCTAssertEqual(model.query, "d")
        XCTAssertEqual(model.selectedId, 2)
        XCTAssertNil(model.stripReleaseKey(flags: []))
        model.changePresentation("strip")
        model.removeStripItems([2])
        XCTAssertEqual(model.settings.presentation, "strip")
        XCTAssertEqual(model.results.map(\.id), [1, 3])
        XCTAssertEqual(model.selectedId, 3)
    }
}
