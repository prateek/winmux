import Common

struct MoveNodeToZoneCommand: Command {
    let args: MoveNodeToZoneCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let window = target.windowOrNil else {
            return io.err(noWindowIsFocused)
        }
        switch resolveZoneSelector(args.zone.val) {
            case .success(let zone):
                return moveWindowOrTabGroupToWorkspace(
                    window,
                    zone.monitor.activeWorkspace,
                    io,
                    focusFollowsWindow: args.focusFollowsWindow,
                    failIfNoop: args.failIfNoop,
                )
            case .failure(let msg):
                return io.err(msg)
        }
    }
}

@MainActor
func moveWindowOrTabGroupToWorkspace(
    _ window: Window,
    _ targetWorkspace: Workspace,
    _ io: CmdIo,
    focusFollowsWindow: Bool,
    failIfNoop: Bool,
    index: Int = INDEX_BIND_LAST,
) -> Bool {
    let node = window.moveNode
    if node.nodeWorkspace == targetWorkspace {
        if !failIfNoop {
            io.err("Window '\(window.windowId)' already belongs to workspace '\(targetWorkspace.name)'. Tip: use --fail-if-noop to exit with non-zero code")
        }
        return !failIfNoop
    }
    if node === window, window.isFloating {
        window.bind(to: targetWorkspace, adaptiveWeight: WEIGHT_AUTO, index: index)
    } else {
        let binding = workspaceAppendBindingData(targetWorkspace: targetWorkspace, index: index)
        node.bind(to: binding.parent, adaptiveWeight: binding.adaptiveWeight, index: binding.index)
    }
    return focusFollowsWindow ? window.focusWindow() : true
}

@MainActor
@discardableResult
func moveWindowOrTabGroupToWorkspace(
    _ window: Window,
    _ targetWorkspace: Workspace,
    focusFollowsWindow: Bool,
    index: Int = INDEX_BIND_LAST,
) -> Bool {
    let node = window.moveNode
    if node.nodeWorkspace == targetWorkspace {
        return true
    }
    if node === window, window.isFloating {
        window.bind(to: targetWorkspace, adaptiveWeight: WEIGHT_AUTO, index: index)
    } else {
        let binding = workspaceAppendBindingData(targetWorkspace: targetWorkspace, index: index)
        node.bind(to: binding.parent, adaptiveWeight: binding.adaptiveWeight, index: binding.index)
    }
    return focusFollowsWindow ? window.focusWindow() : true
}
