import AppKit
import Common
import HotKey

@MainActor
func parseKeymap(_ value: JSONValue?, modes: [String: Mode], mapping: [String: Key], errors: inout [TomlParseError]) -> [KeymapBlock] {
    let data = try! JSONEncoder().encode(value ?? .object([:]))
    let raw = try! JSONSerialization.jsonObject(with: data)
    let sugar = modes.mapValues { mode -> [String: Any] in
        var bindings: [String: Any] = [:]
        for binding in mode.bindings.values { bindings[binding.descriptionWithKeyNotation] = binding.commands.map { $0.args.description } }
        for binding in mode.sequenceBindings.values { bindings[binding.descriptionWithKeyNotation] = binding.commands.map { $0.args.description } }
        for binding in mode.passBindings { bindings[binding] = "pass" }
        return ["binding": bindings]
    }
    let compiled = compileModeKeymap(["keymap": raw, "mode": sugar], mapping: mapping)
    errors += compiled.errors.map(TomlParseError.syntax)
    return compiled.blocks.map { block in
        KeymapBlock(name: block.name, condition: block.condition, priority: block.priority, bindings: block.bindings.map { binding in
            KeymapBinding(name: binding.name, chords: binding.chords, commands: binding.commands.map { commands in
                commands.compactMap { if case .cmd(let command) = parseCommand($0) { command } else { nil } }
            })
        })
    }
}
