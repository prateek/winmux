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

    func testSwapCommandAndDragExchangeSlots() async throws {
        let ws = workspace()
        let a = arrive(1, ws)
        let b = arrive(2, ws)
        _ = arrive(3, ws)
        XCTAssertTrue(a.focusWindow())
        _ = try await parseCommand("swap right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        ws.normalizeContainers()
        XCTAssertEqual(a.columnSlot, 2)
        XCTAssertEqual(b.columnSlot, 1)
        swapNodes(a, b)
        ws.normalizeContainers()
        XCTAssertEqual(a.columnSlot, 1)
        XCTAssertEqual(b.columnSlot, 2)
    }

    func testNormalizationLeavesAllMruLevelsUntouched() {
        let ws = workspace()
        let a = arrive(1, ws)
        _ = arrive(2, ws)
        let c = arrive(3, ws)
        a.markAsMostRecentChild()
        c.markAsMostRecentChild()
        let floating = TestWindow.new(id: 4, parent: ws)
        XCTAssertTrue(floating.focusWindow())
        let rootMru = ws.rootTilingContainer.childrenByMostRecentUse
        let workspaceMru = ws.childrenByMostRecentUse
        ws.normalizeContainers()
        XCTAssertEqual(ws.rootTilingContainer.childrenByMostRecentUse, rootMru)
        XCTAssertEqual(ws.childrenByMostRecentUse, workspaceMru)
        XCTAssertTrue(Workspace.get(byName: "Elsewhere").focusWorkspace())
        XCTAssertTrue(ws.focusWorkspace())
        XCTAssertTrue(focus.windowOrNil === floating)
    }

    func testOverflowPreservesVerticalSplitAndFoldingFlattensTabGroups() {
        let ws = workspace(2)
        let column = TilingContainer(parent: ws.rootTilingContainer, adaptiveWeight: 1, .v, .tiles, index: 0)
        column.columnSlot = 1
        let a = TestWindow.new(id: 1, parent: column)
        TestWindow.new(id: 2, parent: column)
        _ = arrive(3, ws)
        XCTAssertTrue(a.focusWindow())
        _ = arrive(4, ws)
        ws.normalizeContainers()
        XCTAssertEqual(column.orientation, .v)
        ws.columns = ColumnState(count: 1)
        ws.normalizeContainers()
        XCTAssertFalse(ws.rootTilingContainer.allLeafWindowsRecursive.contains {
            ($0.parent as? TilingContainer)?.parent is TilingContainer &&
            ($0.parent as? TilingContainer)?.layout == .tabGroup &&
            (($0.parent as? TilingContainer)?.parent as? TilingContainer)?.layout == .tabGroup
        })
    }

    func testMoveFromTabGroupMovesOnlyFocusedWindowAndHonorsFail() async throws {
        let ws = workspace(2)
        let a = arrive(1, ws)
        _ = arrive(2, ws)
        XCTAssertTrue(a.focusWindow())
        let extra = arrive(3, ws)
        _ = try await parseCommand("move right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        ws.normalizeContainers()
        XCTAssertEqual(ws.columnSlot(containing: a), 2)
        XCTAssertEqual(ws.columnSlot(containing: extra), 1)
        let result = try await parseCommand("move --boundaries-action fail right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 1)
    }

    func testOptimisticLayoutRepairsInvalidAndMissingSlots() async throws {
        let ws = workspace(2)
        let a = TestWindow.new(id: 1, parent: ws.rootTilingContainer)
        a.columnSlot = 7
        let b = TestWindow.new(id: 2, parent: ws.rootTilingContainer)
        try await ws.layoutWorkspace()
        XCTAssertNotNil(a.lastAppliedLayoutVirtualRect)
        XCTAssertNotNil(b.lastAppliedLayoutVirtualRect)
        XCTAssertEqual(ws.rootTilingContainer.children.compactMap(\.columnSlot), [1, 2])
    }

    func testDragSplitAndAgentReplacementKeepSparseDestinationSlot() {
        for agent in [false, true] {
            setUpWorkspacesForTests()
            let ws = workspace(4)
            _ = arrive(1, ws)
            ws.columns?.focusedSlot = 3
            let target = arrive(2, ws)
            let source = TestWindow.new(id: 3, parent: Workspace.get(byName: "Source").rootTilingContainer)
            if agent {
                placeAgentPane(source, relation: .below, target: target)
            } else {
                XCTAssertTrue(applyWindowStackSplitDragIntent(sourceWindow: source, sourceSubject: .window,
                    targetWindow: target, position: .below))
            }
            ws.normalizeContainers()
            XCTAssertEqual(ws.columnSlot(containing: target), 3)
            XCTAssertEqual(ws.columnSlot(containing: source), 3)
            XCTAssertEqual(ws.rootTilingContainer.children.compactMap(\.columnSlot), [1, 3])
        }
    }

    func testRealFocusReplacesEmptyAnchorAndInvalidAnchorIsClamped() {
        let ws = workspace(4)
        let a = arrive(1, ws)
        ws.columns?.focusedSlot = 3
        let b = arrive(2, ws)
        XCTAssertTrue(a.focusWindow())
        XCTAssertEqual(ws.columns?.focusedSlot, 1)
        XCTAssertTrue(b.focusWindow())
        XCTAssertEqual(ws.columns?.focusedSlot, 3)
        ws.columns?.focusedSlot = 900
        XCTAssertTrue((1...4).contains(ws.columnPlacementSlot()))
    }

    func testSwapInsideColumnKeepsItsSlot() async throws {
        let ws = workspace()
        let split = TilingContainer(parent: ws.rootTilingContainer, adaptiveWeight: 1, .v, .tiles, index: 0)
        split.columnSlot = 3
        let a = TestWindow.new(id: 1, parent: split)
        let b = TestWindow.new(id: 2, parent: split)
        XCTAssertTrue(a.focusWindow())
        _ = try await parseCommand("swap down").cmdOrDie.run(.defaultEnv, .emptyStdin)
        ws.normalizeContainers()
        XCTAssertEqual(split.children, [b, a])
        swapNodes(a, b)
        ws.normalizeContainers()
        XCTAssertEqual(split.children, [a, b])
        XCTAssertEqual(split.columnSlot, 3)
    }

    func testClosingFocusedColumnUsesMruAndOverflowUsesMruAfterRefresh() {
        let ws = workspace()
        let a = arrive(1, ws)
        let b = arrive(2, ws)
        let c = arrive(3, ws)
        XCTAssertTrue(b.focusWindow())
        XCTAssertTrue(a.focusWindow())
        ws.normalizeContainers()
        a.unbindFromParent()
        ws.normalizeContainers()
        XCTAssertTrue(ws.rootTilingContainer.mostRecentWindowRecursive === b)
        ws.columns?.focusedSlot = 1
        _ = arrive(4, ws)
        b.markAsMostRecentChild()
        XCTAssertTrue(Workspace.get(byName: "Elsewhere").focusWorkspace())
        ws.columns?.focusedSlot = nil
        ws.normalizeContainers()
        let extra = arrive(5, ws)
        XCTAssertTrue(extra.parent === b.parent)
        XCTAssertEqual(c.columnSlot, 3)
    }

    func testAllColumnEdgesHonorBoundaryActions() async throws {
        let ws = workspace()
        let a = arrive(1, ws)
        XCTAssertTrue(a.focusWindow())
        for direction in ["left", "up", "down"] {
            for boundary in ["workspace", "all-monitors-outer-frame"] {
                for action in ["fail", "stop", "create-implicit-container"] {
                    let result = try await parseCommand("move --boundaries \(boundary) --boundaries-action \(action) \(direction)").cmdOrDie.run(.defaultEnv, .emptyStdin)
                    XCTAssertEqual(result.exitCode, action == "fail" ? 1 : 0)
                    ws.normalizeContainers()
                    XCTAssertEqual(a.columnSlot, 1)
                    XCTAssertEqual(ws.rootTilingContainer.orientation, .h)
                }
            }
        }
    }

    func testWidthPresetsProportionsSteppingAndFloor() {
        let columns = ColumnState(count: 3, widths: [0.2, 0.3, 0.5])
        columns.setWidth(slot: 1, fraction: 0.5, availableWidth: 1000)
        XCTAssertEqual(columns.widths[0], 0.5, accuracy: 0.000001)
        XCTAssertEqual(columns.widths[1] / columns.widths[2], 0.6, accuracy: 0.000001)
        XCTAssertEqual(columns.widths.reduce(0, +), 1, accuracy: 0.000001)
        columns.stepWidth(slot: 1, forward: true, presets: [1/3, 1/2, 2/3], availableWidth: 1000)
        XCTAssertEqual(columns.widths[0], 2/3, accuracy: 0.000001)
        columns.stepWidth(slot: 1, forward: true, presets: [1/3, 1/2, 2/3], availableWidth: 1000)
        XCTAssertEqual(columns.widths[0], 1/3, accuracy: 0.000001)
        columns.stepWidth(slot: 1, forward: false, presets: [1/3, 1/2, 2/3], availableWidth: 1000)
        XCTAssertEqual(columns.widths[0], 2/3, accuracy: 0.000001)
        columns.setWidth(slot: 1, fraction: 0, availableWidth: 1000)
        XCTAssertEqual(columns.widths[0] * 1000, minimumTiledResizeWeight, accuracy: 0.000001)
        columns.setWidth(slot: 1, fraction: 1, availableWidth: 1000)
        XCTAssertGreaterThanOrEqual(columns.widths[1] * 1000 + 0.000001, minimumTiledResizeWeight)
        XCTAssertGreaterThanOrEqual(columns.widths[2] * 1000 + 0.000001, minimumTiledResizeWeight)
    }

    func testResizeRepairsWidthsWhoseProportionsCannotFitTheFloor() {
        let columns = ColumnState(count: 3, widths: [0.01, 0.01, 0.98])
        columns.setWidth(slot: 1, fraction: 0.5, availableWidth: 1000)
        XCTAssertEqual(columns.widths.reduce(0, +), 1, accuracy: 0.000001)
        for width in columns.widths {
            XCTAssertGreaterThanOrEqual(width * 1000, minimumTiledResizeWeight)
        }
    }

    func testResizeColumnSplitAndBalanceDeclaredWidths() async throws {
        let ws = workspace()
        ws.columns = ColumnState(count: 3, widths: [0.2, 0.3, 0.5])
        let a = arrive(1, ws)
        _ = arrive(2, ws)
        try await ws.layoutWorkspace()
        XCTAssertTrue(a.focusWindow())
        _ = try await parseCommand("resize width 80").cmdOrDie.run(.defaultEnv, .emptyStdin)
        try await ws.layoutWorkspace()
        XCTAssertEqual(a.hWeight, 80, accuracy: 0.000001)
        _ = try await parseCommand("balance-sizes").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(ws.columns?.widths, ws.columns?.declaredWidths)
        let binding = a.unbindFromParent()
        let split = TilingContainer(replacing: binding, .v, .tiles)
        a.bind(to: split, adaptiveWeight: 200, index: 0)
        TestWindow.new(id: 3, parent: split, adaptiveWeight: 200)
        XCTAssertTrue(a.focusWindow())
        let before = ws.columns?.widths
        _ = try await parseCommand("resize height +20").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(ws.columns?.widths, before)
        XCTAssertEqual(a.vWeight, 220)
        let widthResult = try await parseCommand("resize width +40").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(widthResult.exitCode, 1)
        XCTAssertEqual(ws.columns?.widths, before)
    }

    func testDividerResizeProposalPreservesSparseSlotsAndAppliesFractions() async throws {
        let ws = workspace()
        let a = arrive(1, ws)
        ws.columns?.focusedSlot = 3
        let c = arrive(2, ws)
        try await ws.layoutWorkspace()
        let rect = a.lastAppliedLayoutPhysicalRect!
        let changed = Rect(topLeftX: rect.minX, topLeftY: rect.minY, width: rect.width + 100, height: rect.height)
        let before = ws.columns!.widths
        let proposal = proposedResizeWeightMap(a, rect: changed)!
        XCTAssertNotNil(proposal.columnWidths)
        XCTAssertEqual(ws.columns!.widths, before)
        applyResizeWithMouse(a, rect: changed)
        XCTAssertGreaterThan(ws.columns!.widths[0], before[0])
        XCTAssertEqual(ws.columns!.widths.reduce(0, +), 1, accuracy: 0.000001)
        XCTAssertEqual(c.columnSlot, 3)
    }

    func testFocusedEmptyOutlineGeometryAndRemoval() {
        let ws = workspace()
        let a = arrive(1, ws)
        XCTAssertTrue(a.focusWindow())
        ws.columns?.focusedSlot = 3
        let frame = ws.workspaceMonitor.visibleRectPaddedByOuterGaps
        XCTAssertEqual(ws.focusedEmptyColumnRect?.minX ?? 0, frame.minX + frame.width * 2/3, accuracy: 0.000001)
        let b = arrive(2, ws)
        XCTAssertNil(ws.focusedEmptyColumnRect)
        b.unbindFromParent()
        ws.columns?.focusedSlot = 3
        XCTAssertNotNil(ws.focusedEmptyColumnRect)
        XCTAssertTrue(Workspace.get(byName: "Elsewhere").focusWorkspace())
        XCTAssertNil(ws.focusedEmptyColumnRect)
        XCTAssertTrue(ws.focusWorkspace())
        ws.columns?.focusedSlot = 3
        ws.columns = nil
        XCTAssertNil(ws.focusedEmptyColumnRect)
    }

    func testLeavingNativeMinimizedAndFullscreenPreservesCount() async throws {
        for fullscreen in [false, true] {
            setUpWorkspacesForTests()
            let ws = workspace(2)
            let a = arrive(1, ws)
            _ = arrive(2, ws)
            _ = arrive(3, ws)
            XCTAssertTrue(a.focusWindow())
            if fullscreen { a.nativeIsMacosFullscreen = true } else { a.nativeIsMacosMinimized = true }
            try await normalizeLayoutReason()
            ws.normalizeContainers()
            if fullscreen { a.nativeIsMacosFullscreen = false } else { a.nativeIsMacosMinimized = false }
            try await normalizeLayoutReason()
            ws.normalizeContainers()
            XCTAssertTrue(a.nodeWorkspace === ws)
            XCTAssertEqual(ws.rootTilingContainer.allLeafWindowsRecursive.count, 3)
            XCTAssertLessThanOrEqual(ws.rootTilingContainer.children.count, 2)
        }
    }

    func testPendingDragDropDispatchPreservesCountAndSparseSlot() async throws {
        let ws = workspace(4)
        _ = arrive(1, ws)
        ws.columns?.focusedSlot = 3
        let target = arrive(2, ws)
        let source = TestWindow.new(id: 3, parent: Workspace.get(byName: "Source").rootTilingContainer)
        config.windowTabs.enabled = true
        let point = MousePointerTracker.shared.currentSample.point
        let rect = Rect(topLeftX: point.x - 10, topLeftY: point.y - 10, width: 100, height: 100)
        pendingWindowDragIntent = PendingWindowDragIntent(sourceWindowId: source.windowId, sourceSubject: .window,
            kind: .stackSplit(targetWindowId: target.windowId, position: .below), previewRect: rect,
            interactionRect: rect, title: "Place below", subtitle: "", previewStyle: .stackSplit,
            previewGeometry: .splitBelow, isGroup: false, isPointerSettled: true)
        XCTAssertTrue(applyPendingWindowDragIntentIfPossible())
        XCTAssertNil(pendingWindowDragIntent)
        ws.normalizeContainers()
        XCTAssertEqual(ws.rootTilingContainer.children.compactMap(\.columnSlot), [1, 3])
        XCTAssertEqual(ws.columnSlot(containing: source), 3)
    }

    func testShakeRetileRestoresSparseSlot() {
        let ws = workspace(4)
        _ = arrive(1, ws)
        ws.columns?.focusedSlot = 3
        let a = arrive(2, ws)
        WindowMouseInteractionDriver.shared.toggleFloatingForShake(a)
        ws.normalizeContainers()
        XCTAssertTrue(a.isFloating)
        XCTAssertTrue(ws.rootTilingContainer.children[0].mostRecentWindowRecursive!.focusWindow())
        WindowMouseInteractionDriver.shared.toggleFloatingForShake(a)
        ws.normalizeContainers()
        XCTAssertEqual(a.columnSlot, 3)
    }

    func testColumnBoundaryCanMoveToNextMonitor() async throws {
        let ws = workspace()
        ws.columns?.focusedSlot = 3
        let a = arrive(1, ws)
        let target = Workspace.get(byName: "OtherMonitor")
        let firstRect = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800)
        let secondRect = Rect(topLeftX: 1000, topLeftY: 0, width: 1000, height: 800)
        let first = TestMonitor(monitorAppKitNsScreenScreensId: 1, name: "First", rect: firstRect, visibleRect: firstRect, isMain: true)
        let second = TestMonitor(monitorAppKitNsScreenScreensId: 2, name: "Second", rect: secondRect, visibleRect: secondRect, isMain: false)
        setMonitorsForTests([first, second])
        _ = first.setActiveWorkspace(ws)
        _ = second.setActiveWorkspace(target)
        XCTAssertTrue(a.focusWindow())
        let result = try await parseCommand("move --boundaries all-monitors-outer-frame --boundaries-action fail right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(a.nodeWorkspace === target)
    }

    func testExplicitDividerSessionPreviewsWithoutMutationAndCommitsProportions() async throws {
        let ws = workspace()
        ws.columns = ColumnState(count: 3, widths: [0.2, 0.3, 0.5])
        _ = arrive(1, ws)
        ws.columns?.focusedSlot = 3
        _ = arrive(2, ws)
        try await ws.layoutWorkspace()
        let session = ColumnDividerResizeSession(workspace: ws, slot: 1, startX: 100)
        let width = ws.workspaceMonitor.visibleRectPaddedByOuterGaps.width
        let proposal = session.proposal(pointerX: 200)
        XCTAssertEqual(ws.columns!.widths, [0.2, 0.3, 0.5])
        XCTAssertEqual(proposal.columnWidths![0], 0.2 + 100 / width, accuracy: 0.000001)
        XCTAssertEqual(proposal.columnWidths![1] / proposal.columnWidths![2], 0.6, accuracy: 0.000001)
        session.commit(pointerX: 200)
        XCTAssertEqual(ws.columns!.widths, proposal.columnWidths!)
        XCTAssertEqual(ws.rootTilingContainer.children.compactMap(\.columnSlot), [1, 3])
    }

    func testLoweredCountMergesTabGroupsAsOrderedWindows() {
        let ws = workspace()
        let root = ws.rootTilingContainer
        let a = TestWindow.new(id: 1, parent: root)
        a.columnSlot = 1
        for slot in [2, 3] {
            let group = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tabGroup, index: INDEX_BIND_LAST)
            group.columnSlot = slot
            TestWindow.new(id: UInt32(slot * 2 - 2), parent: group)
            TestWindow.new(id: UInt32(slot * 2 - 1), parent: group)
        }
        ws.columns = ColumnState(count: 1)
        ws.normalizeContainers()
        let group = root.children.singleOrNil() as? TilingContainer
        XCTAssertEqual(group?.layout, .tabGroup)
        XCTAssertTrue(group?.children.allSatisfy { $0 is Window } == true)
        XCTAssertEqual(group?.children.compactMap { ($0 as? Window)?.windowId }, [1, 2, 3, 4, 5])
    }

    func testExplicitWindowMoveNormalizesArrivalAndDoesNotMoveAnotherTab() async throws {
        let ws = workspace(2)
        let a = arrive(1, ws)
        let b = arrive(2, ws)
        XCTAssertTrue(a.focusWindow())
        let extra = arrive(3, ws)
        XCTAssertTrue(extra.focusWindow())
        XCTAssertTrue(b.focusWindow())
        extra.markAsMostRecentChild()
        let result = try await parseCommand("move --window-id 1 right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        ws.normalizeContainers()
        XCTAssertEqual(ws.columnSlot(containing: a), 2)
        XCTAssertEqual(ws.columnSlot(containing: extra), 1)
        let raw = TestWindow.new(id: 4, parent: ws.rootTilingContainer)
        let normalized = try await parseCommand("move --window-id 4 --boundaries-action fail right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertNotNil(ws.columnSlot(containing: raw))
        XCTAssertEqual(normalized.exitCode, 1)
    }

    func testHorizontalDragAndAgentSplitStayInsideSparseColumn() {
        for agent in [false, true] {
            setUpWorkspacesForTests()
            let ws = workspace(4)
            _ = arrive(1, ws)
            ws.columns?.focusedSlot = 3
            let target = arrive(2, ws)
            let source = TestWindow.new(id: 3, parent: Workspace.get(byName: "Source").rootTilingContainer)
            if agent {
                placeAgentPane(source, relation: .rightOf, target: target)
            } else {
                XCTAssertTrue(applyWindowStackSplitDragIntent(sourceWindow: source, sourceSubject: .window,
                    targetWindow: target, position: .right))
            }
            ws.normalizeContainers()
            XCTAssertEqual(ws.columnSlot(containing: target), 3)
            XCTAssertEqual(ws.columnSlot(containing: source), 3)
            XCTAssertEqual(ws.rootTilingContainer.children.compactMap(\.columnSlot), [1, 3])
        }
    }

    func testRecoveringWrappedRootPreservesColumnMru() {
        let ws = workspace()
        let a = arrive(1, ws)
        let b = arrive(2, ws)
        let c = arrive(3, ws)
        c.markAsMostRecentChild()
        a.markAsMostRecentChild()
        let oldRoot = ws.rootTilingContainer
        let expected = oldRoot.childrenByMostRecentUse
        oldRoot.unbindFromParent()
        let newRoot = TilingContainer(parent: ws, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
        oldRoot.bind(to: newRoot, adaptiveWeight: WEIGHT_AUTO, index: 0)
        ws.enforceColumnInvariant()
        XCTAssertEqual(newRoot.childrenByMostRecentUse, expected)
        XCTAssertEqual(newRoot.children, [a, b, c])
    }

    func testMovingFocusedWindowUpdatesAnchorWhileDirectEmptyFocusSurvivesRefresh() async throws {
        let ws = workspace()
        let a = arrive(1, ws)
        XCTAssertTrue(a.focusWindow())
        ws.columns?.focusedSlot = 3
        ws.enforceColumnInvariant()
        XCTAssertEqual(ws.columns?.focusedSlot, 3)
        let result = try await parseCommand("move right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        ws.normalizeContainers()
        XCTAssertEqual(ws.columnSlot(containing: a), 2)
        XCTAssertEqual(ws.columns?.focusedSlot, 2)
        XCTAssertNil(ws.focusedEmptyColumnRect)
        XCTAssertEqual(arrive(2, ws).columnSlot, 1)
    }

}
