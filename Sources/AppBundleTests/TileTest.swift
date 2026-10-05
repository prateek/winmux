@testable import AppBundle
import AppKit
import XCTest

final class TileTest: XCTestCase {
    func testKindResolutionUsesOverrideThenConfigThenPresentation() {
        for (presentation, expected): (String, TileKind) in [("strip", .card), ("grid", .card), ("list", .text), ("miniatures", .picture)] {
            XCTAssertEqual(TileKind.resolve(configured: nil, override: nil, presentation: presentation), expected)
            for kind in TileKind.allCases {
                XCTAssertEqual(TileKind.resolve(configured: kind.rawValue, override: nil, presentation: presentation), presentation == "miniatures" ? .picture : kind)
                XCTAssertEqual(TileKind.resolve(configured: "text", override: kind.rawValue, presentation: presentation), presentation == "miniatures" ? .picture : kind)
            }
        }
    }

    func testBadgesAreOrderedAndCanBeDisabledWithoutChangingEntryFlags() {
        let flags = TileBadges(workspaceNumber: 3, onFocusedWorkspace: false, floating: true, minimized: true, hidden: true)
        XCTAssertEqual(flags.chips(enabled: true), ["3", "floating", "minimized", "hidden"])
        XCTAssertEqual(flags.chips(enabled: false), [])
        XCTAssertEqual(TileBadges(workspaceNumber: 1, onFocusedWorkspace: true).chips(enabled: true), [])
        XCTAssertEqual(TileBadges(workspaceNumber: nil, onFocusedWorkspace: false, hidden: true).chips(enabled: true), ["hidden"])
    }

    func testMetricsScaleEveryPrototypeDimension() {
        let full = TileMetrics(visibleHeight: 1080), half = TileMetrics(visibleHeight: 540)
        let dimensions: [(KeyPath<TileMetrics, CGFloat>, CGFloat)] = [
            (\.padding, 10), (\.gap, 8), (\.radius, 14), (\.barHeight, 28),
            (\.icon, 26), (\.titleFont, 17), (\.appFont, 14), (\.chipFont, 12),
            (\.chipVerticalPadding, 2), (\.chipHorizontalPadding, 7), (\.chipRadius, 6),
            (\.pictureRadius, 7), (\.selectionRing, 2.5), (\.textHeight, 46),
            (\.textWidth, 330), (\.textRadius, 10), (\.listPictureHeight, 74), (\.listPictureWidth, 96),
            (\.miniatureRadius, 5), (\.miniatureIcon, 22), (\.miniatureRing, 4),
            (\.stripGap, 14), (\.rowGap, 14), (\.rowHorizontalPadding, 12), (\.rowVerticalPadding, 6),
            (\.chipGap, 5), (\.labelVerticalPadding, 3), (\.labelHorizontalPadding, 8),
            (\.pictureIcon, 30), (\.pictureIconInset, 6), (\.miniatureIconInset, 4),
            (\.miniaturePictureRadius, 4), (\.adornmentGap, 4),
            (\.pictureShadowRadius, 9), (\.pictureShadowY, 6),
            (\.iconShadowRadius, 2), (\.iconShadowY, 2),
            (\.selectionShadowRadius, 20), (\.selectionShadowY, 18),
            (\.miniatureShadowRadius, 15), (\.miniatureShadowY, 10), (\.accessoryPictureFloor, 28),
        ]
        for (property, points) in dimensions {
            XCTAssertEqual(full[keyPath: property], points, "\(property)")
            XCTAssertEqual(half[keyPath: property], points / 2, "\(property)")
        }
        XCTAssertEqual(full.selectionScale, 1.045)
        XCTAssertEqual(half.selectionScale, full.selectionScale)
    }

    func testAccessoryActualSizeUsesRealHeightShareAndKeepsAHittableFloor() {
        let metrics = TileMetrics(visibleHeight: 1080)
        XCTAssertEqual(metrics.pictureHeight(rowHeight: 190, accessory: true, actualSize: true, monitorHeightFraction: 0.5), 95)
        XCTAssertEqual(metrics.pictureHeight(rowHeight: 190, accessory: true, actualSize: true, monitorHeightFraction: 0.01), 28)
        XCTAssertEqual(metrics.pictureHeight(rowHeight: 190, accessory: true, actualSize: true, monitorHeightFraction: 2), 190)
        XCTAssertEqual(metrics.pictureHeight(rowHeight: 190, accessory: true, actualSize: false, monitorHeightFraction: 0.1), 190)
        XCTAssertEqual(metrics.pictureHeight(rowHeight: 190, accessory: false, actualSize: true, monitorHeightFraction: 0.1), 190)
    }

    func testWidthsKeepRealShapeWithPictureFloorAndCardTitleFloor() {
        let metrics = TileMetrics(visibleHeight: 1080)
        XCTAssertEqual(metrics.width(kind: .picture, aspect: 0.2, rowHeight: 190), 90)
        XCTAssertEqual(metrics.width(kind: .picture, aspect: 2, rowHeight: 190), 400)
        XCTAssertEqual(metrics.width(kind: .card, aspect: 0.2, rowHeight: 190), 220)
        XCTAssertEqual(metrics.width(kind: .card, aspect: 0.2, rowHeight: 100), 140)
        XCTAssertEqual(metrics.width(kind: .text, aspect: 2, rowHeight: 190), 330)
        XCTAssertEqual(metrics.fittedPicture(aspect: 0.5, in: CGSize(width: 96, height: 62)), CGSize(width: 31, height: 62))
        XCTAssertEqual(metrics.fittedPicture(aspect: 3, in: CGSize(width: 96, height: 62)), CGSize(width: 96, height: 32))
    }
}

@MainActor
final class TileSnapshotTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testWorkspaceBadgeUsesSidebarOrdinalInsteadOfInternalNumericId() async throws {
        let first = Workspace.get(byName: "10"); first.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 40, parent: first.rootTilingContainer).focusWindow()
        let second = Workspace.get(byName: "7"); second.markAsAutomaticallyNamed()
        let window = TestWindow.new(id: 41, parent: second)
        let record = try await window.windowRecord().orDie()
        let source = LensWindow(record: record, window: window, spatialIndex: 0, workspaceIndex: 0)
        let miniature = MiniatureWindow(workspace: second.name, frame: .zero, tray: false, frozen: false, accessory: false, floating: true, window: window)
        let numbers = tileWorkspaceNumbers([first.name, second.name, second.name])
        XCTAssertEqual(numbers, [first.name: 1, second.name: 2])
        let tile = tileEntry(source, miniature: miniature, icon: nil, workspaceNumbers: numbers)
        XCTAssertEqual(tile.badges.chips(enabled: true), ["2", "floating"])
        XCTAssertEqual(second.name, "7")
    }

    func testExplicitNumericWorkspaceBadgeUsesTheNumberActuallyShown() async throws {
        _ = TestWindow.new(id: 50, parent: focus.workspace.rootTilingContainer).focusWindow()
        let workspace = Workspace.get(byName: "9")
        let window = TestWindow.new(id: 51, parent: workspace.rootTilingContainer)
        let record = try await window.windowRecord().orDie()
        let source = LensWindow(record: record, window: window, spatialIndex: 0, workspaceIndex: 0)
        let miniature = MiniatureWindow(workspace: workspace.name, frame: .zero, tray: false, frozen: true, accessory: false, floating: false, window: window)
        XCTAssertEqual(tileEntry(source, miniature: miniature, icon: nil).badges.chips(enabled: true), ["9"])
    }

    func testSnapshotSeparatesMinimizedHiddenAndEntriesWithoutMiniatureCells() async throws {
        let workspace = Workspace.get(byName: "2")
        let minimized = TestWindow.new(id: 1, parent: macosMinimizedWindowsContainer)
        let hidden = TestWindow.new(id: 2, parent: workspace.macOsNativeHiddenAppsWindowsContainer)
        let popup = TestWindow.new(id: 3, parent: macosPopupWindowsContainer)
        for window in [minimized, hidden, popup] {
            let snapshot = try await window.windowRecord()
            let record = try XCTUnwrap(snapshot)
            let source = LensWindow(record: record, window: window, spatialIndex: 0, workspaceIndex: 0)
            let geometry = MiniatureWindow(workspace: record.workspace, frame: CGRect(x: 0, y: 0, width: 300, height: 600), tray: window !== popup,
                                           frozen: window !== popup, accessory: false, floating: false, window: window)
            let tile = tileEntry(source, miniature: geometry, icon: nil)
            XCTAssertEqual(tile.aspect, 0.5)
            XCTAssertTrue(tile.picture === window.thumbnail)
            XCTAssertEqual(tile.badges.minimized, window === minimized)
            XCTAssertEqual(tile.badges.hidden, window === hidden)
        }
    }

    func testAppEntryCarriesAppTitleAndWindowCountEvenWithoutGeometry() {
        var settings = LensConfig(); settings.entries = "app"
        let items = (1 ... 2).map { id in
            SwitcherPaletteItem(id: UInt32(id), title: "Document", appName: "Editor", icon: nil, workspaceName: "", appIdentity: "editor", isFocused: false,
                                tile: TileEntry(title: "Document", appName: "Editor"))
        }
        let session = LensSession(name: "apps", settings: settings, items: items, search: "")
        let tile = session.results[0].tile
        XCTAssertEqual(tile.title, "Editor")
        XCTAssertEqual(tile.appName, "Editor")
        XCTAssertEqual(tile.appCount, 2)
        XCTAssertNil(tile.picture)
    }

    func testPictureListUsesTheLifecycleRefreshSeamAndSkipsFrozenWindows() {
        let workspace = focus.workspace
        var settings = LensConfig(); settings.tile = "card"
        let items = [false, true].enumerated().map { index, frozen in
            let window = TestWindow.new(id: UInt32(index + 1), parent: workspace.rootTilingContainer)
            return SwitcherPaletteItem(id: window.windowId, title: "Document", appName: "Editor", icon: nil, workspaceName: workspace.name, isFocused: false,
              miniature: MiniatureWindow(workspace: workspace.name, frame: .zero, tray: false, frozen: frozen, accessory: false, floating: false, window: window))
        }
        let session = LensSession(name: "pictures", settings: settings, items: items, search: "")
        var requested: [UInt32] = []
        session.refreshListThumbnails(lens: 10) { window, token in
            XCTAssertEqual(token, 10)
            requested.append(window.windowId)
        }
        XCTAssertEqual(requested, [1])
        XCTAssertEqual(lensOnscreenWindows(presentation: "list", tile: .card) { [42] }, [42])
    }
}
