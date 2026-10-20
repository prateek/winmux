import Common

@MainActor
enum WindowMarks {
    // Window objects are replaced on screen lock; registers follow their ids.
    private static var registers: [String: UInt32] = [:]

    static func set(_ register: String, to window: Window) {
        registers[register] = window.windowId
    }

    static func window(for register: String) -> Window? {
        registers[register].flatMap { Window.get(byId: $0) }
    }

    static var live: [(register: String, window: Window)] {
        registers.keys.sorted().compactMap { register in
            window(for: register).map { (register, $0) }
        }
    }

    static func forget(except windowIds: Set<UInt32>) {
        registers = registers.filter { windowIds.contains($0.value) }
    }

    static func resetForTests() { registers = [:] }
}

/// Forgets what WinMux keeps of every window but `windowIds`: its place in focus order and its marks.
@MainActor
func forgetWindowsExcept(_ windowIds: Set<UInt32>) {
    Window.forgetLastFocusedSeqs(except: windowIds)
    WindowMarks.forget(except: windowIds)
}
