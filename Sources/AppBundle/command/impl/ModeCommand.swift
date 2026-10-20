import AppKit
import Common

struct ModeCommand: Command {
    let args: ModeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        if config.modes[args.targetMode.val]?.lifetime == .held, modeInvocation == nil {
            io.stderr.append("Entering held mode '\(args.targetMode.val)' latched from the CLI")
        }
        try await activateMode(args.targetMode.val)
        return true
    }
}
