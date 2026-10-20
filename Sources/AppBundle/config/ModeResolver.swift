import AppKit
import Common
import HotKey

struct KeymapBinding: Sendable {
    let name: String
    let chords: [ModeChord]
    /// nil is an explicit pass; an empty list consumes the chord.
    let commands: [any Command]?
}

struct KeymapBlock: Sendable {
    let name: String
    let condition: KeyCondition
    let priority: Int
    let bindings: [KeymapBinding]
}

struct ModeKeyResolution {
    enum Kind: Equatable { case run, pass, consume, type, latch, cancel, pending, global }
    var kind: Kind
    var commands: [any Command] = []
    var pending: [ModeChord] = []
    var count: Int? = nil
    var repetitions = 1
    var target: String? = nil
    var bindingName: String? = nil
    var editorOwned = false
    var editsSearch = false
}

func modeRegistrationChords(keymap: [KeymapBlock], context: KeyContext, mode: Mode, entryModifiers: NSEvent.ModifierFlags = [], pending: [ModeChord] = [], panelIsKey: Bool = false) -> Set<ModeChord> {
    let continuations = winningKeyBindings(keymap, context: context, prefix: pending).compactMap { binding -> ModeChord? in
        guard binding.commands != nil, binding.chords.count > pending.count else { return nil }
        return binding.chords[pending.count]
    }
    let fresh = winningKeyBindings(keymap, context: context, prefix: []).compactMap { $0.commands == nil ? nil : $0.chords.first }
    var global: [ModeChord] = []
    if context.lensOpen {
        var main = context; main.mode = mainModeId
        global = winningKeyBindings(keymap, context: main, prefix: []).compactMap { $0.commands == nil ? nil : $0.chords.first }.filter {
            resolveModeKey(keymap: keymap, context: context, mode: mode, chord: $0, entryModifiers: entryModifiers, pending: pending).kind == .global
        }
    }
    var result = Set(global)
    for chord in continuations + fresh where chord.code != 49 {
        let candidate = ModeChord(code: chord.code, modifiers: chord.modifiers.union(entryModifiers))
        let resolution = resolveModeKey(keymap: keymap, context: context, mode: mode, chord: candidate, entryModifiers: entryModifiers, pending: pending)
        if resolution.kind == .run || resolution.kind == .pending { result.insert(candidate) }
    }
    return result.filter { $0.code != 49 && (!panelIsKey || !$0.modifiers.intersection([.command, .control, .option]).isEmpty) }
}

func resolveModeKey(keymap: [KeymapBlock], context: KeyContext, mode: Mode, chord: ModeChord,
                    characters: String = "", entryModifiers: NSEvent.ModifierFlags = [], entryChordModifiers: NSEvent.ModifierFlags? = nil,
                    pending: [ModeChord] = [], count: Int? = nil, peeking: Bool = false, composing: Bool = false,
                    typingModifiers: NSEvent.ModifierFlags = []) -> ModeKeyResolution {
    if composing, mode.unbound == .type { return .init(kind: .type, editorOwned: true) }
    if peeking, chord.code == 53, case .cmd(let peek) = parseCommand("lens peek") { return .init(kind: .run, commands: [peek], bindingName: "esc") }
    let held = !entryModifiers.isEmpty
    let discount = (chord.code == 36 ? entryChordModifiers ?? entryModifiers : entryModifiers).union(typingModifiers)
    let stripped = ModeChord(code: chord.code, modifiers: chord.modifiers.subtracting(discount))
    let strippedPeek = winningKeyBindings(keymap, context: context, prefix: [stripped]).first?.commands?.map { $0.args.description } == ["lens peek"]
    let strippedFirst = held && ([UInt16(36), 53, 123, 124, 125, 126].contains(chord.code) || strippedPeek)
    let candidates = stripped != chord ? (strippedFirst ? [stripped, chord] : [chord, stripped]) : [chord]
    for candidate in candidates {
        if !pending.isEmpty, let match = winningKeyBindings(keymap, context: context, prefix: pending + [candidate]).first {
            if match.chords.count > pending.count + 1 { return .init(kind: .pending, pending: pending + [candidate], count: count) }
            return match.commands.map { .init(kind: .run, commands: $0, repetitions: count ?? 1, bindingName: match.name) } ?? .init(kind: .pass, bindingName: match.name)
        }
    }
    for candidate in candidates {
        if let match = winningKeyBindings(keymap, context: context, prefix: [candidate]).first {
            if match.chords.count > 1 { return .init(kind: .pending, pending: [candidate], count: count) }
            return match.commands.map { .init(kind: .run, commands: $0, repetitions: count ?? 1, bindingName: match.name) } ?? .init(kind: .pass, bindingName: match.name)
        }
    }
    if !pending.isEmpty && chord.code == 53 { return .init(kind: .consume) }
    if chord.code == 53 && context.mode != mainModeId { return .init(kind: .cancel, target: mode.lifetime == .transient ? nil : mainModeId) }
    if mode.count, stripped.modifiers.isEmpty, characters.count == 1, let digit = Int(characters), (0...9).contains(digit) {
        return .init(kind: .consume, count: min(9999, (count ?? 0) * 10 + digit))
    }
    let foreign = chord.modifiers.subtracting(entryModifiers.union(.shift))
    if !foreign.isEmpty && (held || mode.unbound != .type) { return .init(kind: .global) }
    switch mode.unbound {
        case .pass: return .init(kind: .pass)
        case .consume: return .init(kind: .consume)
        case .type: return .init(kind: .type, editsSearch: chord.modifiers.contains(.command) && [UInt16(7), 9, 51].contains(chord.code))
        case .latch:
            if !characters.isEmpty, characters.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) {
                return .init(kind: .latch, target: mode.latchTo)
            }
            return .init(kind: .consume)
    }
}

func winningKeyBindings(_ keymap: [KeymapBlock], context: KeyContext, prefix: [ModeChord]) -> [KeymapBinding] {
    let blocks = keymap.filter { $0.condition.matches(context) }.sorted {
        if $0.condition.specificity != $1.condition.specificity { return $0.condition.specificity > $1.condition.specificity }
        if $0.priority != $1.priority { return $0.priority > $1.priority }
        return $0.name < $1.name
    }
    var seen = Set<[ModeChord]>()
    return blocks.flatMap(\.bindings).filter { binding in
        guard binding.chords.starts(with: prefix), seen.insert(binding.chords).inserted else { return false }
        return true
    }
}
