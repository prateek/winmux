@testable import AppBundle
import AppKit
import Clocks
import Common
import XCTest

@MainActor
final class LensReleaseTest: SerialClockTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    private func model(_ presentation: String, startsIn: String? = nil) -> LensSession {
        var settings = LensConfig()
        settings.presentation = presentation
        settings.startsIn = startsIn
        let items = (1...3).map { SwitcherPaletteItem(id: UInt32($0), title: "Window \($0)", appName: "Demo", icon: nil, workspaceName: "1", isFocused: $0 == 1) }
        return LensSession(name: "release", settings: settings, items: items, search: "")
    }

    func testShippedAppWindowsGridStepsOnlyBacktickAndReleasesEnter() throws {
        let settings = try XCTUnwrap(defaultConfig.lenses["app-windows"])
        XCTAssertEqual(settings.presentation, "grid")
        XCTAssertEqual(settings.resolvedOnRelease, "commit")
        let gesture = StripGesture(keyCode: 50, invoking: .command)
        let items = (1...3).map { SwitcherPaletteItem(id: UInt32($0), title: "Window \($0)", appName: "Demo", icon: nil, workspaceName: "1", isFocused: $0 == 1) }
        let session = LensSession(name: "app-windows", settings: settings, items: items, search: "")
        let owner = testLensLifecycle()
        defer { owner.dismiss() }
        owner.complete(session, ticket: owner.begin("app-windows", toggle: true, invocation: gesture, settings: settings)!)
        XCTAssertTrue(session.commitsOnRelease)
        XCTAssertEqual(session.selectedId, 2)
        func press(_ code: UInt16, _ flags: NSEvent.ModifierFlags) throws {
            let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, characters: code == 50 ? "`" : "\t", charactersIgnoringModifiers: code == 50 ? "`" : "\t", isARepeat: false, keyCode: code))
            XCTAssertTrue(session.perform(session.meaning(for: event)))
        }
        try press(50, .command)
        XCTAssertEqual(session.selectedId, 3)
        try press(50, [.command, .shift])
        XCTAssertEqual(session.selectedId, 2)
        try press(48, .command)
        XCTAssertEqual(session.selectedId, 2, "Tab is not this gesture")
        var actions: [String] = []
        session.onAction = { actions.append($0); owner.dismiss() }
        owner.stripFlagsChanged([], from: session)
        XCTAssertEqual(actions, ["enter"])
        XCTAssertEqual(settings.keys["enter"], ["focus"])
        let recent = LensSession(name: "recent", settings: try XCTUnwrap(defaultConfig.lenses["recent"]), items: items, search: "")
        recent.beginStrip(StripGesture(keyCode: 48, invoking: .command))
        XCTAssertEqual(lensKeyMeaning(state: recent.inputState, hold: recent.hold, keys: recent.activeKeyBindings, code: 50, characters: "`", flags: .command, presentation: recent.settings.presentation, commitsOnRelease: recent.commitsOnRelease), .step(0))
    }

    func testShippedAppWindowsTapIsSilentAndHoldWaitsOneHundredMilliseconds() async throws {
        let settings = try XCTUnwrap(defaultConfig.lenses["app-windows"])
        for (tap, beforeReady) in [(true, true), (true, false), (false, false)] {
            let clock = TestClock<Duration>()
            var events: [ServerEvent] = []
            var frames = 0
            let owner = testLensLifecycle(clock: clock, emit: { events.append($0) }, show: { _ in frames += 1 })
            let gesture = StripGesture(keyCode: 50, invoking: .command, clock: clock)
            let session = LensSession(name: "app-windows", settings: settings, items: [], search: "")
            let ticket = owner.begin("app-windows", toggle: true, invocation: gesture, settings: settings)!
            var actions: [String] = []
            session.onAction = { actions.append($0); owner.dismiss() }
            if tap && beforeReady { owner.openingFlagsChanged([]) }
            owner.complete(session, ticket: ticket)
            if tap && !beforeReady { owner.stripFlagsChanged([], from: session) }
            await clock.advance(by: .milliseconds(99))
            XCTAssertEqual(frames, 0)
            await clock.advance(by: .milliseconds(1))
            XCTAssertEqual(frames, tap ? 0 : 1)
            if tap {
                XCTAssertEqual(actions, ["enter"])
                XCTAssertTrue(events.isEmpty)
                XCTAssertNil(owner.session)
            } else {
                XCTAssertFalse(events.isEmpty)
                owner.stripFlagsChanged([], from: session)
                XCTAssertEqual(actions, ["enter"])
            }
            owner.dismiss()
        }
    }

    func testBaselineGridReleaseReturnsToStartingStateAndRepeatedTriggerTogglesClosed() {
        for startsIn in ["normal", "search"] {
            let owner = testLensLifecycle()
            let session = model("grid", startsIn: startsIn)
            let gesture = StripGesture(keyCode: 48, invoking: .command)
            owner.complete(session, ticket: owner.begin("release", toggle: true, invocation: gesture)!)
            XCTAssertEqual(session.inputState, .hold)
            XCTAssertTrue(session.perform(.step(1)))
            let selected = session.selectedId
            owner.stripFlagsChanged([], from: session)
            XCTAssertNil(session.hold)
            XCTAssertEqual(session.inputState.rawValue, startsIn)
            XCTAssertEqual(session.selectedId, selected)
            XCTAssertTrue(owner.session === session)
            XCTAssertNil(owner.begin("release", toggle: true, invocation: gesture))
            XCTAssertNil(owner.session)
        }
    }

    func testBaselineStripStepsReversesAndResolvesReleasedEnterModifiers() {
        let owner = testLensLifecycle()
        defer { owner.dismiss() }
        let session = model("strip")
        let gesture = StripGesture(keyCode: 48, invoking: .command)
        owner.complete(session, ticket: owner.begin("release", toggle: true, strip: gesture)!)
        XCTAssertEqual(session.selectedId, 2)
        XCTAssertTrue(session.cycleStrip(keyCode: 48, flags: .command))
        XCTAssertEqual(session.selectedId, 3)
        XCTAssertTrue(session.cycleStrip(keyCode: 48, flags: [.command, .shift]))
        XCTAssertEqual(session.selectedId, 2)
        var actions: [String] = []
        session.onAction = { actions.append($0) }
        owner.stripFlagsChanged([.option, .shift], from: session)
        XCTAssertEqual(actions, ["alt-enter"])
    }

    func testBaselineStripSlashAndLetterEndReleaseGesture() {
        for text in ["/", "j"] {
            let owner = testLensLifecycle()
            let session = model("strip")
            let gesture = StripGesture(keyCode: 48, invoking: .command)
            owner.complete(session, ticket: owner.begin("release", toggle: true, strip: gesture)!)
            var actions: [String] = []
            session.onAction = { actions.append($0) }
            XCTAssertTrue(session.perform(.endHold(text == "/" ? 44 : 38, text)))
            XCTAssertEqual(session.settings.presentation, text == "/" ? "list" : "strip")
            owner.stripFlagsChanged([], from: session)
            XCTAssertTrue(actions.isEmpty)
            XCTAssertTrue(owner.session === session)
            owner.dismiss()
        }
    }

    func testBaselineStripTapBeforeReadinessNeverDrawsOrEmitsEvents() async {
        let clock = TestClock<Duration>()
        var events: [ServerEvent] = []
        var frames = 0
        let owner = testLensLifecycle(clock: clock, emit: { events.append($0) }, show: { _ in frames += 1 })
        let gesture = StripGesture(keyCode: 48, invoking: .command, clock: clock)
        let ticket = owner.begin("release", toggle: true, strip: gesture)!
        owner.openingFlagsChanged([])
        owner.complete(model("strip"), ticket: ticket)
        await clock.advance(by: .seconds(1))
        XCTAssertNil(owner.session)
        XCTAssertEqual(frames, 0)
        XCTAssertTrue(events.isEmpty)
    }
    func testCommitPolicyStepsAndReleasesEveryPresentationWithHeldChord() async {
        for presentation in ["strip", "grid", "list", "miniatures"] {
            let clock = TestClock<Duration>()
            var events: [ServerEvent] = []
            var drawn: [String] = []
            let owner = testLensLifecycle(clock: clock, emit: { events.append($0) }, show: { drawn.append($0.settings.presentation) })
            var settings = LensConfig(); settings.presentation = presentation; settings.onRelease = "commit"
            let session = LensSession(name: "release", settings: settings, items: model("grid").items, search: "")
            let gesture = StripGesture(keyCode: 48, invoking: .command, clock: clock)
            let ticket = owner.begin("release", toggle: true, strip: gesture, settings: settings)!
            owner.complete(session, ticket: ticket)
            XCTAssertTrue(session.commitsOnRelease)
            XCTAssertEqual(session.selectedId, 2)
            XCTAssertTrue(session.cycleStrip(keyCode: 48, flags: .command))
            XCTAssertEqual(session.selectedId, 3)
            XCTAssertTrue(session.cycleStrip(keyCode: 48, flags: [.command, .shift]))
            XCTAssertEqual(session.selectedId, 2)
            await clock.advance(by: .milliseconds(99))
            XCTAssertTrue(drawn.isEmpty)
            await clock.advance(by: .milliseconds(1))
            XCTAssertEqual(drawn, [presentation], "The gesture must not change the shape")
            var actions: [String] = []
            session.onAction = { actions.append($0); owner.dismiss() }
            owner.stripFlagsChanged([.option, .shift], from: session)
            XCTAssertEqual(actions, ["alt-enter"])
            XCTAssertEqual(events.map(\.eventType), [.lensOpened, .lensClosed])
            XCTAssertNil(owner.session)
        }
    }

    func testCommitGridQuickTapBeforeAndAfterReadinessNeverDrawsOrEmits() async {
        for beforeReady in [false, true] {
            let clock = TestClock<Duration>()
            var events: [ServerEvent] = []
            var frames = 0
            let owner = testLensLifecycle(clock: clock, emit: { events.append($0) }, show: { _ in frames += 1 })
            var settings = LensConfig(); settings.presentation = "grid"; settings.onRelease = "commit"
            let gesture = StripGesture(keyCode: 48, invoking: .command, clock: clock)
            let ticket = owner.begin("release", toggle: false, strip: gesture, settings: settings)!
            if beforeReady { owner.openingFlagsChanged([]) }
            let session = LensSession(name: "release", settings: settings, items: model("grid").items, search: "")
            var selected: UInt32?
            session.onAction = { _ in selected = session.selectedId; owner.dismiss() }
            owner.complete(session, ticket: ticket)
            if !beforeReady { owner.stripFlagsChanged([], from: session) }
            await clock.advance(by: .seconds(1))
            XCTAssertEqual(selected, 2)
            XCTAssertEqual(frames, 0)
            XCTAssertTrue(events.isEmpty)
            XCTAssertNil(owner.session)
        }
    }

    func testStayStripDrawsImmediatelyAndReleaseLeavesZoomUntilEnterOrEscape() {
        for exit in [LensKeyMeaning.command("enter"), .dismiss] {
            let owner = testLensLifecycle()
            defer { owner.dismiss() }
            var settings = LensConfig(); settings.presentation = "strip"; settings.onRelease = "stay"
            let session = LensSession(name: "release", settings: settings, items: model("grid").items, search: "")
            let gesture = StripGesture(keyCode: 48, invoking: .command)
            owner.complete(session, ticket: owner.begin("release", toggle: true, invocation: gesture, settings: settings)!)
            guard case .presented = owner.state else { return XCTFail("Stay has no display delay") }
            XCTAssertFalse(session.commitsOnRelease)
            session.send(.peekToggled)
            let peek = session.peekedId
            owner.stripFlagsChanged([], from: session)
            XCTAssertEqual(session.inputState, .normal)
            XCTAssertEqual(session.peekedId, peek)
            XCTAssertTrue(owner.session === session)
            XCTAssertEqual(session.meaning(for: NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "\t", charactersIgnoringModifiers: "\t", isARepeat: false, keyCode: 48)!), .mark)
            var action: String?
            session.onAction = { action = $0; owner.dismiss() }
            if exit == .dismiss { owner.dismiss() } else { session.perform(exit); XCTAssertEqual(action, "enter") }
            XCTAssertNil(owner.session)
            XCTAssertNil(session.peekedId)
        }
    }

    func testCommitWithoutHeldChordStaysOpenIncludingStrip() {
        for presentation in ["strip", "grid", "list", "miniatures"] {
            for gesture in [nil, StripGesture(keyCode: nil, invoking: .command), StripGesture(keyCode: 15, invoking: [])] {
                let owner = testLensLifecycle()
                var settings = LensConfig(); settings.presentation = presentation; settings.onRelease = "commit"
                let session = LensSession(name: "release", settings: settings, items: [], search: "")
                owner.complete(session, ticket: owner.begin("release", toggle: true, invocation: gesture, settings: settings)!)
                XCTAssertFalse(session.commitsOnRelease)
                owner.stripFlagsChanged([], from: session)
                XCTAssertTrue(owner.session === session)
                guard case .presented = owner.state else { return XCTFail("No chord means no delay") }
                owner.dismiss()
            }
        }
    }

    func testListConversionAndLetterCancelCommitGridGesture() {
        for text in ["/", "j"] {
            let owner = testLensLifecycle()
            var settings = LensConfig(); settings.presentation = "grid"; settings.onRelease = "commit"
            let gesture = StripGesture(keyCode: 48, invoking: .command)
            let session = LensSession(name: "release", settings: settings, items: [], search: "")
            owner.complete(session, ticket: owner.begin("release", toggle: true, strip: gesture, settings: settings)!)
            session.perform(.endHold(text == "/" ? 44 : 38, text))
            if text == "/" { session.changePresentation("list") }
            owner.stripFlagsChanged([], from: session)
            XCTAssertTrue(owner.session === session)
            XCTAssertNil(session.stripReleaseKey(flags: []))
            owner.dismiss()
        }
    }

    func testCommittingListUsesStripTabBacktickAndClickModifiersUntilConversion() {
        for release in ["commit", "stay"] {
            var settings = LensConfig(); settings.onRelease = release
            let session = LensSession(name: "list", settings: settings, items: model("grid").items, search: "")
            session.startHold(StripGesture(keyCode: 5, invoking: .command))
            func key(_ code: UInt16, _ flags: NSEvent.ModifierFlags) -> NSEvent {
                NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code)!
            }
            XCTAssertEqual(session.meaning(for: key(48, .command)), .step(release == "commit" ? 0 : 1))
            XCTAssertEqual(session.meaning(for: key(50, .command)), .step(0))
            XCTAssertEqual(session.key(for: key(36, [.command, .shift]), click: true), release == "commit" ? "enter" : "shift-enter")
            session.changePresentation("list")
            XCTAssertFalse(session.commitsOnRelease)
            XCTAssertEqual(session.key(for: key(36, [.command, .shift]), click: true), "shift-enter")
        }
    }

    func testOpeningCommitGridReplaysStepsAndLetterBeforeRecordedRelease() {
        for letter in [false, true] {
            let owner = testLensLifecycle()
            var settings = LensConfig(); settings.presentation = "grid"; settings.onRelease = "commit"
            let gesture = StripGesture(keyCode: 5, invoking: .command)
            let ticket = owner.begin("release", toggle: true, strip: gesture, settings: settings)!
            XCTAssertEqual(owner.openingStripKey(keyCode: 5, flags: .command), .consumed)
            if letter { XCTAssertEqual(owner.openingStripKey(keyCode: 38, flags: .command, characters: "j"), .consumed) }
            owner.openingFlagsChanged([])
            let session = LensSession(name: "release", settings: settings, items: model("grid").items, search: "")
            var actions: [String] = []
            session.onAction = { actions.append($0) }
            owner.complete(session, ticket: ticket)
            XCTAssertEqual(actions, letter ? [] : ["enter"])
            XCTAssertEqual(session.settings.presentation, "grid")
            XCTAssertEqual(session.holdEndedByKey, letter)
            owner.dismiss()
        }
    }

    func testShiftOnlyCommitWaitsForItsHeldModifierToRelease() {
        var settings = LensConfig(); settings.presentation = "grid"; settings.onRelease = "commit"
        let session = LensSession(name: "shift", settings: settings, items: [], search: "")
        let gesture = StripGesture(keyCode: 5, invoking: .shift)
        session.beginStrip(gesture)
        XCTAssertTrue(session.commitsOnRelease)
        XCTAssertNil(session.stripReleaseKey(flags: .shift))
        XCTAssertEqual(session.stripReleaseKey(flags: []), "enter")
    }

}
