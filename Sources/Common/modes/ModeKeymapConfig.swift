import AppKit
import Foundation
import HotKey

public struct ModeConfigError: Error, CustomStringConvertible {
    public let description: String
    public init(_ message: String) { description = message }
}

public func parseModeChord(_ text: String, mapping: [String: Key]) throws -> ModeChord {
    let parts = text.split(separator: "-").map(String.init)
    guard let last = parts.last, let key = mapping[last] else { throw ModeConfigError("Can't parse the key in '\(text)' binding") }
    var modifiers: NSEvent.ModifierFlags = []
    for part in parts.dropLast() {
        guard let modifier = modifiersMap[part] else { throw ModeConfigError("Can't parse modifiers in '\(text)' binding") }
        modifiers.formUnion(modifier)
    }
    return ModeChord(code: UInt16(key.carbonKeyCode), modifiers: modifiers)
}

public func parseModeSequence(_ text: String, mapping: [String: Key]) throws -> [ModeChord] {
    var parts = text.split(whereSeparator: \.isWhitespace).map(String.init)
    if parts.count == 1 {
        let legacy = text.split(separator: "-").map(String.init)
        if legacy.count == 2, mapping[legacy[0]] != nil, modifiersMap[legacy[0]] == nil { parts = legacy }
    }
    guard !parts.isEmpty else { throw ModeConfigError("empty chord") }
    return try parts.map { try parseModeChord($0, mapping: mapping) }
}

public struct ModeBindingSource {
    public let name: String
    public let chords: [ModeChord]
    public let commands: [String]?
}
public struct ModeBlockSource {
    public let name: String
    public let condition: KeyCondition
    public let priority: Int
    public let bindings: [ModeBindingSource]
}

/// Compiles keymap records and mode.binding sugar.
public func compileModeKeymap(_ fields: [String: Any], mapping suppliedMapping: [String: Key]? = nil) -> (blocks: [ModeBlockSource], errors: [String]) {
    var errors: [String] = []
    let modes = fields["mode"] as? [String: [String: Any]] ?? [:]
    let policies = modes.mapValues { $0["unbound"] as? String ?? "pass" }
    for (name, mode) in modes where mode["latch-to"] != nil || mode["unbound"] as? String == "latch" {
        if let error = modeLatchDiagnostic(mode["latch-to"] as? String ?? "browse", policies: policies) {
            errors.append("mode.\(name).latch-to: \(error)")
        }
    }
    let keySettings = fields["key-mapping"] as? [String: Any] ?? [:]
    let preset = (keySettings["preset"] as? String).flatMap(KeyMapping.Preset.init(rawValue:)) ?? .qwerty
    let aliases = (keySettings["key-notation-to-key-code"] as? [String: String] ?? [:]).compactMapValues { keyNotationToKeyCode[$0] }
    let mapping = suppliedMapping ?? KeyMapping(preset: preset, rawKeyNotationToKeyCode: aliases).resolve()
    var raw = fields["keymap"] as? [String: [String: Any]] ?? [:]
    for (name, mode) in fields["mode"] as? [String: [String: Any]] ?? [:] {
        if let bindings = mode["binding"] as? [String: Any], !bindings.isEmpty {
            let blockName = "mode-\(name)"
            if raw[blockName] != nil { errors.append("keymap.\(blockName): name is reserved by mode.\(name).binding") }
            else { raw[blockName] = ["context": "mode == '\(name)'", "priority": 1, "bindings": bindings] }
        }
        var lists = ["on-enter": mode["on-enter"], "on-release": mode["on-release"]]
        for (key, value) in mode["binding-tap"] as? [String: Any] ?? [:] { lists["binding-tap.\(key)"] = value }
        for (property, value) in lists {
            let commands = (value as? String).map { [$0] } ?? value as? [String] ?? []
            for command in commands {
                if let diagnostic = modeCommandDiagnostic(command) { errors.append("mode.\(name).\(property): \(diagnostic)") }
            }
        }
    }
    var blocks: [ModeBlockSource] = []
    for (name, block) in raw.sorted(by: { $0.key < $1.key }) {
        do {
            let condition = try KeyCondition(block["context"] as? String ?? "mode == main")
            var bindings: [ModeBindingSource] = []
            for (key, value) in (block["bindings"] as? [String: Any] ?? [:]).sorted(by: { $0.key < $1.key }) {
                do {
                    let chords = try parseModeSequence(key, mapping: mapping)
                    let commands: [String]?
                    if value as? String == "pass" { commands = nil }
                    else if let string = value as? String { commands = [string] }
                    else if let strings = value as? [String] { commands = strings }
                    else { throw ModeConfigError("expected commands or 'pass") }
                    for command in commands ?? [] {
                        if let diagnostic = modeCommandDiagnostic(command) { errors.append("keymap.\(name).\(key): \(diagnostic)") }
                    }
                    if let commands, commands.contains("lens peek"), commands != ["lens peek"] { errors.append("keymap.\(name).\(key): lens peek runs alone") }
                    bindings.append(.init(name: key, chords: chords, commands: commands))
                } catch { errors.append("keymap.\(name): unparseable chord '\(key)': \(error)") }
            }
            blocks.append(.init(name: name, condition: condition, priority: block["priority"] as? Int ?? 1, bindings: bindings))
        } catch { errors.append("keymap.\(name): \(error)") }
    }
    for (index, a) in blocks.enumerated() {
        for b in blocks.dropFirst(index) where !a.condition.excludes(b.condition) {
            for (xIndex, x) in a.bindings.enumerated() {
                for (yIndex, y) in b.bindings.enumerated() {
                    if a.name == b.name && yIndex <= xIndex { continue }
                    let same = x.chords == y.chords
                    let prefix = !same && (x.chords.starts(with: y.chords) || y.chords.starts(with: x.chords))
                    if prefix || (same && a.priority == b.priority && a.condition.specificity == b.condition.specificity) {
                        errors.append("keymap.\(a.name) and \(b.name): conflicting binding '\(x.name)' / '\(y.name)'")
                    }
                }
            }
        }
    }
    for name in (fields["lenses"] as? [String: Any] ?? [:]).keys where LensCmdArgs.verbNames.contains(name) {
        errors.append("lenses.\(name): reserved Lens verb")
    }
    return (blocks, errors)
}

public func modeLatchDiagnostic(_ target: String, policies: [String: String]) -> String? {
    guard let policy = policies[target] else { return "Unknown mode '\(target)'" }
    return policy == "latch" ? "Target '\(target)' must not itself use unbound = 'latch" : nil
}

public func modeCommandDiagnostic(_ command: String) -> String? {
    if command.hasPrefix("exec-and-forget ") { return nil }
    switch command.splitArgs() {
        case .failure(let error): return error
        case .success(let words):
            switch parseCmdArgs(words.slice) {
                case .cmd(let args):
                    if let lens = args as? LensCmdArgs, lens.verb == "run" { return modeCommandDiagnostic(lens.operands.joinArgs()) }
                    return type(of: args).info.allowInConfig ? nil : "Command '\(type(of: args).info.kind.rawValue)' cannot be used in config"
                case .failure(let error): return error
                case .help: return "Help is not a binding"
            }
    }
}
