import AppKit

public struct ModeChord: Hashable, Sendable {
    public let code: UInt16
    public var modifiers: NSEvent.ModifierFlags = []
    public init(code: UInt16, modifiers: NSEvent.ModifierFlags = []) {
        self.code = code == 76 ? 36 : code
        self.modifiers = modifiers.intersection([.command, .control, .option, .shift])
    }
    public func hash(into hasher: inout Hasher) { hasher.combine(code); hasher.combine(modifiers.rawValue) }
}
