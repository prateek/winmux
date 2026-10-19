@MainActor
func buildWorkspaceSidebarItems(
    for workspace: Workspace,
    currentFocus: LiveFocus,
) async -> [WorkspaceSidebarItemViewModel] {
    workspaceSidebarProjectItems(await buildWorkspaceSidebarLayoutTree(for: workspace, currentFocus: currentFocus), splits: false, columns: false)
}
