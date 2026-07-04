import Foundation

@MainActor
func workspaceSidebarSnapshot(from model: TrayMenuModel) -> WorkspaceSidebarSnapshot {
    WorkspaceSidebarSnapshot(
        workspaces: model.workspaceSidebarWorkspaces,
        monitorScopes: model.workspaceSidebarMonitorScopes,
        zoneTargets: model.workspaceSidebarZoneTargets,
        columnSections: model.workspaceSidebarColumnSections,
        sceneSwitchTargets: model.workspaceSidebarSceneSwitchTargets,
        selectedMonitorScopeId: model.workspaceSidebarSelectedMonitorScopeId,
        targetMonitorScopeId: model.workspaceSidebarTargetMonitorScopeId,
        focusedMonitorScopeId: model.workspaceSidebarFocusedMonitorScopeId,
        visibleWidth: model.workspaceSidebarVisibleWidth,
        hoveredWorkspaceName: model.workspaceSidebarHoveredWorkspaceName,
        dropPreview: model.workspaceSidebarDropPreview,
        configuration: workspaceSidebarConfiguration(),
    )
}
