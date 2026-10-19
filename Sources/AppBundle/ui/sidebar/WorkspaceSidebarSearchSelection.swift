enum WorkspaceSidebarSearchSelection: Hashable {
    case workspace(String)
    case window(UInt32)
}

func workspaceSidebarSearchSelections(
    workspaces: [WorkspaceSidebarWorkspaceViewModel],
) -> [WorkspaceSidebarSearchSelection] {
    workspaces.flatMap { workspace in
        let itemSelections = workspace.items.flatMap(\.descendantItems).flatMap { item -> [WorkspaceSidebarSearchSelection] in
            switch item.kind {
                case .window(let window):
                    return [.window(window.windowId)]
                case .tabGroup(let group):
                    if !item.children.isEmpty { return [] }
                    return (group.searchVisibleTabs ?? group.tabs).map { .window($0.windowId) }
                case .split, .column, .floating: return []
            }
        }
        return itemSelections.isEmpty ? [.workspace(workspace.name)] : itemSelections
    }
}
