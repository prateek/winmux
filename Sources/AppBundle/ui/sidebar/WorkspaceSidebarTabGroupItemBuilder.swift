@MainActor
func makeWorkspaceSidebarTabGroupViewModel(
    for container: TilingContainer,
    children: [WorkspaceSidebarItemViewModel],
    workspaceName: String,
    currentFocus: LiveFocus,
) -> WorkspaceSidebarTabGroupViewModel? {
    let representativeWindow = container.tabActiveWindow ?? container.mostRecentWindowRecursive ?? container.anyLeafWindowRecursive
    guard let representativeWindow else { return nil }
    let windows = children.flatMap(\.descendantItems).compactMap { item -> WorkspaceSidebarWindowViewModel? in
        if case .window(let window) = item.kind { return window }
        return nil
    }
    let windowsById = Dictionary(uniqueKeysWithValues: windows.map { ($0.windowId, $0) })
    let tabs = container.children.compactMap { child -> WorkspaceSidebarWindowViewModel? in
        guard let representative = child.tabRepresentativeWindow ?? child.mostRecentWindowRecursive ?? child.anyLeafWindowRecursive,
              representative.isBound else { return nil }
        return windowsById[representative.windowId]
    }
    guard !tabs.isEmpty else { return nil }
    return WorkspaceSidebarTabGroupViewModel(
        representativeWindowId: representativeWindow.windowId,
        workspaceName: workspaceName,
        title: sidebarDisplayLabel(for: representativeWindow),
        windowCount: container.allLeafWindowsRecursive.count,
        isFocused: representativeWindow.moveNode == currentFocus.windowOrNil?.moveNode,
        tabs: tabs,
        containerIdentity: container.stableId,
    )
}
