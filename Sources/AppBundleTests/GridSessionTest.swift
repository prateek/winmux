@testable import AppBundle
import AppKit
import Clocks
import Common
import XCTest

@MainActor
final class GridSessionTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }
    private func model(count: Int = 14, settings: LensConfig? = nil) -> LensSession {
        var config = settings ?? LensConfig(); config.presentation = "grid"
        let items = (0..<count).map { index in
            let size = index == 1 ? CGSize(width: 300, height: 200) : CGSize(width: 1200, height: 900)
            let workspace = Workspace.get(byName: index < 7 ? "1" : "2")
            let window = TestWindow.new(id: UInt32(index + 1), parent: workspace.rootTilingContainer)
            return SwitcherPaletteItem(id: window.windowId, title: index == 1 ? "Alpha" : "Alpha document", appName: "Editor", icon: nil,
                workspaceName: workspace.name, appIdentity: index < 7 ? "editor" : "browser", isFocused: false,
                miniature: MiniatureWindow(workspace: workspace.name, frame: CGRect(origin: .zero, size: size), tray: false,
                                           frozen: index == 2, accessory: false, floating: false, window: window),
                tile: TileEntry(title: "Document", appName: "Editor", aspect: size.width / size.height, realSize: size))
        }
        let model = LensSession(name: "grid", settings: config, items: items, search: "")
        model.miniatureSize = CGSize(width: 1920, height: 1080)
        model.miniatureWorkspaces = ["1", "2"].map { MiniatureWorkspace(name: $0, title: $0, source: CGRect(x: 0, y: 0, width: 1920, height: 1080), current: $0 == "1") }
        return model
    }
    func testSearchKeepsSessionOrderAndResizesToOnlyMatches() {
        let session = model(count: 40)
        let before = session.gridLayout
        session.send(.searchChanged("Alpha"))
        XCTAssertEqual(session.results.map(\.id), Array(1...40).map(UInt32.init), "Grid matches stay in session order, regardless of Search score")
        session.send(.searchChanged("document"))
        XCTAssertEqual(session.results.count, 39)
        session.send(.searchChanged("2"))
        XCTAssertEqual(session.gridLayout.tiles.count, session.results.count)
        XCTAssertNotEqual(session.gridLayout.panelSize, before.panelSize)
        session.send(.searchChanged(""))
        XCTAssertEqual(session.gridLayout.panelSize, before.panelSize)
    }
    func testArrowsMoveWithoutAHoldAndDoNotMoveSearchCaret() {
        let session = model(count: 7)
        let expected = session.gridLayout.nearest(from: session.selection, direction: .right)
        XCTAssertNotNil(expected)
        XCTAssertTrue(session.perform(.arrow(124)))
        XCTAssertEqual(session.selection, expected)
        XCTAssertTrue(session.perform(.arrow(126)))
        XCTAssertEqual(session.query, "")
    }
    func testHeldTypingReleaseMarksAndAppEntriesShareTheSession() {
        let session = model()
        let owner = testLensLifecycle()
        let gesture = StripGesture(keyCode: 5, invoking: .option)
        owner.complete(session, ticket: owner.begin("grid", toggle: false, invocation: gesture)!)
        XCTAssertTrue(session.perform(.text("document")))
        XCTAssertEqual(session.settings.presentation, "grid")
        session.perform(.mark)
        let marked = session.selectedId
        owner.stripFlagsChanged([], from: session)
        XCTAssertNil(session.hold)
        XCTAssertTrue(owner.session === session)
        XCTAssertEqual(session.marks, marked.map { [$0] })
        owner.dismiss()
        var settings = LensConfig(); settings.entries = "app"
        let apps = model(settings: settings)
        XCTAssertEqual(apps.results.count, 2)
        XCTAssertEqual(apps.results.map { $0.tile.appCount }, [7, 7])
    }
    func testLifecycleRefreshesEveryLiveMatchEachHalfSecondAndCancels() async throws {
        let clock = TestClock<Duration>()
        var requests: [UInt32] = [], closed: [Int] = []
        let deps = LensLifecycle.Dependencies(evaluate: { _, _, _ in .success([]) }, requestThumbnail: { window, _ in requests.append(window.windowId) }, closeThumbnails: { closed.append($0) }, flags: { [] })
        let owner = LensLifecycle(clock: clock, dependencies: deps, emit: { _ in }, show: { _ in }, hide: {})
        let session = model(count: 14)
        owner.complete(session, ticket: owner.begin("grid", toggle: false)!)
        await clock.advance(by: .milliseconds(499))
        XCTAssertEqual(requests.count, 13)
        await clock.advance(by: .milliseconds(1))
        XCTAssertEqual(requests.count, 26)
        session.send(.searchChanged("document"))
        await clock.advance(by: .milliseconds(500))
        XCTAssertEqual(requests.count, 38)
        owner.dismiss()
        await clock.advance(by: .seconds(2))
        XCTAssertEqual(requests.count, 38)
        XCTAssertEqual(closed.count, 1)
        try await clock.checkSuspension()
    }
    func testSummonLandingUsesLifecycleAndClearsOnRelease() {
        let session = model()
        let owner = ownLens(session)
        defer { owner.dismiss() }
        session.hover(10)
        session.send(.summonChanged(true))
        XCTAssertNotNil(session.miniatureLanding)
        session.send(.summonChanged(false))
        XCTAssertNil(session.miniatureLanding)
    }
    func testGridPictureAllocationAndSelectionLiftNeverUpscaleADialog() {
        let entry = TileEntry(title: "Dialog", appName: "Editor", aspect: 1.5, realSize: CGSize(width: 300, height: 200))
        let metrics = TileMetrics(visibleSize: CGSize(width: 1920, height: 1080))
        let box = CGSize(width: 495, height: 330)
        for presentation in ["strip", "list", "miniatures"] {
            let view = TileView(entry: entry, kind: .card, presentation: presentation, metrics: metrics, size: box,
                                settings: LensConfig(), selected: false, marked: false, hint: nil)
            XCTAssertEqual(view.fittedPicture(in: box), box, "Existing Presentations keep their fitting")
        }
        for selected in [false, true] {
            let view = TileView(entry: entry, kind: .card, presentation: "grid", metrics: metrics, size: box,
                                settings: LensConfig(), selected: selected, marked: false, hint: nil, pictureSize: entry.realSize)
            let picture = view.fittedPicture(in: box)
            let lift = selected ? metrics.selectionScale : 1
            XCTAssertLessThanOrEqual(picture.width * lift, 300)
            XCTAssertLessThanOrEqual(picture.height * lift, 200)
        }
    }
    func testGridSettingsResolveAndReportEvenWhenIgnored() {
        for presentation in ["grid", "strip", "list", "miniatures"] {
            let settings = LensConfig(.object(["presentation": .string(presentation), "grid": .object(["tile-size": .string("same-height")]), "when": .object(["default": .object(["grid": .object(["tile-size": .string("equal")])])])]))
            XCTAssertEqual(settings.grid.tileSize, "equal")
            XCTAssertEqual(settings.json["grid"]?["tile-size"], .string("equal"))
        }
        XCTAssertEqual(LensConfig().json["grid"]?["tile-size"], .string("real"))
    }
}
