import AppKit
import Common

struct TriggerBindingCommand: Command {
    let args: TriggerBindingCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    /// The commands the named binding runs, or nil when the mode or binding does not exist.
    @MainActor var bindingCommands: [any Command]? {
        guard let mode = config.modes[args.mode] else { return nil }
        return mode.bindings.values.first(where: { $0.descriptionWithKeyNotation == args.binding.val })?.commands
            ?? mode.sequenceBindings.values.first(where: { $0.descriptionWithKeyNotation == args.binding.val })?.commands
    }

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        guard config.modes[args.mode] != nil else {
            return io.err("Mode '\(args.mode)' doesn't exist. " +
                "Available modes: \(config.modes.keys.joined(separator: ","))")
        }
        guard let commands = bindingCommands else {
            return io.err("Binding '\(args.binding.val)' is not presented in mode '\(args.mode)'")
        }
        // The config can be reloaded between a URL's gate and this run, so check what runs now.
        if isURLCommand, let refusal = urlCommandRefusal(self) { return io.err(refusal) }
        // refreshSession is not needed since commands are already run in refreshSession
        return try await commands.runCmdSeq(env, io)
    }
}
