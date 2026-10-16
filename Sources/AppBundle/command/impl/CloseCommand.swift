import AppKit
import Common

struct CloseCommand: Command {
    let args: CloseCmdArgs
    var isReadOnly: Bool = serverArgs.isReadOnly
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        try await allowOnlyCancellationError { @MainActor @Sendable in
            guard let target = args.resolveTargetOrReportError(env, io) else { return false }
            guard let window = target.windowOrNil else {
                return io.err("Empty workspace")
            }
            // Access ax directly. Not cool :(
            if try await args.quitIfLastWindow.andAsync({ @MainActor @Sendable in try await window.macAppUnsafe.getAxWindowsCount() == 1 }) {
                let app = window.macAppUnsafe
                if app.nsApp.terminate() {
                    for workspace in Workspace.all {
                        for window in workspace.allLeafWindowsRecursive where window.app.pid == app.pid {
                            window.asMacWindow().garbageCollect(skipClosedWindowsCache: true)
                        }
                    }
                    return true
                } else {
                    return io.err("Failed to quit '\(window.app.name ?? "Unknown app")'")
                }
            } else {
                let appName = window.app.name ?? "Unknown app"
                if isReadOnly { return io.err("Can't close '\(appName)': WinMux is read-only") }
                switch await window.closeAxWindow() {
                    case .closed: return true
                    case .notClosed(let reason): return io.err("Can't close '\(appName)': \(reason.rawValue)")
                }
            }
        }
    }
}
