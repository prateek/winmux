@testable import AppBundle
import AppKit
import Common

@MainActor var testModeBindings: [String: [String]] {
    get {
        var result: [String: [String]] = [:]
        for binding in winningKeyBindings(config.keymap.isEmpty ? defaultConfig.keymap : config.keymap, context: .init(mode: activeMode ?? "browse"), prefix: []) where binding.chords.count == 1 {
            if result[binding.name] == nil { result[binding.name] = binding.commands?.map { normalizedLensCommandForTests($0.args.description) }.filter { !$0.hasPrefix("mode ") } ?? [] }
        }
        return result
    }
    set { modeBindingsForTests(newValue.mapValues { $0.map(lensCommandForTests) }, mode: activeMode == "search" ? "search" : "browse") }
}

func normalizedLensCommandForTests(_ command: String) -> String {
    if command.hasPrefix("lens run ") { return String(command.dropFirst(9)) }
    if command == "lens close-window" { return "close" }
    return ["lens focus", "lens summon", "lens peek", "lens sections next"].contains(command) ? String(command.dropFirst(5)) : command
}
func lensCommandForTests(_ command: String) -> String {
    if ["focus", "summon", "peek", "sections next"].contains(command) { return "lens " + command }
    if command == "close" { return "lens close-window" }
    return command.hasPrefix("lens ") || command.hasPrefix("mode ") ? command : "lens run " + command
}

@MainActor
func enterModeForTests(_ name: String, gesture: ModeInvocation? = nil) {
    if config.keymap.isEmpty { config.keymap = defaultConfig.keymap }
    for (name, mode) in defaultConfig.modes where config.modes[name] == nil { config.modes[name] = mode }
    ModeEngine.shared.changed = {}
    ModeEngine.shared.modeChanged = {}
    ModeEngine.shared.replace(name, mode: config.modes[name] ?? defaultConfig.modes[name] ?? .zero, invocation: gesture)
}

@MainActor
func modeBindingsForTests(_ bindings: [String: [String]], mode: String = "browse") {
    let values = bindings.mapValues { JSONValue.array($0.map(JSONValue.string)) }
    var errors: [TomlParseError] = []
    let block: JSONValue = .object(["test": .object(["context": .string("mode == '\(mode)'"), "priority": .int(10), "bindings": .object(values)])])
    let base = defaultConfig.keymap.filter { !$0.condition.matches(.init(mode: mode)) }
    config.keymap = base + parseKeymap(block, modes: [:], mapping: config.keyMapping.resolve(), errors: &errors)
    precondition(errors.isEmpty, "\(errors)")
    enterModeForTests(mode)
}

extension LensSession {
    func resolutionForTests(_ event: NSEvent) -> ModeKeyResolution {
        let engine = ModeEngine.shared
        return resolveModeKey(keymap: resolvedModeKeymap(), context: .init(mode: engine.current ?? "main", lensOpen: true, lens: name, presentation: settings.presentation),
                              mode: engine.properties, chord: .init(code: event.keyCode, modifiers: event.modifierFlags),
                              characters: event.charactersIgnoringModifiers ?? "", entryModifiers: engine.entryModifiers)
    }
    @discardableResult
    func cycleStripForTests(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: keyCode)!
        return pressForTests(event)
    }
    func releaseModeForTests(flags: NSEvent.ModifierFlags) {
        if flags.intersection(ModeEngine.shared.entryModifiers).isEmpty { enterBrowseForTests() }
        updateHintModifiers(flags)
    }
    func actionCommandsForTests(for key: String) -> [String] { commands(for: key).map(normalizedLensCommandForTests).filter { !$0.hasPrefix("mode ") } }
    func enterHeldModeForTests(_ gesture: ModeInvocation, staying: Bool = false) {
        let target = staying ? "search-hold" : "cmd-tab"
        if let custom = config.keymap.first(where: { $0.name == "test" }) {
            config.keymap.removeAll { $0.name == "test-held" || $0.condition.matches(.init(mode: target)) }
            config.keymap.append(.init(name: "test-held", condition: try! KeyCondition("mode == '\(target)'"), priority: 10, bindings: custom.bindings))
        }
        enterModeForTests(target, gesture: gesture)
        send(.modifiersChanged(gesture.invoking))
    }
    func enterSearchForTests() { enterModeForTests("search"); modeChanged() }
    func enterBrowseForTests() { enterModeForTests("browse"); modeChanged() }

    @discardableResult
    func pressForTests(_ event: NSEvent) -> Bool {
        if event.keyCode == 53, zoomPeeking { send(.peekToggled); return true }
        let engine = ModeEngine.shared
        let entry = engine.entryModifiers
        let result = resolveModeKey(keymap: resolvedModeKeymap(), context: .init(mode: engine.current ?? "main", lensOpen: true, lens: name, presentation: settings.presentation),
                                    mode: engine.properties, chord: .init(code: event.keyCode, modifiers: event.modifierFlags),
                                    characters: event.charactersIgnoringModifiers ?? "", entryModifiers: entry)
        switch result.kind {
            case .type: typeKey(code: event.keyCode, characters: event.charactersIgnoringModifiers ?? ""); return true
            case .consume, .pending: return true
            case .cancel: enterModeForTests(result.target ?? "main"); owner?.dismiss(); return true
            case .latch:
                enterModeForTests(result.target ?? "browse"); modeChanged()
                let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: event.modifierFlags.subtracting(entry), timestamp: 0, windowNumber: 0, context: nil,
                                          characters: event.charactersIgnoringModifiers ?? "", charactersIgnoringModifiers: event.charactersIgnoringModifiers ?? "", isARepeat: false, keyCode: event.keyCode)!
                return pressForTests(key)
            case .run:
                for command in result.commands {
                    if let args = command.args as? ModeCmdArgs { enterModeForTests(args.targetMode.val); modeChanged() }
                    else if let args = command.args as? LensCmdArgs {
                        switch args.verb {
                            case "step": step(args.operands[0])
                            case "peek": send(.peekToggled)
                            case "mark": toggleMark()
                            case "sections": changeSections("next")
                            case "presentation": changePresentation(args.operands[0])
                            case "close": owner?.dismiss()
                            case "focus", "summon", "close-window", "run":
                                let key = activeKeyBindings.first { $0.code == event.keyCode && $0.modifiers == event.modifierFlags.subtracting(entry) }?.name ?? "enter"
                                onAction?(key)
                            default: break
                        }
                    }
                }
                return true
            case .pass, .global: return false
        }
    }
}
