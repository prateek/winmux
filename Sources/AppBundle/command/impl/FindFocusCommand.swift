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
        var applied = window.lastAppliedLayoutPhysicalRect
        var live = try await readAxRect(window)
        // A layout during the read may have moved the window after AX answered: read again.
        if window.lastAppliedLayoutPhysicalRect != applied {
            applied = window.lastAppliedLayoutPhysicalRect
            live = try await readAxRect(window)
        }
        guard ticket == highlight.generation, focus == target, window.lastAppliedLayoutPhysicalRect == applied,
              TrayMenuModel.shared.isEnabled, !MissionControlState.shared.isOpen else { return true }
        guard let rect = live ?? window.lastKnownActualRect ?? cached ?? applied else {
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
    } catch is CancellationError {
        throw CancellationError()
    } catch {
        return nil
    }
}
