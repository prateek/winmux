import AppKit
import Common

func resizedObs(_: AXObserver, ax: AXUIElement, notif: CFString, _: UnsafeMutableRawPointer?) {
    let notif = notif as String
    let windowId = ax.containingWindowId()
    Task { @MainActor in
        if WindowMouseInteractionOpacityController.shared.shouldSuppressObserverEvent(windowId: windowId) {
            return
        }
        if shouldIgnoreAxObserverEventForPostDragSuppression(windowId: windowId, notif: notif) {
            return
        }
        // See movedObs: geometry events invalidate the cached native state (consumers re-fetch
        // on demand), but suppressed events are our own moves whose authors maintain the cache.
        if let windowId {
            Window.get(byId: windowId)?.invalidateLastKnownNativeState()
        }
        guard RunSessionGuard.isServerEnabled != nil else { return }
        guard let windowId, let window = Window.get(byId: windowId) else {
            scheduleRefreshSession(.ax(notif))
            return
        }
        if isContinuingManagedDragSessionForResizedEvent(windowId) { return }
        guard try await isManipulatedWithMouse(window) else {
            scheduleRefreshSession(.ax(notif))
            return
        }
        guard window.parent is TilingContainer else {
            scheduleRefreshSession(.ax(notif))
            return
        }
        WindowMouseInteractionDriver.shared.startResize(windowId: window.windowId)
    }
}

@MainActor
func resetManipulatedWithMouseIfPossible() async throws {
    await WindowMouseInteractionDriver.shared.flushBeforeMouseUp()
    let didApplyPendingDragIntent = applyPendingWindowDragIntentIfPossible()
    clearPendingWindowDragIntent()
    if currentlyManipulatedWithMouseWindowId != nil || didApplyPendingDragIntent {
        armGlobalPostDragAxObserverSuppression()
        cancelManipulatedWithMouseState()
        scheduleRefreshSession(.resetManipulatedWithMouse, optimisticallyPreLayoutWorkspaces: true)
    }
    WindowMouseInteractionDriver.shared.stop()
}

private let adaptiveWeightBeforeResizeWithMouseKey = TreeNodeUserDataKey<CGFloat>(key: "adaptiveWeightBeforeResizeWithMouseKey")

@MainActor
func updateCompositedResizePreview(_ window: Window, rect: Rect) {
    syncClosedWindowsCacheToCurrentWorld()
    // The actively resized content stays real. Hide all tab chrome, including the active
    // group, so every inactive group can be represented by one uninterrupted glass pane.
    WindowTabStripPanelController.shared.hideChromeDuringMouseInteraction(showFrameOnly: false)
    guard let workspace = window.nodeWorkspace,
          workspace.isVisible,
          let weightMap = proposedResizeWeightMap(window, rect: rect)
    else {
        logWindowDragLive("resizePreview hide requested reason=resizePreview.no-workspace-or-weightMap window=\(window.windowId) workspace=\(window.nodeWorkspace?.name.description ?? "nil") visible=\(window.nodeWorkspace?.isVisible.description ?? "nil") hasWeightMap=\(proposedResizeWeightMap(window, rect: rect) != nil)")
        WindowResizePreviewPanel.shared.endStableFrame()
        WindowResizePreviewPanel.shared.hide(reason: "resizePreview.no-workspace-or-weightMap")
        return
    }
    WindowResizePreviewPanel.shared.beginStableFrame(workspace.workspaceMonitor.rect.toAppKitScreenRect)
    let items = windowResizePreviewItems(
        in: workspace,
        weightMap: weightMap,
        excludingActiveWindowId: window.windowId,
    )
    guard !items.isEmpty else {
        logWindowDragLive("resizePreview hide requested reason=resizePreview.no-items window=\(window.windowId)")
        WindowTabStripPanelController.shared.clearHiddenPassiveTabGroupChrome()
        WindowResizePreviewPanel.shared.endStableFrame()
        WindowResizePreviewPanel.shared.hide(reason: "resizePreview.no-items")
        return
    }
    currentlyManipulatedWithMouseWindowId = window.windowId
    setCurrentMouseManipulationKind(.resize)
    WindowResizePreviewPanel.shared.show(items, presentation: .resizeOverlay)
}

@MainActor
func applyResizeWithMouse(_ window: Window, rect: Rect) {
    syncClosedWindowsCacheToCurrentWorld()
    guard let weightMap = proposedResizeWeightMap(window, rect: rect) else { return }
    if let widths = weightMap.columnWidths { window.nodeWorkspace?.columns?.widths = widths }
    for change in weightMap.changes {
        change.node.setWeight(change.orientation, change.weight)
    }
    currentlyManipulatedWithMouseWindowId = window.windowId
    setCurrentMouseManipulationKind(.resize)
    clearPendingWindowDragIntent()
}

struct WindowResizeWeightChange {
    let node: TreeNode
    let orientation: Orientation
    let weight: CGFloat
}

struct WindowResizePreviewWeightMap {
    var columnWidths: [CGFloat]?

    init() {}

    @MainActor init(columnWidths: [CGFloat], workspace: Workspace) {
        self.columnWidths = columnWidths
        let width = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps.width
        for child in workspace.rootTilingContainer.children {
            if let slot = child.columnSlot, columnWidths.indices.contains(slot - 1) {
                set(columnWidths[slot - 1] * width, for: child, orientation: .h)
            }
        }
    }
    private var weights: [WindowResizeWeightKey: CGFloat] = [:]
    private var nodes: [ObjectIdentifier: TreeNode] = [:]

    @MainActor
    var changes: [WindowResizeWeightChange] {
        weights.compactMap { key, weight in
            guard let node = nodes[key.nodeId] else { return nil }
            return WindowResizeWeightChange(node: node, orientation: key.orientation, weight: weight)
        }
    }

    mutating func set(_ weight: CGFloat, for node: TreeNode, orientation: Orientation) {
        let nodeId = ObjectIdentifier(node)
        weights[WindowResizeWeightKey(nodeId: nodeId, orientation: orientation)] = weight
        nodes[nodeId] = node
    }

    @MainActor
    func weight(for node: TreeNode, orientation: Orientation) -> CGFloat {
        weights[WindowResizeWeightKey(nodeId: ObjectIdentifier(node), orientation: orientation)] ??
            node.getWeight(orientation)
    }
}

private struct WindowResizeWeightKey: Hashable {
    let nodeId: ObjectIdentifier
    let orientation: Orientation
}

@MainActor
func proposedResizeWeightMap(_ window: Window, rect: Rect) -> WindowResizePreviewWeightMap? {
    guard window.parent is TilingContainer else { return nil }
    guard let lastAppliedLayoutRect = window.lastAppliedLayoutPhysicalRect else { return nil }
    var weightMap = WindowResizePreviewWeightMap()
    if let workspace = window.nodeWorkspace, let columns = workspace.columns,
       let slot = workspace.columnSlot(containing: window) {
        let leftParent = window.closestParent(hasChildrenInDirection: .left, withLayout: .tiles)?.0
        let rightParent = window.closestParent(hasChildrenInDirection: .right, withLayout: .tiles)?.0
        let leftDiff = lastAppliedLayoutRect.minX - rect.minX
        let rightDiff = rect.maxX - lastAppliedLayoutRect.maxX
        let left = leftParent == nil || leftParent === workspace.rootTilingContainer ? leftDiff : 0
        let right = rightParent == nil || rightParent === workspace.rootTilingContainer ? rightDiff : 0
        if abs(left + right) > 5 {
            let width = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps.width
            let base = columns.widthsBeforeMouseResize ?? columns.widths
            columns.widthsBeforeMouseResize = base
            // The dragged edge follows the pointer; the other Columns absorb in proportion.
            let before = base.prefix(slot - 1).reduce(0, +)
            let fraction = abs(right) >= abs(left)
                ? columns.fraction(slot: slot, rightEdgeAt: before + base[slot - 1] + right / width, starting: base)
                : columns.fraction(slot: slot, leftEdgeAt: before - left / width, starting: base)
            let widths = columns.proposedWidths(slot: slot, fraction: fraction, availableWidth: width, starting: base)
            weightMap = WindowResizePreviewWeightMap(columnWidths: widths, workspace: workspace)
        }
    }
    let (lParent, lOwnIndex) = window.closestParent(hasChildrenInDirection: .left, withLayout: .tiles) ?? (nil, nil)
    let (dParent, dOwnIndex) = window.closestParent(hasChildrenInDirection: .down, withLayout: .tiles) ?? (nil, nil)
    let (uParent, uOwnIndex) = window.closestParent(hasChildrenInDirection: .up, withLayout: .tiles) ?? (nil, nil)
    let (rParent, rOwnIndex) = window.closestParent(hasChildrenInDirection: .right, withLayout: .tiles) ?? (nil, nil)
    let table: [(CGFloat, TilingContainer?, Int?, Int?)] = [
        (lastAppliedLayoutRect.minX - rect.minX, lParent, 0,                        lOwnIndex),               // Horizontal, to the left of the window
        (rect.maxY - lastAppliedLayoutRect.maxY, dParent, dOwnIndex.map { $0 + 1 }, dParent?.children.count), // Vertical, to the down of the window
        (lastAppliedLayoutRect.minY - rect.minY, uParent, 0,                        uOwnIndex),               // Vertical, to the up of the window
        (rect.maxX - lastAppliedLayoutRect.maxX, rParent, rOwnIndex.map { $0 + 1 }, rParent?.children.count), // Horizontal, to the right of the window
    ]
    for (diff, parent, startIndex, pastTheEndIndex) in table {
        if let parent, let startIndex, let pastTheEndIndex, pastTheEndIndex - startIndex > 0 && abs(diff) > 5 { // 5 pixels should be enough to fight with accumulated floating precision error
            if parent.isRootContainer && window.nodeWorkspace?.columns != nil { continue }
            let orientation = parent.orientation
            let resizedNodes = Array(window.parentsWithSelf.lazy
                .prefix(while: { $0 != parent })
                .filter {
                    let parent = $0.parent as? TilingContainer
                    return parent?.orientation == orientation && parent?.layout == .tiles
                })
            let siblings = Array(parent.children[startIndex ..< pastTheEndIndex])
            let siblingMultiplier = -CGFloat(1).div(siblings.count).orDie()
            let constrainedDiff = constrainedTiledResizeDiff(
                diff,
                adjustments: resizedNodes.map {
                    TiledResizeAdjustment(weight: $0.getWeightBeforeResize(orientation), multiplier: 1)
                } + siblings.map {
                    TiledResizeAdjustment(weight: $0.getWeightBeforeResize(orientation), multiplier: siblingMultiplier)
                },
            )
            let siblingDiff = constrainedDiff.div(siblings.count).orDie()

            for node in resizedNodes {
                weightMap.set(node.getWeightBeforeResize(orientation) + constrainedDiff, for: node, orientation: orientation)
            }
            for sibling in siblings {
                weightMap.set(sibling.getWeightBeforeResize(orientation) - siblingDiff, for: sibling, orientation: orientation)
            }
        }
    }
    return weightMap
}

extension TreeNode {
    @MainActor
    func getWeightBeforeResize(_ orientation: Orientation) -> CGFloat {
        let currentWeight = getWeight(orientation) // Check assertions
        return getUserData(key: adaptiveWeightBeforeResizeWithMouseKey)
            ?? (lastAppliedLayoutVirtualRect?.getDimension(orientation) ?? currentWeight)
            .also { putUserData(key: adaptiveWeightBeforeResizeWithMouseKey, data: $0) }
    }

    func resetResizeWeightBeforeResizeRecursive() {
        if (self as? TilingContainer)?.isRootContainer == true { nodeWorkspace?.columns?.widthsBeforeMouseResize = nil }
        cleanUserData(key: adaptiveWeightBeforeResizeWithMouseKey)
        for child in children {
            child.resetResizeWeightBeforeResizeRecursive()
        }
    }
}
