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
    if !TrayMenuModel.shared.workspaceSidebarSceneSwitchTargets.isEmpty {
        TrayMenuModel.shared.workspaceSidebarSceneSwitchTargets = []
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
        TrayMenuModel.shared.workspaceSidebarColumnSections != state.columnSections ||
        TrayMenuModel.shared.workspaceSidebarSceneSwitchTargets != state.sceneSwitchTargets

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
        WorkspaceSidebarPanel.visiblePanels.isEmpty
    {
        WorkspaceSidebarPanel.refreshAll()
    }
}

@MainActor
private func updateWorkspaceSidebarTrayModel(with state: WorkspaceSidebarModelState) {
    TrayMenuModel.shared.workspaceSidebarTopPadding = state.topPadding
    TrayMenuModel.shared.workspaceSidebarHoveredWorkspaceName = state.hoveredWorkspaceName
    TrayMenuModel.shared.workspaceSidebarMonitorScopes = state.monitorScopes
    TrayMenuModel.shared.workspaceSidebarZoneTargets = state.zoneTargets
    TrayMenuModel.shared.workspaceSidebarColumnSections = state.columnSections
    TrayMenuModel.shared.workspaceSidebarSceneSwitchTargets = state.sceneSwitchTargets
    TrayMenuModel.shared.workspaceSidebarFocusedMonitorScopeId = state.focusedMonitorScopeId
    TrayMenuModel.shared.workspaceSidebarShowsMonitorSelector = state.showsMonitorSelector
}
