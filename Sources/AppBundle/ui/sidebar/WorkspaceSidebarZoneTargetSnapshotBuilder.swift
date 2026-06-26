import Foundation

@MainActor
func buildWorkspaceSidebarZoneTargetViewModels(
    sortedMonitors: [Monitor],
    currentFocus: LiveFocus,
) -> [WorkspaceSidebarZoneTargetViewModel] {
    sortedMonitors.compactMap { monitor in
        guard let zoneId = monitor.zoneId else { return nil }
        let monitorScopeId = workspaceSidebarMonitorScopeId(for: monitor)
        let activeWorkspace = monitor.activeWorkspace
        return WorkspaceSidebarZoneTargetViewModel(
            id: "\(monitorScopeId):\(zoneId)",
            monitorScopeId: monitorScopeId,
            zoneId: zoneId,
            displayName: workspaceSidebarZoneDisplayName(monitor),
            activeWorkspaceName: activeWorkspace.name,
            activeWorkspaceDisplayName: workspaceDisplayName(activeWorkspace.name),
            isFocused: currentFocus.workspace === activeWorkspace,
            isDefaultZone: monitor.isDefaultZone,
            styleId: monitor.zoneStyleId,
            styleColorHex: monitor.zoneStyleColorHex,
        )
    }
}

func workspaceSidebarZoneDisplayName(_ monitor: Monitor) -> String {
    monitor.zoneName?.takeIf { !$0.isEmpty } ?? monitor.zoneId ?? "Zone"
}
