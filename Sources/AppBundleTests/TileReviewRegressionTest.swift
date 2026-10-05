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
        XCTAssertEqual(full.height, 1080 * 0.82)
        XCTAssertEqual(full.rowHeight, 74)
        XCTAssertEqual(full.headerHeight, 90)
        XCTAssertEqual(full.capacity, 11)
        let small = ListLayout(count: 2, kind: .card, visibleSize: CGSize(width: 960, height: 540))
        XCTAssertEqual(small.width, 380)
        XCTAssertEqual(small.height, (90 + 2 * 78) / 2)
        XCTAssertEqual(small.rowHeight, 37)
        XCTAssertEqual(small.visibleRange(selection: 0, count: 2), 0..<2)
        let portrait = ListLayout(count: 40, kind: .text, visibleSize: CGSize(width: 1080, height: 1920))
        XCTAssertEqual(portrait.width, 760 * 1080 / 1920)
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
        try renameWorkspaceForSidebar(workspaceName: workspace.name, displayName: "mail")
        XCTAssertEqual(tileWorkspaceLabels([workspace.name])[workspace.name], "mail")
        try renameWorkspaceForSidebar(workspaceName: workspace.name, displayName: "correspondence")
        XCTAssertEqual(tileWorkspaceLabels([workspace.name])[workspace.name], "corresponden…")
    }

    func testNamedWorkspaceHasItsSidebarLabel() async throws {
        let workspace = Workspace.get(byName: "mail")
        let window = TestWindow.new(id: 91, parent: workspace.rootTilingContainer)
        let source = LensWindow(record: try await window.windowRecord().orDie(), window: window, spatialIndex: 0, workspaceIndex: 0)
        let miniature = MiniatureWindow(workspace: workspace.name, frame: .zero, tray: false, frozen: true, accessory: false, floating: false, window: window)
        let tile = tileEntry(source, miniature: miniature, icon: nil, workspaceLabels: tileWorkspaceLabels([workspace.name]), monitorHeight: 1080, focusedWorkspaceName: "1")
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
        XCTAssertEqual(requests.count, 11)
        XCTAssertTrue(requests.contains(21))
        XCTAssertFalse(requests.contains(1))
        XCTAssertFalse(requests.contains(40))
        owner.dismiss()
        try await clock.checkSuspension()
    }
}

final class TileDrawingArchitectureTest: XCTestCase {
    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    func testPictureBadgesAreSharedWithThePresentationFooters() throws {
        let tile = try source("Sources/AppBundle/ui/hud/TileView.swift")
        XCTAssertFalse(tile.contains("pictureBadgeTop"))
        XCTAssertFalse(tile.contains(".overlay(alignment: .topLeading)"))
        for path in ["StripView.swift", "MiniaturesView.swift"] {
            XCTAssertTrue(try source("Sources/AppBundle/ui/hud/" + path).contains("TileChips("))
        }
    }

    func testMiniatureSelectionPreservesTheFloatingDrawOrder() throws {
        let miniatures = try source("Sources/AppBundle/ui/hud/MiniaturesView.swift")
        XCTAssertTrue(miniatures.contains("miniatureDrawOrder("))
        XCTAssertFalse(miniatures.contains(".zIndex("))
        XCTAssertTrue(try source("Sources/AppBundle/ui/hud/StripView.swift").contains(".zIndex("))
    }

    func testListAdornmentsUseTheLineInsteadOfThePicture() throws {
        let tile = try source("Sources/AppBundle/ui/hud/TileView.swift")
        XCTAssertTrue(tile.contains("if line {"))
        XCTAssertTrue(tile.contains("if entry.accessory && line"))
        XCTAssertTrue(tile.contains("if let hint, !line"))
        XCTAssertTrue(tile.contains("if entry.accessory && !line"))
    }

    func testFooterDoesNotAlwaysRepeatTheAppAndEmptyStateLivesThere() throws {
        let strip = try source("Sources/AppBundle/ui/hud/StripView.swift")
        XCTAssertFalse(strip.contains("Text(\" · \\(selected.appName)"))
        XCTAssertFalse(strip.contains("if items.isEmpty { Text(\"No windows\").frame"))
        XCTAssertTrue(strip.contains("No windows"))
    }

    func testStripRenderAndRefreshConsumeOneSnapshot() throws {
        let strip = try source("Sources/AppBundle/ui/hud/StripView.swift")
        XCTAssertFalse(strip.contains("model.stripWidths"))
        XCTAssertFalse(strip.contains("model.stripRowHeight"))
        XCTAssertFalse(strip.contains("model.results"))
        let layout = try source("Sources/AppBundle/lens/StripLayout.swift")
        XCTAssertFalse(layout.contains("var stripWidths:"))
        XCTAssertFalse(layout.contains("var stripRowHeight:"))
    }

    func testLifecycleUsesOnePicturePolicyAndRefreshDispatch() throws {
        let lifecycle = try source("Sources/AppBundle/lens/LensLifecycle.swift")
        XCTAssertTrue(lifecycle.contains("guard model.drawsPictures"))
        XCTAssertTrue(lifecycle.contains("model.refreshThumbnails("))
        XCTAssertFalse(lifecycle.contains("model.refreshListThumbnails("))
        XCTAssertFalse(try source("Sources/AppBundle/lens/Tile.swift").contains("override: String?"))
        let palette = try source("Sources/AppBundle/ui/hud/SwitcherPalette.swift")
        XCTAssertFalse(palette.contains("monitorHeight: CGFloat? = nil"))
        XCTAssertFalse(palette.contains("focusedWorkspaceName: String? = nil"))
    }
}
