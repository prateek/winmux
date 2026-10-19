@MainActor
func agentMoveWindowToWorkspace(_ window: Window, _ targetWorkspace: Workspace, focusFollowsWindow: Bool) -> Bool {
    moveWindowToWorkspace(window, targetWorkspace, CmdIo(stdin: .emptyStdin), focusFollowsWindow: focusFollowsWindow, failIfNoop: false)
}

@MainActor
func placeAgentPane(_ source: TreeNode, relation: AgentPaneRelationKind, target: TreeNode) {
    if source == target || source.parentsWithSelf.contains(target) || target.parentsWithSelf.contains(source) {
        return
    }
    if let insertion = target.agentNearestInsertionParent(orientation: relation.orientation) {
        placeAgentPane(source, relation: relation, insertion: insertion)
        return
    }

    _ = source.unbindFromParent()
    guard target.parent != nil else { return }
    let targetBinding = target.unbindFromParent()
    let newParent = TilingContainer(replacing: targetBinding, relation.orientation, .tiles)
    if relation.sourceIsAfterTarget {
        target.bind(to: newParent, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        source.bind(to: newParent, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    } else {
        source.bind(to: newParent, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        target.bind(to: newParent, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }
    source.mostRecentWindowRecursive?.markAsMostRecentChild()
}

@MainActor
private func placeAgentPane(
    _ source: TreeNode,
    relation: AgentPaneRelationKind,
    insertion: (parent: TilingContainer, anchor: TreeNode),
) {
    guard let binding = workspaceSidebarSiblingBindingData(source: source, target: insertion.anchor, after: relation.sourceIsAfterTarget) else { return }
    source.bind(to: binding.parent, adaptiveWeight: binding.adaptiveWeight, index: binding.index)
    source.mostRecentWindowRecursive?.markAsMostRecentChild()
}
