import AppKit
@testable import AppBundle
import XCTest

final class WorkspaceSidebarTreeTest: XCTestCase {
    @MainActor
    func testUnassignedColumnChildrenRemainListedAndSearchable() async {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "2")
        workspace.columns = ColumnState(count: 2)
        let first = TestWindow.new(id: 701, parent: workspace.rootTilingContainer)
        let second = TestWindow.new(id: 702, parent: workspace.rootTilingContainer)
        second.columnSlot = 9
        let tree = await buildWorkspaceSidebarLayoutTree(for: workspace, currentFocus: focus)
        XCTAssertEqual(tree.count, 4)
        let flat = workspaceSidebarProjectItems(tree, splits: false, columns: false)
        XCTAssertEqual(flat.map(\.identity), [.window(first.windowId), .window(second.windowId)])
        XCTAssertEqual(flat.map(\.indexInParent), [0, 1])
        XCTAssertTrue(flat.allSatisfy { $0.realParent == .container(workspace.rootTilingContainer.stableId) })
    }

    @MainActor
    func testFloatingDropRestoresRememberedSizeAndPreservesUnknownSize() async throws {
        for remembered in [false, true] {
            setUpWorkspacesForTests()
            let workspace = Workspace.get(byName: "1")
            let window = TestWindow.new(id: 703, parent: workspace.rootTilingContainer, rect: Rect(topLeftX: 20, topLeftY: 30, width: 900, height: 700))
            window.lastFloatingSize = remembered ? CGSize(width: 320, height: 240) : nil
            try await checkDrop(window, .floatingGroup("1"))
            XCTAssertTrue(window.parent === workspace)
            let rect = try await window.getAxRect()
            XCTAssertEqual(rect?.size, remembered ? CGSize(width: 320, height: 240) : CGSize(width: 900, height: 700))
            XCTAssertEqual(rect?.topLeftCorner, CGPoint(x: 20, y: 30))
        }
    }

    @MainActor
    func testColumnsRootCannotBeAStaleSplitOrTabTarget() async throws {
        for layout: Layout in [.tiles, .tabGroup] {
            setUpWorkspacesForTests()
            let workspace = Workspace.get(byName: "1")
            let root = workspace.rootTilingContainer
            root.layout = layout
            let target: WorkspaceSidebarTreeDropTarget = layout == .tiles ? .split(root.stableId, workspace: "1") : .tabGroup(root.stableId, workspace: "1")
            workspace.columns = ColumnState(count: 2)
            let sourceParent = Workspace.get(byName: "2").rootTilingContainer
            let source = TestWindow.new(id: 704, parent: sourceParent)
            XCTAssertNil(workspaceSidebarTreeDestination(target))
            try await checkDrop(source, target, accepted: false)
            XCTAssertTrue(source.parent === sourceParent)
            XCTAssertTrue(root.children.isEmpty)
        }
    }

    @MainActor
    func testColumnsRootIsRecheckedAfterSuspendedFloatingSizeRead() async throws {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        let root = workspace.rootTilingContainer
        let sourceWorkspace = Workspace.get(byName: "2")
        let source = TestWindow.new(id: 709, parent: sourceWorkspace)
        let target = WorkspaceSidebarTreeDropTarget.split(root.stableId, workspace: "1")
        XCTAssertNotNil(workspaceSidebarTreeDestination(target))
        source.beforeAxSize = { workspace.columns = ColumnState(count: 2) }
        try await checkDrop(source, target, accepted: false)
        XCTAssertTrue(source.parent === sourceWorkspace)
        XCTAssertTrue(root.children.isEmpty)
        previewWorkspaceSidebarDrop(source.windowId, subject: .window, target: .tree(target))
        XCTAssertEqual(TrayMenuModel.shared.workspaceSidebarDropPreview?.refusalReason, "Destination no longer exists")
        clearWorkspaceSidebarDropPreview()
    }

    func testVisibleControlsBeatTreeFramesUnderTheHeader() {
        let row = WorkspaceSidebarDropTarget(kind: .tree(.window(1, after: false)), rect: Rect(topLeftX: 10, topLeftY: 10, width: 100, height: 24))
        for kind: WorkspaceSidebarDropTargetKind in [.monitor("display"), .newWorkspace(projectId: workspaceProjectDefaultId, monitorScopeId: "display")] {
            let control = WorkspaceSidebarDropTarget(kind: kind, rect: Rect(topLeftX: 0, topLeftY: 0, width: 300, height: 50))
            XCTAssertEqual(resolveWorkspaceSidebarDropTarget(at: CGPoint(x: 20, y: 20), targets: [control, row])?.kind, kind)
        }
    }

    func testSearchRestoresBundleTermsGroupTitlesAndEmptyWorkspaceMatches() {
        let window = WorkspaceSidebarWindowViewModel(windowId: 705, workspaceName: "work", appName: "Editor", appBundleId: "org.example.editor", appBundlePath: "/Apps/Editor.app", title: "Draft", isFocused: false)
        let group = WorkspaceSidebarTabGroupViewModel(representativeWindowId: 705, workspaceName: "work", title: "Special group", windowCount: 1, isFocused: false, tabs: [window])
        let model = WorkspaceSidebarWorkspaceViewModel(name: "work", projectId: workspaceProjectDefaultId, displayName: "Work", sidebarLabel: "Label", isGeneratedName: false, monitorScopeId: "display", monitorName: "Studio", isFocused: false, isVisible: true, items: [.init(kind: .tabGroup(group))])
        for query in ["org.example", "/apps/", "draft editor", "editor work"] {
            let results = workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [model]], projects: [], query: query)[workspaceProjectDefaultId]!
            XCTAssertEqual(workspaceSidebarSearchSelections(workspaces: results), [.window(705)], query)
        }
        let groups = workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [model]], projects: [], query: "special group")[workspaceProjectDefaultId]!
        XCTAssertEqual(groups.count, 1)
        if case .tabGroup(let result) = groups.first?.items.first?.kind { XCTAssertEqual(result.searchVisibleTabs, []) }
        XCTAssertEqual(groups.first?.items.first?.isSearchAncestor, false, "A group whose own title matches is a match, not a dimmed ancestor")
        var empty = model
        empty.items = []
        for query in ["label", "studio", "work"] {
            let results = workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [empty]], projects: [], query: query)[workspaceProjectDefaultId]!
            XCTAssertEqual(workspaceSidebarSearchSelections(workspaces: results), [.workspace("work")])
        }
        let projects = [WorkspaceSidebarProjectViewModel(id: workspaceProjectDefaultId, displayName: "Build project", colorHex: nil)]
        let projectResults = workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [model]], projects: projects, query: "editor build")[workspaceProjectDefaultId]!
        XCTAssertEqual(workspaceSidebarSearchSelections(workspaces: projectResults), [.window(705)])
        XCTAssertTrue(workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [model]], projects: [], query: "draft absent")[workspaceProjectDefaultId]!.isEmpty)
    }
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
    func testNativeFeedbackProtectsTreeOnlyOverSidebarAndClearsItOutside() {
        setUpWorkspacesForTests()
        let window = TestWindow.new(id: 798, parent: Workspace.get(byName: "1").rootTilingContainer)
        beginActiveWorkspaceSidebarDrag(windowId: window.windowId, subject: .window)
        defer { clearActiveWorkspaceSidebarDrag(); clearWorkspaceSidebarDropPreview() }
        previewWorkspaceSidebarDrop(window.windowId, subject: .window, target: .tree(.window(window.windowId, after: false)))
        let preview = TrayMenuModel.shared.workspaceSidebarDropPreview
        XCTAssertNotNil(preview?.refusalReason)
        XCTAssertTrue(preservesWorkspaceSidebarTreePreview(isOverSidebar: true))
        XCTAssertFalse(preservesWorkspaceSidebarTreePreview(isOverSidebar: false))
        MousePointerTracker.shared.note(point: CGPoint(x: 10000, y: 10000))
        updateSidebarDragFeedback(sourceWindow: window, subject: .window, destination: nil)
        XCTAssertNil(TrayMenuModel.shared.workspaceSidebarDropPreview)
    }

    @MainActor
    func testSplitSidebarDragNeverOffersScreenOrMonitorAndKeepsWholeSource() async throws {
        setUpWorkspacesForTests()
        let root = Workspace.get(byName: "1").rootTilingContainer
        let split = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .h, .tiles, index: 0)
        let first = TestWindow.new(id: 706, parent: split)
        _ = TestWindow.new(id: 707, parent: split)
        let targetWorkspace = Workspace.get(byName: "2")
        let monitor = WorkspaceSidebarDragTestMonitor(monitorAppKitNsScreenScreensId: 1, name: "Test", rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080), visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080), isMain: true)
        setMonitorsForTests([monitor])
        defer { setMonitorsForTests(nil) }
        XCTAssertTrue(monitor.setActiveWorkspace(targetWorkspace))
        let target = TestWindow.new(id: 708, parent: targetWorkspace.rootTilingContainer)
        beginActiveWorkspaceSidebarDrag(windowId: first.windowId, subject: .group, container: split, sidebarOnly: true)
        defer { clearActiveWorkspaceSidebarDrag(); clearPendingWindowDragIntent() }
        XCTAssertTrue(workspaceSidebarDragSource(first, subject: .group) === split)
        XCTAssertNil(currentWindowDragIntentDestination(sourceWindow: first, mouseLocation: CGPoint(x: 500, y: 500), subject: .group, detachOrigin: .window))
        XCTAssertFalse(workspaceSidebarTreeAcceptsTarget(sourceWorkspaceName: "1", target: .monitor("display")))
        XCTAssertFalse(workspaceSidebarTreeAcceptsTarget(sourceWorkspaceName: "1", target: .newWorkspace(projectId: workspaceProjectDefaultId, monitorScopeId: "display")))
        XCTAssertTrue(workspaceSidebarTreeAcceptsTarget(sourceWorkspaceName: "1", target: .tree(.window(target.windowId, after: true))))
        _ = setPendingWindowDragIntent(sourceWindowId: first.windowId, sourceSubject: .group, detachOrigin: .window,
                                       destination: WindowDragIntentDestination(kind: .moveToWorkspace(workspaceName: "2"), previewRect: monitor.rect,
                                           interactionRect: monitor.rect, title: "Move", subtitle: "", previewStyle: .workspaceMove,
                                           previewGeometry: .rounded, isGroup: true))
        finishSidebarWindowDrag(pointer: CGPoint(x: 10000, y: 10000))
        XCTAssertNil(pendingWindowDragIntent)
        XCTAssertTrue(split.parent === root)
        XCTAssertEqual(split.allLeafWindowsRecursive.map(\.windowId), [706, 707])
        XCTAssertNil(currentActiveWorkspaceSidebarDrag())
        beginActiveWorkspaceSidebarDrag(windowId: first.windowId, subject: .group, container: split, sidebarOnly: true)
        let source = try XCTUnwrap(workspaceSidebarDragSource(first, subject: .group))
        try await checkDrop(source, .window(target.windowId, after: true))
        XCTAssertTrue(split.parent === targetWorkspace.rootTilingContainer)
        XCTAssertEqual(split.allLeafWindowsRecursive.map(\.windowId), [706, 707])
    }

    @MainActor
    func testFreedContainerIdentityCannotResolveReplacementOrInheritDisclosure() async {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        var old: TilingContainer? = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
        let identity = old!.stableId
        weak var freed = old
        old!.unbindFromParent()
        old = nil
        XCTAssertNil(freed)
        let replacement = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
        XCTAssertGreaterThan(replacement.stableId, identity)
        XCTAssertNil(workspaceSidebarLiveContainer(identity, workspaceName: "1"))
        XCTAssertTrue(workspaceSidebarLiveContainer(replacement.stableId, workspaceName: "1") === replacement)
        var state = WorkspaceSidebarTreeState()
        state.collapsedNodes = [.container(identity)]
        let models = await buildWorkspaceSidebarWorkspaceViewModels(currentFocus: focus, workspaceLabels: [:], availableMonitors: [])
        state.prune(workspaces: models)
        XCTAssertFalse(state.collapsedNodes.contains(.container(replacement.stableId)))
        XCTAssertTrue(state.collapsedNodes.isEmpty)
    }

    func testViewportDropsScrolledAndPartlyClippedTreeFrames() {
        let viewport = CGRect(x: 0, y: 50, width: 320, height: 300)
        let hidden = WorkspaceSidebarDropTargetFrame(kind: .tree(.window(1, after: false)), frame: CGRect(x: 10, y: 20, width: 100, height: 24))
        let partial = WorkspaceSidebarDropTargetFrame(kind: .tree(.window(2, after: false)), frame: CGRect(x: 10, y: 40, width: 100, height: 24))
        let visible = WorkspaceSidebarDropTargetFrame(kind: .tree(.window(3, after: false)), frame: CGRect(x: 10, y: 60, width: 100, height: 24))
        let clipped = WorkspaceSidebarDropTargetFrame(kind: partial.kind, frame: CGRect(x: 10, y: 50, width: 100, height: 14), rowFrame: partial.frame)
        XCTAssertEqual(workspaceSidebarVisibleTreeTargets([hidden, partial, visible], viewport: viewport), [clipped, visible])
    }

    func testAPartlyHiddenRowTakesDropsOnlyWhereItShowsAndKeepsItsHalves() {
        // The row spans 40-64, centre 52; the header covers everything above 50.
        let row = WorkspaceSidebarDropTarget(kind: .tree(.window(2, after: false)), rect: Rect(topLeftX: 10, topLeftY: 50, width: 100, height: 14),
                                             rowRect: Rect(topLeftX: 10, topLeftY: 40, width: 100, height: 24))
        let section = WorkspaceSidebarDropTarget(kind: .workspace("1"), rect: Rect(topLeftX: 0, topLeftY: 0, width: 320, height: 400))
        let targets = [section, row]
        XCTAssertEqual(resolveWorkspaceSidebarDropTarget(at: CGPoint(x: 50, y: 45), targets: targets)?.kind, .workspace("1"), "The hidden part takes no drop")
        XCTAssertEqual(resolveWorkspaceSidebarDropTarget(at: CGPoint(x: 50, y: 51), targets: targets)?.kind, .tree(.window(2, after: false)))
        XCTAssertEqual(resolveWorkspaceSidebarDropTarget(at: CGPoint(x: 50, y: 54), targets: targets)?.kind, .tree(.window(2, after: true)), "Halves follow the whole row")
    }

    @MainActor
    func testFloatingTargetDoesNotResizeAFullscreenLeaf() async throws {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        let target = Workspace.get(byName: "2")
        let window = TestWindow.new(id: 725, parent: workspace.macOsNativeFullscreenWindowsContainer, rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080))
        window.lastFloatingSize = CGSize(width: 320, height: 240)
        try await checkDrop(window, .floatingGroup("2"))
        XCTAssertTrue(window.parent === target)
        let rect = try await window.getAxRect()
        XCTAssertEqual(rect?.size, CGSize(width: 1920, height: 1080))
    }

    @MainActor
    func testFloatingReorderKeepsTheSizeOfAnAlreadyFloatingWindow() async throws {
        setUpWorkspacesForTests()
        let source = Workspace.get(byName: "1")
        let target = Workspace.get(byName: "2")
        let window = TestWindow.new(id: 723, parent: source, rect: Rect(topLeftX: 20, topLeftY: 30, width: 900, height: 700))
        window.lastFloatingSize = CGSize(width: 320, height: 240)
        try await checkDrop(window, .floatingGroup("2"))
        XCTAssertTrue(window.parent === target)
        let rect = try await window.getAxRect()
        XCTAssertEqual(rect?.size, CGSize(width: 900, height: 700))
    }

    func testWorkspaceNameMatchKeepsTheWholeWorkspaceUndimmed() {
        let window = WorkspaceSidebarWindowViewModel(windowId: 724, workspaceName: "coding", appName: "Editor", appBundleId: nil, appBundlePath: nil, title: "Draft", isFocused: false)
        let occupied = WorkspaceSidebarItemViewModel(kind: .column(workspace: "coding", slot: 1, fraction: 0.5), children: [.init(kind: .window(window), columnSlot: 1)], columnSlot: 1)
        let empty = WorkspaceSidebarItemViewModel(kind: .column(workspace: "coding", slot: 2, fraction: 0.5), columnSlot: 2)
        let model = WorkspaceSidebarWorkspaceViewModel(name: "coding", projectId: workspaceProjectDefaultId, displayName: "coding", sidebarLabel: "", isGeneratedName: false, monitorScopeId: "", monitorName: nil, isFocused: false, isVisible: true, items: [occupied, empty])
        let results = workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [model]], projects: [], query: "coding")[workspaceProjectDefaultId]!
        XCTAssertEqual(results.first?.items.map(\.identity), [.column("coding", 1), .column("coding", 2)])
        XCTAssertEqual(results.first?.items.map(\.isSearchAncestor), [false, false])
        XCTAssertEqual(results.first?.items.map(\.isSearchRevealed), [true, false], "A workspace match opens collapsed nodes, as a window match does")
    }

    func testRenderReadsReuseProjectionStorageAndModelChangesRebuildIt() {
        let window = WorkspaceSidebarWindowViewModel(windowId: 710, workspaceName: "1", appName: "Editor", appBundleId: nil, appBundlePath: nil, title: "Draft", isFocused: false)
        let child = WorkspaceSidebarItemViewModel(kind: .window(window), columnSlot: 1)
        let column = WorkspaceSidebarItemViewModel(kind: .column(workspace: "1", slot: 1, fraction: 1), children: [child])
        var model = WorkspaceSidebarWorkspaceViewModel(name: "1", projectId: workspaceProjectDefaultId, displayName: "1", sidebarLabel: "", isGeneratedName: false, monitorScopeId: "", monitorName: nil, isFocused: false, isVisible: true, items: [column])
        let first = model.projectedItems
        let second = model.projectedItems
        first.withUnsafeBufferPointer { firstBuffer in
            second.withUnsafeBufferPointer { secondBuffer in
                XCTAssertEqual(firstBuffer.baseAddress, secondBuffer.baseAddress, "Repeated render reads must not allocate another projection")
            }
        }
        XCTAssertEqual(model.columnSlot(for: 710), 1)
        XCTAssertEqual(first.map(\.identity), [.window(710)])
        model.showsColumns = true
        XCTAssertEqual(model.projectedItems.map(\.identity), [.column("1", 1)])
        model.items = []
        XCTAssertTrue(model.projectedItems.isEmpty)
        XCTAssertNil(model.columnSlot(for: 710))
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
                let binding = siblingBindingData(source: source, target: target, after: after)!
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
        try await checkDrop(source, .tabGroup(tabs.stableId, workspace: "2"))
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
        let identity = tabs.stableId
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
        let target = WorkspaceSidebarTreeDropTarget.split(split.stableId, workspace: "1")
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
        model.collapsedNodes = [.container(tabs.stableId), .column("2", 2)]
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
                    let binding = siblingBindingData(source: source, target: target, after: after)!
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
        XCTAssertEqual(tree[1].children.first?.realParent, .container(workspace.rootTilingContainer.stableId))
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
        let tree = await buildWorkspaceSidebarLayoutTree(for: workspace, currentFocus: focus)
        let items = workspaceSidebarProjectItems(tree, splits: false, columns: false)
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
