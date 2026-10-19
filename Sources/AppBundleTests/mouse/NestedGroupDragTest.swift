@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor
final class NestedGroupDragTest: XCTestCase {
    private enum Header: CaseIterable { case strip, flatSidebar, treeSidebar }
    private struct Fixture {
        let workspace: Workspace
        let outer: TilingContainer
        let split: TilingContainer
        let representative: TestWindow
        let leaves: [Window]
        let target: TestWindow
    }

    override func tearDown() async throws {
        clearActiveWorkspaceSidebarDrag()
        clearPendingWindowDragIntent()
        cancelManipulatedWithMouseState()
        MousePointerTracker.shared.reset()
    }

    private func fixture(innerTabs: Bool) throws -> Fixture {
        setUpWorkspacesForTests()
        clearActiveWorkspaceSidebarDrag()
        config.enableNormalizationFlattenContainers = true
        config.enableNormalizationOppositeOrientationForNestedContainers = true
        config.windowTabs.enabled = true
        let workspace = Workspace.get(byName: "1")
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800)
        let monitor = TestMonitor(monitorAppKitNsScreenScreensId: 1, name: "Test", rect: rect, visibleRect: rect, isMain: true)
        setMonitorsForTests([monitor])
        _ = monitor.setActiveWorkspace(workspace)
        let root = workspace.rootTilingContainer
        let outer = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tabGroup, index: 0)
        let plain = TestWindow.new(id: 701, parent: outer)
        let split = TilingContainer(parent: outer, adaptiveWeight: WEIGHT_AUTO, .h, .tiles, index: 1)
        let parent = innerTabs ? TilingContainer(parent: split, adaptiveWeight: WEIGHT_AUTO, .v, .tabGroup, index: 0) : split
        let representative = TestWindow.new(id: 702, parent: parent)
        if innerTabs { _ = TestWindow.new(id: 703, parent: parent) }
        _ = TestWindow.new(id: 704, parent: split)
        representative.markAsMostRecentChild()
        let target = TestWindow.new(id: 705, parent: root)
        workspace.normalizeContainers()
        XCTAssertTrue(outer.parent === root)
        XCTAssertTrue(split.parent === outer)
        XCTAssertEqual(outer.layout, .tabGroup)
        XCTAssertEqual(split.layout, .tiles)
        XCTAssertEqual(split.children.count, 2)
        XCTAssertTrue(outer.mostRecentChild === split)
        XCTAssertTrue(outer.tabActiveWindow === representative)
        XCTAssertTrue(plain.parent === outer)
        if innerTabs { XCTAssertTrue(representative.parent === parent); XCTAssertTrue(parent.parent === split); XCTAssertEqual(parent.layout, .tabGroup) }
        return Fixture(workspace: workspace, outer: outer, split: split, representative: representative,
                       leaves: outer.allLeafWindowsRecursive, target: target)
    }

    private func subject(_ fixture: Fixture) -> WindowDragSubject { .group(fixture.outer.stableId) }

    private func start(_ fixture: Fixture, from header: Header) {
        switch header {
            case .strip:
                XCTAssertTrue(shouldAllowTabStripChromeGroupDrag(windowId: fixture.representative.windowId, containerIdentity: fixture.outer.stableId))
                updateMoveFromTabStrip(fixture.representative.windowId, containerIdentity: fixture.outer.stableId)
            case .flatSidebar:
                makeWorkspaceSidebarActionsAdapter().tabGroupDragChanged(fixture.outer.stableId, CGPoint(x: 1100, y: 700))
            case .treeSidebar:
                updateSidebarWindowDrag(fixture.representative.windowId, subject: subject(fixture), pointer: CGPoint(x: 1100, y: 700))
        }
        // These tests supply pointer samples; a native display tick would finish the drag as a missed mouse-up.
        DisplayRefreshDriver.shared.remove(owner: WindowMouseInteractionDriver.shared)
        XCTAssertEqual(getCurrentMouseDragSubject(), subject(fixture))
        if header != .strip {
            XCTAssertEqual(currentActiveWorkspaceSidebarDrag()?.source, .container(fixture.outer.stableId, workspace: fixture.workspace.name))
        }
    }

    private func destination(_ kind: WindowDragIntentKind) -> WindowDragIntentDestination {
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800)
        return WindowDragIntentDestination(kind: kind, previewRect: rect, interactionRect: rect,
                                          title: "Group", subtitle: "", previewStyle: .sidebarWorkspaceMove,
                                          previewGeometry: .rounded, isGroup: true)
    }

    private func pending(_ fixture: Fixture, _ kind: WindowDragIntentKind) {
        MousePointerTracker.shared.note(point: CGPoint(x: 400, y: 300))
        _ = setPendingWindowDragIntent(sourceWindowId: fixture.representative.windowId,
                                      sourceSubject: subject(fixture), detachOrigin: .window,
                                      destination: destination(kind))
    }

    func testNestedHeaderTilePendingIntentMovesEveryOuterLeaf() throws {
        for inner in [false, true] {
            for header in Header.allCases {
                let f = try fixture(innerTabs: inner)
                start(f, from: header)
                pending(f, .stackSplit(targetWindowId: f.target.windowId, position: .right))
                XCTAssertTrue(applyPendingWindowDragIntentIfPossible())
                XCTAssertTrue(f.outer.parent === f.target.parent)
                XCTAssertEqual(f.outer.allLeafWindowsRecursive.map(\.windowId), f.leaves.map(\.windowId))
            }
        }
    }

    func testNestedHeaderSidebarWindowAndSplitDropsMoveEveryOuterLeaf() async throws {
        for inner in [false, true] {
            for header in Header.allCases {
                for splitTarget in [false, true] {
                    let f = try fixture(innerTabs: inner)
                    start(f, from: header)
                    let other = Workspace.get(byName: "2")
                    let split = TilingContainer(parent: other.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
                    let target = TestWindow.new(id: 706, parent: split)
                    _ = TestWindow.new(id: 707, parent: split)
                    beginActiveWorkspaceSidebarDrag(windowId: f.representative.windowId, subject: subject(f))
                    let source = try XCTUnwrap(workspaceSidebarDragSource(f.representative, subject: subject(f)))
                    let drop: WorkspaceSidebarTreeDropTarget = splitTarget ? .split(split.stableId, workspace: other.name) : .window(target.windowId, after: true)
                    let applied = try await applyWorkspaceSidebarTreeDrop(source: source, target: drop)
                    XCTAssertTrue(applied)
                    XCTAssertTrue(f.outer.parent === split)
                    XCTAssertTrue(f.leaves.allSatisfy { $0.nodeWorkspace === other })
                }
            }
        }
    }

    func testNestedHeaderWorkspacePendingIntentMovesEveryOuterLeaf() throws {
        for inner in [false, true] {
            for header in Header.allCases {
                let f = try fixture(innerTabs: inner)
                start(f, from: header)
                let other = Workspace.get(byName: "2")
                pending(f, .moveToWorkspace(workspaceName: other.name))
                XCTAssertTrue(applyPendingWindowDragIntentIfPossible())
                XCTAssertTrue(f.outer.nodeWorkspace === other)
                XCTAssertTrue(f.leaves.allSatisfy { $0.nodeWorkspace === other })
            }
        }
    }

    func testNestedHeaderSidebarPreviewIncludesEveryOuterLeaf() throws {
        for inner in [false, true] {
            let f = try fixture(innerTabs: inner)
            let preview = try XCTUnwrap(workspaceSidebarSourcePreview(sourceWindow: f.representative, subject: subject(f)))
            XCTAssertTrue(preview.isTabGroup)
            XCTAssertEqual(preview.windowCount, f.leaves.count)
            XCTAssertEqual(preview.tabItems.count, f.leaves.count)
        }
    }

    func testNestedHeaderRefusesTileInsideOuterGroup() throws {
        for inner in [false, true] {
            let f = try fixture(innerTabs: inner)
            pending(f, .stackSplit(targetWindowId: 701, position: .right))
            XCTAssertFalse(applyPendingWindowDragIntentIfPossible())
            XCTAssertEqual(f.outer.allLeafWindowsRecursive.map(\.windowId), f.leaves.map(\.windowId))
        }
    }

    func testNestedHeaderOnScreenLookupUsesOuterContainmentAndPendingDrop() async throws {
        for inner in [false, true] {
            let f = try fixture(innerTabs: inner)
            config.workspaceSidebar.enabled = false
            try await f.workspace.layoutWorkspace()
            let targetFrame = try XCTUnwrap(f.target.lastAppliedLayoutPhysicalRect)
            let point = CGPoint(x: targetFrame.maxX - 6, y: targetFrame.center.y)
            let drop = try XCTUnwrap(currentWindowDragIntentDestination(sourceWindow: f.representative, mouseLocation: point, subject: subject(f), detachOrigin: .window))
            MousePointerTracker.shared.note(point: point)
            XCTAssertTrue(setPendingWindowDragIntent(sourceWindowId: 702, sourceSubject: subject(f), detachOrigin: .window, destination: drop))
            XCTAssertTrue(applyPendingWindowDragIntentIfPossible())
            XCTAssertEqual(f.outer.allLeafWindowsRecursive.map(\.windowId), f.leaves.map(\.windowId))
            XCTAssertTrue(f.outer.parent === f.target.parent)
        }
    }

    func testNestedHeaderColumnPolicyAppliesWholeOuterGroupOnce() async throws {
        for inner in [false, true] {
            for header in Header.allCases {
                let f = try fixture(innerTabs: inner)
                start(f, from: header)
                let other = Workspace.get(byName: "2")
                other.columns = ColumnState(count: 3)
                let decision = PlacementDecision(slot: 2, target: "2", overflow: .tabGroup, hook: nil)
                pending(f, .column(workspaceName: other.name, slot: 2, decision: decision))
                let applied = try await applyPendingWindowDragIntentWithPolicy()
                XCTAssertTrue(applied)
                XCTAssertTrue(f.outer.nodeWorkspace === other)
                XCTAssertEqual(other.columnSlot(containing: f.outer), 2)
                XCTAssertTrue(f.leaves.allSatisfy { $0.nodeWorkspace === other })
                XCTAssertEqual(f.outer.allLeafWindowsRecursive.map(\.windowId), f.leaves.map(\.windowId))
            }
        }
    }

    func testNestedHeaderNewWorkspacePendingIntentMovesEveryOuterLeaf() throws {
        for inner in [false, true] {
            for header in Header.allCases {
                let f = try fixture(innerTabs: inner)
                start(f, from: header)
                pending(f, .createWorkspace(projectId: workspaceProjectDefaultId, monitorScopeId: workspaceSidebarDefaultScopeId))
                XCTAssertTrue(applyPendingWindowDragIntentIfPossible())
                let other = try XCTUnwrap(f.outer.nodeWorkspace)
                XCTAssertFalse(other === f.workspace)
                XCTAssertTrue(f.leaves.allSatisfy { $0.nodeWorkspace === other })
            }
        }
    }

    func testNestedHeaderMonitorChipLookupAndApplyMovesEveryOuterLeaf() throws {
        for inner in [false, true] {
            for header in Header.allCases {
                let f = try fixture(innerTabs: inner)
                start(f, from: header)
                let other = Workspace.get(byName: "2")
                let rect = Rect(topLeftX: 1200, topLeftY: 0, width: 1200, height: 800)
                let second = TestMonitor(monitorAppKitNsScreenScreensId: 2, name: "Second", rect: rect, visibleRect: rect, isMain: false)
                setMonitorsForTests([mainMonitor, second])
                _ = second.setActiveWorkspace(other)
                let point = CGPoint(x: 1250, y: 100)
                let target = WorkspaceSidebarDropTarget(kind: .monitor(workspaceSidebarMonitorScopeId(for: second)), rect: Rect(topLeftX: 1220, topLeftY: 80, width: 100, height: 40))
                let drop = try XCTUnwrap(sidebarWorkspaceDropDestination(sourceWindow: f.representative, mouseLocation: point, subject: subject(f), target: target))
                XCTAssertEqual(drop.kind, .moveToWorkspace(workspaceName: other.name))
                MousePointerTracker.shared.note(point: point)
                XCTAssertTrue(setPendingWindowDragIntent(sourceWindowId: f.representative.windowId, sourceSubject: subject(f), detachOrigin: .window, destination: drop))
                XCTAssertTrue(applyPendingWindowDragIntentIfPossible())
                XCTAssertTrue(f.outer.nodeWorkspace === other)
                XCTAssertTrue(f.leaves.allSatisfy { $0.nodeWorkspace === other })
            }
        }
    }

    func testNestedHeaderFeedbackAnchorGhostAndViewModelsUseOuterIdentity() async throws {
        for inner in [false, true] {
            let f = try fixture(innerTabs: inner)
            XCTAssertTrue(f.representative.focusWindow())
            try await f.workspace.layoutWorkspace()
            let frame = try XCTUnwrap(f.outer.lastAppliedLayoutPhysicalRect)
            XCTAssertEqual(resolvedDraggedWindowAnchorRect(for: f.representative, subject: subject(f)), frame)
            let ghost = try XCTUnwrap(windowDragSourcePreviewItem(window: f.representative, subject: subject(f), frame: frame))
            XCTAssertTrue(ghost.isTabGroup)
            XCTAssertEqual(ghost.icons.count, f.outer.children.count)
            let strips = await buildWindowTabStripViewModelsFromChromeItems()
            let strip = try XCTUnwrap(strips.first { $0.id == ObjectIdentifier(f.outer) })
            XCTAssertEqual(strip.containerIdentity, f.outer.stableId)
            XCTAssertEqual(strip.alignedForWindowTabChrome().containerIdentity, f.outer.stableId)
            var children: [WorkspaceSidebarItemViewModel] = []
            for window in f.leaves {
                let item = await makeWorkspaceSidebarWindowViewModel(for: window, workspaceName: f.workspace.name, currentFocus: focus)
                children.append(WorkspaceSidebarItemViewModel(kind: .window(item)))
            }
            let group = try XCTUnwrap(makeWorkspaceSidebarTabGroupViewModel(for: f.outer, children: children, workspaceName: f.workspace.name, currentFocus: focus))
            XCTAssertEqual(group.containerIdentity, f.outer.stableId)
            XCTAssertEqual(group.windowCount, f.leaves.count)
            let drop = destination(.moveToWorkspace(workspaceName: "2"))
            updateSidebarDragFeedback(sourceWindow: f.representative, subject: subject(f), destination: drop)
            let feedback = try XCTUnwrap(TrayMenuModel.shared.workspaceSidebarDropPreview)
            XCTAssertEqual(feedback.windowCount, f.leaves.count)
            XCTAssertEqual(feedback.tabItems.count, f.leaves.count)
        }
    }

    func testFlattenedOuterIdentityRefusesDestinationsPreviewsAndPendingApply() async throws {
        for inner in [false, true] {
            let f = try fixture(innerTabs: inner)
            let dragged = subject(f)
            let other = Workspace.get(byName: "2")
            pending(f, .moveToWorkspace(workspaceName: other.name))
            Window.get(byId: 701)?.unbindFromParent()
            f.workspace.normalizeContainers()
            XCTAssertNil(workspaceSidebarLiveContainer(f.outer.stableId))
            XCTAssertNil(dragSubjectNode(for: f.representative, subject: dragged))
            XCTAssertNil(currentWindowDragIntentDestination(sourceWindow: f.representative, mouseLocation: CGPoint(x: 700, y: 400), subject: dragged, detachOrigin: .window))
            XCTAssertNil(workspaceSidebarSourcePreview(sourceWindow: f.representative, subject: dragged))
            XCTAssertNil(windowDragSourcePreviewItem(window: f.representative, subject: dragged, frame: Rect(topLeftX: 0, topLeftY: 0, width: 500, height: 300)))
            XCTAssertFalse(applyPendingWindowDragIntentIfPossible())
            XCTAssertTrue(f.representative.nodeWorkspace === f.workspace)
            XCTAssertFalse(updatePendingWindowDragIntent(sourceWindow: f.representative, mouseLocation: CGPoint(x: 700, y: 400), subject: dragged, detachOrigin: .window))
            XCTAssertNil(pendingWindowDragIntent)
            let decision = PlacementDecision(slot: 2, target: "2", overflow: .tabGroup, hook: nil)
            other.columns = ColumnState(count: 3)
            XCTAssertFalse(setPendingWindowDragIntent(sourceWindowId: f.representative.windowId, sourceSubject: dragged, detachOrigin: .window, destination: destination(.column(workspaceName: other.name, slot: 2, decision: decision))))
            let applied = try await applyPendingWindowDragIntentWithPolicy()
            XCTAssertFalse(applied)
            XCTAssertTrue(f.representative.nodeWorkspace === f.workspace)
        }
    }

    func testDifferentOuterIdsAreDifferentSessionsAndIntents() throws {
        let f = try fixture(innerTabs: true)
        let inner = try XCTUnwrap(f.representative.parent as? TilingContainer)
        XCTAssertTrue(beginWindowMoveWithMouseSessionIfNeeded(windowId: 702, subject: .group(inner.stableId), detachOrigin: .window, startedInSidebar: false, anchorRect: nil, refreshActualRects: false))
        XCTAssertTrue(beginWindowMoveWithMouseSessionIfNeeded(windowId: 702, subject: subject(f), detachOrigin: .window, startedInSidebar: false, anchorRect: nil, refreshActualRects: false))
        XCTAssertTrue(shouldContinueCurrentGroupDrag(windowId: 702, subject: subject(f)))
        XCTAssertFalse(shouldContinueCurrentGroupDrag(windowId: 702, subject: .group(inner.stableId)))
        XCTAssertTrue(shouldPromoteTabStripDragToGroup(windowId: 702, containerIdentity: f.outer.stableId))
        XCTAssertEqual(resolvedMouseDragSubject(for: f.representative), subject(f))
        beginActiveWorkspaceSidebarDrag(windowId: 702, subject: .group(inner.stableId))
        beginActiveWorkspaceSidebarDrag(windowId: 702, subject: subject(f))
        XCTAssertEqual(currentActiveWorkspaceSidebarDrag()?.subject, subject(f))
        pending(f, .moveToWorkspace(workspaceName: "2"))
        XCTAssertTrue(setPendingWindowDragIntent(sourceWindowId: 702, sourceSubject: .group(inner.stableId), detachOrigin: .window, destination: destination(.moveToWorkspace(workspaceName: "2"))))
        XCTAssertEqual(pendingWindowDragIntent?.sourceSubject, .group(inner.stableId))
        let payload = WorkspaceSidebarDragPayload.tabGroup(UInt64(UInt32.max) + 30)
        XCTAssertEqual(WorkspaceSidebarDragPayload(encodedValue: payload.encodedValue), payload)
        cancelManipulatedWithMouseState()
        XCTAssertFalse(isWindowInDraggableTabGroup(f.representative.parent === f.split ? f.representative : Window.get(byId: 704)!))
    }

    func testColumnPendingBeforeFlattenRefusesAndClearsAtPolicyApply() async throws {
        for inner in [false, true] {
            let f = try fixture(innerTabs: inner)
            let other = Workspace.get(byName: "2")
            other.columns = ColumnState(count: 3)
            let decision = PlacementDecision(slot: 2, target: "2", overflow: .tabGroup, hook: nil)
            pending(f, .column(workspaceName: other.name, slot: 2, decision: decision))
            Window.get(byId: 701)?.unbindFromParent()
            f.workspace.normalizeContainers()
            let applied = try await applyPendingWindowDragIntentWithPolicy()
            XCTAssertFalse(applied)
            XCTAssertNil(pendingWindowDragIntent)
            XCTAssertTrue(f.representative.nodeWorkspace === f.workspace)
            XCTAssertTrue(other.rootTilingContainer.children.isEmpty)
        }
    }
}
