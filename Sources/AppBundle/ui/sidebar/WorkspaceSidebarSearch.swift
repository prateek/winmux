import Foundation

func workspaceSidebarFilteredWorkspaces(
    _ workspaces: [WorkspaceSidebarWorkspaceViewModel],
    query: String,
) -> [WorkspaceSidebarWorkspaceViewModel] {
    let terms = workspaceSidebarSearchTerms(query)
    guard !terms.isEmpty else { return workspaces }
    return workspaces.compactMap { workspace in
        workspaceSidebarFilteredWorkspace(workspace, terms: terms)
    }
}

private func workspaceSidebarFilteredWorkspace(
    _ workspace: WorkspaceSidebarWorkspaceViewModel,
    terms: [String],
) -> WorkspaceSidebarWorkspaceViewModel? {
    let matchingItems = workspace.items.compactMap { item in
        workspaceSidebarSearchResultItem(item, workspace: workspace, terms: terms)
    }
    if !matchingItems.isEmpty {
        return WorkspaceSidebarWorkspaceViewModel(
            name: workspace.name,
            projectId: workspace.projectId,
            displayName: workspace.displayName,
            sidebarLabel: workspace.sidebarLabel,
            isGeneratedName: workspace.isGeneratedName,
            monitorScopeId: workspace.monitorScopeId,
            monitorName: workspace.monitorName,
            isFocused: workspace.isFocused,
            isVisible: workspace.isVisible,
            items: matchingItems,
        )
    }
    if workspaceSidebarWorkspaceMatchesSearch(workspace, terms: terms) {
        return workspace
    }
    return nil
}

private func workspaceSidebarSearchTerms(_ query: String) -> [String] {
    query
        .split(whereSeparator: { $0.isWhitespace })
        .map { String($0).localizedLowercase }
        .filter { !$0.isEmpty }
}

private func workspaceSidebarSearchResultItem(
    _ item: WorkspaceSidebarItemViewModel,
    workspace: WorkspaceSidebarWorkspaceViewModel,
    terms: [String],
) -> WorkspaceSidebarItemViewModel? {
    switch item.kind {
        case .window(let window):
            if workspaceSidebarSearchTextMatches(
                [
                    window.title,
                    window.appName,
                    window.appBundleId,
                    window.appBundlePath,
                    workspace.displayName,
                    workspace.name,
                ],
                terms: terms,
            ) {
                return item
            }
            return nil
        case .tabGroup(let group):
            let matchingTabs = group.tabs.filter { tab in
                workspaceSidebarSearchTextMatches(
                    [tab.title, tab.appName, tab.appBundleId, tab.appBundlePath, workspace.displayName, workspace.name],
                    terms: terms,
                )
            }
            if !matchingTabs.isEmpty {
                return WorkspaceSidebarItemViewModel(kind: .tabGroup(WorkspaceSidebarTabGroupViewModel(
                    representativeWindowId: group.representativeWindowId,
                    workspaceName: group.workspaceName,
                    title: group.title,
                    windowCount: group.windowCount,
                    isFocused: group.isFocused,
                    tabs: group.tabs,
                    searchVisibleTabs: matchingTabs,
                )))
            }
            guard workspaceSidebarSearchTextMatches(
                [
                    group.title,
                    workspace.displayName,
                    workspace.name,
                ],
                terms: terms,
            ) else {
                return nil
            }
            return WorkspaceSidebarItemViewModel(kind: .tabGroup(WorkspaceSidebarTabGroupViewModel(
                representativeWindowId: group.representativeWindowId,
                workspaceName: group.workspaceName,
                title: group.title,
                windowCount: group.windowCount,
                isFocused: group.isFocused,
                tabs: group.tabs,
                searchVisibleTabs: [],
            )))
    }
}

private func workspaceSidebarWorkspaceMatchesSearch(
    _ workspace: WorkspaceSidebarWorkspaceViewModel,
    terms: [String],
) -> Bool {
    workspaceSidebarSearchTextMatches(
        [
            workspace.displayName,
            workspace.sidebarLabel,
            workspace.name,
            workspace.monitorName,
        ],
        terms: terms,
    )
}

private func workspaceSidebarSearchTextMatches(_ values: [String?], terms: [String]) -> Bool {
    let searchableText = values
        .compactMap { $0?.localizedLowercase }
        .joined(separator: " ")
    return terms.allSatisfy { searchableText.contains($0) }
}
