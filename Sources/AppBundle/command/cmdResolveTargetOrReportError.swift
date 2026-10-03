import Common

extension CmdArgs {
    @MainActor
    func resolveTargetOrReportError(_ env: CmdEnv, _ io: CmdIo) -> LiveFocus? {
        // Flags
        if let windowId {
            if let wi = Window.get(byId: windowId) {
                return wi.toLiveFocusOrReportError(io, fallbackWorkspace: env.windowWorkspaceFallback.flatMap { Workspace.existing(byName: $0) })
            } else {
                io.err("Invalid <window-id> \(windowId) passed to --window-id")
                return nil
            }
        }
        if let workspaceName {
            guard let workspace = Workspace.existing(byName: workspaceName.raw),
                  isUserFacingWorkspace(workspace, focusedWorkspace: focus.workspace)
            else {
                io.err("Workspace '\(workspaceName.raw)' doesn't exist")
                return nil
            }
            return workspace.toLiveFocus()
        }
        // Env
        if let windowId = env.windowId {
            if let wi = Window.get(byId: windowId) {
                return wi.toLiveFocusOrReportError(io, fallbackWorkspace: env.windowWorkspaceFallback.flatMap { Workspace.existing(byName: $0) })
            } else {
                io.err("Invalid <window-id> \(windowId) specified in \(WINMUX_WINDOW_ID) env variable")
                return nil
            }
        }
        if let wsName = env.workspaceName {
            guard let workspace = Workspace.existing(byName: wsName),
                  isUserFacingWorkspace(workspace, focusedWorkspace: focus.workspace)
            else {
                io.err("Workspace '\(wsName)' doesn't exist")
                return nil
            }
            return workspace.toLiveFocus()
        }
        // Real Focus
        return focus
    }
}

extension Window {
    @MainActor
    func toLiveFocusOrReportError(_ io: CmdIo, fallbackWorkspace: Workspace? = nil) -> LiveFocus? {
        if let result = toLiveFocusOrNil() {
            return result
        } else if let fallbackWorkspace {
            return LiveFocus(windowOrNil: self, workspace: fallbackWorkspace)
        } else {
            io.err("Window \(windowId) doesn't belong to any monitor. And thus can't even define a focused workspace")
            return nil
        }
    }
}
