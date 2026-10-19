struct WorkspaceSidebarItemViewModel: Hashable, Identifiable, Sendable {
    let kind: WorkspaceSidebarItemKind
    var children: [WorkspaceSidebarItemViewModel] = []
    var realParent: WorkspaceSidebarNodeIdentity? = nil
    var indexInParent: Int = 0
    var columnSlot: Int? = nil
    var isFloating: Bool = false
    var isSearchAncestor: Bool = false
    var isSearchRevealed: Bool = false

    var id: String {
        switch kind {
            case .window(let window):
                "window:\(window.windowId)"
            case .tabGroup(let group):
                group.containerIdentity.map { "container:\($0)" } ?? group.id
            case .split(let identity, _, _): "container:\(identity)"
            case .column(let workspace, let slot, _): "column:\(workspace):\(slot)"
            case .floating(let workspace): "floating:\(workspace)"
        }
    }
}

enum WorkspaceSidebarItemKind: Hashable, Sendable {
    case window(WorkspaceSidebarWindowViewModel)
    case tabGroup(WorkspaceSidebarTabGroupViewModel)
    case split(ObjectIdentifier, orientation: String, layout: String)
    case column(workspace: String, slot: Int, fraction: Double)
    case floating(workspace: String)
}

enum WorkspaceSidebarNodeIdentity: Hashable, Sendable {
    case workspace(String)
    case container(ObjectIdentifier)
    case column(String, Int)
    case floating(String)
    case window(UInt32)
}

extension WorkspaceSidebarItemViewModel {
    var identity: WorkspaceSidebarNodeIdentity {
        switch kind {
            case .window(let window): .window(window.windowId)
            case .tabGroup(let group): group.containerIdentity.map(WorkspaceSidebarNodeIdentity.container) ?? .window(group.representativeWindowId)
            case .split(let identity, _, _): .container(identity)
            case .column(let workspace, let slot, _): .column(workspace, slot)
            case .floating(let workspace): .floating(workspace)
        }
    }

    var descendantItems: [Self] { [self] + children.flatMap(\.descendantItems) }
}
