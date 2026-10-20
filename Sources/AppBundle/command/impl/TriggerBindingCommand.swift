import AppKit
import Common

struct TriggerBindingCommand: Command {
    let args: TriggerBindingCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    /// The commands the named binding runs, or nil when the mode or binding does not exist.
    @MainActor var bindingCommands: [any Command]? {
        guard config.modes[args.mode] != nil else { return nil }
        return winningKeyBindings(resolvedModeKeymap(), context: currentKeyContext(mode: args.mode), prefix: [])
            .first(where: { $0.name == args.binding.val })?.commands
    }

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        guard config.modes[args.mode] != nil else {
            return io.err("Mode '\(args.mode)' doesn't exist. " +
                "Available modes: \(config.modes.keys.joined(separator: ","))")
        }
        guard let commands = bindingCommands else {
            return io.err("Binding '\(args.binding.val)' is not presented in mode '\(args.mode)'")
        }
        // The config can be reloaded between a URL's gate and this run, so check what runs.
        if env.isFromURL, let refusal = urlBindingRefusal(args.binding.val, commands) { return io.err(refusal) }
        // refreshSession is not needed since commands are already run in refreshSession
        FindFocusHighlight.shared.dismiss()
        return try await commands.runCmdSeq(env, io)
    }
}
