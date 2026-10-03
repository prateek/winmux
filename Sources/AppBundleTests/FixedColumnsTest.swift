@testable import AppBundle
import Common
import XCTest

@MainActor
final class FixedColumnsTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    private func workspace(_ count: Int = 3) -> Workspace {
        let workspace = Workspace.get(byName: "Columns")
        workspace.columns = ColumnState(count: count)
        config.enableNormalizationFlattenContainers = true
        config.enableNormalizationOppositeOrientationForNestedContainers = true
        return workspace
    }

    private func arrive(_ id: UInt32, _ workspace: Workspace) -> TestWindow {
        let binding = bindingDataForNewTilingWindow(workspace, window: nil)
        let window = TestWindow.new(id: id, parent: binding.parent)
        workspace.normalizeContainers()
        return window
    }

    func testOffDoesNotAssignSlotsOrChangeRoot() {
        let workspace = Workspace.get(byName: "Plain")
        let root = workspace.rootTilingContainer
        root.changeOrientation(.v)
        TestWindow.new(id: 1, parent: root)
        workspace.normalizeContainers()
        XCTAssertEqual(root.orientation, .v)
        XCTAssertNil(root.children.first?.columnSlot)
    }

    func testArrivalFillsSlotsThenJoinsFocusedColumn() {
        let workspace = workspace()
        let first = arrive(1, workspace)
        XCTAssertTrue(first.focusWindow())
        _ = arrive(2, workspace)
        _ = arrive(3, workspace)
        XCTAssertEqual(workspace.rootTilingContainer.children.compactMap(\.columnSlot), [1, 2, 3])
        _ = arrive(4, workspace)
        let root = workspace.rootTilingContainer
        XCTAssertEqual(root.children.count, 3)
        let group = root.children[0] as? TilingContainer
        XCTAssertEqual(group?.layout, .tabGroup)
        XCTAssertEqual(group?.allLeafWindowsRecursive.map(\.windowId).sorted(), [1, 4])
    }

    func testNearestEmptyTieGoesLeftAndFocusedEmptyReceivesArrival() {
        let workspace = workspace(5)
        workspace.columns?.focusedSlot = 3
        let first = arrive(1, workspace)
        XCTAssertEqual(first.columnSlot, 3)
        XCTAssertTrue(first.focusWindow())
        XCTAssertEqual(arrive(2, workspace).columnSlot, 2)
        workspace.columns?.focusedSlot = 5
        XCTAssertEqual(arrive(3, workspace).columnSlot, 5)
    }

    func testFocusElsewhereUsesMostRecentTilingColumn() {
        let workspace = workspace(2)
        let first = arrive(1, workspace)
        let second = arrive(2, workspace)
        first.markAsMostRecentChild()
        XCTAssertTrue(Workspace.get(byName: "Elsewhere").focusWorkspace())
        _ = arrive(3, workspace)
        XCTAssertEqual(first.parent as? TilingContainer, workspace.rootTilingContainer.children[0] as? TilingContainer)
        XCTAssertEqual(second.columnSlot, 2)
    }

    func testNormalizationPreservesSingleOccupiedColumnWithSeveralWindows() {
        let workspace = workspace()
        let root = workspace.rootTilingContainer
        let column = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tabGroup, index: 0)
        column.columnSlot = 2
        TestWindow.new(id: 1, parent: column)
        TestWindow.new(id: 2, parent: column)
        workspace.normalizeContainers()
        workspace.normalizeContainers()
        XCTAssertTrue(workspace.rootTilingContainer === root)
        XCTAssertEqual(root.orientation, .h)
        XCTAssertEqual(root.layout, .tiles)
        XCTAssertTrue(root.children.singleOrNil() === column)
        XCTAssertEqual(column.columnSlot, 2)
        XCTAssertEqual(column.children.count, 2)
    }

    func testFlattenTransfersSlotToRemainingWindow() {
        let workspace = workspace()
        let column = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: 1, .v, .tabGroup, index: 0)
        column.columnSlot = 3
        let window = TestWindow.new(id: 1, parent: column)
        workspace.normalizeContainers()
        XCTAssertEqual(window.columnSlot, 3)
        XCTAssertTrue(window.parent === workspace.rootTilingContainer)
    }

    func testInvariantFoldsUnindexedAndLoweredCountIdempotently() {
        let workspace = workspace()
        for id in UInt32(1)...5 { TestWindow.new(id: id, parent: workspace.rootTilingContainer) }
        workspace.normalizeContainers()
        XCTAssertEqual(workspace.rootTilingContainer.children.count, 3)
        XCTAssertEqual(workspace.rootTilingContainer.allLeafWindowsRecursive.count, 5)
        workspace.columns = ColumnState(count: 2)
        workspace.normalizeContainers()
        let before = workspace.rootTilingContainer.children
        workspace.normalizeContainers()
        XCTAssertEqual(workspace.rootTilingContainer.children, before)
        XCTAssertEqual(before.compactMap(\.columnSlot), [1, 2])
        XCTAssertEqual(workspace.rootTilingContainer.allLeafWindowsRecursive.count, 5)
    }

    func testInvariantUnwrapsOldRootFromNewRoot() {
        let workspace = workspace()
        let first = arrive(1, workspace)
        let second = arrive(2, workspace)
        let oldRoot = workspace.rootTilingContainer
        oldRoot.unbindFromParent()
        let wrapper = TilingContainer(parent: workspace, adaptiveWeight: 1, .v, .tiles, index: 0)
        oldRoot.bind(to: wrapper, adaptiveWeight: 1, index: 0)
        TestWindow.new(id: 3, parent: wrapper)
        workspace.normalizeContainers()
        XCTAssertEqual(workspace.rootTilingContainer.orientation, .h)
        XCTAssertEqual(workspace.rootTilingContainer.children.count, 3)
        XCTAssertEqual(first.columnSlot, 1)
        XCTAssertEqual(second.columnSlot, 2)
    }

    func testCloseLeavesGapAndMonitorChangePreservesFractions() async throws {
        let workspace = workspace()
        let first = arrive(1, workspace)
        let middle = arrive(2, workspace)
        let last = arrive(3, workspace)
        try await workspace.layoutWorkspace()
        let firstRect = first.lastAppliedLayoutVirtualRect
        let lastRect = last.lastAppliedLayoutVirtualRect
        middle.unbindFromParent()
        workspace.normalizeContainers()
        try await workspace.layoutWorkspace()
        XCTAssertEqual(first.lastAppliedLayoutVirtualRect, firstRect)
        XCTAssertEqual(last.lastAppliedLayoutVirtualRect, lastRect)
        XCTAssertEqual(last.columnSlot, 3)
        XCTAssertEqual(first.hWeight / workspace.rootTilingContainer.hWeight, 1.0 / 3, accuracy: 0.000001)
    }
    func testMoveAcrossColumnsAndStopsAtAllWorkspaceEdges() async throws {
        let workspace = workspace()
        let window = arrive(1, workspace)
        XCTAssertTrue(window.focusWindow())
        for direction in [CardinalDirection.up, .down, .left] {
            _ = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], direction)).run(.defaultEnv, .emptyStdin)
            workspace.normalizeContainers()
            XCTAssertEqual(workspace.columnSlot(containing: window), 1)
            XCTAssertEqual(workspace.rootTilingContainer.children.count, 1)
        }
        _ = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.defaultEnv, .emptyStdin)
        workspace.normalizeContainers()
        XCTAssertEqual(workspace.columnSlot(containing: window), 2)
        workspace.columns?.focusedSlot = 3
        let neighbour = arrive(2, workspace)
        XCTAssertTrue(window.focusWindow())
        _ = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.defaultEnv, .emptyStdin)
        workspace.normalizeContainers()
        XCTAssertEqual(workspace.columnSlot(containing: window), 3)
        XCTAssertTrue(window.parent === neighbour.parent)
        XCTAssertEqual((window.parent as? TilingContainer)?.layout, .tabGroup)
        _ = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.defaultEnv, .emptyStdin)
        workspace.normalizeContainers()
        XCTAssertEqual(workspace.rootTilingContainer.children.count, 1)
        XCTAssertEqual(workspace.columnSlot(containing: window), 3)
        _ = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin)
        workspace.normalizeContainers()
        XCTAssertEqual(workspace.columnSlot(containing: window), 2)
    }

    func testFocusSkipsEmptyColumnInBothDirections() async throws {
        let workspace = workspace()
        let first = arrive(1, workspace)
        workspace.columns?.focusedSlot = 3
        let last = arrive(2, workspace)
        XCTAssertTrue(first.focusWindow())
        _ = try await parseCommand("focus right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertTrue(focus.windowOrNil === last)
        _ = try await parseCommand("focus left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertTrue(focus.windowOrNil === first)
    }

    func testWorkspaceMoveSummonFlattenAndFloatingArrivalPreserveCount() async throws {
        let workspace = workspace(2)
        let first = arrive(1, workspace)
        _ = arrive(2, workspace)
        let source = Workspace.get(byName: "Source")
        let moved = TestWindow.new(id: 3, parent: source.rootTilingContainer)
        XCTAssertTrue(moved.focusWindow())
        _ = try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "Columns")).run(.defaultEnv, .emptyStdin)
        workspace.normalizeContainers()
        XCTAssertEqual(workspace.rootTilingContainer.children.count, 2)
        let summoned = TestWindow.new(id: 4, parent: source.rootTilingContainer)
        XCTAssertTrue(first.focusWindow())
        _ = try await parseCommand("summon --window-id 4").cmdOrDie.run(.defaultEnv, .emptyStdin)
        workspace.normalizeContainers()
        XCTAssertTrue(summoned.nodeWorkspace === workspace)
        XCTAssertEqual(workspace.rootTilingContainer.children.count, 2)
        _ = try await parseCommand("flatten-workspace-tree").cmdOrDie.run(.defaultEnv, .emptyStdin)
        workspace.normalizeContainers()
        XCTAssertEqual(workspace.rootTilingContainer.children.count, 2)
        XCTAssertEqual(workspace.rootTilingContainer.allLeafWindowsRecursive.count, 4)
        let floating = TestWindow.new(id: 5, parent: workspace)
        try await floating.relayoutWindow(on: workspace, forceTile: true)
        workspace.normalizeContainers()
        XCTAssertEqual(workspace.rootTilingContainer.children.count, 2)
        XCTAssertEqual(workspace.rootTilingContainer.allLeafWindowsRecursive.count, 5)
    }

    func testWorkspaceSiblingInsertionRootWrappingKeepsSlots() {
        let workspace = workspace()
        let first = arrive(1, workspace)
        _ = arrive(2, workspace)
        let wrapper = workspaceSiblingInsertionRoot(workspace, orientation: .v)
        TestWindow.new(id: 3, parent: wrapper)
        workspace.normalizeContainers()
        XCTAssertEqual(workspace.rootTilingContainer.children.compactMap(\.columnSlot), [1, 2, 3])
        XCTAssertEqual(first.columnSlot, 1)
    }

    func testClosedWindowCacheRestoresSparseSlots() async throws {
        let workspace = workspace()
        workspace.columns?.focusedSlot = 3
        let window = arrive(1, workspace)
        syncClosedWindowsCacheToCurrentWorld()
        window.bind(to: Workspace.get(byName: "Elsewhere").rootTilingContainer, adaptiveWeight: 1, index: 0)
        workspace.columns?.focusedSlot = nil
        let restored = try await restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: window)
        XCTAssertTrue(restored)
        workspace.normalizeContainers()
        XCTAssertEqual(window.columnSlot, 3)
        XCTAssertEqual(workspace.rootTilingContainer.children.count, 1)
    }

    func testSparseSlotGeometryAndGapsAcrossMonitorChange() async throws {
        let workspace = workspace()
        workspace.columns = ColumnState(count: 3, widths: [0.2, 0.3, 0.5])
        workspace.columns?.focusedSlot = 3
        let window = arrive(1, workspace)
        config.gaps.inner.horizontal = .constant(20)
        for width in [CGFloat(1000), 2000] {
            let rect = Rect(topLeftX: 0, topLeftY: 0, width: width, height: 800)
            let monitor = TestMonitor(monitorAppKitNsScreenScreensId: 1, name: "Demo", rect: rect, visibleRect: rect, isMain: true)
            setMonitorsForTests([monitor])
            _ = monitor.setActiveWorkspace(workspace)
            try await workspace.layoutWorkspace()
            let available = monitor.visibleRectPaddedByOuterGaps
            XCTAssertEqual(window.lastAppliedLayoutVirtualRect?.width ?? 0, available.width * 0.5, accuracy: 0.000001)
            XCTAssertEqual(window.lastAppliedLayoutVirtualRect?.topLeftX ?? 0, available.topLeftX + available.width * 0.5, accuracy: 0.000001)
            XCTAssertEqual(window.lastAppliedLayoutPhysicalRect?.width ?? 0, available.width * 0.5 - 10, accuracy: 0.000001)
        }
    }

    func testDragTabGroupKeepsDestinationSlotAndCount() {
        let workspace = workspace()
        let source = arrive(1, workspace)
        workspace.columns?.focusedSlot = 3
        let target = arrive(2, workspace)
        workspace.columns?.focusedSlot = nil
        createOrAppendWindowTabStack(sourceWindow: source, onto: target)
        workspace.normalizeContainers()
        XCTAssertEqual(workspace.columnSlot(containing: source), 3)
        XCTAssertEqual(workspace.columnSlot(containing: target), 3)
        XCTAssertEqual(workspace.rootTilingContainer.children.count, 1)
    }

    func testInvariantForcesHorizontalTilesAndPreservesColumnOrientation() {
        let workspace = workspace()
        let root = workspace.rootTilingContainer
        root.changeOrientation(.v)
        root.layout = .tabGroup
        let column = TilingContainer(parent: root, adaptiveWeight: 1, .h, .tiles, index: 0)
        column.columnSlot = 2
        TestWindow.new(id: 1, parent: column)
        TestWindow.new(id: 2, parent: column)
        workspace.normalizeContainers()
        XCTAssertEqual(root.orientation, .h)
        XCTAssertEqual(root.layout, .tiles)
        XCTAssertEqual(column.orientation, .h)
        XCTAssertEqual(column.columnSlot, 2)
    }

    func testMoveInsideVerticalSplitAndStopAtColumnTopAndBottom() async throws {
        let workspace = workspace()
        let column = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: 1, .v, .tiles, index: 0)
        column.columnSlot = 2
        let first = TestWindow.new(id: 1, parent: column)
        let second = TestWindow.new(id: 2, parent: column)
        workspace.normalizeContainers()
        XCTAssertTrue(first.focusWindow())
        _ = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .down)).run(.defaultEnv, .emptyStdin)
        workspace.normalizeContainers()
        XCTAssertEqual(column.children, [second, first])
        _ = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .down)).run(.defaultEnv, .emptyStdin)
        workspace.normalizeContainers()
        XCTAssertEqual(column.children, [second, first])
        _ = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .up)).run(.defaultEnv, .emptyStdin)
        workspace.normalizeContainers()
        XCTAssertEqual(column.children, [first, second])
        _ = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .up)).run(.defaultEnv, .emptyStdin)
        workspace.normalizeContainers()
        XCTAssertEqual(column.children, [first, second])
        XCTAssertEqual(workspace.rootTilingContainer.children.count, 1)
        XCTAssertEqual(column.columnSlot, 2)
    }

    func testColumnsIgnoreAutomaticTabInsertionWhileAnEmptySlotExists() {
        let workspace = workspace()
        config.autoAddNewWindowsToTabGroup = true
        let column = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: 1, .v, .tabGroup, index: 0)
        column.columnSlot = 2
        let focused = TestWindow.new(id: 1, parent: column)
        TestWindow.new(id: 2, parent: column)
        XCTAssertTrue(focused.focusWindow())
        workspace.normalizeContainers()
        let arrival = arrive(3, workspace)
        XCTAssertEqual(arrival.columnSlot, 1)
        XCTAssertTrue(arrival.parent === workspace.rootTilingContainer)
        XCTAssertEqual(column.children.count, 2)
    }

    func testJoinWithKeepsDestinationSlotAndCreatesSplitWithinColumn() async throws {
        let workspace = workspace()
        let first = arrive(1, workspace)
        workspace.columns?.focusedSlot = 3
        let last = arrive(2, workspace)
        workspace.columns?.focusedSlot = nil
        XCTAssertTrue(first.focusWindow())
        _ = try await parseCommand("join-with right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        workspace.normalizeContainers()
        XCTAssertEqual(workspace.columnSlot(containing: first), 3)
        XCTAssertEqual(workspace.columnSlot(containing: last), 3)
        XCTAssertEqual((first.parent as? TilingContainer)?.layout, .tiles)
        XCTAssertEqual(workspace.rootTilingContainer.children.count, 1)
    }

}
