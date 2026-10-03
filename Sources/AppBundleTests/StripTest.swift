@testable import AppBundle
import AppKit
import XCTest

final class StripLayoutTest: XCTestCase {
    func testFitsWidthCapsAtNineAndCountsHiddenEntries() {
        let wide = StripLayout(count: 20, selection: 10, width: 3000)
        XCTAssertEqual(wide.range.count, 9)
        XCTAssertEqual(wide.before, 6)
        XCTAssertEqual(wide.after, 5)
        let narrow = StripLayout(count: 20, selection: 19, width: 600)
        XCTAssertEqual(narrow.range, 17..<20)
        XCTAssertEqual(narrow.before, 17)
        XCTAssertEqual(narrow.after, 0)
        XCTAssertLessThanOrEqual(narrow.rowWidth, 600)
        XCTAssertEqual(StripLayout(count: 0, selection: 0, width: 600).range, 0..<0)
        XCTAssertEqual(StripLayout(count: 1, selection: 0, width: 600).range, 0..<1)
    }
    func testInvokingModifiersDelayAndReleaseBinding() {
        let gesture = StripGesture(keyCode: 48, invoking: [.command, .shift], openedAt: 10)
        XCTAssertEqual(gesture.committingModifiers, [.command])
        XCTAssertFalse(gesture.shouldDisplay(now: 10.099))
        XCTAssertTrue(gesture.shouldDisplay(now: 10.1))
        XCTAssertFalse(gesture.shouldCommit(flags: [.command]))
        XCTAssertTrue(gesture.shouldCommit(flags: [.option, .shift]))
        XCTAssertEqual(gesture.releaseModifiers([.option, .shift]), [.option])
        XCTAssertTrue(StripGesture(keyCode: 48, invoking: [], openedAt: 0).shouldCommit(flags: []))
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
    func testInitialSelectionForwardReverseWrapAndOnlyInvokingKeyCycles() {
        let model = model()
        model.beginStrip(StripGesture(keyCode: 48, invoking: [.command], openedAt: 0))
        XCTAssertEqual(model.selectedId, 2)
        XCTAssertTrue(model.cycleStrip(keyCode: 48, flags: [.command]))
        XCTAssertEqual(model.selectedId, 3)
        model.cycleStrip(keyCode: 48, flags: [.command])
        XCTAssertEqual(model.selectedId, 1)
        model.cycleStrip(keyCode: 48, flags: [.command, .shift])
        XCTAssertEqual(model.selectedId, 3)
        XCTAssertFalse(model.cycleStrip(keyCode: 50, flags: [.command]))
        let reversed = self.model()
        reversed.beginStrip(StripGesture(keyCode: 48, invoking: [.command, .shift], openedAt: 0))
        XCTAssertEqual(reversed.selectedId, 3)
        let one = self.model(count: 1); one.beginStrip(StripGesture(keyCode: 50, invoking: [.command], openedAt: 0))
        one.cycleStrip(keyCode: 50, flags: [.command]); XCTAssertEqual(one.selectedId, 1)
        let empty = self.model(count: 0); empty.beginStrip(StripGesture(keyCode: 48, invoking: [.command], openedAt: 0))
        empty.cycleStrip(keyCode: 48, flags: [.command]); XCTAssertNil(empty.selectedId)
    }
    func testCarbonAndLocalInputsShareNavigationActionAndHandOff() throws {
        let model = model()
        model.beginStrip(StripGesture(keyCode: 48, invoking: .command, openedAt: 0))
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
        model.beginStrip(StripGesture(keyCode: 48, invoking: [.command], openedAt: 0))
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
