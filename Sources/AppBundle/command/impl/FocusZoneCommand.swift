import Common

struct FocusZoneCommand: Command {
    let args: FocusZoneCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        switch resolveZoneSelector(args.zone.val) {
            case .success(let zone):
                return zone.monitor.activeWorkspace.focusWorkspace()
            case .failure(let msg):
                return io.err(msg)
        }
    }
}
