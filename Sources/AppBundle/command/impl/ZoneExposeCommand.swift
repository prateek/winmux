import AppKit
import Common

struct ZoneExposeCommand: Command {
    let args: ZoneExposeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        ZoneExposePanelController.shared.toggle(scope: args.scope.val)
        return true
    }
}
