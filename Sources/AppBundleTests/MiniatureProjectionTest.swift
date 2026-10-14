@testable import AppBundle
import AppKit
import XCTest

@MainActor
final class MiniatureProjectionTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testOrdinaryNestedTilesKeepPhysicalGapsAndWeightsWithMiniaturesOff() async throws {
        let workspace = Workspace.get(byName: "1")
        let root = workspace.rootTilingContainer
        root.layout = .tiles
        root.changeOrientation(.h)
        let left = TestWindow.new(id: 1, parent: root, adaptiveWeight: 100)
        let right = TilingContainer(parent: root, adaptiveWeight: 300, .v, .tiles, index: INDEX_BIND_LAST)
        let top = TestWindow.new(id: 2, parent: right, adaptiveWeight: 100)
        let bottom = TestWindow.new(id: 3, parent: right, adaptiveWeight: 300)
        try await workspace.layoutWorkspace()
        let leftFrame = try XCTUnwrap(left.lastAppliedLayoutPhysicalRect)
        let rightFrame = try XCTUnwrap(right.lastAppliedLayoutPhysicalRect)
        let topFrame = try XCTUnwrap(top.lastAppliedLayoutPhysicalRect)
        let bottomFrame = try XCTUnwrap(bottom.lastAppliedLayoutPhysicalRect)
        let gaps = ResolvedGaps(gaps: config.gaps, monitor: workspace.workspaceMonitor)
        XCTAssertEqual(rightFrame.minX - leftFrame.maxX, gaps.inner.get(.h).toDouble(), accuracy: 0.001)
        XCTAssertEqual(bottomFrame.minY - topFrame.maxY, gaps.inner.get(.v).toDouble(), accuracy: 0.001)
        XCTAssertEqual(leftFrame.height, rightFrame.height)
        XCTAssertEqual(topFrame.width, bottomFrame.width)
        XCTAssertEqual(right.hWeight - left.hWeight, 200, accuracy: 0.001)
        XCTAssertEqual(bottom.vWeight - top.vWeight, 200, accuracy: 0.001)
    }

    func testUnvisitedNestedGroupUsesItsLayoutFrameWithoutWritingWindowOrTree() async throws {
        let workspace = Workspace.get(byName: "1")
        let root = workspace.rootTilingContainer
        let beside = TestWindow.new(id: 1, parent: root, adaptiveWeight: 100)
        let split = TilingContainer(parent: root, adaptiveWeight: 300, .v, .tiles, index: INDEX_BIND_LAST)
        _ = TestWindow.new(id: 2, parent: split, adaptiveWeight: 100)
        let group = TilingContainer(parent: split, adaptiveWeight: 300, .h, .tabGroup, index: INDEX_BIND_LAST)
        let a = TestWindow.new(id: 3, parent: group)
        let b = TestWindow.new(id: 4, parent: group)
        b.markAsMostRecentChild()
        try await workspace.layoutWorkspace()
        let expected = try XCTUnwrap(group.lastAppliedLayoutPhysicalRect?.cgRect)
        let nativeBefore = try await beside.getAxRect()
        let weights = [beside.hWeight, split.hWeight, group.vWeight]
        for node in [workspace, root, split, group] as [TreeNode] {
            node.lastAppliedLayoutPhysicalRect = nil
            node.lastAppliedLayoutVirtualRect = nil
        }
        for window in [a, b] {
            window.miniatureFrame = nil
            window.recordAuthoritativeActualRect(nil)
        }
        let snapshot = try XCTUnwrap(miniatureTabSnapshot(a, tray: false))
        XCTAssertEqual(snapshot.frame, expected)
        XCTAssertEqual(snapshot.activeIndex, 1)
        XCTAssertEqual([beside.hWeight, split.hWeight, group.vWeight], weights)
        XCTAssertNil(group.lastAppliedLayoutPhysicalRect)
        let nativeAfter = try await beside.getAxRect()
        XCTAssertEqual(nativeAfter, nativeBefore)
    }
    private func checkUnvisited(_ workspace: Workspace, group: TilingContainer, window: Window) async throws {
        try await workspace.layoutWorkspace()
        let expected = try XCTUnwrap(group.lastAppliedLayoutPhysicalRect?.cgRect)
        let children = group.children
        for node in group.parentsWithSelf {
            node.lastAppliedLayoutPhysicalRect = nil
            node.lastAppliedLayoutVirtualRect = nil
        }
        let snapshot = try XCTUnwrap(miniatureTabSnapshot(window, tray: false))
        XCTAssertEqual(snapshot.frame, expected)
        XCTAssertEqual(group.children, children)
        XCTAssertNil(group.lastAppliedLayoutPhysicalRect)
    }

    func testUnvisitedColumnGroupUsesTheColumnSlotFrame() async throws {
        let workspace = Workspace.get(byName: "1")
        workspace.columns = ColumnState(count: 3, widths: [0.28, 0.44, 0.28])
        let root = workspace.rootTilingContainer
        let left = TestWindow.new(id: 1, parent: root)
        left.columnSlot = 1
        let group = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tabGroup, index: INDEX_BIND_LAST)
        group.columnSlot = 2
        let a = TestWindow.new(id: 2, parent: group)
        _ = TestWindow.new(id: 3, parent: group)
        let right = TestWindow.new(id: 4, parent: root)
        right.columnSlot = 3
        try await checkUnvisited(workspace, group: group, window: a)
    }

    func testUnvisitedNestedTabGroupKeepsItsParentChromeInsets() async throws {
        let workspace = Workspace.get(byName: "1")
        let root = workspace.rootTilingContainer
        root.layout = .tabGroup
        _ = TestWindow.new(id: 1, parent: root)
        let group = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tabGroup, index: INDEX_BIND_LAST)
        _ = TestWindow.new(id: 2, parent: group)
        let active = TestWindow.new(id: 3, parent: group)
        active.markAsMostRecentChild()
        try await checkUnvisited(workspace, group: group, window: active)
    }

    func testUnvisitedLegacyGroupKeepsItsParentPadding() async throws {
        config.windowTabs.enabled = false
        config.tabGroupPadding = 12
        let workspace = Workspace.get(byName: "1")
        let root = workspace.rootTilingContainer
        root.layout = .tabGroup
        _ = TestWindow.new(id: 1, parent: root)
        let group = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tabGroup, index: INDEX_BIND_LAST)
        _ = TestWindow.new(id: 2, parent: group)
        let active = TestWindow.new(id: 3, parent: group)
        _ = TestWindow.new(id: 4, parent: root)
        active.markAsMostRecentChild()
        try await checkUnvisited(workspace, group: group, window: active)
    }

    func testUnvisitedFullscreenGroupUsesTheWholeWorkspace() async throws {
        let workspace = Workspace.get(byName: "1")
        let root = workspace.rootTilingContainer
        _ = TestWindow.new(id: 1, parent: root)
        let group = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tabGroup, index: INDEX_BIND_LAST)
        _ = TestWindow.new(id: 2, parent: group)
        let active = TestWindow.new(id: 3, parent: group)
        active.isFullscreen = true
        active.markAsMostRecentChild()
        try await checkUnvisited(workspace, group: group, window: active)
    }

}
