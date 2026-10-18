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
        let appliedBefore = window.lastAppliedLayoutPhysicalRect
        var live = try await readAxRect(window)
        if window.lastAppliedLayoutPhysicalRect != appliedBefore, window.lastAppliedLayoutPhysicalRect == nil {
            // A layout during the read made the window floating or fullscreen: only AX knows its frame now.
            live = try await readAxRect(window)
        }
        guard ticket == highlight.generation, focus == target,
              TrayMenuModel.shared.isEnabled, !MissionControlState.shared.isOpen else { return true }
        let applied = window.lastAppliedLayoutPhysicalRect
        // A layout during the read re-tiled the window after AX answered: mark where WinMux put it.
        let moved = applied != appliedBefore ? applied : nil
        guard let rect = moved ?? live ?? window.lastKnownActualRect ?? cached ?? applied else {
            highlight.dismiss()
            return io.err("find-focus: the focused window's frame is unavailable")
        }
        highlight.show(window: window, rect: rect, appliedRect: applied)
        return true
    }
}

/// A failed AX read leaves the cached frames to answer; cancellation still ends the command.
@MainActor private func readAxRect(_ window: Window) async throws -> Rect? {
    do {
        return try await window.getAxRect()
    } catch let error as CancellationError {
        throw error
    } catch {
        return nil
    }
}
