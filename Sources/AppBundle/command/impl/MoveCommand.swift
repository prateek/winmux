import AppKit
import Common

struct MoveCommand: PolicyCommand {
    let args: MoveCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func runWithPolicy(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io), let window = target.windowOrNil,
              let workspace = window.nodeWorkspace, let columns = workspace.columns,
              args.direction.val.orientation == .h else { return try await runFallback(env, io) }
        let direction = args.direction.val
        let node = window.moveNode
        for child in node.parentsWithSelf {
            guard let parent = child.parent as? TilingContainer else { break }
            if parent === workspace.rootTilingContainer { break }
            if parent.orientation == .h, let index = child.ownIndex,
               parent.children.indices.contains(index + direction.focusOffset) { return try await runFallback(env, io) }
        }
        workspace.enforceColumnInvariant()
        guard let slot = workspace.columnSlot(containing: node) else { return try await runFallback(env, io) }
        let destination = slot + direction.focusOffset
        let edge = !(1...columns.slotCount).contains(destination)
        let neighbour = workspace.rootTilingContainer.children.first { $0.columnSlot == destination }
        if !edge && neighbour == nil { return try await runFallback(env, io) }
        let path = config.columns.hook("move-boundary", workspace: workspace.name)
        let result = await ColumnPolicy.call(path, window: window, workspace: workspace, edge: edge)
        if path != nil && result == nil { return try await runFallback(env, io) }
        let action = result?["action"]?.stringOrNil ?? (edge ? "stop" : "join")
        if result == nil && edge { return try await runFallback(env, io) }
        guard (edge ? ["stop", "wrap", "next-workspace", "next-monitor"] : ["join", "swap"]).contains(action) else {
            NickelSupervisor.shared.recordHookFailure("\(path ?? "move-boundary"): action \(action) is not valid at this boundary")
            return try await runFallback(env, io)
        }
        var success = true
        switch action {
            case "join":
                let overflow: String
                if let selected = result?["overflow"]?.stringOrNil { overflow = selected }
                else { overflow = await ColumnPolicy.decision(window: window, workspace: workspace).overflow }
                window.unbindFromParent()
                workspace.bindToColumn(window, slot: destination, overflow: overflow)
            case "swap":
                if let neighbour {
                    let moving = workspace.rootTilingContainer.children.first { $0.columnSlot == slot }.orDie()
                    moving.columnSlot = destination
                    neighbour.columnSlot = slot
                }
            case "wrap":
                window.unbindFromParent()
                workspace.bindToColumn(window, slot: direction.focusOffset > 0 ? 1 : columns.slotCount)
            case "next-workspace":
                if let next = getNextPrevWorkspace(current: workspace, isNext: direction.focusOffset > 0, wrapAround: true, stdin: nil) {
                    success = moveWindowToWorkspace(window, next, io, focusFollowsWindow: focus.windowOrNil == window, failIfNoop: false)
                    if success, next !== workspace, !window.isFloating { try await ColumnPolicy.place(window, on: next) }
                } else { success = io.err("No adjacent workspace") }
            case "next-monitor":
                success = try await MoveNodeToMonitorCommand(args: MoveNodeToMonitorCmdArgs(target: .direction(direction))
                    .copy(\.windowId, window.windowId).copy(\.focusFollowsWindow, focus.windowOrNil == window)).runWithPolicy(env, io)
            default: break
        }
        workspace.normalizeContainers()
        if success { try await ColumnPolicy.run(ColumnPolicy.commands(result), window: window) }
        return success
    }
    @MainActor private func runFallback(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let window = args.resolveTargetOrReportError(env, io)?.windowOrNil
        let previous = window?.nodeWorkspace
        let success = runBuiltIn(env, io)
        if let window { return try await ColumnPolicy.afterTransfer(window, from: previous, didMove: success) }
        return success
    }
    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool { runBuiltIn(env, io) }

    @MainActor private func runBuiltIn(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let direction = args.direction.val
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let currentWindow = target.windowOrNil else {
            return io.err(noWindowIsFocused)
        }
        let currentNode = currentWindow.moveNode
        guard let parent = currentNode.parent else { return false }
        switch parent.cases {
            case .tilingContainer(let parent):
                if parent.isRootContainer, let workspace = currentNode.nodeWorkspace, workspace.columns != nil {
                    return moveAtColumnBoundary(currentNode, currentWindow, workspace, direction, io, args, env)
                }
                let indexOfCurrent = currentNode.ownIndex.orDie()
                let indexOfSiblingTarget = indexOfCurrent + direction.focusOffset
                if parent.orientation == direction.orientation && parent.children.indices.contains(indexOfSiblingTarget) {
                    let siblingTarget = parent.children[indexOfSiblingTarget]
                    if currentNode is TilingContainer || (siblingTarget as? TilingContainer)?.layout == .tabGroup {
                        return moveNodeToSiblingIndex(currentNode, parent, indexOfSiblingTarget)
                    }
                    switch siblingTarget.tilingTreeNodeCasesOrDie() {
                        case .tilingContainer(let topLevelSiblingTargetContainer):
                            return deepMoveIn(node: currentNode, into: topLevelSiblingTargetContainer, moveDirection: direction)
                        case .window: // "swap windows"
                            return moveNodeToSiblingIndex(currentNode, parent, indexOfSiblingTarget)
                    }
                } else {
                    return moveOut(node: currentNode, window: currentWindow, direction: direction, io, args, env)
                }
            case .workspace: // floating window
                return io.err("moving floating windows isn't yet supported") // todo
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
                return io.err(moveOutMacosUnconventionalWindow)
            case .macosPopupWindowsContainer:
                return false // Impossible
        }
    }
}

@MainActor
private func moveNodeToSiblingIndex(_ node: TreeNode, _ parent: TilingContainer, _ targetIndex: Int) -> Bool {
    let prevBinding = node.unbindFromParent()
    node.bind(to: parent, adaptiveWeight: prevBinding.adaptiveWeight, index: targetIndex)
    return true
}

@MainActor private func hitWorkspaceBoundaries(
    _ node: TreeNode,
    _ workspace: Workspace,
    _ io: CmdIo,
    _ args: MoveCmdArgs,
    _ direction: CardinalDirection,
    _ env: CmdEnv,
) -> Bool {
    switch args.boundaries {
        case .workspace:
            switch args.boundariesAction {
                case .stop: return true
                case .fail: return false
                case .createImplicitContainer:
                    if workspace.columns == nil { createImplicitContainerAndMoveNode(node, workspace, direction) }
                    return true
            }
        case .allMonitorsOuterFrame:
            guard let (monitors, index) = node.nodeMonitor?.findRelativeMonitor(inDirection: direction) else {
                return io.err("Should never happen. Can't find the current monitor")
            }

            if monitors.indices.contains(index) {
                let focusWindow = node.mostRecentWindowRecursive
                guard let focusWindow else { return false }
                let moveNodeToMonitorArgs = MoveNodeToMonitorCmdArgs(target: .direction(direction))
                    .copy(\.windowId, focusWindow.windowId)
                    .copy(\.focusFollowsWindow, focus.windowOrNil == focusWindow)

                return MoveNodeToMonitorCommand(args: moveNodeToMonitorArgs).run(env, io)
            } else {
                return hitAllMonitorsOuterFrameBoundaries(node, workspace, args, direction)
            }
    }
}

@MainActor private func hitAllMonitorsOuterFrameBoundaries(
    _ node: TreeNode,
    _ workspace: Workspace,
    _ args: MoveCmdArgs,
    _ direction: CardinalDirection,
) -> Bool {
    switch args.boundariesAction {
        case .stop: return true
        case .fail: return false
        case .createImplicitContainer:
            if workspace.columns == nil { createImplicitContainerAndMoveNode(node, workspace, direction) }
            return true
    }
}

private let moveOutMacosUnconventionalWindow = "moving macOS fullscreen, minimized windows and windows of hidden apps isn't yet supported. This behavior is subject to change"

@MainActor private func moveOut(
    node: TreeNode,
    window: Window,
    direction: CardinalDirection,
    _ io: CmdIo,
    _ args: MoveCmdArgs,
    _ env: CmdEnv,
) -> Bool {
    let innerMostChild = node.parents.first(where: {
        return switch $0.parent?.cases {
            case .tilingContainer(let parent): parent.orientation == direction.orientation
            // Stop searching
            case .workspace, .macosMinimizedWindowsContainer, nil, .macosFullscreenWindowsContainer,
                 .macosHiddenAppsWindowsContainer, .macosPopupWindowsContainer: true
        }
    }) as? TilingContainer
    guard let innerMostChild else { return false }
    guard let parent = innerMostChild.parent else { return false }
    switch parent.cases {
        case .tilingContainer(let parent):
            if parent.isRootContainer, let workspace = node.nodeWorkspace, workspace.columns != nil {
                return moveAtColumnBoundary(node, window, workspace, direction, io, args, env)
            }
            check(parent.orientation == direction.orientation)
            guard let ownIndex = innerMostChild.ownIndex else { return false }
            node.bind(to: parent, adaptiveWeight: WEIGHT_AUTO, index: ownIndex + direction.insertionOffset)
            return true
        case .workspace(let parent):
            if parent.columns != nil { return moveAtColumnBoundary(node, window, parent, direction, io, args, env) }
            return hitWorkspaceBoundaries(node, parent, io, args, direction, env)
        case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
            return io.err(moveOutMacosUnconventionalWindow)
        case .macosPopupWindowsContainer:
            return false // Impossible
    }
}

@MainActor private func createImplicitContainerAndMoveNode(
    _ node: TreeNode,
    _ workspace: Workspace,
    _ direction: CardinalDirection,
) {
    let prevRoot = workspace.rootTilingContainer
    prevRoot.unbindFromParent()
    // Force tiles layout
    _ = TilingContainer(parent: workspace, adaptiveWeight: WEIGHT_AUTO, direction.orientation, .tiles, index: 0)
    check(prevRoot != workspace.rootTilingContainer)
    prevRoot.bind(to: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: 0)
    node.bind(to: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: direction.insertionOffset)
}

@MainActor private func deepMoveIn(node: TreeNode, into container: TilingContainer, moveDirection: CardinalDirection) -> Bool {
    let deepTarget = container.tilingTreeNodeCasesOrDie().findDeepMoveInTargetRecursive(moveDirection.orientation)
    switch deepTarget {
        case .tilingContainer(let deepTarget):
            node.bind(to: deepTarget, adaptiveWeight: WEIGHT_AUTO, index: 0)
        case .window(let deepTarget):
            guard let parent = deepTarget.parent as? TilingContainer else { return false }
            node.bind(
                to: parent,
                adaptiveWeight: WEIGHT_AUTO,
                index: deepTarget.ownIndex.orDie() + 1,
            )
    }
    return true
}

extension TilingTreeNodeCases {
    @MainActor fileprivate func findDeepMoveInTargetRecursive(_ orientation: Orientation) -> TilingTreeNodeCases {
        return switch self {
            case .window:
                self
            case .tilingContainer(let container):
                if container.orientation == orientation {
                    .tilingContainer(container)
                } else {
                    container.mostRecentChild.orDie("Empty containers must be detached during normalization")
                        .tilingTreeNodeCasesOrDie()
                        .findDeepMoveInTargetRecursive(orientation)
                }
        }
    }
}

extension Window {
    @MainActor
    var moveNode: TreeNode {
        if let parent = parent as? TilingContainer, parent.layout == .tabGroup {
            return parent
        } else {
            return self
        }
    }
}

@MainActor private func moveAtColumnBoundary(
    _ node: TreeNode, _ window: Window, _ workspace: Workspace, _ direction: CardinalDirection,
    _ io: CmdIo, _ args: MoveCmdArgs, _ env: CmdEnv
) -> Bool {
    workspace.enforceColumnInvariant()
    guard let columns = workspace.columns, let slot = workspace.columnSlot(containing: node) else {
        return io.err("Cannot resolve the window's Column")
    }
    if direction.orientation == .h, (1...columns.slotCount).contains(slot + direction.focusOffset) {
        return workspace.moveAcrossColumnBoundary(node, window: window, direction: direction)
    }
    return hitWorkspaceBoundaries(node, workspace, io, args, direction, env)
}
