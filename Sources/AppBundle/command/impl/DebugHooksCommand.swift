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
                    let status = store.status()
                    // The start failure is what to report, even if its status cannot be encoded.
                    if args.json, let json = JSONEncoder.winMuxDefault.encodeToString(status) { io.out(json) }
                    return io.err(status.error.stringOrNil ?? error.localizedDescription)
                }
            case .off: store.stop()
            case .status: break
        }
        let status = store.status()
        if args.json { return io.out(String(decoding: try JSONEncoder.winMuxDefault.encode(status), as: UTF8.self)) }
        let state = status.capturing ? "on" : "off"
        let prefix = if let stopped = store.stoppedItselfAt, !status.capturing {
            "Hook capture stopped itself at \(HookCaptureStore.timestamp(stopped))."
        } else if args.action == .off && !wasCapturing {
            "Hook capture was not on."
        } else {
            "Hook capture is \(state)."
        }
        let deadline = status.until.stringOrNil.map { " Stops at \($0)." } ?? ""
        let failure = status.error.stringOrNil.map { " Error: \($0)" } ?? ""
        return io.out("\(prefix) \(status.path) — \(status.records) records.\(deadline)\(failure)")
    }
}
