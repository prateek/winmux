import CoreGraphics

struct WorkspaceSidebarSnapshot: Equatable {
    var workspaces: [WorkspaceSidebarWorkspaceViewModel]
    var monitorScopes: [WorkspaceSidebarMonitorScopeViewModel]
    var zoneTargets: [WorkspaceSidebarZoneTargetViewModel] = []
    var columnSections: [WorkspaceSidebarColumnSectionViewModel] = []
    var sceneSwitchTargets: [WorkspaceSidebarSceneTargetViewModel] = []
    var selectedMonitorScopeId: String
    var targetMonitorScopeId: String
    var focusedMonitorScopeId: String
    var visibleWidth: CGFloat
    var hoveredWorkspaceName: String?
    var dropPreview: WorkspaceSidebarDropPreviewViewModel?
    var configuration: WorkspaceSidebarConfiguration

    static let empty = WorkspaceSidebarSnapshot(
        workspaces: [],
        monitorScopes: [],
        zoneTargets: [],
        columnSections: [],
        sceneSwitchTargets: [],
        selectedMonitorScopeId: workspaceSidebarDefaultScopeId,
        targetMonitorScopeId: workspaceSidebarDefaultScopeId,
        focusedMonitorScopeId: "",
        visibleWidth: 0,
        hoveredWorkspaceName: nil,
        dropPreview: nil,
        configuration: .empty,
    )
}

struct WorkspaceSidebarConfiguration: Equatable {
    var collapsedWidth: CGFloat
    var expandedWidth: CGFloat
    var topPadding: CGFloat
    var showMonitorSelector: Bool
    var showsDate: Bool
    var showsStatusPills: Bool

    static let empty = WorkspaceSidebarConfiguration(
        collapsedWidth: 0,
        expandedWidth: 0,
        topPadding: 12,
        showMonitorSelector: false,
        showsDate: false,
        showsStatusPills: false,
    )
}

enum WorkspaceSidebarAction: Equatable {
    case selectWorkspace(String)
    case overrideWorkspaceInUse(String)
    case selectWindow(UInt32)
    case selectMonitorScope(String)
    case createWorkspace(projectId: WorkspaceProjectId, monitorScopeId: String)
    case renameWorkspace(String, displayName: String)
    case deleteWorkspace(String)
    case moveWindow(UInt32, toWorkspace: String)
    case moveTabGroup(UInt32, toWorkspace: String)
    case moveWindowToZone(UInt32, monitorScopeId: String, zoneId: String)
    case moveTabGroupToZone(UInt32, monitorScopeId: String, zoneId: String)
    case moveWindowToNewWorkspace(UInt32, projectId: WorkspaceProjectId, monitorScopeId: String)
    case moveTabGroupToNewWorkspace(UInt32, projectId: WorkspaceProjectId, monitorScopeId: String)
    case moveCard(String, target: WorkspaceSidebarDropTargetKind)
    case previewWindowDrop(UInt32, target: WorkspaceSidebarDropTargetKind)
    case previewTabGroupDrop(UInt32, target: WorkspaceSidebarDropTargetKind)
    case clearDropPreview
}

struct WorkspaceSidebarActions {
    var send: @MainActor (WorkspaceSidebarAction) -> Void
    var setDropTargets: @MainActor ([WorkspaceSidebarDropTargetFrame]) -> Void
    var hoverWorkspace: @MainActor (String, Bool) -> Void
    var windowDragChanged: @MainActor (UInt32, CGPoint) -> Void
    var windowDragEnded: @MainActor (UInt32, CGPoint) -> Void
    var tabGroupDragChanged: @MainActor (UInt32, CGPoint) -> Void
    var tabGroupDragEnded: @MainActor (UInt32, CGPoint) -> Void

    init(
        send: @escaping @MainActor (WorkspaceSidebarAction) -> Void = { _ in },
        setDropTargets: @escaping @MainActor ([WorkspaceSidebarDropTargetFrame]) -> Void = { _ in },
        hoverWorkspace: @escaping @MainActor (String, Bool) -> Void = { _, _ in },
        windowDragChanged: @escaping @MainActor (UInt32, CGPoint) -> Void = { _, _ in },
        windowDragEnded: @escaping @MainActor (UInt32, CGPoint) -> Void = { _, _ in },
        tabGroupDragChanged: @escaping @MainActor (UInt32, CGPoint) -> Void = { _, _ in },
        tabGroupDragEnded: @escaping @MainActor (UInt32, CGPoint) -> Void = { _, _ in }
    ) {
        self.send = send
        self.setDropTargets = setDropTargets
        self.hoverWorkspace = hoverWorkspace
        self.windowDragChanged = windowDragChanged
        self.windowDragEnded = windowDragEnded
        self.tabGroupDragChanged = tabGroupDragChanged
        self.tabGroupDragEnded = tabGroupDragEnded
    }
}
