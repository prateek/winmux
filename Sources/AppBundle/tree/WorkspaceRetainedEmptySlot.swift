@MainActor
func workspaceIsRetainedEmptySlot(_ workspace: Workspace) -> Bool {
    guard let columnKey = winMuxWorkspaceState.columnDecks.columnKey(of: workspace.id) else { return false }
    return retainedEmptyWorkspaceId(inColumn: columnKey) == workspace.id
}

@MainActor
func retainedEmptyWorkspaceIdsByColumn() -> [String: WorkspaceId] {
    let columnKeys = Set(Workspace.all.filter { !$0.isArchived }.compactMap { winMuxWorkspaceState.columnDecks.columnKey(of: $0.id) })
    return Dictionary(
        uniqueKeysWithValues: columnKeys.compactMap { columnKey in
            retainedEmptyWorkspaceId(inColumn: columnKey).map { (columnKey, $0) }
        },
    )
}

@MainActor
func retainedEmptyWorkspaceId(inColumn columnKey: String) -> WorkspaceId? {
    let orderedWorkspaces = orderedDeckWorkspaces(inColumn: columnKey)
    let ordinaryEmptyWorkspaces = orderedWorkspaces.filter(\.isOrdinaryEmptySlot).sorted {
        if $0.lifecycle != $1.lifecycle {
            return $0.lifecycle == .durable
        }
        return $0 < $1
    }
    guard !ordinaryEmptyWorkspaces.isEmpty else { return nil }

    let hasAnchors = orderedWorkspaces.contains(where: workspaceAnchorsEmptySlot)
    guard hasAnchors else {
        return ordinaryEmptyWorkspaces.first(where: \.isVisible)?.id ?? ordinaryEmptyWorkspaces.first?.id
    }

    if let visibleEmptyWorkspace = ordinaryEmptyWorkspaces.first(where: \.isVisible),
       workspaceHasAdjacentAnchor(visibleEmptyWorkspace, in: orderedWorkspaces)
    {
        return visibleEmptyWorkspace.id
    }
    return nil
}

@MainActor
func workspaceAnchorsEmptySlot(_ workspace: Workspace) -> Bool {
    workspaceHasLifecycleWindows(workspace) || workspace.isConfiguredPersistent
}

@MainActor
func workspaceHasAdjacentAnchor(_ workspace: Workspace, in orderedWorkspaces: [Workspace]) -> Bool {
    guard let index = orderedWorkspaces.firstIndex(of: workspace) else { return false }
    return orderedWorkspaces.getOrNil(atIndex: index - 1).map(workspaceAnchorsEmptySlot) == true ||
        orderedWorkspaces.getOrNil(atIndex: index + 1).map(workspaceAnchorsEmptySlot) == true
}
