import AppKit

struct WorkspaceSidebarModelState {
    let workspaces: [WorkspaceSidebarWorkspaceViewModel]
    let monitorScopes: [WorkspaceSidebarMonitorScopeViewModel]
    let columnTargets: [WorkspaceSidebarColumnTargetViewModel]
    let columnSections: [WorkspaceSidebarColumnSectionViewModel]
    let sceneSwitchTargets: [WorkspaceSidebarSceneTargetViewModel]
    let focusedMonitorScopeId: String
    let showsMonitorSelector: Bool
    let topPadding: CGFloat
    let hoveredWorkspaceName: String?
}
