import Common

struct FindFocusCommand: Command {
    let args: FindFocusCmdArgs
    let shouldResetClosedWindowsCache = false

    @MainActor
    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let highlight = FindFocusHighlight.shared
        guard TrayMenuModel.shared.isEnabled, !MissionControlState.shared.isOpen else {
            highlight.dismiss()
            return true
        }
        let target = focus
        guard let window = target.windowOrNil else {
            highlight.dismiss()
            return io.err("find-focus: no window is focused")
        }
        let ticket = highlight.generation
        let cached = window.lastKnownActualRect
        let rect = try await window.getAxRect() ?? cached ?? window.lastAppliedLayoutPhysicalRect
        guard ticket == highlight.generation, focus == target,
              TrayMenuModel.shared.isEnabled, !MissionControlState.shared.isOpen else { return true }
        guard let rect else {
            highlight.dismiss()
            return io.err("find-focus: the focused window's frame is unavailable")
        }
        highlight.show(window: window, rect: rect)
        return true
    }
}
