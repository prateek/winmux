import AppKit

struct ModeInvocation {
    let keyCode: UInt16?
    let invoking: NSEvent.ModifierFlags
    var holdModifiers: NSEvent.ModifierFlags {
        let primary = invoking.intersection([.command, .control, .option])
        return primary.isEmpty ? invoking.intersection(.shift) : primary
    }
}

@TaskLocal var modeInvocation: ModeInvocation?
