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
        for presentation in ["strip", "list", "miniatures", "grid"] {
            let model = LensStartupPreparation.model(presentation: presentation, size: CGSize(width: 1280, height: 720))
            XCTAssertTrue(model.items.contains { !$0.tile.chips(enabled: true).isEmpty })
            XCTAssertTrue(model.items.contains { $0.tile.picture != nil && $0.tile.picture?.image == nil })
            XCTAssertNil(model.owner)
            XCTAssertEqual(model.settings.presentation, presentation)
            XCTAssertEqual(model.items.count, 4)
            XCTAssertTrue(model.items.contains { $0.tile.picture?.image != nil })
            XCTAssertTrue(model.items.contains { $0.tile.picture?.image == nil })
            XCTAssertTrue(model.items.allSatisfy { $0.miniature == nil })
        }
    }

    func testStartupUsesExistingTileSnapshotsWithoutOpeningALens() {
        let thumbnail = WindowThumbnail()
        let tile = TileEntry(icon: nil, title: "Existing window", appName: "Existing app", picture: thumbnail)
        let item = SwitcherPaletteItem(id: 42, title: tile.title, appName: tile.appName, icon: nil, workspaceName: "real", isFocused: true, tile: tile)
        let workspace = MiniatureWorkspace(name: "real", title: "Real workspace", source: CGRect(x: 0, y: 0, width: 1280, height: 720), current: true)
        for presentation in ["strip", "list", "miniatures", "grid"] {
            let model = LensStartupPreparation.model(presentation: presentation, size: workspace.source.size, existingItems: [item], workspaces: [workspace])
            XCTAssertEqual(model.items.map(\.id), [42])
            XCTAssertTrue(model.items[0].tile.picture === thumbnail)
            XCTAssertEqual(model.miniatureWorkspaces.map(\.name), ["real"])
            XCTAssertNil(model.owner)
            XCTAssertNil(model.onAction)
        }
    }

    func testStartupPreparesEachPresentationOnlyOnce() {
        let preparation = LensStartupPreparation()
        var rendered: [String] = []
        preparation.run(idle: true) { rendered.append($0) }
        preparation.run(idle: true) { rendered.append($0) }
        XCTAssertEqual(rendered, ["strip", "list", "miniatures", "grid"])
    }

    func testStartupDrawsNothingWhileALensOwnsThePanel() {
        let preparation = LensStartupPreparation()
        var rendered: [String] = []
        XCTAssertFalse(preparation.run(idle: false) { rendered.append($0) })
        XCTAssertEqual(rendered, [])
    }
}
