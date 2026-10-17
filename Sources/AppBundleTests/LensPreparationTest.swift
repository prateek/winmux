@testable import AppBundle
import AppKit
import Clocks
import Common
import XCTest

@MainActor
final class LensPreparationTest: SerialClockTestCase {
    private func backingProbe() -> (NSPanel, StartupBackingProbe) {
        _ = NSApplication.shared
        let frame = NSRect(x: 0, y: 0, width: 32, height: 32)
        let window = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let probe = StartupBackingProbe(frame: frame)
        probe.wantsLayer = true
        window.contentView = probe
        probe.needsDisplay = true
        return (window, probe)
    }

    func testStartupDrawsTheHiddenWindowBackingWithoutOrderingIt() {
        let (window, probe) = backingProbe()
        defer { window.close() }
        let before = probe.draws
        XCTAssertFalse(window.isVisible)
        LensStartupPreparation.drawHiddenBacking(window)
        XCTAssertGreaterThan(probe.draws, before)
        XCTAssertFalse(window.isVisible)
    }

    func testStartupBackingDrawDoesNothingWhileALensOwnsThePanel() {
        let (window, probe) = backingProbe()
        defer { window.close() }
        let before = probe.draws
        let preparation = LensStartupPreparation()
        preparation.run(idle: false) { _ in LensStartupPreparation.drawHiddenBacking(window) }
        XCTAssertEqual(probe.draws, before)
        XCTAssertFalse(window.isVisible)
        preparation.run(idle: true) { _ in
            probe.needsDisplay = true
            LensStartupPreparation.drawHiddenBacking(window)
        }
        XCTAssertGreaterThan(probe.draws, before)
        XCTAssertFalse(window.isVisible)
    }

    func testEmptyDesktopGridPreparationExercisesRealPicturesSectionsAndFrozenDrawing() {
        let model = LensStartupPreparation.gridModel(size: CGSize(width: 1920, height: 1050), existingItems: [], workspaces: [])
        XCTAssertEqual(model.settings.presentation, "grid")
        XCTAssertEqual(model.settings.grid.tileSize, "real")
        XCTAssertEqual(model.tileKind, .card)
        XCTAssertEqual(model.items.count, 14)
        XCTAssertEqual(model.sections.count, 4)
        XCTAssertEqual(model.gridLayout.headers.count, 4)
        XCTAssertEqual(model.gridLayout.tiles.count, 14)
        XCTAssertGreaterThan(Set(model.gridLayout.tiles.map { $0.frame.minY }).count, 1)
        XCTAssertTrue(model.items.contains { $0.tile.realSize.height > $0.tile.realSize.width })
        XCTAssertTrue(model.items.contains { $0.tile.realSize.width <= 400 })
        XCTAssertTrue(model.items.contains { $0.tile.realSize.width >= 1400 })
        XCTAssertTrue(model.items.contains { $0.tile.frozen && $0.tile.picture?.image != nil })
        XCTAssertTrue(model.items.contains { !$0.tile.frozen && $0.tile.picture?.image != nil })
        XCTAssertTrue(model.items.contains { $0.tile.picture != nil && $0.tile.picture?.image == nil })
        XCTAssertTrue(model.items.contains { ($0.tile.picture?.image?.width ?? 0) >= 500 })
        XCTAssertTrue(model.items.allSatisfy { $0.icon != nil && $0.miniature == nil })
        XCTAssertEqual(model.miniatureWorkspaces.count, 4)
        XCTAssertNil(model.owner)
        XCTAssertNil(model.onAction)
        XCTAssertNil(model.onControl)
        model.refreshThumbnails(lens: 1) { _, _, _ in XCTFail("Synthetic preparation must never request a capture") }
    }

    func testGridPreparationRetainsRealSnapshotsAndTheirCachedPictures() {
        let thumbnail = WindowThumbnail()
        let item = SwitcherPaletteItem(id: 42, title: "Real", appName: "Editor", icon: nil, workspaceName: "real", isFocused: true,
            tile: TileEntry(title: "Real", appName: "Editor", picture: thumbnail))
        let workspace = MiniatureWorkspace(name: "real", title: "Real workspace", source: CGRect(x: 0, y: 0, width: 1920, height: 1050), current: true)
        let model = LensStartupPreparation.gridModel(size: workspace.source.size, existingItems: [item], workspaces: [workspace])
        XCTAssertEqual(model.items.map(\.id), [42])
        XCTAssertTrue(model.items[0].tile.picture === thumbnail)
        XCTAssertNil(thumbnail.image)
        XCTAssertEqual(model.miniatureWorkspaces.map(\.name), ["real"])
        XCTAssertNil(model.owner)
        XCTAssertNil(model.onAction)
    }

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


extension LensPreparationTest {
    func testNeutralPreparationWarmsHeadersAndGroupingControlWithoutWindows() {
        for presentation in ["list", "grid"] {
            let model = LensStartupPreparation.model(presentation: presentation, size: CGSize(width: 1920, height: 1080), existingItems: [])
            XCTAssertEqual(model.sections.count, 1)
            XCTAssertTrue(model.sections[0].current)
            XCTAssertEqual(model.visibleSectionValues, ["none", "workspace", "app"])
            XCTAssertEqual(model.sectionsKey, "cmd-g")
            XCTAssertNil(model.owner)
            if presentation == "grid" {
                XCTAssertEqual(model.gridLayout.headers.count, 1)
                XCTAssertGreaterThanOrEqual(model.gridLayout.panelSize.width, model.sectionControlMinimumWidth)
            } else { XCTAssertEqual(model.listLayout.rowOffsets[0], 32) }
        }
    }
}

@MainActor
private final class StartupBackingProbe: NSView {
    var draws = 0
    override func draw(_ dirtyRect: NSRect) { draws += 1 }
}
