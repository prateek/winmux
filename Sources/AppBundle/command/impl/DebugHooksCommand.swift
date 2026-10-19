import Common
import Foundation

struct DebugHooksCommand: Command {
    let args: DebugHooksCmdArgs
    let shouldResetClosedWindowsCache = false
    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let store = HookCaptureStore.shared
        let wasCapturing = store.status().capturing
        switch args.action ?? .status {
            case .on:
                do { try store.start() }
                catch {
                    if args.json { io.out(String(decoding: try JSONEncoder().encode(store.status()), as: UTF8.self)) }
                    return io.err(store.status().error ?? error.localizedDescription)
                }
            case .off: store.stop()
            case .status: break
        }
        let status = store.status()
        if args.json { return io.out(String(decoding: try JSONEncoder().encode(status), as: UTF8.self)) }
        let state = status.capturing ? "on" : "off"
        let prefix = args.action == .off && !wasCapturing ? "Hook capture was not on." : "Hook capture is \(state)."
        let deadline = status.until.stringOrNil.map { " Stops at \($0)." } ?? ""
        let failure = status.error.map { " Error: \($0)" } ?? ""
        return io.out("\(prefix) \(status.path) — \(status.records) records.\(deadline)\(failure)")
    }
}
