import Common

struct SectionsCommand: Command {
    let args: SectionsCmdArgs
    let shouldResetClosedWindowsCache = false
    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        guard let model = SwitcherPalettePanel.shared.session else { io.failureExitCode = 2; return io.err("No Lens is open") }
        model.changeSections(args.value.val)
        return true
    }
}
