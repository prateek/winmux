@testable import AppBundle
import AppKit
import Clocks
import Common
import XCTest

@MainActor
final class TileReviewRegressionTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testPortraitAndNarrowDisplaysUseTheSmallerScale() {
        let session = LensSession(name: "test", settings: LensConfig(), items: [], search: "")
        session.miniatureSize = CGSize(width: 1080, height: 1920)
        XCTAssertEqual(session.tileMetrics.scale, 1080.0 / 1920)
        session.miniatureSize = CGSize(width: 960, height: 1440)
        XCTAssertEqual(session.tileMetrics.scale, 0.5)
    }

    func testExtremeAspectDoesNotCollapseStripOrChangeVisibleCount() {
        let metrics = TileMetrics(visibleSize: CGSize(width: 1920, height: 1080))
        let ordinary = Array(repeating: CGFloat(3), count: 8)
        let mixed = ordinary + [10]
        let normalHeight = metrics.stripRowHeight(aspects: ordinary, kind: .card, availableWidth: 1920)
        let height = metrics.stripRowHeight(aspects: mixed, kind: .card, availableWidth: 1920)
        XCTAssertLessThanOrEqual(abs(normalHeight - height), 6)
        let widths = mixed.map { metrics.width(kind: .card, aspect: $0, rowHeight: height) }
        let counts = widths.indices.map { StripLayout(widths: widths, selection: $0, width: 1920 * 0.9, gap: metrics.stripGap).range.count }
        XCTAssertEqual(Set(counts), [9])
        XCTAssertEqual(metrics.width(kind: .picture, aspect: 10, rowHeight: 100), 380)
        XCTAssertEqual(metrics.width(kind: .picture, aspect: 0.01, rowHeight: 300), 110)
        XCTAssertEqual(metrics.fittedPicture(aspect: 10, in: CGSize(width: 360, height: 100)), CGSize(width: 360, height: 36))
    }

    func testListPanelUsesPrototypeSizeAndOneScale() {
        let full = ListLayout(count: 40, kind: .card, visibleSize: CGSize(width: 1920, height: 1080))
        XCTAssertEqual(full.width, 760)
        XCTAssertEqual(full.radius, 30)
        XCTAssertEqual(full.height, 1080 * 0.66, accuracy: 0.001)
        XCTAssertLessThanOrEqual(full.topOffset + full.panelHeight, 1080 * 0.96)
        XCTAssertEqual(full.rowHeight, 74)
        XCTAssertEqual(full.headerHeight, 90)
        XCTAssertEqual(full.capacity, 8)
        // The window is sized for the tallest list and one error line, whatever the row count,
        // so clearing a Search that opened on three rows has room for all of them.
        let few = ListLayout(count: 3, kind: .card, visibleSize: CGSize(width: 1920, height: 1080))
        XCTAssertLessThan(few.height, full.height)
        XCTAssertEqual(few.panelHeight, full.panelHeight)
        XCTAssertGreaterThanOrEqual(full.panelHeight, full.height + 30)
        let small = ListLayout(count: 2, kind: .card, visibleSize: CGSize(width: 960, height: 540))
        XCTAssertEqual(small.width, 380)
        XCTAssertEqual(small.radius, 15)
        XCTAssertEqual(small.height, (90 + 2 * 78) / 2)
        XCTAssertEqual(small.rowHeight, 37)
        XCTAssertEqual(small.visibleRange(selection: 0, count: 2), 0..<2)
        let portrait = ListLayout(count: 40, kind: .text, visibleSize: CGSize(width: 1080, height: 1920))
        XCTAssertEqual(portrait.width, 760 * 1080 / 1920)
    }

    func testEmptyStripReservesReadableFooterWidth() {
        for size in [CGSize(width: 1920, height: 1080), CGSize(width: 960, height: 540)] {
            let metrics = TileMetrics(visibleSize: size)
            let empty = StripSnapshot(items: [], selection: 0, size: size, kind: .picture, settings: LensConfig())
            let caption = ("No windows" as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 15 * metrics.scale)]).width
            XCTAssertGreaterThanOrEqual(empty.layout.rowWidth - 88 * metrics.scale, caption)
            XCTAssertTrue(empty.layout.range.isEmpty)
        }
    }

    func testOnePortraitPictureStillLeavesRoomForItsFooter() {
        let size = CGSize(width: 1920, height: 1080)
        let metrics = TileMetrics(visibleSize: size)
        var item = SwitcherPaletteItem(id: 1, title: "Notes", appName: "Notes", icon: nil, workspaceName: "2", isFocused: false)
        item.tile = TileEntry(title: "Notes", appName: "Notes", aspect: 0.5)
        let strip = StripSnapshot(items: [item], selection: 0, size: size, kind: .picture, settings: LensConfig())
        XCTAssertLessThan(strip.layout.rowWidth, strip.minimumWidth)
        XCTAssertEqual(strip.minimumWidth, metrics.textWidth + 88 * metrics.scale)
    }

    func testFooterOmitsAppNameWhenItIsAlreadyTheTitle() {
        XCTAssertNil(TileEntry(title: "Safari", appName: "Safari").footerAppName)
        XCTAssertNil(TileEntry(title: "", appName: "Safari").footerAppName)
        XCTAssertEqual(TileEntry(title: "Lenses", appName: "Safari").footerAppName, "Safari")
    }

    func testCellFooterOmitsOnlyTheWorkspaceChipAndKeepsBadgeSetting() {
        let tile = TileEntry(title: "Calculator", appName: "Calculator", badges: TileBadges(workspaceLabel: "4", onFocusedWorkspace: false, floating: true))
        XCTAssertEqual(tile.chips(enabled: true), ["4", "floating"])
        XCTAssertEqual(tile.chips(enabled: true, includeWorkspace: false), ["floating"])
        XCTAssertEqual(tile.chips(enabled: false, includeWorkspace: false), [])
    }

    func testWorkspaceLabelTruncatesByCharacterWithoutBreakingUnicode() {
        XCTAssertEqual(tileWorkspaceLabel("correspondence"), "corresponden…")
        XCTAssertEqual(tileWorkspaceLabel("mail"), "mail")
        XCTAssertEqual(tileWorkspaceLabel(String(repeating: "👩🏽‍💻", count: 13)), String(repeating: "👩🏽‍💻", count: 12) + "…")
    }

    func testPicturePolicyFollowsResolvedKindForEveryPresentation() {
        for presentation in ["list", "strip", "miniatures", "grid"] {
            for kind in TileKind.allCases {
                var settings = LensConfig(); settings.presentation = presentation; settings.tile = kind.rawValue
                let session = LensSession(name: "test", settings: settings, items: [], search: "")
                XCTAssertEqual(session.drawsPictures, presentation == "miniatures" || kind != .text)
            }
        }
    }

    func testExtremePictureSelectionLeavesRowsAndMiniaturesUnchanged() {
        for (presentation, kind, expected): (String, TileKind, Bool) in [("strip", .card, true), ("strip", .picture, true), ("strip", .text, false), ("list", .card, false), ("list", .picture, false), ("miniatures", .picture, false)] {
            let view = TileView(entry: TileEntry(title: "Toolbar", appName: "Editor", aspect: 10), kind: kind, presentation: presentation,
                                metrics: TileMetrics(visibleSize: CGSize(width: 1920, height: 1080)), size: CGSize(width: 380, height: 156),
                                settings: LensConfig(), selected: true, marked: false, hint: nil)
            XCTAssertEqual(view.extremeAspect, expected, presentation)
        }
    }

    func testFloatingTileUsesCaptureFrameAndKeepsOpeningAspect() async throws {
        let workspace = focus.workspace
        let window = TestWindow.new(id: 90, parent: workspace)
        window.miniatureFrame = CGRect(x: 0, y: 0, width: 300, height: 600)
        window.recordAuthoritativeActualRect(Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 200))
        let source = LensWindow(record: try await window.windowRecord().orDie(), window: window, spatialIndex: 0, workspaceIndex: 0)
        let miniature = MiniatureWindow(workspace: workspace.name, frame: window.miniatureFrame!, tray: false, frozen: false, accessory: false, floating: true, window: window)
        let tile = tileEntry(source, miniature: miniature, icon: nil, workspaceLabels: [:], monitorHeight: 1080, focusedWorkspaceName: workspace.name)
        XCTAssertEqual(tile.aspect, 4)
        XCTAssertEqual(miniature.frame.size, CGSize(width: 300, height: 600))
        window.recordAuthoritativeActualRect(Rect(topLeftX: 0, topLeftY: 0, width: 200, height: 800))
        XCTAssertEqual(tile.aspect, 4)
    }

    func testSidebarRenameReplacesAnAutomaticWorkspaceNumber() throws {
        let workspace = Workspace.get(byName: "2")
        workspace.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 92, parent: workspace.rootTilingContainer)
        // Before a rename the chip is the sidebar's number, read from the title the sidebar shows.
        XCTAssertNotNil(tileWorkspaceLabels([workspace.name], workspaces: miniatureWorkspaceSnapshot([]))[workspace.name].flatMap(Int.init))
        try renameWorkspaceForSidebar(workspaceName: workspace.name, displayName: "mail")
        XCTAssertEqual(tileWorkspaceLabels([workspace.name], workspaces: miniatureWorkspaceSnapshot([]))[workspace.name], "mail")
        try renameWorkspaceForSidebar(workspaceName: workspace.name, displayName: "correspondence")
        XCTAssertEqual(tileWorkspaceLabels([workspace.name], workspaces: miniatureWorkspaceSnapshot([]))[workspace.name], "corresponden…")
    }

    func testWorkspaceChipKeepsTheOpeningSnapshotLabel() {
        let workspace = Workspace.get(byName: "2")
        workspace.markAsAutomaticallyNamed()
        let snapshot = [MiniatureWorkspace(name: workspace.name, title: "Workspace 7", source: .zero, current: false)]
        XCTAssertEqual(tileWorkspaceLabels([workspace.name], workspaces: snapshot)[workspace.name], "7")
    }

    func testNamedWorkspaceHasItsSidebarLabel() async throws {
        let workspace = Workspace.get(byName: "mail")
        let window = TestWindow.new(id: 91, parent: workspace.rootTilingContainer)
        let source = LensWindow(record: try await window.windowRecord().orDie(), window: window, spatialIndex: 0, workspaceIndex: 0)
        let miniature = MiniatureWindow(workspace: workspace.name, frame: .zero, tray: false, frozen: true, accessory: false, floating: false, window: window)
        let tile = tileEntry(source, miniature: miniature, icon: nil, workspaceLabels: tileWorkspaceLabels([workspace.name], workspaces: miniatureWorkspaceSnapshot([])), monitorHeight: 1080, focusedWorkspaceName: "1")
        XCTAssertEqual(tile.badges.chips(enabled: true), ["mail"])
    }

    func testPictureListRequestsOnlyTheRowsThatCanBeVisibleOnOneClockTick() async throws {
        let clock = TestClock()
        var settings = LensConfig(); settings.tile = "card"
        let items = (1...40).map { id in
            let window = TestWindow.new(id: UInt32(id), parent: focus.workspace.rootTilingContainer)
            return SwitcherPaletteItem(id: window.windowId, title: "Document", appName: "Editor", icon: nil, workspaceName: "1", isFocused: false,
                miniature: MiniatureWindow(workspace: "1", frame: .zero, tray: false, frozen: false, accessory: false, floating: false, window: window))
        }
        let session = LensSession(name: "pictures", settings: settings, items: items, search: "")
        session.miniatureSize = CGSize(width: 1920, height: 1080)
        session.send(.selectionChanged(20))
        var requests: [UInt32] = []
        let dependencies = LensLifecycle.Dependencies(evaluate: { _, _, _ in .success([]) }, requestThumbnail: { window, _ in requests.append(window.windowId) }, closeThumbnails: { _ in }, flags: { [] })
        let owner = LensLifecycle(clock: clock, dependencies: dependencies, emit: { _ in }, show: { _ in }, hide: {})
        owner.complete(session, ticket: owner.begin("pictures", toggle: false)!)
        await clock.advance()
        requests.removeAll()
        await clock.advance(by: .milliseconds(500))
        XCTAssertEqual(requests.count, session.listLayout.capacity)
        XCTAssertEqual(requests.count, 8)
        XCTAssertTrue(requests.contains(21))
        XCTAssertFalse(requests.contains(1))
        XCTAssertFalse(requests.contains(40))
        owner.dismiss()
        try await clock.checkSuspension()
    }
}
