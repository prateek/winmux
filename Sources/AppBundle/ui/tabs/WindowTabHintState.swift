import AppKit

/// The deadline is an effect token: callers supply when it fires, without sleeping in the reducer.
struct WindowTabHintState {
    private(set) var shown: NSEvent.ModifierFlags?
    private(set) var deadline: Int?
    private(set) var held: NSEvent.ModifierFlags = []
    private var spoiled = false
    private var generation = 0

    mutating func flagsChanged(_ flags: NSEvent.ModifierFlags, hasBindings: () -> Bool, allowed: Bool) {
        defer { enforce(allowed: allowed) }
        guard flags != held else { return }
        held = flags
        hide()
        if flags.isEmpty { spoiled = false }
        else if !spoiled && allowed && hasBindings() {
            generation += 1
            deadline = generation
        }
    }

    /// A key or click under held modifiers spoils the hold until every modifier is released, even
    /// under a set with no tab bindings: releasing Shift after an Option-Shift chord must not arm.
    mutating func keyOrClick(allowed: Bool) {
        if shown == nil, !held.isEmpty {
            hide()
            spoiled = true
        }
        enforce(allowed: allowed)
    }

    /// The caller first catches up with the live modifiers, which re-arms or clears the deadline
    /// when they changed, so a token still current means they are the armed set.
    mutating func fire(_ token: Int, allowed: Bool) {
        defer { enforce(allowed: allowed) }
        guard deadline == token else { return }
        deadline = nil
        shown = allowed ? held : nil
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
