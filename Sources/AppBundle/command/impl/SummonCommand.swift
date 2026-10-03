import Common

struct SummonCommand: Command {
    let args: SummonCmdArgs
    let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let destination = focus.workspace
        let window = (args.windowId ?? env.windowId).flatMap { Window.get(byId: $0) } ?? ((args.windowId ?? env.windowId) == nil ? focus.windowOrNil : nil)
        guard let window else { return io.err("Can't find the window to Summon") }
        guard ![WindowClass.appPopup, .accessoryPopup].contains(window.windowClass) else { return io.err("Cannot Summon a popup window") }
        try await restoreLensWindow(window, on: destination, runPlace: false)
        if destination.columns != nil {
            try await ColumnPolicy.place(window, on: destination)
        }
        if window.nodeWorkspace != destination {
            guard moveWindowToWorkspace(window, destination, io, focusFollowsWindow: false, failIfNoop: false) else { return false }
        }
        return window.focusWindow()
    }
}

@MainActor
func restoreLensWindow(_ window: Window, on workspace: Workspace, runPlace: Bool = true) async throws {
    if let macWindow = window as? MacWindow {
        if window.windowClass == .minimized { macWindow.setNativeMinimized(false) }
        if window.windowClass == .hiddenApp { macWindow.macApp.nsApp.unhide() }
    }
    if [.minimized, .hiddenApp].contains(window.windowClass) {
        let kind: NonLeafTreeNodeKind
        if case .macos(let previousKind, _, _) = window.layoutReason { kind = previousKind } else { kind = .tilingContainer }
        try await exitMacOsNativeUnconventionalState(window: window, prevParentKind: kind, prevWorkspaceName: nil, workspace: workspace, runPlace: runPlace)
    }
}

@MainActor
func runLensAction(_ commands: [String], session: LensSession, io: CmdIo) async throws -> Bool {
    var success = true
    for raw in commands {
        for id in session.targets(forCommand: raw) {
            guard let window = Window.get(byId: id) else { success = io.err("Window \(id) has closed"); continue }
            if raw == "focus" {
                try await restoreLensWindow(window, on: lensRestoreWorkspace(window))
                if ![WindowClass.appPopup, .accessoryPopup].contains(window.windowClass) {
                    success = window.focusWindow() && success
                }
                window.nativeFocus()
            } else {
                switch parseCommand(raw) {
                    case .cmd(let command):
                        if command.args is MoveNodeToWorkspaceCmdArgs, [WindowClass.appPopup, .accessoryPopup].contains(window.windowClass) {
                            success = io.err("Cannot move a popup window to a workspace")
                            continue
                        }
                        if !(command.args is CloseCmdArgs), !(command.args is SummonCmdArgs) {
                            try await restoreLensWindow(window, on: lensRestoreWorkspace(window))
                        }
                        success = try await [command].runCmdSeq(CmdEnv(windowWorkspaceFallback: focus.workspace.name, windowId: id), io) && success
                    case .failure(let error): success = io.err(error)
                    case .help(let help): success = io.err(help)
                }
            }
        }
    }
    return success
}

@MainActor
private func lensRestoreWorkspace(_ window: Window) -> Workspace {
    if let workspace = window.nodeWorkspace { return workspace }
    guard let origin = window.layoutReason.origin else { return focus.workspace }
    let existedBefore = Workspace.existing(byName: origin.workspaceName) != nil
    let workspace = Workspace.get(byName: origin.workspaceName)
    if !existedBefore {
        workspace.assignProject(origin.projectId)
    }
    workspace.seedMonitorIfNeeded(focus.workspace.workspaceMonitor)
    return workspace
}
