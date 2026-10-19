struct WorkspaceSidebarWorkspaceViewModel: Hashable, Identifiable {
    let name: String
    let projectId: WorkspaceProjectId
    let displayName: String
    let sidebarLabel: String
    let isGeneratedName: Bool
    let monitorScopeId: String
    let monitorName: String?
    var isFocused: Bool
    var isVisible: Bool
    var items: [WorkspaceSidebarItemViewModel]
    var columnWidths: [Double] = []
    var focusedColumn: Int? = nil
    var showsSplits: Bool = false
    var showsColumns: Bool = false
    var collapsedNodes: Set<WorkspaceSidebarNodeIdentity> = []

    var projectedItems: [WorkspaceSidebarItemViewModel] {
        workspaceSidebarProjectItems(items, splits: showsSplits, columns: showsColumns)
    }

    func columnSlot(for windowId: UInt32?) -> Int? {
        guard let windowId else { return nil }
        return items.flatMap(\.descendantItems).first { $0.identity == .window(windowId) }?.columnSlot
    }

    var id: String { name }
}

struct WorkspaceSidebarMonitorScopeViewModel: Hashable, Identifiable {
    let id: String
    let displayName: String
    let subtitle: String?
    let systemImageName: String
    let isFocusedMonitor: Bool
}
