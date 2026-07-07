import AppKit
import Common

extension Monitor {
    @MainActor
    var activeWorkspace: Workspace {
        let viewport = workspaceViewportForWorkspaceAssignment
        if viewport.rect.topLeftCorner != rect.topLeftCorner || viewport.columnId != columnId {
            return viewport.activeWorkspace
        }
        if let existing = winMuxWorkspaceState.visibleWorkspace(for: viewport) {
            return existing
        }
        rearrangeWorkspacesOnMonitors()
        if let existing = winMuxWorkspaceState.visibleWorkspace(for: viewport) {
            return existing
        }
        let currentViewport = MonitorViewportId(viewport).currentMonitorApproximation
        if currentViewport.rect.topLeftCorner != viewport.rect.topLeftCorner || currentViewport.columnId != viewport.columnId {
            return currentViewport.activeWorkspace
        }
        die("Current monitor viewport '\(MonitorViewportId(viewport))' has no active workspace after reconciliation")
    }

    @MainActor
    func setActiveWorkspace(_ workspace: Workspace) -> Bool {
        let viewport = workspaceViewportForWorkspaceAssignment
        if !isValidAssignment(workspace: workspace, screen: viewport.rect.topLeftCorner) {
            return false
        }
        let viewportId = MonitorViewportId(viewport)
        guard !winMuxWorkspaceState.isWorkspaceActive(workspace.id, outside: viewportId) else {
            return false
        }
        _ = winMuxWorkspaceState.setActiveWorkspace(workspace, on: viewportId, deckColumnKey: columnDeckKey(for: viewport))
        checkWorkspaceHierarchyInvariants()
        return true
    }

    @MainActor
    private var workspaceViewportForWorkspaceAssignment: Monitor {
        defaultWorkspaceViewport
    }
}

@MainActor
func activateWorkspaceOnMonitorPreservingSourceViewport(_ workspace: Workspace, targetMonitor: Monitor) -> Bool {
    let sourceMonitor = workspace.isVisible ? workspace.workspaceMonitor : nil
    let sourceProjectId = workspace.projectId
    if let sourceMonitor,
       !sourceMonitor.hasSameWorkspaceViewport(as: targetMonitor)
    {
        let fallbackWorkspace = getOrCreateMonitorViewportFallbackWorkspace(
            projectId: sourceProjectId,
            for: sourceMonitor,
            excluding: workspace,
        )
        if !sourceMonitor.setActiveWorkspace(fallbackWorkspace) {
            let blankFallback = createBlankWorkspace(projectId: sourceProjectId, monitor: sourceMonitor)
            guard sourceMonitor.setActiveWorkspace(blankFallback) else {
                return false
            }
        }
    }
    guard targetMonitor.setActiveWorkspace(workspace) else { return false }
    return true
}

@MainActor
func overrideWorkspaceOnMonitorBySwappingActiveViewports(_ workspace: Workspace, targetMonitor: Monitor) -> Bool {
    guard isValidAssignment(workspace: workspace, screen: targetMonitor.rect.topLeftCorner) else {
        return false
    }
    guard workspace.isVisible else {
        return targetMonitor.setActiveWorkspace(workspace)
    }

    let sourceMonitor = workspace.workspaceMonitor
    guard !sourceMonitor.hasSameWorkspaceViewport(as: targetMonitor) else {
        return true
    }

    let sourceReplacement = nearestWorkspaceForOverrideSourceMonitor(
        excluding: workspace,
        sourceMonitor: sourceMonitor,
        targetMonitor: targetMonitor,
    )
    if let sourceReplacement {
        _ = winMuxWorkspaceState.setActiveWorkspace(sourceReplacement, on: MonitorViewportId(sourceMonitor), deckColumnKey: columnDeckKey(for: sourceMonitor))
    } else {
        let fallback = createBlankWorkspace(projectId: workspace.projectId, monitor: sourceMonitor)
        _ = winMuxWorkspaceState.setActiveWorkspace(fallback, on: MonitorViewportId(sourceMonitor), deckColumnKey: columnDeckKey(for: sourceMonitor))
    }
    _ = winMuxWorkspaceState.setActiveWorkspace(workspace, on: MonitorViewportId(targetMonitor), deckColumnKey: columnDeckKey(for: targetMonitor))
    checkWorkspaceHierarchyInvariants()
    return true
}

@MainActor
func nearestWorkspaceForOverrideSourceMonitor(
    excluding workspace: Workspace,
    sourceMonitor: Monitor,
    targetMonitor: Monitor,
) -> Workspace? {
    let candidates = orderedWorkspacesForPresentation()
        .filter { candidate in
                candidate.projectId == workspace.projectId &&
                candidate != workspace &&
                !candidate.isArchived &&
                isValidAssignment(workspace: candidate, screen: sourceMonitor.rect.topLeftCorner) &&
                (!candidate.isVisible || candidate.workspaceMonitor.hasSameWorkspaceViewport(as: targetMonitor))
        }
    guard let workspaceIndex = orderedWorkspacesForPresentation().firstIndex(of: workspace) else {
        return candidates.first
    }
    return candidates.min {
        abs((orderedWorkspacesForPresentation().firstIndex(of: $0) ?? Int.max) - workspaceIndex) <
            abs((orderedWorkspacesForPresentation().firstIndex(of: $1) ?? Int.max) - workspaceIndex)
    }
}

@MainActor
func gcMonitors() {
    rearrangeWorkspacesOnMonitors()
}

@MainActor
func checkWorkspaceHierarchyInvariants(requireActiveMonitorViewports: Bool = false) {
    for workspace in Workspace.all {
        check(winMuxWorkspaceState.projectsById[workspace.projectId] != nil, "Workspace '\(workspace.name)' references missing project '\(workspace.projectId)'")
    }

    for (viewportId, viewport) in winMuxWorkspaceState.monitorViewportsById {
        if let activeWorkspaceId = viewport.activeWorkspaceId {
            check(winMuxWorkspaceState.workspaceById[activeWorkspaceId] != nil, "Display viewport '\(viewportId)' references missing workspace '\(activeWorkspaceId)'")
            check(!winMuxWorkspaceState.isWorkspaceActive(activeWorkspaceId, outside: viewportId), "Workspace '\(activeWorkspaceId)' is active on more than one display viewport")
            if let workspace = winMuxWorkspaceState.workspaceById[activeWorkspaceId] {
                check(isValidAssignment(workspace: workspace, screen: viewportId.topLeftCorner), "Display viewport '\(viewportId)' has incompatible active workspace '\(workspace.name)'")
            }
        }
    }

    let columnDecks = winMuxWorkspaceState.columnDecks
    for workspace in Workspace.all where !workspace.isArchived {
        check(columnDecks.columnKey(of: workspace.id) != nil, "Workspace '\(workspace.name)' belongs to no column deck")
    }
    for (columnKey, deck) in columnDecks.decksByColumnKey {
        for cardId in deck {
            check(winMuxWorkspaceState.workspaceById[cardId] != nil, "Column deck '\(columnKey)' references missing workspace '\(cardId)'")
            check(columnDecks.columnKey(of: cardId) == columnKey, "Workspace '\(cardId)' is present in more than one column deck")
        }
        check(Set(deck).count == deck.count, "Column deck '\(columnKey)' contains duplicate cards")
    }

    guard requireActiveMonitorViewports else { return }
    // Deck keys follow display names while viewport identities follow geometry, so viewport
    // and deck can disagree between a display swap and the next reconciliation
    // (alignActiveCardsWithColumnDecks). Check the agreement only at the reconciled gate.
    for monitor in monitors {
        let viewportId = MonitorViewportId(monitor)
        guard let activeWorkspaceId = winMuxWorkspaceState.monitorViewportsById[viewportId]?.activeWorkspaceId else { continue }
        check(
            columnDecks.columnKey(of: activeWorkspaceId) == columnDeckKey(for: monitor),
            "Display viewport '\(viewportId)' shows workspace '\(activeWorkspaceId)' that is not in its column's deck",
        )
    }
    for monitor in monitors {
        let viewportId = MonitorViewportId(monitor)
        guard let viewport = winMuxWorkspaceState.monitorViewportsById[viewportId],
              let activeWorkspaceId = viewport.activeWorkspaceId,
              let workspace = winMuxWorkspaceState.workspaceById[activeWorkspaceId]
        else {
            check(false, "Current monitor viewport '\(viewportId)' has no active workspace after reconciliation")
            continue
        }
        check(isValidAssignment(workspace: workspace, screen: viewportId.topLeftCorner), "Current monitor viewport '\(viewportId)' has incompatible active workspace '\(workspace.name)'")
    }
}

@MainActor
func rearrangeWorkspacesOnMonitors() {
    let oldViewportsById = winMuxWorkspaceState.monitorViewportsById
    let currentMonitors = monitors
    let currentMonitorIds = Set(currentMonitors.map(MonitorViewportId.init))
    let activeViewportIds = Set(oldViewportsById.compactMap { viewportId, viewport -> MonitorViewportId? in
        guard let workspaceId = viewport.activeWorkspaceId,
              let workspace = winMuxWorkspaceState.workspaceById[workspaceId],
              isValidAssignment(workspace: workspace, screen: viewportId.topLeftCorner)
        else { return nil }
        return viewportId
    })
    if activeViewportIds == currentMonitorIds {
        return
    }

    remapColumnDecksOntoCurrentDisplays()

    var oldVisibleMonitors: Set<MonitorViewportId> = oldViewportsById.compactMap { viewportId, viewport in
        guard let activeWorkspaceId = viewport.activeWorkspaceId,
              winMuxWorkspaceState.workspaceById[activeWorkspaceId] != nil
        else { return nil }
        return viewportId
    }.toSet()

    let newMonitors = currentMonitors.map(MonitorViewportId.init)
    var newMonitorToOldMonitorMapping: [MonitorViewportId: MonitorViewportId] = [:]
    for newMonitor in newMonitors where oldVisibleMonitors.contains(newMonitor) {
        check(oldVisibleMonitors.remove(newMonitor) != nil)
        newMonitorToOldMonitorMapping[newMonitor] = newMonitor
    }
    for newMonitor in newMonitors {
        if newMonitorToOldMonitorMapping[newMonitor] != nil { continue }
        if let oldMonitor = oldVisibleMonitors.first(where: { $0.hasSameStableIdentity(as: newMonitor) }) {
            check(oldVisibleMonitors.remove(oldMonitor) != nil)
            newMonitorToOldMonitorMapping[newMonitor] = oldMonitor
        }
    }
    for newMonitor in newMonitors {
        if newMonitorToOldMonitorMapping[newMonitor] != nil { continue }
        if let oldMonitor = oldVisibleMonitors.minBy({ ($0.topLeftCorner - newMonitor.topLeftCorner).vectorLength }) {
            check(oldVisibleMonitors.remove(oldMonitor) != nil)
            newMonitorToOldMonitorMapping[newMonitor] = oldMonitor
        }
    }

    winMuxWorkspaceState.monitorViewportsById = [:]

    for (newMonitor, monitor) in zip(newMonitors, currentMonitors) {
        let newScreen = newMonitor.topLeftCorner
        let mappedOldMonitor = newMonitorToOldMonitorMapping[newMonitor]
        let preservedViewport = mappedOldMonitor.flatMap { oldViewportsById[$0] } ?? oldViewportsById[newMonitor]
        if var preservedViewport {
            preservedViewport = MonitorViewport(
                id: newMonitor,
                activeWorkspaceId: nil,
                previousWorkspaceId: preservedViewport.previousWorkspaceId,
                lastActiveWorkspaceByProject: preservedViewport.lastActiveWorkspaceByProject,
            )
            winMuxWorkspaceState.monitorViewportsById[newMonitor] = preservedViewport
        }
        let existingVisibleWorkspace = mappedOldMonitor
            .flatMap { oldViewportsById[$0]?.activeWorkspaceId }
            .flatMap { winMuxWorkspaceState.workspaceById[$0] }
        if let existingVisibleWorkspace,
           monitor.setActiveWorkspace(existingVisibleWorkspace)
        {
            continue
        }
        let projectId = existingVisibleWorkspace?.projectId ?? workspaceProjectDefaultId
        let workspace = getOrCreateFallbackWorkspace(
            projectId: projectId,
            monitor: monitor,
            excluding: existingVisibleWorkspace,
        )
        check(monitor.setActiveWorkspace(workspace),
              "Generated incompatible fallback workspace (\(workspace)) for the display viewport (\(newScreen)")
    }
}

@MainActor
func isValidAssignment(workspace: Workspace, screen: CGPoint) -> Bool {
    isValidAssignment(workspaceName: workspace.name, screen: screen)
}

@MainActor
func isValidAssignment(workspaceName: String, screen: CGPoint) -> Bool {
    guard let forceAssigned = resolvedForceAssignedPhysicalMonitor(forWorkspaceName: workspaceName) else { return true }
    guard let physicalMonitor = sortedPhysicalMonitors.first(where: { $0.rect.contains(screen) }) else {
        return false
    }
    return forceAssigned.rect.topLeftCorner == physicalMonitor.rect.topLeftCorner
}
