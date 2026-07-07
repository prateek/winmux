struct WorkspaceSidebarResolvedColumnTarget {
    let monitorScopeId: String
    let columnId: String
    let monitor: Monitor
    let activeWorkspace: Workspace
    let displayName: String
}

@MainActor
func workspaceSidebarResolvedColumnTarget(
    monitorScopeId: String,
    columnId: String,
) -> WorkspaceSidebarResolvedColumnTarget? {
    guard let monitor = sortedMonitors.first(where: {
        $0.columnId == columnId &&
            workspaceSidebarMonitorScopeId(for: $0) == monitorScopeId
    }) else { return nil }
    return WorkspaceSidebarResolvedColumnTarget(
        monitorScopeId: monitorScopeId,
        columnId: columnId,
        monitor: monitor,
        activeWorkspace: monitor.activeWorkspace,
        displayName: workspaceSidebarColumnDisplayName(monitor),
    )
}

@MainActor
func workspaceSidebarResolvedColumnTarget(
    for targetKind: WorkspaceSidebarDropTargetKind?,
) -> WorkspaceSidebarResolvedColumnTarget? {
    guard case .column(let monitorScopeId, let columnId) = targetKind else { return nil }
    return workspaceSidebarResolvedColumnTarget(monitorScopeId: monitorScopeId, columnId: columnId)
}
