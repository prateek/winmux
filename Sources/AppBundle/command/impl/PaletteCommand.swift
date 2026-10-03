import AppKit
import Common

struct PaletteCommand: Command {
    let args: PaletteCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        if case .cmd(let command) = parseCommand(["lens", "search"]) {
            return try await command.run(env, io)
        }
        return io.err("Cannot parse lens search")
    }
}
