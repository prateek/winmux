import Foundation

@MainActor
func buildWorkspaceSidebarLayoutTree(for workspace: Workspace, currentFocus: LiveFocus) async -> [WorkspaceSidebarItemViewModel] {
    let root = workspace.rootTilingContainer
    var items: [WorkspaceSidebarItemViewModel] = []
    if let columns = workspace.columns {
        for slot in 1...columns.slotCount {
            var children: [WorkspaceSidebarItemViewModel] = []
            for child in root.children where child.columnSlot == slot {
                children.append(await workspaceSidebarTreeItem(child, workspace: workspace, slot: slot, currentFocus: currentFocus))
            }
            items.append(.init(kind: .column(workspace: workspace.name, slot: slot, fraction: Double(columns.widths[slot - 1])),
                               children: children, realParent: .container(root.stableId), indexInParent: slot - 1, columnSlot: slot))
        }
        for child in root.children where !(1...columns.slotCount).contains(child.columnSlot ?? 0) {
            items.append(await workspaceSidebarTreeItem(child, workspace: workspace, slot: nil, currentFocus: currentFocus))
        }
    } else if !root.children.isEmpty {
        items.append(await workspaceSidebarTreeItem(root, workspace: workspace, slot: nil, currentFocus: currentFocus))
    }
    var floating: [WorkspaceSidebarItemViewModel] = []
    for window in workspace.floatingWindows where window.isBound {
        var item = await workspaceSidebarTreeItem(window, workspace: workspace, slot: nil, currentFocus: currentFocus)
        item.isFloating = true
        floating.append(item)
    }
    if !floating.isEmpty {
        items.append(.init(kind: .floating(workspace: workspace.name), children: floating, realParent: .workspace(workspace.name)))
    }
    return items
}

@MainActor
private func workspaceSidebarTreeItem(_ node: TreeNode, workspace: Workspace, slot: Int?, currentFocus: LiveFocus) async -> WorkspaceSidebarItemViewModel {
    let parent: WorkspaceSidebarNodeIdentity? = (node.parent as? TilingContainer).map { .container($0.stableId) } ?? .workspace(workspace.name)
    let kind: WorkspaceSidebarItemKind
    var children: [WorkspaceSidebarItemViewModel] = []
    if let window = node as? Window {
        kind = .window(await makeWorkspaceSidebarWindowViewModel(for: window, workspaceName: workspace.name, currentFocus: currentFocus))
    } else if let container = node as? TilingContainer {
        for child in container.children {
            children.append(await workspaceSidebarTreeItem(child, workspace: workspace, slot: slot, currentFocus: currentFocus))
        }
        if container.layout == .tabGroup, container.children.count > 1,
           let group = makeWorkspaceSidebarTabGroupViewModel(for: container, children: children, workspaceName: workspace.name, currentFocus: currentFocus) {
            kind = .tabGroup(group)
        } else {
            kind = .split(container.stableId, orientation: container.orientation == .v ? "vertical" : "horizontal", layout: container.layout.rawValue)
        }
    } else { preconditionFailure("Sidebar tree contains only layout nodes") }
    return .init(kind: kind, children: children, realParent: parent, indexInParent: node.ownIndex ?? 0, columnSlot: slot)
}
