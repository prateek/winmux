import AppKit
import Common

struct CloseAllWindowsButCurrentCommand: Command {
    let args: CloseAllWindowsButCurrentCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let focused = target.windowOrNil else {
            return io.err("Empty workspace")
        }
        guard let workspace = focused.nodeWorkspace else {
            return io.err("Focused window '\(focused.windowId)' doesn't belong to workspace")
        }
        var result = true
        for window in workspace.allLeafWindowsRecursive where window != focused {
            // An app can close a companion window along with one closed earlier in this loop.
            guard Window.get(byId: window.windowId) != nil else { continue }
            result = try await CloseCommand(args: args.closeArgs).run(env.copy(\.windowId, window.windowId), io) && result
        }
        return result
    }
}
