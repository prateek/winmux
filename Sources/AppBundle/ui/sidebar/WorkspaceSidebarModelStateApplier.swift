import AppKit

@MainActor
func clearWorkspaceSidebarModelState() {
    if !TrayMenuModel.shared.workspaceSidebarWorkspaces.isEmpty {
        TrayMenuModel.shared.workspaceSidebarWorkspaces = []
    }
    if !TrayMenuModel.shared.workspaceSidebarMonitorScopes.isEmpty {
        TrayMenuModel.shared.workspaceSidebarMonitorScopes = []
    }
    if !TrayMenuModel.shared.workspaceSidebarZoneTargets.isEmpty {
        TrayMenuModel.shared.workspaceSidebarZoneTargets = []
    }
    if !TrayMenuModel.shared.workspaceSidebarColumnSections.isEmpty {
        TrayMenuModel.shared.workspaceSidebarColumnSections = []
    }
    if !TrayMenuModel.shared.workspaceSidebarProjects.isEmpty {
        TrayMenuModel.shared.workspaceSidebarProjects = []
    }
    TrayMenuModel.shared.workspaceSidebarShowsMonitorSelector = false
    WorkspaceSidebarPanel.refreshAll()
}

@MainActor
func applyWorkspaceSidebarModelState(_ state: WorkspaceSidebarModelState, previousTopPadding: CGFloat) {
    let didMonitorScopeChange =
        TrayMenuModel.shared.workspaceSidebarMonitorScopes != state.monitorScopes ||
        TrayMenuModel.shared.workspaceSidebarFocusedMonitorScopeId != state.focusedMonitorScopeId ||
        TrayMenuModel.shared.workspaceSidebarShowsMonitorSelector != state.showsMonitorSelector
    let didZoneTargetChange =
        TrayMenuModel.shared.workspaceSidebarZoneTargets != state.zoneTargets ||
        TrayMenuModel.shared.workspaceSidebarColumnSections != state.columnSections
    let didProjectChange =
        TrayMenuModel.shared.workspaceSidebarProjects != state.projects ||
        TrayMenuModel.shared.workspaceSidebarActiveProjectId != state.activeProjectId

    updateWorkspaceSidebarTrayModel(with: state)
    WorkspaceSidebarPanel.syncVisiblePanelModelsFromShared()
    let didWorkspaceChange = TrayMenuModel.shared.workspaceSidebarWorkspaces != state.workspaces
    if didWorkspaceChange {
        TrayMenuModel.shared.workspaceSidebarWorkspaces = state.workspaces
        WorkspaceSidebarPanel.syncVisiblePanelModelsFromShared()
    }
    if didWorkspaceChange ||
        state.topPadding != previousTopPadding ||
        didMonitorScopeChange ||
        didZoneTargetChange ||
        didProjectChange ||
        WorkspaceSidebarPanel.visiblePanels.isEmpty
    {
        WorkspaceSidebarPanel.refreshAll()
    }
}

@MainActor
private func updateWorkspaceSidebarTrayModel(with state: WorkspaceSidebarModelState) {
    TrayMenuModel.shared.workspaceSidebarTopPadding = state.topPadding
    TrayMenuModel.shared.workspaceSidebarHoveredWorkspaceName = state.hoveredWorkspaceName
    TrayMenuModel.shared.workspaceSidebarProjects = state.projects
    TrayMenuModel.shared.workspaceSidebarActiveProjectId = state.activeProjectId
    TrayMenuModel.shared.workspaceSidebarMonitorScopes = state.monitorScopes
    TrayMenuModel.shared.workspaceSidebarZoneTargets = state.zoneTargets
    TrayMenuModel.shared.workspaceSidebarColumnSections = state.columnSections
    TrayMenuModel.shared.workspaceSidebarFocusedMonitorScopeId = state.focusedMonitorScopeId
    TrayMenuModel.shared.workspaceSidebarShowsMonitorSelector = state.showsMonitorSelector
}
