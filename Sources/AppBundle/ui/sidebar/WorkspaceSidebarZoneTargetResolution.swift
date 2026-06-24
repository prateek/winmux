struct WorkspaceSidebarResolvedZoneTarget {
    let monitorScopeId: String
    let zoneId: String
    let monitor: Monitor
    let activeWorkspace: Workspace
    let displayName: String
}

@MainActor
func workspaceSidebarResolvedZoneTarget(
    monitorScopeId: String,
    zoneId: String,
) -> WorkspaceSidebarResolvedZoneTarget? {
    guard let monitor = sortedMonitors.first(where: {
        $0.zoneId == zoneId &&
            workspaceSidebarMonitorScopeId(for: $0) == monitorScopeId
    }) else { return nil }
    return WorkspaceSidebarResolvedZoneTarget(
        monitorScopeId: monitorScopeId,
        zoneId: zoneId,
        monitor: monitor,
        activeWorkspace: monitor.activeWorkspace,
        displayName: workspaceSidebarZoneDisplayName(monitor),
    )
}

@MainActor
func workspaceSidebarResolvedZoneTarget(
    for targetKind: WorkspaceSidebarDropTargetKind?,
) -> WorkspaceSidebarResolvedZoneTarget? {
    guard case .zone(let monitorScopeId, let zoneId) = targetKind else { return nil }
    return workspaceSidebarResolvedZoneTarget(monitorScopeId: monitorScopeId, zoneId: zoneId)
}
