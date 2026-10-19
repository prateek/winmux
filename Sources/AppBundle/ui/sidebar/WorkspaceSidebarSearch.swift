import Foundation

func workspaceSidebarFilteredWorkspacesByProject(
    _ workspacesByProject: [WorkspaceProjectId: [WorkspaceSidebarWorkspaceViewModel]],
    projects: [WorkspaceSidebarProjectViewModel],
    query: String,
) -> [WorkspaceProjectId: [WorkspaceSidebarWorkspaceViewModel]] {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return workspacesByProject }
    return workspacesByProject.mapValues { workspaces in
        workspaces.compactMap { workspace in
            var result = workspace
            result.items = workspace.items.compactMap { workspaceSidebarSearchResultItem($0, query: query) }
            return result.items.isEmpty ? nil : result
        }
    }
}

private func workspaceSidebarWindowMatches(_ window: WorkspaceSidebarWindowViewModel, query: String) -> Bool {
    window.appName.localizedLowercase.contains(query) || window.title?.localizedLowercase.contains(query) == true
}

private func workspaceSidebarSearchResultItem(_ item: WorkspaceSidebarItemViewModel, query: String) -> WorkspaceSidebarItemViewModel? {
    var result = item
    if !item.children.isEmpty {
        result.children = item.children.compactMap { workspaceSidebarSearchResultItem($0, query: query) }
        guard !result.children.isEmpty else { return nil }
        result.isSearchAncestor = true
        result.isSearchRevealed = true
        return result
    }
    switch item.kind {
        case .window(let window):
            return workspaceSidebarWindowMatches(window, query: query) ? result : nil
        case .tabGroup(var group):
            let matches = group.tabs.filter { workspaceSidebarWindowMatches($0, query: query) }
            guard !matches.isEmpty else { return nil }
            group.searchVisibleTabs = matches
            result = .init(kind: .tabGroup(group), realParent: item.realParent, indexInParent: item.indexInParent, columnSlot: item.columnSlot, isSearchAncestor: true, isSearchRevealed: true)
            return result
        case .split, .column, .floating: return nil
    }
}
