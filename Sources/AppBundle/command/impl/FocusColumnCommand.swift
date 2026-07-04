import Common

struct FocusColumnCommand: Command {
    let args: FocusColumnCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        switch resolveZoneSelector(args.column.val) {
            case .success(let column):
                return column.monitor.activeWorkspace.focusWorkspace()
            case .failure(let msg):
                return io.err(msg)
        }
    }
}
