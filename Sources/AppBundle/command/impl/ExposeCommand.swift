import AppKit
import Common

struct ExposeCommand: Command {
    let args: ExposeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        ZoneExposePanelController.shared.toggle(scope: args.scope.val)
        return true
    }
}
