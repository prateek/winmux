import AppKit

@MainActor
func currentColumnDragDestination(sourceWindow: Window, workspace: Workspace, mouseLocation: CGPoint,
                                  subject: WindowDragSubject, detachOrigin: TabDetachOrigin) -> WindowDragIntentDestination? {
    guard let columns = workspace.columns, !sourceWindow.isFloating,
          detachOrigin != .tabStrip else { return nil }
    let rect = workspace.rootTilingContainer.lastAppliedLayoutPhysicalRect ?? workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
    guard rect.contains(mouseLocation),
          !workspace.rootTilingContainer.allTabbedContainersRecursive.contains(where: {
              $0.windowTabDropZoneRect?.contains(mouseLocation) == true
          }) else { return nil }
    let gaps = ResolvedGaps(gaps: config.gaps, monitor: workspace.workspaceMonitor)
    let gap = gaps.inner.get(.h).toDouble()
    func distance(_ slot: Int) -> CGFloat {
        let frame = ColumnState.frame(slot: slot, widths: columns.widths, in: rect.cgRect, gap: gap)
        return max(frame.minX - mouseLocation.x, mouseLocation.x - frame.maxX, 0)
    }
    let slot = (1...columns.slotCount).min { left, right in
        return distance(left) < distance(right)
    }.orDie()
    let incoming = dragSubjectNode(for: sourceWindow, subject: subject)
    guard workspace.columnSlot(containing: incoming) != slot else { return nil }
    let decision = ColumnDropDecisionCache.shared.preview(window: sourceWindow, workspace: workspace, slot: slot, incoming: incoming) {
        guard isLeftMouseButtonDown, currentlyManipulatedWithMouseWindowId == sourceWindow.windowId else { return }
        _ = updatePendingWindowDragIntent(sourceWindow: sourceWindow, mouseLocation: MousePointerTracker.shared.currentSample.point,
                                         subject: subject, detachOrigin: detachOrigin)
    }
    return columnDragDestination(workspace: workspace, slot: slot, decision: decision, incoming: incoming,
                                 rect: rect, subject: subject)
}

@MainActor
func columnDragDestination(workspace: Workspace, slot: Int, decision: PlacementDecision, incoming: TreeNode,
                           rect: Rect, subject: WindowDragSubject) -> WindowDragIntentDestination {
    let placement = ColumnPlacement.resolve(decision, columns: workspace.columns.orDie(),
                                            children: workspace.rootTilingContainer.children, incoming: incoming)
    let gaps = ResolvedGaps(gaps: config.gaps, monitor: workspace.workspaceMonitor)
    let frame = placement.verticalRange.map { _ in
        ColumnPlacement.frame(placement, in: rect.cgRect, horizontalGap: gaps.inner.get(.h).toDouble(), verticalGap: gaps.inner.get(.v).toDouble())
    }.map { Rect(topLeftX: $0.minX, topLeftY: $0.minY, width: $0.width, height: $0.height) }
    let title: String
    switch placement.effect {
        case .float: title = "Float"
        case .split: title = "Column \(placement.slot) · split"
        case .attach:
            if placement.widths.count > workspace.columns.orDie().widths.count {
                title = "New Column · squeeze"
            } else if ColumnPlacement.isOccupied(workspace.rootTilingContainer.children.first { $0.columnSlot == placement.slot }, excluding: incoming) {
                title = "Column \(placement.slot) · tab group"
            } else {
                title = "Column \(placement.slot)"
            }
    }
    return WindowDragIntentDestination(kind: .column(workspaceName: workspace.name, slot: slot, decision: decision), previewRect: frame ?? rect,
        interactionRect: rect, title: title, subtitle: "Drop to place this item", previewStyle: .workspaceMove,
        previewGeometry: .rounded, isGroup: subject == .group,
        dropIntentOverlay: frame.map { WindowDropIntentOverlayModel(targetFrame: $0, activeZone: nil, cornerRadius: nil, plainTarget: true) })
}
