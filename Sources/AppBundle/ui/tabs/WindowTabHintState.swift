import AppKit

/// The deadline is an effect token: callers supply when it fires, without sleeping in the reducer.
struct WindowTabHintState {
    private(set) var shown: NSEvent.ModifierFlags?
    private(set) var deadline: Int?
    private var held: NSEvent.ModifierFlags = []
    private var spoiled = false
    private var generation = 0

    mutating func flagsChanged(_ flags: NSEvent.ModifierFlags, hasBindings: Bool, allowed: Bool) {
        defer { enforce(allowed: allowed) }
        guard flags != held else { return }
        held = flags
        hide()
        if flags.isEmpty { spoiled = false }
        else if !spoiled && hasBindings && allowed {
            generation += 1
            deadline = generation
        }
    }

    mutating func keyOrClick(allowed: Bool) {
        if deadline != nil {
            hide()
            spoiled = true
        }
        enforce(allowed: allowed)
    }

    mutating func fire(_ token: Int, liveFlags: NSEvent.ModifierFlags, allowed: Bool) {
        defer { enforce(allowed: allowed) }
        guard deadline == token else { return }
        deadline = nil
        shown = allowed && liveFlags == held ? held : nil
    }

    mutating func enforce(allowed: Bool) {
        if !allowed { hide() }
    }

    mutating func reset() { hide() }

    private mutating func hide() {
        shown = nil
        deadline = nil
    }
}

func windowTabHintModifiers(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
    flags.intersection([.control, .option, .shift, .command])
}
