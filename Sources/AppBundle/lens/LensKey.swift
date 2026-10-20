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

@MainActor
func lensCharacters(_ event: NSEvent) -> String {
    event.characters(byApplyingModifiers: event.modifierFlags.subtracting(ModeEngine.shared.entryModifiers.union(ModeEngine.shared.textModifiers))) ?? event.charactersIgnoringModifiers ?? ""
}

extension LensSession {
    func step(_ direction: String) {
        if direction == "next" || direction == "prev" { cycleStripSelection(direction == "next" ? 1 : -1); return }
        reanchorPointer()
        let code: UInt16 = ["left": 123, "right": 124, "down": 125, "up": 126][direction] ?? 125
        if settings.presentation == "miniatures", let direction = [UInt16(123): MiniatureLayout.Direction.left, 124: .right, 125: .down, 126: .up][code] {
            moveMiniatureSelection(direction)
        } else if settings.presentation == "grid", let direction = [UInt16(123): GridLayout.Direction.left, 124: .right, 125: .down, 126: .up][code] {
            moveGridSelection(direction)
        } else if settings.presentation == "strip" { moveStripSelection(code) }
        else { moveSelection(code == 123 || code == 126 ? -1 : 1) }
    }
}

extension LensConfig {
    func followsPeek(presentation: String) -> Bool { peek == "follow" && presentation != "miniatures" }
}
