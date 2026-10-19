import AppKit
@testable import AppBundle
import XCTest

final class WorkspaceSidebarTreeTest: XCTestCase {
    @MainActor
    func testSidebarMonitorPreviewKeepsItsExistingActiveWorkspaceDestination() {
        setUpWorkspacesForTests()
        let monitor = WorkspaceSidebarDragTestMonitor(monitorAppKitNsScreenScreensId: 1, name: "Test", rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080), visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080), isMain: true)
        setMonitorsForTests([monitor])
        defer { setMonitorsForTests(nil); clearWorkspaceSidebarDropPreview() }
        let destination = Workspace.get(byName: "2")
        XCTAssertTrue(monitor.setActiveWorkspace(destination))
        let window = TestWindow.new(id: 796, parent: Workspace.get(byName: "1").rootTilingContainer)
        previewWorkspaceSidebarDrop(window.windowId, subject: .window, target: .monitor(workspaceSidebarMonitorScopeId(for: monitor)))
        XCTAssertEqual(TrayMenuModel.shared.workspaceSidebarDropPreview?.targetWorkspaceName, "2")
    }
    @MainActor
    func testHiddenEmptyColumnsKeepTheExistingOtherDisplayEmptySectionHeight() {
        let workspace = WorkspaceSidebarWorkspaceViewModel(name: "2", projectId: workspaceProjectDefaultId, displayName: "2", sidebarLabel: "", isGeneratedName: false, monitorScopeId: "", monitorName: nil, isFocused: false, isVisible: true, items: [.init(kind: .column(workspace: "2", slot: 1, fraction: 1))])
        let section = WorkspaceSidebarWorkspaceSection(
            workspace: workspace, dragPreview: nil, expansionProgress: 1, layout: .empty,
            emitsDropTarget: false, isFromOtherDisplay: true, isInUseOnOtherDisplay: true,
            isOnFocusedMonitor: false, allowsWorkspaceActivation: true, isPinnedActiveWorkspace: false,
            isActiveOnTargetMonitor: false, projectContextLabel: nil, projectContextColor: nil,
            renamingWorkspaceName: .constant(nil), renamingWorkspaceText: .constant(""),
            onBeginRenameWorkspace: {}, onCommitRenameWorkspace: {}, onCancelRenameWorkspace: {},
            selectedSearchTarget: nil, isSearchFiltering: false,
            activeInUseOverrideWorkspaceName: .constant(nil), actions: .init()
        )
        XCTAssertEqual(section.sectionMinHeight, workspaceSidebarInUseOverrideEmptySectionMinHeight)
    }
    @MainActor
    func testOnScreenFeedbackStillClearsPreviewWithoutSidebarSource() {
        setUpWorkspacesForTests()
        let window = TestWindow.new(id: 797, parent: Workspace.get(byName: "1").rootTilingContainer)
        clearActiveWorkspaceSidebarDrag()
        previewWorkspaceSidebarDrop(window.windowId, subject: .window, target: .tree(.window(window.windowId, after: false)))
        XCTAssertNotNil(TrayMenuModel.shared.workspaceSidebarDropPreview)
        updateSidebarDragFeedback(sourceWindow: window, subject: .window, destination: nil)
        XCTAssertNil(TrayMenuModel.shared.workspaceSidebarDropPreview)
    }

    @MainActor
    func testNativeFeedbackDoesNotClearTheActiveTreePreview() {
        setUpWorkspacesForTests()
        let window = TestWindow.new(id: 798, parent: Workspace.get(byName: "1").rootTilingContainer)
        beginActiveWorkspaceSidebarDrag(windowId: window.windowId, subject: .window)
        defer { clearActiveWorkspaceSidebarDrag(); clearWorkspaceSidebarDropPreview() }
        previewWorkspaceSidebarDrop(window.windowId, subject: .window, target: .tree(.window(window.windowId, after: false)))
        let preview = TrayMenuModel.shared.workspaceSidebarDropPreview
        XCTAssertNotNil(preview?.refusalReason)
        updateSidebarDragFeedback(sourceWindow: window, subject: .window, destination: nil)
        XCTAssertEqual(TrayMenuModel.shared.workspaceSidebarDropPreview, preview)
    }
    @MainActor
    func testStructuralHeadingDragsPublishRefusalWithoutMovingWindows() {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        let window = TestWindow.new(id: 799, parent: workspace.rootTilingContainer)
        let targets: [WorkspaceSidebarTreeDropTarget?] = [nil, .column("1", slot: 1)]
        for target in targets {
            handleWorkspaceSidebarAction(.refuseStructuralDrag("1", target: target))
            XCTAssertEqual(TrayMenuModel.shared.workspaceSidebarDropPreview?.refusalReason, "Workspaces and Columns are not windows")
            XCTAssertEqual(TrayMenuModel.shared.workspaceSidebarDropPreview?.treeTarget, target)
            XCTAssertTrue(window.parent === workspace.rootTilingContainer)
        }
        handleWorkspaceSidebarAction(.clearDropPreview)
        XCTAssertNil(TrayMenuModel.shared.workspaceSidebarDropPreview)
    }
    @MainActor
    private func checkDrop(_ source: TreeNode, _ target: WorkspaceSidebarTreeDropTarget, accepted: Bool = true, file: StaticString = #filePath, line: UInt = #line) async throws {
        let result = try await applyWorkspaceSidebarTreeDrop(source: source, target: target)
        XCTAssertEqual(result, accepted, file: file, line: line)
    }
    @MainActor
    func testTreeSameWorkspaceTargetIsAcceptedButScreenDragGuardIsUnchanged() {
        XCTAssertTrue(workspaceSidebarTreeAcceptsTarget(sourceWorkspaceName: "2", target: .workspace("2")))
        XCTAssertFalse(isActionableSidebarWorkspaceDropTarget(sourceWorkspaceName: "2", targetKind: .workspace("2")))
    }

    @MainActor
    func testSiblingInsertAcrossParentsAndWorkspaces() {
        for crossWorkspace in [false, true] {
            for after in [false, true] {
                setUpWorkspacesForTests()
                let sourceWorkspace = Workspace.get(byName: "1")
                let targetWorkspace = Workspace.get(byName: crossWorkspace ? "2" : "1")
                let sourceParent = TilingContainer(parent: sourceWorkspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
                let source = TestWindow.new(id: 901, parent: sourceParent)
                let target = TestWindow.new(id: 902, parent: targetWorkspace.rootTilingContainer)
                let binding = workspaceSidebarSiblingBindingData(source: source, target: target, after: after)!
                source.bind(to: binding.parent, adaptiveWeight: binding.adaptiveWeight, index: binding.index)
                XCTAssertTrue(source.parent === target.parent)
                XCTAssertEqual(source.ownIndex, target.ownIndex! + (after ? 1 : -1))
            }
        }
    }

    @MainActor
    func testDirectColumnSiblingFormsVerticalSplitWithoutChangingWidths() async throws {
        for after in [false, true] {
            setUpWorkspacesForTests()
            let workspace = Workspace.get(byName: "2")
            workspace.columns = ColumnState(count: 3, widths: [0.28, 0.44, 0.28])
            let target = TestWindow.new(id: 921, parent: workspace.rootTilingContainer)
            target.columnSlot = 2
            let source = TestWindow.new(id: 922, parent: Workspace.get(byName: "1").rootTilingContainer)
            try await checkDrop(source, .window(target.windowId, after: after))
            let wrapper = try XCTUnwrap(target.parent as? TilingContainer)
            XCTAssertEqual(wrapper.orientation, .v)
            XCTAssertEqual(wrapper.columnSlot, 2)
            XCTAssertTrue(source.parent === wrapper)
            XCTAssertEqual(source.ownIndex, after ? 1 : 0)
            XCTAssertEqual(workspace.columns?.widths, [0.28, 0.44, 0.28])
        }
    }

    @MainActor
    func testGroupJoinsTabsAsOrderedLeavesAndFloatingTargetFloatsLeaves() async throws {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "2")
        let tabs = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .h, .tabGroup, index: 0)
        _ = TestWindow.new(id: 931, parent: tabs)
        _ = TestWindow.new(id: 932, parent: tabs)
        let source = TilingContainer(parent: Workspace.get(byName: "1").rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
        _ = TestWindow.new(id: 933, parent: source)
        _ = TestWindow.new(id: 934, parent: source)
        try await checkDrop(source, .tabGroup(ObjectIdentifier(tabs), workspace: "2"))
        XCTAssertEqual(tabs.allLeafWindowsRecursive.map(\.windowId), [931, 932, 933, 934])
        XCTAssertFalse(source.isBound)
        try await checkDrop(tabs, .floatingGroup("2"))
        XCTAssertEqual(workspace.floatingWindows.map(\.windowId), [931, 932, 933, 934])
        XCTAssertFalse(tabs.isBound)
    }

    @MainActor
    func testNestedGroupJoinsSiblingTabAtBothHalves() async throws {
        for after in [false, true] {
            setUpWorkspacesForTests()
            let root = Workspace.get(byName: "1").rootTilingContainer
            root.layout = .tabGroup
            let source = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
            _ = TestWindow.new(id: 961, parent: source)
            _ = TestWindow.new(id: 962, parent: source)
            let target = TestWindow.new(id: 963, parent: root)
            try await checkDrop(source, .tab(target.windowId, after: after))
            XCTAssertEqual(root.allLeafWindowsRecursive.map(\.windowId), after ? [963, 961, 962] : [961, 962, 963])
        }
    }

    @MainActor
    func testFloatingSourceTilesDirectlyAndStaleOrCyclicTargetsDoNotMutate() async throws {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        let tabs = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .h, .tabGroup, index: 0)
        let first = TestWindow.new(id: 941, parent: tabs)
        _ = TestWindow.new(id: 942, parent: tabs)
        let floating = TestWindow.new(id: 943, parent: workspace)
        try await checkDrop(tabs, .tab(first.windowId, after: true), accepted: false)
        XCTAssertEqual(tabs.children.count, 2)
        try await checkDrop(floating, .tab(first.windowId, after: true))
        XCTAssertTrue(floating.parent === tabs)
        XCTAssertEqual(tabs.allLeafWindowsRecursive.map(\.windowId), [941, 943, 942])
        let identity = ObjectIdentifier(tabs)
        tabs.unbindFromParent()
        try await checkDrop(TestWindow.new(id: 944, parent: workspace.rootTilingContainer), .split(identity, workspace: "1"), accepted: false)
    }

    @MainActor
    func testChangedContainerLayoutCancelsAStaleSplitTarget() async throws {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        let split = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
        _ = TestWindow.new(id: 971, parent: split)
        _ = TestWindow.new(id: 972, parent: split)
        let sourceParent = Workspace.get(byName: "2").rootTilingContainer
        let source = TestWindow.new(id: 973, parent: sourceParent)
        let target = WorkspaceSidebarTreeDropTarget.split(ObjectIdentifier(split), workspace: "1")
        split.layout = .tabGroup
        try await checkDrop(source, target, accepted: false)
        XCTAssertTrue(source.parent === sourceParent)
    }

    @MainActor
    func testExplicitColumnTargetsMergeOccupiedAndPreserveGroupInEmptySlot() async throws {
        for occupied in [false, true] {
            setUpWorkspacesForTests()
            let workspace = Workspace.get(byName: "2")
            workspace.columns = ColumnState(count: 3)
            if occupied {
                let existing = TestWindow.new(id: 951, parent: workspace.rootTilingContainer)
                existing.columnSlot = 2
            }
            let source = TilingContainer(parent: Workspace.get(byName: "1").rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
            _ = TestWindow.new(id: 952, parent: source)
            _ = TestWindow.new(id: 953, parent: source)
            try await checkDrop(source, .column("2", slot: 2))
            let column = try XCTUnwrap(workspace.rootTilingContainer.children.first { $0.columnSlot == 2 })
            XCTAssertEqual(column.allLeafWindowsRecursive.map(\.windowId), occupied ? [951, 952, 953] : [952, 953])
            XCTAssertEqual(source.isBound, !occupied)
        }
    }
    func testReloadClearsOnlyOverridesWhoseDefaultChanged() {
        for splits in [false, true] {
            for columns in [false, true] {
                var state = WorkspaceSidebarTreeState()
                state.splitOverrides = ["1": true]
                state.columnOverrides = ["2": true]
                state.reload(defaults: WorkspaceSidebarTreeConfig(splits: splits, columns: columns))
                XCTAssertEqual(state.splitOverrides.isEmpty, splits)
                XCTAssertEqual(state.columnOverrides.isEmpty, columns)
            }
        }
    }

    @MainActor
    func testSearchRevealsAncestorsAndRestoresDisclosureWithoutDuplicateWindows() async {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "2")
        workspace.columns = ColumnState(count: 3, widths: [0.28, 0.44, 0.28])
        let tabs = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .h, .tabGroup, index: 0)
        tabs.columnSlot = 2
        _ = TestWindow.new(id: 981, parent: tabs)
        _ = TestWindow.new(id: 982, parent: tabs)
        let models = await buildWorkspaceSidebarWorkspaceViewModels(currentFocus: focus, workspaceLabels: [:], availableMonitors: [])
        var model = models.first { $0.name == "2" }!
        XCTAssertEqual(model.columnWidths, [0.28, 0.44, 0.28])
        XCTAssertEqual(model.columnSlot(for: 981), 2)
        model.collapsedNodes = [.container(ObjectIdentifier(tabs)), .column("2", 2)]
        let original = model
        let title = model.items.flatMap(\.descendantItems).compactMap { item -> WorkspaceSidebarWindowViewModel? in
            if case .window(let window) = item.kind { return window }; return nil
        }.first!.appName
        let filtered = workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [model]], projects: [], query: title.lowercased())[workspaceProjectDefaultId]!
        XCTAssertEqual(Set(workspaceSidebarSearchSelections(workspaces: filtered)), [.window(981), .window(982)])
        XCTAssertEqual(filtered.first?.collapsedNodes, original.collapsedNodes)
        XCTAssertTrue(filtered.first!.items[0].isSearchRevealed)
        let cleared = workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [model]], projects: [], query: "")[workspaceProjectDefaultId]!
        XCTAssertEqual(cleared, [original])
        XCTAssertTrue(workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [model]], projects: [], query: "qzxnomatch")[workspaceProjectDefaultId]!.isEmpty)
    }

    func testDisclosurePrunesRemovedIdentitiesAndKeepsSurvivingChoices() {
        var state = WorkspaceSidebarTreeState()
        let live = WorkspaceSidebarWorkspaceViewModel(name: "2", projectId: workspaceProjectDefaultId, displayName: "2", sidebarLabel: "", isGeneratedName: false, monitorScopeId: "", monitorName: nil, isFocused: false, isVisible: false, items: [.init(kind: .column(workspace: "2", slot: 1, fraction: 1))])
        state.collapsedNodes = [.workspace("2"), .column("2", 1), .column("2", 3), .workspace("removed")]
        state.prune(workspaces: [live])
        XCTAssertEqual(state.collapsedNodes, [.workspace("2"), .column("2", 1)])
    }

    @MainActor
    func testSiblingBindingUsesRealParentAndAdjustsSameParentRemoval() {
        for sourceIndex in 0...2 {
            for targetIndex in 0...2 where sourceIndex != targetIndex {
                for after in [false, true] {
                    setUpWorkspacesForTests()
                    let root = Workspace.get(byName: "1").rootTilingContainer
                    let windows = (0...2).map { TestWindow.new(id: UInt32(850 + $0), parent: root) }
                    let source = windows[sourceIndex]
                    let target = windows[targetIndex]
                    let binding = workspaceSidebarSiblingBindingData(source: source, target: target, after: after)!
                    source.bind(to: binding.parent, adaptiveWeight: binding.adaptiveWeight, index: binding.index)
                    var expected = windows.filter { $0 !== source }
                    let index = expected.firstIndex { $0 === target }! + (after ? 1 : 0)
                    expected.insert(source, at: index)
                    XCTAssertEqual(root.children.map { ($0 as! Window).windowId }, expected.map(\.windowId))
                }
            }
        }
    }

    @MainActor
    func testTreeCarriesEmptyColumnsWidthsAndRealParents() async {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "2")
        workspace.columns = ColumnState(count: 3, widths: [0.28, 0.44, 0.28])
        workspace.columns?.focusedSlot = 2
        let window = TestWindow.new(id: 890, parent: workspace.rootTilingContainer)
        window.columnSlot = 2
        let tree = await buildWorkspaceSidebarLayoutTree(for: workspace, currentFocus: focus)
        XCTAssertEqual(tree.count, 3)
        XCTAssertEqual(tree[1].children.first?.realParent, .container(ObjectIdentifier(workspace.rootTilingContainer)))
        XCTAssertEqual(tree[1].children.first?.indexInParent, 0)
        XCTAssertEqual(workspaceSidebarProjectItems(tree, splits: false, columns: false).map(\.id), ["window:890"])
    }

    @MainActor
    func testFlatTabProjectionRetainsNativeRepresentativeTabsAndRevealsRealSplitOnDemand() async {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        let root = workspace.rootTilingContainer
        root.layout = .tabGroup
        let split = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
        _ = TestWindow.new(id: 991, parent: split)
        _ = TestWindow.new(id: 992, parent: split)
        _ = TestWindow.new(id: 993, parent: root)
        let tree = await buildWorkspaceSidebarLayoutTree(for: workspace, currentFocus: focus)
        let flat = workspaceSidebarProjectItems(tree, splits: false, columns: false)
        guard case .tabGroup(let group) = flat[0].kind else { return XCTFail("Native tab group") }
        XCTAssertEqual(flat[0].children.map(\.identity), group.tabs.map { .window($0.windowId) })
        let revealed = workspaceSidebarProjectItems(tree, splits: true, columns: false)
        guard case .split = revealed[0].children[0].kind else { return XCTFail("Real nested split") }
        XCTAssertEqual(revealed[0].children[0].children.count, 2)
    }
    @MainActor
    func testFlatProjectionPreservesNativeItemsAndFloatingWindows() async {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        let root = workspace.rootTilingContainer
        let split = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: INDEX_BIND_LAST)
        let first = TestWindow.new(id: 801, parent: split)
        let tabs = TilingContainer(parent: split, adaptiveWeight: WEIGHT_AUTO, .h, .tabGroup, index: INDEX_BIND_LAST)
        _ = TestWindow.new(id: 802, parent: tabs)
        _ = TestWindow.new(id: 803, parent: tabs)
        _ = TestWindow.new(id: 804, parent: workspace)
        let items = await buildWorkspaceSidebarItems(for: workspace, currentFocus: focus)
        XCTAssertEqual(items.count, 3)
        guard case .window(let window) = items[0].kind,
              case .tabGroup(let group) = items[1].kind,
              case .window(let floating) = items[2].kind else { return XCTFail("Flat windows, tab group, then floating") }
        XCTAssertEqual(window.windowId, first.windowId)
        XCTAssertEqual(group.tabs.map(\.windowId), [802, 803])
        XCTAssertEqual(floating.windowId, 804)
    }

    @MainActor
    func testExistingWorkspaceRowMovePreservesFloatingAndAppendsTiledNode() {
        setUpWorkspacesForTests()
        let source = Workspace.get(byName: "1")
        let destination = Workspace.get(byName: "2")
        let existing = TestWindow.new(id: 811, parent: destination.rootTilingContainer)
        let tiled = TestWindow.new(id: 812, parent: source.rootTilingContainer)
        let floating = TestWindow.new(id: 813, parent: source)
        applySidebarWorkspaceMove(sourceNode: tiled, sourceWindow: tiled, targetWorkspace: destination)
        applySidebarWorkspaceMove(sourceNode: floating, sourceWindow: floating, targetWorkspace: destination)
        XCTAssertEqual(destination.rootTilingContainer.children.map { ($0 as? Window)?.windowId }, [existing.windowId, tiled.windowId])
        XCTAssertTrue(floating.parent === destination)
        XCTAssertFalse(isActionableSidebarWorkspaceDropTarget(sourceWorkspaceName: "2", targetKind: .workspace("2")))
    }
}
