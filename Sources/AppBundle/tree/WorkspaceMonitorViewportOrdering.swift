import AppKit

@MainActor func getOrCreateMonitorViewportFallbackWorkspace(for monitor: Monitor) -> Workspace {
    getOrCreateMonitorViewportFallbackWorkspace(
        projectId: activeWorkspaceProjectId(for: monitor),
        for: monitor,
    )
}

@MainActor func getOrCreateMonitorViewportFallbackWorkspace(projectId: WorkspaceProjectId, for monitor: Monitor) -> Workspace {
    getOrCreateFallbackWorkspace(
        projectId: projectId,
        monitor: monitor,
        excluding: nil,
    )
}

@MainActor func getOrCreateMonitorViewportFallbackWorkspace(
    projectId: WorkspaceProjectId,
    for monitor: Monitor,
    excluding excludedWorkspace: Workspace?,
) -> Workspace {
    getOrCreateFallbackWorkspace(
        projectId: projectId,
        monitor: monitor,
        excluding: excludedWorkspace,
    )
}

@MainActor
func getOrCreateFallbackWorkspace(
    projectId: WorkspaceProjectId,
    monitor: Monitor,
    excluding excludedWorkspace: Workspace?,
) -> Workspace {
    if let workspace = deckFallbackWorkspace(for: monitor, excluding: excludedWorkspace) {
        return workspace
    }
    let workspace = Workspace.get(byName: nextAutomaticWorkspaceName(projectId: projectId, monitor: monitor))
    workspace.markAsAutomaticallyNamed()
    workspace.assignProject(projectId)
    workspace.seedMonitorIfNeeded(monitor)
    return workspace
}

/// The deck's next card after the departing one (wrapping), or the column's active card
/// when nothing departs.
@MainActor
private func deckFallbackWorkspace(for monitor: Monitor, excluding excludedWorkspace: Workspace?) -> Workspace? {
    let viewport = monitor.defaultWorkspaceViewport
    let deck = orderedDeckWorkspaces(inColumn: columnDeckKey(for: viewport))
    guard !deck.isEmpty else { return nil }
    let start: Int = if let excludedWorkspace, let excludedIndex = deck.firstIndex(of: excludedWorkspace) {
        excludedIndex + 1
    } else if let activeCard = winMuxWorkspaceState.visibleWorkspace(for: viewport),
              let activeIndex = deck.firstIndex(of: activeCard)
    {
        activeIndex
    } else {
        0
    }
    let candidates = Array(deck[start...]) + Array(deck[..<start])
    return candidates.first {
        $0 != excludedWorkspace && workspaceIsAvailableForMonitor($0, monitor: viewport)
    }
}

@MainActor
func projectWorkspaces(projectId: WorkspaceProjectId) -> [Workspace] {
    guard let project = winMuxWorkspaceState.projectsById[projectId] else { return [] }
    let indexedWorkspaces = project.workspaceOrder
        .compactMap { winMuxWorkspaceState.workspaceById[$0] }
        .filter { $0.projectId == projectId }
    if !indexedWorkspaces.isEmpty {
        return indexedWorkspaces
    }
    return Workspace.all
        .filter { $0.projectId == projectId }
        .sorted()
}

@MainActor
func orderedWorkspaces(in projectId: WorkspaceProjectId) -> [Workspace] {
    projectWorkspaces(projectId: projectId)
        .filter { !$0.isArchived }
}

@MainActor
func orderedWorkspacesForPresentation() -> [Workspace] {
    var seen: Set<WorkspaceId> = []
    var result: [Workspace] = []
    for project in workspaceProjects() {
        for workspaceId in project.workspaceOrder {
            guard let workspace = winMuxWorkspaceState.workspaceById[workspaceId],
                  !workspace.isArchived,
                  seen.insert(workspaceId).inserted
            else { continue }
            result.append(workspace)
        }
    }
    result.append(contentsOf: Workspace.all.filter { !$0.isArchived && seen.insert($0.id).inserted })
    return result
}
