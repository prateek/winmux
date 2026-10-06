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
    let binding = { (flags: NSEvent.ModifierFlags) in
        keys.first { $0.code == (code == 76 ? 36 : code) && $0.modifiers == flags }
    }
    if let key = binding(modifiers) {
        return .command(key.name)
    }
    if let hold {
        if let step = hold.step(keyCode: code, flags: flags) { return .step(step) }
        if (code == 48 || code == 50 || characters == "`"), hold.owns(flags) { return .step(0) }
        if !modifiers.subtracting(hold.invoking.union(.shift)).isEmpty { return .global }
        if let key = binding(modifiers.subtracting(hold.holdModifiers)) { return .command(key.name) }
    }
    if hold == nil, !modifiers.intersection([.command, .control, .option]).isEmpty, ![UInt16(48), 53, 123, 124, 125, 126].contains(code) { return .fieldEditor }
    switch code {
        case 53: return .dismiss
        case 123...126: return .arrow(code)
        case 51: return .backspace
        case 48: return .mark
        default: break
    }
    // Function and navigation keys carry a private-use character, which is not text.
    if !characters.isEmpty, characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && !(0xF700...0xF8FF).contains($0.value) }) {
        return .text(characters)
    }
    return hold == nil ? .fieldEditor : .dropped
}

extension LensSession {
    func meaning(for event: NSEvent) -> LensKeyMeaning {
        lensKeyMeaning(hold: hold, keys: activeKeyBindings, code: event.keyCode,
                       characters: event.charactersIgnoringModifiers ?? "", flags: event.modifierFlags)
    }

    @discardableResult
    func perform(_ meaning: LensKeyMeaning, retainTyping: Bool = false) -> Bool {
        switch meaning {
            case .command(let key): if !performSectionsAction(key) { onAction?(key) }
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
                    // What the session opened with is selected, so the first edit replaces it.
                    send(.searchChanged(searchEdited ? query + text : text))
                }
            case .backspace:
                guard settings.presentation != "strip", hold != nil || retainTyping else { return false }
                send(.searchChanged(searchEdited ? String(query.dropLast()) : ""))
            case .arrow(let code):
                if settings.presentation == "miniatures", let direction = [UInt16(123): MiniatureLayout.Direction.left, 124: .right, 125: .down, 126: .up][code] {
                    moveMiniatureSelection(direction)
                } else if settings.presentation == "grid", let direction = [UInt16(123): GridLayout.Direction.left, 124: .right, 125: .down, 126: .up][code] {
                    moveGridSelection(direction)
                } else if settings.presentation == "strip" { moveStripSelection(code) }
                // With no Hold, left and right move the caret in a list's Search field.
                else if hold == nil, code == 123 || code == 124 { return false }
                else { moveSelection(code == 123 || code == 126 ? -1 : 1) }
            case .mark: toggleMark()
            case .dropped: break
            case .dismiss, .global, .fieldEditor: return false
        }
        return true
    }
}
