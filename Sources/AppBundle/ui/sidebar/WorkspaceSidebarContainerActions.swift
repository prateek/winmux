import Common

enum WorkspaceSidebarContainerAction: CaseIterable {
    case tabs
    case sideBySide
    case stacked
    case ungroup

    var title: String {
        switch self {
            case .tabs: "Tabs"
            case .sideBySide: "Split side by side"
            case .stacked: "Split stacked"
            case .ungroup: "Ungroup"
        }
    }
}

@MainActor
@discardableResult
func changeWorkspaceSidebarContainer(identity: UInt64, workspaceName: String, layout: Layout?, orientation: Orientation?, flattenTabs: Bool = false) -> Bool {
    guard let container = workspaceSidebarLiveContainer(identity, workspaceName: workspaceName) else { return false }
    if flattenTabs, layout == .tabGroup, container.children.contains(where: { $0 is TilingContainer }) {
        let leaves = container.allLeafWindowsRecursive
        for child in container.children { child.unbindFromParent() }
        for leaf in leaves { leaf.bind(to: container, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST) }
    }
    container.layout = layout ?? container.layout
    container.changeOrientation(orientation ?? container.orientation)
    return true
}

@MainActor
func workspaceSidebarUngroupRefusal(_ container: TilingContainer) -> String? {
    guard container.parent is TilingContainer else { return "The workspace root cannot be ungrouped" }
    if let workspace = container.nodeWorkspace, workspace.columns != nil, container.parent === workspace.rootTilingContainer {
        return "Change it to a split or tabs instead"
    }
    return nil
}

@MainActor
@discardableResult
func ungroupWorkspaceSidebarContainer(identity: UInt64, workspaceName: String) -> Bool {
    guard let container = workspaceSidebarLiveContainer(identity, workspaceName: workspaceName),
          workspaceSidebarUngroupRefusal(container) == nil,
          let parent = container.parent as? TilingContainer, let index = container.ownIndex else { return false }
    let children = parent.layout == .tabGroup ? container.allLeafWindowsRecursive : container.children
    for (offset, child) in children.enumerated() {
        child.bind(to: parent, adaptiveWeight: WEIGHT_AUTO, index: index + offset)
    }
    return true
}

@MainActor
func workspaceSidebarContainerActionIsCurrent(_ action: WorkspaceSidebarContainerAction, container: TilingContainer) -> Bool {
    switch action {
        case .tabs: container.layout == .tabGroup
        case .sideBySide: container.layout == .tiles && container.orientation == .h
        case .stacked: container.layout == .tiles && container.orientation == .v
        case .ungroup: false
    }
}

@MainActor
@discardableResult
func applyWorkspaceSidebarContainerAction(_ action: WorkspaceSidebarContainerAction, identity: UInt64, workspaceName: String) -> Bool {
    guard let container = workspaceSidebarLiveContainer(identity, workspaceName: workspaceName) else { return false }
    if action == .tabs, !config.windowTabs.enabled { return false }
    if workspaceSidebarContainerActionIsCurrent(action, container: container) { return true }
    switch action {
        case .tabs: return changeWorkspaceSidebarContainer(identity: identity, workspaceName: workspaceName, layout: .tabGroup, orientation: nil, flattenTabs: true)
        case .sideBySide: return changeWorkspaceSidebarContainer(identity: identity, workspaceName: workspaceName, layout: .tiles, orientation: .h)
        case .stacked: return changeWorkspaceSidebarContainer(identity: identity, workspaceName: workspaceName, layout: .tiles, orientation: .v)
        case .ungroup: return ungroupWorkspaceSidebarContainer(identity: identity, workspaceName: workspaceName)
    }
}

@MainActor
@discardableResult
func flipWorkspaceSidebarSplit(identity: UInt64, workspaceName: String) -> Bool {
    guard let container = workspaceSidebarLiveContainer(identity, workspaceName: workspaceName), container.layout == .tiles else { return false }
    return changeWorkspaceSidebarContainer(identity: identity, workspaceName: workspaceName, layout: nil, orientation: container.orientation.opposite)
}
