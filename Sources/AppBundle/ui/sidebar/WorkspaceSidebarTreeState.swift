struct WorkspaceSidebarTreeState {
    var defaults = WorkspaceSidebarTreeConfig()
    var splitOverrides: [String: Bool] = [:]
    var columnOverrides: [String: Bool] = [:]
    var collapsedNodes: Set<WorkspaceSidebarNodeIdentity> = []

    mutating func reload(defaults next: WorkspaceSidebarTreeConfig) {
        if defaults.splits != next.splits { splitOverrides.removeAll() }
        if defaults.columns != next.columns { columnOverrides.removeAll() }
        defaults = next
    }

    mutating func prune(workspaces: [WorkspaceSidebarWorkspaceViewModel]) {
        let identities = Set(workspaces.flatMap { [.workspace($0.name)] + $0.items.flatMap(\.descendantItems).map(\.identity) })
        collapsedNodes.formIntersection(identities)
        let names = Set(workspaces.map(\.name))
        splitOverrides = splitOverrides.filter { names.contains($0.key) }
        columnOverrides = columnOverrides.filter { names.contains($0.key) }
    }
}

func workspaceSidebarProjectItems(_ items: [WorkspaceSidebarItemViewModel], splits: Bool, columns: Bool) -> [WorkspaceSidebarItemViewModel] {
    items.flatMap { item -> [WorkspaceSidebarItemViewModel] in
        var projected = item
        projected.children = workspaceSidebarProjectItems(item.children, splits: splits, columns: columns)
        switch item.kind {
            case .split: return splits && item.children.count > 1 ? [projected] : projected.children
            case .column: return columns ? [projected] : projected.children
            case .floating: return splits ? [projected] : projected.children
            case .tabGroup(let group):
                if !splits, !item.isSearchRevealed {
                    let descendants = projected.children.flatMap(\.descendantItems)
                    projected.children = group.tabs.compactMap { tab in descendants.first { $0.identity == .window(tab.windowId) } }
                }
                return [projected]
            case .window: return [projected]
        }
    }
}
