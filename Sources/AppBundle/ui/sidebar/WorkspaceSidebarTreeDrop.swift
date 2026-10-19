import AppKit
import Common

@MainActor
func workspaceSidebarLiveContainer(_ identity: UInt64, workspaceName: String? = nil) -> TilingContainer? {
    func find(_ node: TreeNode) -> TilingContainer? {
        if let container = node as? TilingContainer, container.stableId == identity { return container }
        for child in node.children { if let found = find(child) { return found } }
        return nil
    }
    let workspaces = workspaceName.map { Workspace.existing(byName: $0).map { [$0] } ?? [] } ?? Array(Workspace.all)
    return workspaces.lazy.compactMap { find($0.rootTilingContainer) }.first
}

@MainActor
func workspaceSidebarTreeDestination(_ target: WorkspaceSidebarTreeDropTarget) -> (workspace: Workspace, node: TreeNode?)? {
    switch target {
        case .window(let id, _), .tab(let id, _), .windowZone(let id, _):
            guard let window = Window.get(byId: id), let workspace = window.nodeWorkspace else { return nil }
            return (workspace, window)
        case .floatingWindow(let id, _):
            guard let window = Window.get(byId: id), window.isFloating, let workspace = window.nodeWorkspace else { return nil }
            return (workspace, window)
        case .tabGroup(let identity, let name):
            guard let node = workspaceSidebarLiveContainer(identity, workspaceName: name), node.layout == .tabGroup,
                  let workspace = node.nodeWorkspace, !workspaceSidebarIsColumnsRoot(node, workspace: workspace) else { return nil }
            return (workspace, node)
        case .split(let identity, let name):
            guard let node = workspaceSidebarLiveContainer(identity, workspaceName: name), node.layout == .tiles,
                  let workspace = node.nodeWorkspace, !workspaceSidebarIsColumnsRoot(node, workspace: workspace) else { return nil }
            return (workspace, node)
        case .column(let name, let slot), .columnMark(let name, let slot):
            guard let workspace = Workspace.existing(byName: name), let columns = workspace.columns,
                  (1...columns.slotCount).contains(slot) else { return nil }
            return (workspace, nil)
        case .floatingGroup(let name):
            return Workspace.existing(byName: name).map { ($0, nil) }
    }
}

@MainActor
private func workspaceSidebarIsColumnsRoot(_ node: TilingContainer, workspace: Workspace) -> Bool {
    guard let columns = workspace.columns else { return false }
    return node === columns.root || node === workspace.rootTilingContainer
}

@MainActor
func workspaceSidebarTreeRefusal(source: TreeNode, destination: (workspace: Workspace, node: TreeNode?)?) -> String? {
    guard let destination else { return "Destination no longer exists" }
    if let node = destination.node, node.parentsWithSelf.contains(where: { $0 === source }) {
        return "Cannot drop an item on itself or its descendants"
    }
    return nil
}

@MainActor
func workspaceSidebarTreeDropDescription(_ target: WorkspaceSidebarTreeDropTarget, destination: (workspace: Workspace, node: TreeNode?)?) -> String {
    guard let destination else { return "Destination no longer exists" }
    switch target {
        case .windowZone(_, let zone):
            return "\(zone.sidebarIntent) \((destination.node as? Window).map(sidebarDisplayLabel) ?? "window")"
        case .window(_, let after), .tab(_, let after):
            let window = destination.node as? Window
            let parent = window?.parent as? TilingContainer
            let isDirectColumnChild = destination.workspace.columns != nil && parent === destination.workspace.rootTilingContainer
            let parentName = parent?.layout == .tabGroup ? "tab group" : "\(!isDirectColumnChild && parent?.orientation == .h ? "horizontal" : "vertical") split"
            return "\(after ? "After" : "Before") \(window.map(sidebarDisplayLabel) ?? "window"), in a \(parentName)"
        case .tabGroup: return "Append as tabs"
        case .split: return "Append to split"
        case .column(_, let slot), .columnMark(_, let slot): return "Place in Column \(slot)"
        case .floatingGroup, .floatingWindow: return "Place among floating windows"
    }
}

@MainActor
@discardableResult
func applyWorkspaceSidebarTreeDrop(source: TreeNode, target: WorkspaceSidebarTreeDropTarget) async throws -> Bool {
    guard source.isBound, let destination = workspaceSidebarTreeDestination(target),
          workspaceSidebarTreeRefusal(source: source, destination: destination) == nil else { return false }
    if case .windowZone(_, let zone) = target {
        guard let window = destination.node as? Window, workspaceSidebarOfferedZones(source: source, target: window).contains(zone) else { return false }
    }
    let windows = source.allLeafWindowsRecursive
    switch target {
        case .floatingGroup, .floatingWindow:
            var index = INDEX_BIND_LAST
            if case .floatingWindow(_, let after) = target, let targetWindow = destination.node as? Window,
               targetWindow.parent === destination.workspace, let ownIndex = targetWindow.ownIndex {
                index = ownIndex + (after ? 1 : 0)
                index -= windows.filter { $0.parent === destination.workspace && ($0.ownIndex ?? Int.max) < index }.count
            }
            let wereTiled = windows.filter { $0.parent is TilingContainer }
            destination.workspace.bindLeavesAsFloating(source, at: index)
            for window in wereTiled {
                if let size = window.lastFloatingSize { window.setAxFrame(nil, size) }
            }
            return true
        default: break
    }
    for window in windows where window.isFloating {
        window.lastFloatingSize = try await window.getAxSize() ?? window.lastFloatingSize
    }
    // AX size reads can suspend; resolve again before mutation.
    guard source.isBound, let live = workspaceSidebarTreeDestination(target),
          workspaceSidebarTreeRefusal(source: source, destination: live) == nil else { return false }
    switch target {
        case .windowZone(_, let zone):
            guard let window = live.node as? Window,
                  workspaceSidebarOfferedZones(source: source, target: window).contains(zone) else { return false }
            if let position = zone.stackSplitPosition {
                return workspaceSidebarSplit(source: source, target: window, position: position)
            }
            switch zone {
                case .tab:
                    guard let sourceWindow = source as? Window else { return false }
                    createOrAppendWindowTabStack(sourceWindow: sourceWindow, onto: window)
                case .middle: swapNodes(source, window)
                default: return false
            }
        case .column(_, let slot), .columnMark(_, let slot):
            source.unbindFromParent()
            live.workspace.bindToColumn(source, slot: slot)
        case .split:
            guard let container = live.node as? TilingContainer, container.isBound else { return false }
            source.bind(to: container, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        case .tabGroup:
            guard let container = live.node as? TilingContainer, container.isBound else { return false }
            workspaceSidebarJoinLeaves(source, to: container, index: INDEX_BIND_LAST)
        case .window(_, let after), .tab(_, let after):
            guard let node = live.node, let parent = node.parent as? TilingContainer,
                  let binding = siblingBindingData(source: source, target: node, after: after) else { return false }
            if live.workspace.columns != nil, parent === live.workspace.rootTilingContainer {
                let wrapper = live.workspace.wrapColumnChildInVerticalSplit(node)
                source.columnSlot = nil
                source.bind(to: wrapper, adaptiveWeight: WEIGHT_AUTO, index: after ? 1 : 0)
            } else if parent.layout == .tabGroup, source is TilingContainer {
                workspaceSidebarJoinLeaves(source, to: parent, index: binding.index)
            } else {
                source.bind(to: binding.parent, adaptiveWeight: binding.adaptiveWeight, index: binding.index)
            }
        case .floatingGroup, .floatingWindow: return false
    }
    return true
}

@MainActor
func workspaceSidebarOfferedZones(source: TreeNode, target: Window) -> [WindowDropZone] {
    guard let parent = target.parent as? TilingContainer else { return [] }
    let windowSource = source as? Window
    // A floating source is tiled by the drop; a source in a macOS container (minimized, hidden, fullscreen) is not arranged.
    guard source.parent is TilingContainer || windowSource?.isFloating == true else { return [] }
    if parent.layout == .tabGroup, source.parent === parent { return [] }
    let tab: [WindowDropZone] = windowSource != nil && config.windowTabs.enabled ? [.tab] : []
    // Swapping with a floating source would float the pointed window.
    let swap: [WindowDropZone] = source.parent is TilingContainer ? [.middle] : []
    if parent.layout == .tabGroup { return windowSource != nil ? tab + swap : [] }
    // A split that is itself a tab is a nested container in a tab group: its windows take only a swap, and nothing that
    // reshapes the tab. Splitting there can flatten the pointed window into the tab group and turn the new split.
    if (parent.parent as? TilingContainer)?.layout == .tabGroup { return windowSource != nil ? swap : [] }
    return tab + [.left, .right, .top, .bottom] + swap
}

@MainActor
private func workspaceSidebarSplit(source: TreeNode, target: Window, position: WindowStackSplitPosition) -> Bool {
    guard target.parent is TilingContainer else { return false }
    let sourceWorkspace = source.nodeWorkspace
    source.unbindFromParent()
    // Choose the split against the tree normalization leaves once the source is gone. A split the source leaves with
    // one child is flattened into its parent, and a split chosen before that would be turned by normalization to run
    // across its new parent, against the zone.
    sourceWorkspace?.normalizeContainers()
    guard let parent = target.parent as? TilingContainer else {
        // Normalization keeps a tiled window tiled; should it not, the source still lands in the tiling tree.
        (target.nodeWorkspace ?? sourceWorkspace).map { source.bind(to: $0.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST) }
        return false
    }
    let binding = target.unbindFromParent()
    let matching = parent.layout == .tiles && parent.orientation == position.orientation &&
        !(parent.isRootContainer && parent.nodeWorkspace?.columns != nil)
    let container = matching ? parent : TilingContainer(replacing: binding, position.orientation, .tiles)
    let index = matching ? binding.index : 0
    let weight = matching ? binding.adaptiveWeight / 2 : WEIGHT_AUTO
    if position.isPositive {
        target.bind(to: container, adaptiveWeight: weight, index: index)
        source.bind(to: container, adaptiveWeight: weight, index: index + 1)
    } else {
        source.bind(to: container, adaptiveWeight: weight, index: index)
        target.bind(to: container, adaptiveWeight: weight, index: index + 1)
    }
    return true
}

@MainActor
func workspaceSidebarJoinLeaves(_ source: TreeNode, to container: TilingContainer, index: Int) {
    let windows = source.allLeafWindowsRecursive
    if source is TilingContainer { source.unbindFromParent() }
    for (offset, window) in windows.enumerated() {
        window.bind(to: container, adaptiveWeight: WEIGHT_AUTO, index: index == INDEX_BIND_LAST ? INDEX_BIND_LAST : index + offset)
    }
}
