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

enum LensInputState: String, Codable, Equatable {
    case hold, normal, search
}

enum LensKeySource { case panel, carbon }

enum LensKeyMeaning: Equatable {
    case command(String)
    case endPeek
    case step(Int)
    case endHold(UInt16, String, NSEvent.ModifierFlags = [])
    case enterSearch
    case leaveSearch
    case text(String)
    case backspace
    case arrow(UInt16)
    case dismiss
    case mark
    case global
    case triggerGlobal
    case globalBinding
    case fieldEditor
    case fieldEditorEdit
    case dropped

    var editsSearch: Bool {
        switch self {
            case .text, .backspace, .fieldEditorEdit: return true
            default: return false
        }
    }
}

func lensKeyMeaning(state: LensInputState, hold: StripGesture?, keys: [LensKeyBinding], code: UInt16,
                    characters: String, flags: NSEvent.ModifierFlags, presentation: String = "list", source: LensKeySource = .panel, searchEmpty: Bool = false, peekKeys: Set<String> = [], peeking: Bool = false) -> LensKeyMeaning {
    let modifiers = flags.intersection([.command, .control, .option, .shift])
    let binding = { (flags: NSEvent.ModifierFlags) in
        keys.first { $0.code == (code == 76 ? 36 : code) && $0.modifiers == flags }
    }
    if peeking, code == 53 { return .endPeek }
    if source == .carbon, state != .hold, presentation != "strip" {
        if !modifiers.intersection([.command, .control, .option]).isEmpty, let key = binding(modifiers) { return .command(key.name) }
        return .globalBinding
    }
    if state == .hold, let hold, code == 36 || code == 76 {
        let released = modifiers.subtracting(hold.invoking)
        if let key = binding(released) { return .command(key.name) }
        return released.intersection([.command, .control, .option]).isEmpty ? .dropped : .global
    }
    let chord = !modifiers.intersection([.command, .control, .option]).isEmpty
    if (state != .search || chord || code == 36 || code == 76 || (searchEmpty && modifiers.isEmpty && binding(modifiers).map { peekKeys.contains($0.name) } == true)), let key = binding(modifiers) {
        return .command(key.name)
    }
    if state == .hold, let hold {
        if let key = binding(modifiers.subtracting(hold.invoking)), peekKeys.contains(key.name) { return .command(key.name) }
        if let step = hold.step(keyCode: code, flags: flags) { return .step(step) }
        if code == 48, presentation == "list", hold.owns(flags) { return .step(flags.contains(.shift) ? -1 : 1) }
        if (code == 48 || code == 50 || characters == "`"), hold.owns(flags) { return .step(0) }
        if !modifiers.subtracting(hold.invoking.union(.shift)).isEmpty { return .global }
        if code == 53 { return .dismiss }
        if (123...126).contains(code) { return .arrow(code) }
        if characters == "/" || (!characters.isEmpty && characters.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) })) {
            return .endHold(code, characters, modifiers.subtracting(hold.holdModifiers))
        }
        return .dropped
    }
    if state == .search, modifiers.contains(.command), code == 7 || code == 9 { return .fieldEditorEdit }
    if state != .hold, chord, hold?.step(keyCode: code, flags: flags) != nil { return .triggerGlobal }
    if state == .normal, chord { return .fieldEditor }
    if chord, ![UInt16(48), 53, 123, 124, 125, 126].contains(code) { return .fieldEditor }
    switch code {
        case 53: return state == .search ? .leaveSearch : .dismiss
        case 123...126: return .arrow(code)
        case 48: return .mark
        default: break
    }
    if state == .normal {
        if characters == "/" { return .enterSearch }
        if let arrow = ["h": UInt16(123), "j": 125, "k": 126, "l": 124][characters.lowercased()] { return .arrow(arrow) }
        return .dropped
    }
    if code == 51 { return .backspace }
    if !characters.isEmpty, characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && !(0xF700...0xF8FF).contains($0.value) }) {
        return .text(characters)
    }
    return .fieldEditor
}

func lensCharacters(_ event: NSEvent, hold: StripGesture?) -> String {
    if let hold {
        return event.characters(byApplyingModifiers: event.modifierFlags.subtracting(hold.holdModifiers)) ?? event.charactersIgnoringModifiers ?? ""
    }
    return event.charactersIgnoringModifiers ?? ""
}

extension LensSession {
    func meaning(for event: NSEvent, source: LensKeySource = .panel) -> LensKeyMeaning {
        let characters = lensCharacters(event, hold: hold)
        return lensKeyMeaning(state: inputState, hold: hold ?? invokingGesture, keys: activeKeyBindings, code: event.keyCode,
                              characters: characters, flags: event.modifierFlags, presentation: settings.presentation, source: source, searchEmpty: query.isEmpty, peekKeys: peekKeys, peeking: zoomPeeking)
    }

    @discardableResult
    func perform(_ meaning: LensKeyMeaning) -> Bool {
        switch meaning {
            case .endPeek: send(.peekToggled)
            case .command(let key): if !performPeekAction(key) && !performSectionsAction(key) { onAction?(key) }
            case .step(let delta): cycleStripSelection(delta)
            case .endHold(let code, let text, let flags):
                if text == "/" { enterSearch() }
                else {
                    let selected = settings.presentation == "strip" ? selectedId : nil
                    endHoldByKey()
                    let meaning = lensKeyMeaning(state: inputState, hold: nil, keys: activeKeyBindings, code: code, characters: text, flags: flags)
                    let handled = perform(meaning)
                    if inputState == .search, let selected { hover(selected) }
                    return handled
                }
            case .enterSearch: enterSearch()
            case .leaveSearch: leaveSearch()
            case .text(let text):
                guard inputState == .search else { return true }
                let updated = searchEdited ? query + text : text
                noteSearchEdit()
                send(.searchChanged(updated))
            case .backspace:
                guard inputState == .search else { return true }
                let updated = searchEdited ? String(query.dropLast()) : ""
                noteSearchEdit()
                send(.searchChanged(updated))
            case .arrow(let code):
                // Edge arrows can return without sending a selection event.
                reanchorPointer()
                if settings.presentation == "miniatures", let direction = [UInt16(123): MiniatureLayout.Direction.left, 124: .right, 125: .down, 126: .up][code] {
                    moveMiniatureSelection(direction)
                } else if settings.presentation == "grid", let direction = [UInt16(123): GridLayout.Direction.left, 124: .right, 125: .down, 126: .up][code] {
                    moveGridSelection(direction)
                } else if settings.presentation == "strip" { moveStripSelection(code) }
                else if inputState != .hold, code == 123 || code == 124 { return inputState != .search }
                else { moveSelection(code == 123 || code == 126 ? -1 : 1) }
            case .mark: toggleMark()
            case .dropped: break
            case .dismiss, .global, .triggerGlobal, .globalBinding, .fieldEditor, .fieldEditorEdit: return false
        }
        return true
    }
}

extension LensConfig {
    var startingInputState: LensInputState {
        startsIn == "search" || (startsIn == nil && presentation == "list") ? .search : .normal
    }
}
