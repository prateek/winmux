func workspaceSidebarShowsCreateWorkspace(selectedScopeId: String) -> Bool {
    selectedScopeId != workspaceSidebarFocusedScopeId
}

func workspaceSidebarWorkspaceIsInUseOnOtherDisplay(
    _ workspace: WorkspaceSidebarWorkspaceViewModel,
    selectedScopeId: String,
) -> Bool {
    guard selectedScopeId != workspaceSidebarDefaultScopeId,
          selectedScopeId != workspaceSidebarFocusedScopeId,
          workspace.isVisible
    else {
        return false
    }
    return workspace.monitorScopeId != selectedScopeId
}
