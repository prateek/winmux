import HotKey

public struct KeyMapping: ConvenienceCopyable, Equatable, Sendable {
    public enum Preset: String, CaseIterable, Sendable {
        case qwerty, dvorak, colemak
    }

    public init(
        preset: Preset = .qwerty,
        rawKeyNotationToKeyCode: [String: Key] = [:],
    ) {
        self.preset = preset
        self.rawKeyNotationToKeyCode = rawKeyNotationToKeyCode
    }

    public var preset: Preset = .qwerty
    public var rawKeyNotationToKeyCode: [String: Key] = [:]

    public func resolve() -> [String: Key] {
        getKeysPreset(preset) + rawKeyNotationToKeyCode
    }
}
