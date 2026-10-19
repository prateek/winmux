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
    var items: [WorkspaceSidebarItemViewModel] { didSet { rebuildDerivedItems() } }
    var columnWidths: [Double] = []
    var focusedColumn: Int? = nil
    var showsSplits: Bool = false { didSet { rebuildDerivedItems() } }
    var showsColumns: Bool = false { didSet { rebuildDerivedItems() } }
    var collapsedNodes: Set<WorkspaceSidebarNodeIdentity> = []

    private(set) var projectedItems: [WorkspaceSidebarItemViewModel] = []
    private var windowColumnSlots: [UInt32: Int] = [:]

    init(name: String, projectId: WorkspaceProjectId, displayName: String, sidebarLabel: String,
         isGeneratedName: Bool, monitorScopeId: String, monitorName: String?, isFocused: Bool,
         isVisible: Bool, items: [WorkspaceSidebarItemViewModel], columnWidths: [Double] = [],
         focusedColumn: Int? = nil, showsSplits: Bool = false, showsColumns: Bool = false,
         collapsedNodes: Set<WorkspaceSidebarNodeIdentity> = []) {
        self.name = name
        self.projectId = projectId
        self.displayName = displayName
        self.sidebarLabel = sidebarLabel
        self.isGeneratedName = isGeneratedName
        self.monitorScopeId = monitorScopeId
        self.monitorName = monitorName
        self.isFocused = isFocused
        self.isVisible = isVisible
        self.items = items
        self.columnWidths = columnWidths
        self.focusedColumn = focusedColumn
        self.showsSplits = showsSplits
        self.showsColumns = showsColumns
        self.collapsedNodes = collapsedNodes
        rebuildDerivedItems()
    }

    private mutating func rebuildDerivedItems() {
        projectedItems = workspaceSidebarProjectItems(items, splits: showsSplits, columns: showsColumns)
        windowColumnSlots = [:]
        for item in items.flatMap(\.descendantItems) {
            if case .window(let window) = item.kind, let slot = item.columnSlot {
                windowColumnSlots[window.windowId] = slot
            }
        }
    }

    func columnSlot(for windowId: UInt32?) -> Int? {
        guard let windowId else { return nil }
        return windowColumnSlots[windowId]
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
