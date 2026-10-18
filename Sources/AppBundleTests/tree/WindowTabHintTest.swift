@testable import AppBundle
import AppKit
import Clocks
import Common
import HotKey
import XCTest

@MainActor
final class WindowTabHintTest: SerialClockTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testClockDeadlinePointerMovementAndShownClicks() async {
        let clock = TestClock<Duration>()
        let owner = WindowTabHintController(clock: clock, liveFlags: { .option }, allowed: { true }, lensOpen: { false }, bindings: { self.digits() })
        owner.flagsChanged(.option)
        await clock.advance(by: .milliseconds(499))
        XCTAssertNil(owner.shownModifiers)
        owner.pointerActivity(.mouseMoved)
        await clock.advance(by: .milliseconds(1))
        XCTAssertEqual(owner.shownModifiers, .option)
        owner.keyOrClick()
        owner.pointerActivity(.leftMouseDown)
        XCTAssertEqual(owner.shownModifiers, .option)
        owner.flagsChanged([])
        XCTAssertNil(owner.shownModifiers)
    }

    func testClockSpoiledChordModeResetAndContextGates() async {
        let clock = TestClock<Duration>()
        var lens = false
        var enabled = true
        let owner = WindowTabHintController(clock: clock, liveFlags: { .option }, allowed: { enabled }, lensOpen: { lens }, bindings: { self.digits() })
        owner.flagsChanged(.option)
        owner.keyOrClick()
        await clock.advance(by: .seconds(2))
        XCTAssertNil(owner.shownModifiers)
        owner.flagsChanged([])
        owner.flagsChanged(.option)
        owner.reset()
        await clock.advance(by: .seconds(1))
        XCTAssertNil(owner.shownModifiers)
        owner.flagsChanged([])
        owner.flagsChanged(.option)
        lens = true
        await clock.advance(by: .seconds(1))
        XCTAssertNil(owner.shownModifiers)
        owner.flagsChanged([])
        owner.flagsChanged(.option)
        await clock.advance(by: .seconds(1))
        XCTAssertNil(owner.shownModifiers)
        lens = false
        owner.flagsChanged([])
        owner.flagsChanged(.option)
        await clock.advance(by: .seconds(1))
        XCTAssertEqual(owner.shownModifiers, .option)
        lens = true
        owner.keyOrClick()
        XCTAssertNil(owner.shownModifiers)
        lens = false
        owner.flagsChanged([])
        owner.flagsChanged(.option)
        enabled = false
        owner.reconcile()
        await clock.advance(by: .seconds(1))
        XCTAssertNil(owner.shownModifiers)
    }

    func testClockModifierRearmingAndDroppedRelease() async {
        let clock = TestClock<Duration>()
        var live: NSEvent.ModifierFlags = .option
        let owner = WindowTabHintController(clock: clock, liveFlags: { live }, allowed: { true }, lensOpen: { false }, bindings: {
            self.digits() + [self.binding([.option, .shift], .q, .position(1))]
        })
        owner.flagsChanged(.option)
        await clock.advance(by: .milliseconds(300))
        live = [.option, .shift]
        owner.flagsChanged(live)
        await clock.advance(by: .milliseconds(200))
        XCTAssertNil(owner.shownModifiers)
        await clock.advance(by: .milliseconds(300))
        XCTAssertEqual(owner.shownModifiers, [.option, .shift])
        owner.flagsChanged([])
        owner.flagsChanged(.option)
        live = []
        await clock.advance(by: .seconds(1))
        XCTAssertNil(owner.shownModifiers)
    }

    func testOnlyAddressedGroupGetsLabelsAndFloatingFocusGetsNone() async {
        let root = focus.workspace.rootTilingContainer
        let first = TilingContainer(parent: root, adaptiveWeight: 1, .h, .tabGroup, index: INDEX_BIND_LAST)
        let second = TilingContainer(parent: root, adaptiveWeight: 1, .h, .tabGroup, index: INDEX_BIND_LAST)
        let windows = [TestWindow.new(id: 1, parent: first), TestWindow.new(id: 2, parent: first), TestWindow.new(id: 3, parent: second), TestWindow.new(id: 4, parent: second)]
        let clock = TestClock<Duration>()
        let owner = WindowTabHintController(clock: clock, liveFlags: { .option }, allowed: { true }, lensOpen: { false }, bindings: { self.digits() })
        XCTAssertTrue(windows[0].focusWindow())
        XCTAssertEqual(owner.labels, WindowTabHintLabels())
        owner.flagsChanged(.option)
        await clock.advance(by: .seconds(1))
        XCTAssertEqual(owner.labels, WindowTabHintLabels(group: ObjectIdentifier(first), byWindow: [1: "1", 2: "2"]))
        XCTAssertTrue(windows[2].focusWindow())
        owner.reconcile()
        XCTAssertEqual(owner.labels, WindowTabHintLabels(group: ObjectIdentifier(second), byWindow: [3: "1", 4: "2"]))
        let floating = TestWindow.new(id: 5, parent: focus.workspace)
        XCTAssertTrue(floating.focusWindow())
        owner.reconcile()
        XCTAssertEqual(owner.labels, WindowTabHintLabels())
        owner.reset()
    }

    func testDroppedReleaseIsCaughtUpFromLiveFlags() async {
        let clock = TestClock<Duration>()
        var live: NSEvent.ModifierFlags = .option
        let owner = WindowTabHintController(clock: clock, liveFlags: { live }, allowed: { true }, lensOpen: { false }, bindings: { self.digits() })
        owner.flagsChanged(.option)
        await clock.advance(by: .seconds(1))
        XCTAssertEqual(owner.shownModifiers, .option)
        live = []
        owner.pointerActivity(.mouseMoved)
        XCTAssertNil(owner.shownModifiers, "A pointer move after a dropped release hides the hints")
        live = .option
        owner.flagsChanged(.option)
        await clock.advance(by: .seconds(1))
        XCTAssertEqual(owner.shownModifiers, .option, "The next hold of the same modifier shows again")
    }

    func testKeyAfterDroppedReleaseCatchesUpWithoutThePointer() async {
        let clock = TestClock<Duration>()
        var live: NSEvent.ModifierFlags = .option
        let owner = WindowTabHintController(clock: clock, liveFlags: { live }, allowed: { true }, lensOpen: { false }, bindings: { self.digits() })
        owner.flagsChanged(.option)
        await clock.advance(by: .seconds(1))
        XCTAssertEqual(owner.shownModifiers, .option)
        live = []
        owner.keyOrClick()
        XCTAssertNil(owner.shownModifiers, "Typing after a dropped release hides the hints")
        live = .option
        owner.flagsChanged(.option)
        owner.keyOrClick()
        live = []
        owner.keyOrClick()
        live = .option
        owner.flagsChanged(.option)
        await clock.advance(by: .seconds(1))
        XCTAssertEqual(owner.shownModifiers, .option, "A spoiled hold whose release was dropped does not block the next one")
    }

    func testNestedGroupWindowIsLabelledOnlyInTheAddressedStrip() async {
        let outer = TilingContainer(parent: focus.workspace.rootTilingContainer, adaptiveWeight: 1, .h, .tabGroup, index: INDEX_BIND_LAST)
        TestWindow.new(id: 1, parent: outer)
        let inner = TilingContainer(parent: outer, adaptiveWeight: 1, .h, .tabGroup, index: INDEX_BIND_LAST)
        let nested = TestWindow.new(id: 2, parent: inner)
        TestWindow.new(id: 3, parent: inner)
        XCTAssertTrue(nested.focusWindow())
        let clock = TestClock<Duration>()
        let owner = WindowTabHintController(clock: clock, liveFlags: { .option }, allowed: { true }, lensOpen: { false }, bindings: { self.digits() })
        owner.flagsChanged(.option)
        await clock.advance(by: .seconds(1))
        XCTAssertEqual(owner.labels.label(strip: ObjectIdentifier(inner), window: 2), "1")
        XCTAssertEqual(owner.labels.label(strip: ObjectIdentifier(inner), window: 3), "2")
        XCTAssertTrue(outer.children.last?.tabRepresentativeWindow === nested, "The outer strip draws the nested window for its second tab")
        XCTAssertNil(owner.labels.label(strip: ObjectIdentifier(outer), window: 2))
        owner.reset()
    }

    func testKeyUnderUnboundModifiersSpoilsUntilFullRelease() {
        var state = WindowTabHintState()
        state.flagsChanged([.option, .shift], hasBindings: { false }, allowed: true)
        XCTAssertNil(state.deadline)
        state.keyOrClick(allowed: true)
        state.flagsChanged(.option, hasBindings: { true }, allowed: true)
        XCTAssertNil(state.deadline, "Releasing Shift after an Option-Shift chord does not arm")
        state.flagsChanged([], hasBindings: { true }, allowed: true)
        state.flagsChanged(.option, hasBindings: { true }, allowed: true)
        XCTAssertNotNil(state.deadline)
    }

    func testDeadlineReleaseAndShownKey() {
        var state = WindowTabHintState()
        state.flagsChanged(.option, hasBindings: { true }, allowed: true)
        let deadline = state.deadline!
        XCTAssertNil(state.shown)
        state.fire(deadline, allowed: true)
        XCTAssertEqual(state.shown, .option)
        state.keyOrClick(allowed: true)
        XCTAssertEqual(state.shown, .option)
        state.flagsChanged([], hasBindings: { true }, allowed: true)
        XCTAssertNil(state.shown)
        XCTAssertNil(state.deadline)
    }

    func testQuickChordSpoilsUntilFullRelease() {
        var state = WindowTabHintState()
        state.flagsChanged(.option, hasBindings: { true }, allowed: true)
        let old = state.deadline!
        state.keyOrClick(allowed: true)
        state.fire(old, allowed: true)
        state.flagsChanged([.option, .shift], hasBindings: { true }, allowed: true)
        XCTAssertNil(state.deadline)
        XCTAssertNil(state.shown)
        state.flagsChanged([], hasBindings: { true }, allowed: true)
        state.flagsChanged(.option, hasBindings: { true }, allowed: true)
        XCTAssertNotNil(state.deadline)
    }

    func testModifierChangeRearmsAndRejectsStaleOrDroppedRelease() {
        var state = WindowTabHintState()
        state.flagsChanged(.option, hasBindings: { true }, allowed: true)
        let old = state.deadline!
        state.flagsChanged([.option, .shift], hasBindings: { true }, allowed: true)
        let current = state.deadline!
        XCTAssertNotEqual(old, current)
        state.fire(old, allowed: true)
        XCTAssertNil(state.shown, "A stale token shows nothing")
        state.fire(current, allowed: true)
        XCTAssertEqual(state.shown, [.option, .shift])
        XCTAssertNil(state.deadline)
    }

    func testNoBindingsModeChangeAndLensGate() {
        var state = WindowTabHintState()
        state.flagsChanged(.control, hasBindings: { false }, allowed: true)
        XCTAssertNil(state.deadline)
        state.flagsChanged(.option, hasBindings: { true }, allowed: false)
        XCTAssertNil(state.deadline)
        state.flagsChanged([], hasBindings: { true }, allowed: true)
        state.flagsChanged(.option, hasBindings: { true }, allowed: true)
        state.fire(state.deadline!, allowed: true)
        state.keyOrClick(allowed: false)
        XCTAssertNil(state.shown)
        state.reset()
        XCTAssertNil(state.shown)
        XCTAssertNil(state.deadline)
    }

    private func binding(_ modifiers: NSEvent.ModifierFlags, _ key: Key, _ target: FocusCmdArgs.TabIndex) -> HotkeyBinding {
        HotkeyBinding(modifiers, key, [FocusCommand(args: .init(rawArgs: [], tabIndex: target))], descriptionWithKeyNotation: key.description)
    }

    private func digits(_ modifiers: NSEvent.ModifierFlags = .option) -> [HotkeyBinding] {
        let keys: [Key] = [.one, .two, .three, .four, .five, .six, .seven, .eight]
        return keys.enumerated().map { binding(modifiers, $0.element, .position(UInt32($0.offset + 1))) } + [binding(modifiers, .nine, .last)]
    }

    func testDefaultLabelsOnThreeEightNineAndTwelveTabs() {
        for count in [3, 8, 9, 12] {
            let labels = windowTabHintLabels(bindings: digits(), modifiers: .option, childCount: count, isTabGroup: true)
            for index in 0..<min(count, 8) { XCTAssertEqual(labels[index], String(index + 1)) }
            XCTAssertEqual(labels[count - 1], count <= 8 ? String(count) : "9")
            XCTAssertFalse(labels.values.contains("0"))
            if count == 12 { for index in 8...10 { XCTAssertNil(labels[index]) } }
        }
    }

    func testRebindingsExactModifiersAndSingleTab() {
        XCTAssertTrue(windowTabHintLabels(bindings: digits(.control), modifiers: .option, childCount: 3, isTabGroup: true).isEmpty)
        XCTAssertEqual(windowTabHintLabels(bindings: digits(.control), modifiers: .control, childCount: 3, isTabGroup: true)[2], "3")
        let custom = [binding(.option, .q, .position(1)), binding([.option, .shift], .one, .position(2))]
        XCTAssertEqual(windowTabHintLabels(bindings: custom, modifiers: .option, childCount: 3, isTabGroup: true), [0: "Q"])
        XCTAssertEqual(windowTabHintLabels(bindings: custom, modifiers: [.option, .shift], childCount: 3, isTabGroup: true), [1: "1"])
        XCTAssertEqual(windowTabHintLabels(bindings: digits(), modifiers: .option, childCount: 1, isTabGroup: false), [0: "9"])
    }

    func testSingleFocusCommandWithExtraFlagsAndDeterministicCollision() {
        var args = FocusCmdArgs(rawArgs: [], tabIndex: .position(2))
        args.rawBoundaries = .workspace
        let extraFlags = HotkeyBinding(.option, .q, [FocusCommand(args: args)], descriptionWithKeyNotation: "alt-q")
        let multiple = HotkeyBinding(.option, .one, [FocusCommand(args: args), FocusCommand(args: args)], descriptionWithKeyNotation: "alt-1")
        let bindings = [multiple, extraFlags, binding(.option, .a, .position(2)), binding(.option, .nine, .last)]
        XCTAssertEqual(windowTabHintLabels(bindings: bindings, modifiers: .option, childCount: 2, isTabGroup: true), [1: "A"])
    }

    func testLabelsUseConfiguredNotationIncludingKeyboardMappingsAndSpecialKeys() {
        let command = FocusCommand(args: .init(rawArgs: [], tabIndex: .position(1)))
        let mapped = HotkeyBinding(.option, .a, [command], descriptionWithKeyNotation: "alt-q")
        let special = HotkeyBinding(.option, .delete, [command], descriptionWithKeyNotation: "alt-backspace")
        XCTAssertEqual(windowTabHintLabels(bindings: [mapped], modifiers: .option, childCount: 3, isTabGroup: true), [0: "Q"])
        XCTAssertEqual(windowTabHintLabels(bindings: [special], modifiers: .option, childCount: 3, isTabGroup: true), [0: "⌫"])
    }

    func testFeatureOffCommandAndHintResolutionAgreeOnNestedLastChild() async throws {
        let group = TilingContainer(parent: focus.workspace.rootTilingContainer, adaptiveWeight: 1, .h, .tabGroup, index: INDEX_BIND_LAST)
        let first = TestWindow.new(id: 1, parent: group)
        let nested = TilingContainer(parent: group, adaptiveWeight: 1, .v, .tiles, index: INDEX_BIND_LAST)
        TestWindow.new(id: 2, parent: nested)
        let recent = TestWindow.new(id: 3, parent: nested)
        XCTAssertTrue(recent.focusWindow())
        XCTAssertTrue(first.focusWindow())
        let resolved = resolveTabFocusTarget(focus, .last)!
        XCTAssertTrue(resolved.group === group)
        XCTAssertEqual(resolved.zeroBasedIndex, 1)
        XCTAssertEqual(windowTabHintLabels(bindings: digits(), modifiers: .option, childCount: group.children.count, isTabGroup: true)[resolved.zeroBasedIndex], "2")
        let result = try await FocusCommand(args: .init(rawArgs: [], tabIndex: .last)).run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(focus.windowOrNil, recent)
    }
}
