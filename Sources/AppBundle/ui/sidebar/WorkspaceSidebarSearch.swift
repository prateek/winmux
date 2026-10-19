import Foundation

func workspaceSidebarFilteredWorkspacesByProject(
    _ workspacesByProject: [WorkspaceProjectId: [WorkspaceSidebarWorkspaceViewModel]],
    projects: [WorkspaceSidebarProjectViewModel],
    query: String,
) -> [WorkspaceProjectId: [WorkspaceSidebarWorkspaceViewModel]] {
    let terms = query.split(whereSeparator: { $0.isWhitespace }).map { String($0).localizedLowercase }
    guard !terms.isEmpty else { return workspacesByProject }
    let projectNames = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.displayName) })
    return workspacesByProject.mapValues { workspaces in
        workspaces.compactMap { workspace in
            let projectName = projectNames[workspace.projectId]
            // Every window's text includes its workspace's names, so a workspace match keeps it whole.
            let workspaceMatches = workspaceSidebarSearchTextMatches(
                [workspace.displayName, workspace.sidebarLabel, workspace.name, workspace.monitorName, projectName], terms: terms)
            if workspaceMatches { return workspace }
            var result = workspace
            result.items = workspace.items.compactMap { workspaceSidebarSearchResultItem($0, workspace: workspace, projectName: projectName, terms: terms) }
            return result.items.isEmpty ? nil : result
        }
    }
}

private func workspaceSidebarSearchTextMatches(_ values: [String?], terms: [String]) -> Bool {
    let text = values.compactMap { $0?.localizedLowercase }.joined(separator: " ")
    return terms.allSatisfy { text.contains($0) }
}

private func workspaceSidebarWindowMatches(_ window: WorkspaceSidebarWindowViewModel, workspace: WorkspaceSidebarWorkspaceViewModel, projectName: String?, terms: [String]) -> Bool {
    workspaceSidebarSearchTextMatches(
        [window.title, window.appName, window.appBundleId, window.appBundlePath, workspace.displayName, workspace.name, projectName], terms: terms)
}

private func workspaceSidebarSearchResultItem(_ item: WorkspaceSidebarItemViewModel, workspace: WorkspaceSidebarWorkspaceViewModel, projectName: String?, terms: [String]) -> WorkspaceSidebarItemViewModel? {
    var result = item
    switch item.kind {
        case .window(let window):
            return workspaceSidebarWindowMatches(window, workspace: workspace, projectName: projectName, terms: terms) ? item : nil
        case .tabGroup(var group):
            let matches = group.tabs.filter { workspaceSidebarWindowMatches($0, workspace: workspace, projectName: projectName, terms: terms) }
            result.children = item.children.compactMap { workspaceSidebarSearchResultItem($0, workspace: workspace, projectName: projectName, terms: terms) }
            let titleMatches = workspaceSidebarSearchTextMatches([group.title, workspace.displayName, workspace.name, projectName], terms: terms)
            guard !matches.isEmpty || !result.children.isEmpty || titleMatches else { return nil }
            group.searchVisibleTabs = matches
            result = .init(kind: .tabGroup(group), children: result.children, realParent: item.realParent, indexInParent: item.indexInParent, columnSlot: item.columnSlot, isSearchAncestor: !titleMatches, isSearchRevealed: true)
            return result
        case .split, .column, .floating:
            result.children = item.children.compactMap { workspaceSidebarSearchResultItem($0, workspace: workspace, projectName: projectName, terms: terms) }
            guard !result.children.isEmpty else { return nil }
            result.isSearchAncestor = true
            result.isSearchRevealed = true
            return result
    }
}
