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
}
