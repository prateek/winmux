import AppKit

struct LensKeyBinding {
    let name: String
    let code: UInt16
    let modifiers: NSEvent.ModifierFlags

    @MainActor
    static func resolve(_ keys: [String: [String]]) -> [LensKeyBinding] {
        keys.keys.sorted().compactMap { name in
            if case .success(let (modifiers, key)) = parseBinding(name, .emptyRoot, config.keyMapping.resolve()) {
                return LensKeyBinding(name: name, code: UInt16(key.carbonKeyCode), modifiers: modifiers)
            }
            return nil
        }
    }
}

enum LensKeyMeaning: Equatable {
    case command(String)
    case step(Int)
    case text(String)
    case backspace
    case arrow(UInt16)
    case dismiss
    case mark
    case global
    case fieldEditor
    case dropped
}

func lensKeyMeaning(hold: StripGesture?, keys: [LensKeyBinding], code: UInt16,
                    characters: String, flags: NSEvent.ModifierFlags) -> LensKeyMeaning {
    let modifiers = flags.intersection([.command, .control, .option, .shift])
    if let key = keys.first(where: { $0.code == (code == 76 ? 36 : code) && $0.modifiers == modifiers }) {
        return .command(key.name)
    }
    if let hold {
        if let step = hold.step(keyCode: code, flags: flags) { return .step(step) }
        if (code == 48 || code == 50 || characters == "`"), hold.owns(flags) { return .step(0) }
        if !modifiers.subtracting(hold.invoking.union(.shift)).isEmpty { return .global }
        if modifiers.contains(.command), ["a", "v", "c", "x", "z", "y"].contains(characters.lowercased()) { return .dropped }
    }
    if hold == nil, !modifiers.intersection([.command, .control, .option]).isEmpty, ![UInt16(48), 53, 123, 124, 125, 126].contains(code) { return .fieldEditor }
    switch code {
        case 53: return .dismiss
        case 123...126: return .arrow(code)
        case 51: return .backspace
        case 48: return .mark
        default: break
    }
    if !characters.isEmpty, characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) {
        return .text(characters)
    }
    return hold == nil ? .fieldEditor : .dropped
}

extension LensSession {
    func meaning(for event: NSEvent) -> LensKeyMeaning {
        lensKeyMeaning(hold: hold, keys: keyBindings, code: event.keyCode,
                       characters: event.charactersIgnoringModifiers ?? "", flags: event.modifierFlags)
    }

    @discardableResult
    func perform(_ meaning: LensKeyMeaning, retainTyping: Bool = false) -> Bool {
        switch meaning {
            case .command(let key): onAction?(key)
            case .step(let delta): cycleStripSelection(delta)
            case .text(let text):
                if settings.presentation == "strip" {
                    guard text.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) else { return false }
                    let selected = selectedId
                    changePresentation("list")
                    send(.searchChanged(text))
                    if let selected { hover(selected) }
                } else {
                    guard hold != nil || retainTyping else { return false }
                    send(.searchChanged(query + text))
                }
            case .backspace:
                guard settings.presentation != "strip", hold != nil || retainTyping else { return false }
                send(.searchChanged(String(query.dropLast())))
            case .arrow(let code):
                if settings.presentation == "miniatures", let direction = [UInt16(123): MiniatureLayout.Direction.left, 124: .right, 125: .down, 126: .up][code] {
                    moveMiniatureSelection(direction)
                } else if settings.presentation == "strip" { cycleStripSelection(code == 123 || code == 126 ? -1 : 1) }
                else { moveSelection(code == 123 || code == 126 ? -1 : 1) }
            case .mark: toggleMark()
            case .dropped: break
            case .dismiss, .global, .fieldEditor: return false
        }
        return true
    }
}
