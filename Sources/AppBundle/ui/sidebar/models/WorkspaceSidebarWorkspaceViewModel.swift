struct WorkspaceSidebarWorkspaceViewModel: Hashable, Identifiable {
    let name: String
    let projectId: WorkspaceProjectId
    let displayName: String
    let sidebarLabel: String
    let isGeneratedName: Bool
    let monitorScopeId: String
    let monitorName: String?
    let isFocused: Bool
    let isVisible: Bool
    let items: [WorkspaceSidebarItemViewModel]

    var id: String { name }
}

struct WorkspaceSidebarMonitorScopeViewModel: Hashable, Identifiable {
    let id: String
    let displayName: String
    let subtitle: String?
    let systemImageName: String
    let isFocusedMonitor: Bool
}

struct WorkspaceSidebarZoneTargetViewModel: Hashable, Identifiable {
    let id: String
    let monitorScopeId: String
    let zoneId: String
    let displayName: String
    let activeWorkspaceName: String
    let activeWorkspaceDisplayName: String
    let isFocused: Bool
    let isDefaultZone: Bool
    let styleId: String?
    let styleColorHex: String?
}
