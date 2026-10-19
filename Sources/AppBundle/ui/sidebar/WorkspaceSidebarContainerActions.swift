import Common
import Foundation

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
        workspaceSidebarPreservingMru(of: container) {
            for case let child as TilingContainer in container.children {
                workspaceSidebarJoinLeaves(child, to: container, index: child.ownIndex.orDie())
            }
        }
    }
    container.changeLayout(layout, orientation: orientation)
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
    workspaceSidebarPreservingMru(of: parent) {
        if parent.layout == .tabGroup {
            workspaceSidebarJoinLeaves(container, to: parent, index: index)
            return
        }
        // The children share the container's space along the parent's axis, in their own proportions when they lie along it.
        let children = container.children
        let share = container.getWeight(parent.orientation)
        let alongParent = container.layout == .tiles && container.orientation == parent.orientation
        let total = alongParent ? children.reduce(CGFloat(0)) { $0 + $1.getWeight(parent.orientation) } : CGFloat(children.count)
        let weights = children.map { alongParent && total > 0 ? share * $0.getWeight(parent.orientation) / total : share / CGFloat(children.count) }
        for (offset, child) in children.enumerated() {
            child.bind(to: parent, adaptiveWeight: weights[offset], index: index + offset)
        }
    }
    return true
}

/// Rebinding moves each bound node to the front of every ancestor's recency, which would change the visible tab and
/// the remembered focus; this puts each node's recency back, read through the windows it holds.
@MainActor
private func workspaceSidebarPreservingMru(of node: TreeNode, _ body: () -> Void) {
    func windowsByRecency(_ node: TreeNode) -> [TreeNode] {
        node.childrenByMostRecentUse.flatMap { child in child is Window ? [child] : windowsByRecency(child) }
    }
    let previous = node.parentsWithSelf.map { ($0, windowsByRecency($0)) }
    body()
    for (node, order) in previous where node.isBound || node is Workspace { node.restoreChildMru(order) }
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
