import Common

struct DebugLensTraceCommand: Command {
    let args: DebugLensTraceCmdArgs
    let shouldResetClosedWindowsCache = false
    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        io.out(args.json ? LensTraceStore.shared.json(last: args.last ?? 5) : LensTraceStore.shared.text(last: args.last ?? 5))
    }
}
