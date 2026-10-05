@testable import AppBundle
import AppKit
import Clocks
import Common
import XCTest

@MainActor
final class LensPreparationTest: XCTestCase {
    func testStripPreparesWhileWaitingButIsNeverOrderedBeforeTheDeadline() async throws {
        let clock = TestClock<Duration>()
        var prepared = false
        var shown = false
        let owner = testLensLifecycle(clock: clock, show: { _ in
            XCTAssertTrue(prepared)
            shown = true
        })
        owner.prepare = { model in
            XCTAssertTrue(owner.session === model)
            prepared = true
        }
        let gesture = StripGesture(keyCode: 48, invoking: .command, clock: clock)
        let ticket = owner.begin("recent", toggle: false, strip: gesture)!
        var settings = LensConfig(); settings.presentation = "strip"
        let model = LensSession(name: "recent", settings: settings, items: [], search: "")
        await clock.advance(by: .milliseconds(8))
        owner.complete(model, ticket: ticket)
        XCTAssertTrue(prepared)
        XCTAssertFalse(shown)
        await clock.advance(by: .milliseconds(91))
        XCTAssertFalse(shown)
        await clock.advance(by: .milliseconds(1))
        XCTAssertTrue(shown)
        owner.dismiss()
        try await clock.checkSuspension()
    }

    func testStartupModelsExerciseBothPictureAndPlaceholderTilesWithoutWindows() {
        for presentation in ["strip", "list", "miniatures"] {
            let model = LensStartupPreparation.model(presentation: presentation, size: CGSize(width: 1280, height: 720))
            XCTAssertNil(model.owner)
            XCTAssertEqual(model.settings.presentation, presentation)
            XCTAssertEqual(model.items.count, 4)
            XCTAssertTrue(model.items.contains { $0.tile.picture?.image != nil })
            XCTAssertTrue(model.items.contains { $0.tile.picture?.image == nil })
            XCTAssertTrue(model.items.allSatisfy { $0.miniature == nil })
        }
    }

    func testStartupPreparesEachPresentationOnlyOnce() {
        let preparation = LensStartupPreparation()
        var rendered: [String] = []
        preparation.run { rendered.append($0) }
        preparation.run { rendered.append($0) }
        XCTAssertEqual(rendered, ["strip", "list", "miniatures"])
    }

    func testPreparationPutsCurrentContentInTheFrameBeforeLayout() {
        var content = "old"
        var framedContent = ""
        var laidOutContent = ""
        LensPresentationPreparation.run(content: { content = "current" }, frame: { framedContent = content }, layout: { laidOutContent = framedContent })
        XCTAssertEqual(laidOutContent, "current")
    }
}
