@testable import AppBundle
import AppKit
import XCTest

final class MiniatureLayoutTest: XCTestCase {
    func testScaleUsesWorkspaceOriginAndKeepsFloatingPosition() {
        let source = CGRect(x: 100, y: 200, width: 1000, height: 500)
        let target = CGRect(x: 20, y: 40, width: 200, height: 100)
        XCTAssertEqual(MiniatureLayout.scale(CGRect(x: 600, y: 250, width: 400, height: 200), from: source, to: target), CGRect(x: 120, y: 50, width: 80, height: 40))
    }

    func testPagesKeepSidebarOrderAtReadableFloorAndScrollClamps() {
        let layout = MiniatureLayout(workspaces: (1 ... 50).map(String.init), size: CGSize(width: 800, height: 600), aspect: 2, fit: "page")
        XCTAssertGreaterThan(layout.pageCount, 1)
        XCTAssertGreaterThanOrEqual(layout.workspaceHeight, 110)
        XCTAssertEqual(layout.cells(on: 0).map(\.workspace), Array((1 ... layout.capacity).map(String.init)))
        XCTAssertEqual(layout.cells(on: 1).first?.workspace, String(layout.capacity + 1))
        XCTAssertEqual(layout.turnedPage(0, delta: -1), 0)
        XCTAssertEqual(layout.turnedPage(0, delta: 1), 1)
        let shrink = MiniatureLayout(workspaces: (1 ... 50).map(String.init), size: CGSize(width: 800, height: 600), aspect: 2, fit: "shrink")
        XCTAssertEqual(shrink.pageCount, 1)
        XCTAssertEqual(shrink.cells(on: 0).count, 50)
        for cell in shrink.cells(on: 0) {
            XCTAssertLessThanOrEqual(cell.frame.maxX.rounded(), 800 - 24)
            XCTAssertLessThanOrEqual(cell.tray.maxY + 24, 600)
        }
    }

    func testShrinkNeverEnlargesPastTheLargestThumbnailWidth() {
        let layout = MiniatureLayout(workspaces: ["1"], size: CGSize(width: 4000, height: 3000), aspect: 2, fit: "shrink")
        XCTAssertLessThanOrEqual(layout.cells(on: 0)[0].frame.width, 560)
    }

    func testDirectionalMovementUsesGeometryAndOnlyMatches() {
        let frames: [UInt32: CGRect] = [1: CGRect(x: 0, y: 0, width: 20, height: 20), 2: CGRect(x: 50, y: 0, width: 20, height: 20), 3: CGRect(x: 0, y: 50, width: 20, height: 20)]
        XCTAssertEqual(MiniatureLayout.nearest(from: 1, direction: .right, frames: frames, matches: [1, 2, 3]), 2)
        XCTAssertEqual(MiniatureLayout.nearest(from: 1, direction: .down, frames: frames, matches: [1, 2, 3]), 3)
        XCTAssertNil(MiniatureLayout.nearest(from: 1, direction: .right, frames: frames, matches: [1, 3]))
    }
}

@MainActor
final class MiniatureSessionTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    private func session() -> LensSession {
        let workspace = Workspace.get(byName: "1")
        let other = Workspace.get(byName: "2")
        var settings = LensConfig()
        settings.presentation = "miniatures"
        let windows = [TestWindow.new(id: 1, parent: workspace.rootTilingContainer), TestWindow.new(id: 2, parent: workspace), TestWindow.new(id: 3, parent: macosMinimizedWindowsContainer), TestWindow.new(id: 4, parent: other.rootTilingContainer)]
        let items = windows.enumerated().map { index, window in
            SwitcherPaletteItem(id: window.windowId, title: ["Alpha", "Beta", "Gamma", "Delta"][index], appName: "Demo", icon: nil, workspaceName: index == 3 ? "2" : "1", isFocused: false,
                                miniature: MiniatureWindow(workspace: index == 3 ? "2" : "1", frame: CGRect(x: CGFloat(index % 2) * 500, y: 0, width: 500, height: 500), tray: index == 2, frozen: index >= 2, accessory: false, floating: index == 1, window: window))
        }
        let model = LensSession(name: "overview", settings: settings, items: items, search: "")
        model.miniatureWorkspaces = [MiniatureWorkspace(name: "1", title: "One", source: CGRect(x: 0, y: 0, width: 1000, height: 500), current: true), MiniatureWorkspace(name: "2", title: "Two", source: CGRect(x: 0, y: 0, width: 1000, height: 500), current: false)]
        return model
    }

    func testSearchDimsInPlaceRanksSelectionAndNavigationOnlyMatches() {
        let model = session()
        let frames = model.miniatureFrames
        XCTAssertFalse(model.miniatureSearchVisible)
        model.send(.searchChanged("Beta"))
        XCTAssertTrue(model.miniatureSearchVisible)
        XCTAssertEqual(model.selectedId, 2)
        XCTAssertEqual(model.miniatureOpacity(1), 0.18)
        XCTAssertEqual(model.miniatureOpacity(2), 1)
        XCTAssertEqual(model.miniatureFrames, frames)
        model.moveMiniatureSelection(.left)
        XCTAssertEqual(model.selectedId, 2)
        model.send(.searchChanged(""))
        XCTAssertFalse(model.miniatureSearchVisible)
        model.hover(1)
        model.moveMiniatureSelection(.right)
        XCTAssertEqual(model.selectedId, 2)
    }

    func testTrayBelongsToRetainedWorkspaceAndDoesNotMoveOtherFrames() throws {
        let model = session()
        let tray = try XCTUnwrap(model.miniatureFrames[3])
        let cell = try XCTUnwrap(model.miniatureLayout.cells(on: 0).first)
        XCTAssertEqual(tray.minY, cell.tray.minY)
        XCTAssertLessThanOrEqual(tray.maxX, cell.tray.maxX)
        XCTAssertEqual(model.items[2].miniature?.workspace, "1")
    }

    func testByWorkspaceAndOverrideIgnoreAppGrouping() {
        let original = session()
        var settings = original.settings
        settings.entries = "app"
        settings.miniatures.arrowKeys = "by-workspace"
        let model = LensSession(name: "override", settings: settings, items: original.items, search: "")
        model.miniatureWorkspaces = original.miniatureWorkspaces
        XCTAssertEqual(model.results.count, 4)
        model.hover(1)
        model.moveMiniatureSelection(.right)
        XCTAssertEqual(model.selectedId, 2)
        model.moveMiniatureSelection(.down)
        XCTAssertEqual(model.selectedId, 4)
        model.moveMiniatureSelection(.up)
        XCTAssertEqual(model.selectedId, 1)
    }

    func testHiddenCurrentAndListOverridePreserveSelectionAndMarks() {
        let model = session()
        model.send(.excludedChanged([1, 2, 3]))
        XCTAssertEqual(model.selectedId, 4)
        model.toggleMark()
        model.changePresentation("list")
        XCTAssertEqual(model.selectedId, 4)
        XCTAssertEqual(model.marks, [4])
        XCTAssertEqual(model.results.count, 4)
    }

    func testSummonModifierComesFromConfiguredCommands() {
        let original = session()
        var settings = original.settings
        settings.keys["shift-enter"] = ["close"]
        settings.keys["ctrl-enter"] = ["summon"]
        let model = LensSession(name: "custom", settings: settings, items: original.items, search: "")
        model.updateSummonModifiers(.shift)
        XCTAssertFalse(model.summonHeld)
        model.updateSummonModifiers(.control)
        XCTAssertTrue(model.summonHeld)
        model.updateSummonModifiers([])
        XCTAssertFalse(model.summonHeld)
    }

    func testLandingPreviewDoesNotMutateTabTreeAndIsOnlyComputedWhenHeld() {
        let model = session()
        let root = focus.workspace.rootTilingContainer
        root.layout = .tabGroup
        let children = root.children
        model.hover(4)
        XCTAssertNil(model.miniatureLanding)
        let owner = ownLens(model)
        defer { owner.dismiss() }
        model.send(.summonChanged(true))
        XCTAssertNotNil(model.miniatureLanding)
        XCTAssertEqual(root.children, children)
        XCTAssertTrue(focus.workspace.rootTilingContainer === root)
        model.send(.summonChanged(false))
        XCTAssertNil(model.miniatureLanding)
    }
}
