import AppKit
import Common
import HotKey
import TOMLKit

func parseBindings(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
    _ mapping: [String: Key]
) -> (chordBindings: [String: HotkeyBinding], sequenceBindings: [String: SequenceBinding]) {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return ([:], [:])
    }
    var chordResult: [String: HotkeyBinding] = [:]
    var seqResult: [String: SequenceBinding] = [:]
    for (binding, rawCommand): (String, TOMLValueConvertible) in rawTable {
        let backtrace = backtrace + .key(binding)
        if rawCommand.string == "pass" { continue }
        if parseSequenceBindingIfPresent(binding, rawCommand, backtrace, mapping, errors: &errors, result: &seqResult) {
            continue
        }
        parseChordBinding(binding, rawCommand, backtrace, mapping, errors: &errors, result: &chordResult)
    }
    return (chordResult, seqResult)
}

func parseBinding(_ raw: String, _ backtrace: TomlBacktrace, _ mapping: [String: Key]) -> ParsedToml<(NSEvent.ModifierFlags, Key)> {
    do {
        let chord = try parseModeChord(raw, mapping: mapping)
        return .success((chord.modifiers, mapping[String(raw.split(separator: "-").last!)]!))
    } catch { return .failure(.semantic(backtrace, String(describing: error))) }
}

private func parseSequenceBindingIfPresent(
    _ binding: String,
    _ rawCommand: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ mapping: [String: Key],
    errors: inout [TomlParseError],
    result: inout [String: SequenceBinding]
) -> Bool {
    guard looksLikeSequenceBinding(binding, mapping) else { return false }
    let parsedPrefix = tryParseSequenceBinding(binding, backtrace, mapping)
    let seqBindingResult: ParsedToml<SequenceBinding> = parsedPrefix.flatMap { chords in
        parseCommandOrCommands(rawCommand).toParsedToml(backtrace).map { cmds in
            SequenceBinding(chords: chords, commands: cmds, descriptionWithKeyNotation: binding)
        }
    }
    guard let seqBinding = seqBindingResult.getOrNil(appendErrorTo: &errors) else { return true }
    if result.keys.contains(seqBinding.descriptionWithKeyNotation) {
        errors.append(.semantic(backtrace, "'\(seqBinding.descriptionWithKeyNotation)' Sequence binding redeclaration"))
    }
    result[seqBinding.descriptionWithKeyNotation] = seqBinding
    return true
}

private func parseChordBinding(
    _ binding: String,
    _ rawCommand: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ mapping: [String: Key],
    errors: inout [TomlParseError],
    result: inout [String: HotkeyBinding]
) {
    let parsed: ParsedToml<HotkeyBinding> = parseBinding(binding, backtrace, mapping).flatMap { modifiers, key in
        parseCommandOrCommands(rawCommand).toParsedToml(backtrace).map {
            HotkeyBinding(modifiers, key, $0, descriptionWithKeyNotation: binding)
        }
    }
    if let chord = parsed.getOrNil(appendErrorTo: &errors) {
        if result.keys.contains(chord.descriptionWithKeyCode) {
            errors.append(.semantic(backtrace, "'\(chord.descriptionWithKeyCode)' Binding redeclaration"))
        }
        result[chord.descriptionWithKeyCode] = chord
    }
}

private func looksLikeSequenceBinding(_ raw: String, _ mapping: [String: Key]) -> Bool {
    if raw.split(whereSeparator: \.isWhitespace).count > 1 { return true }
    let rawKeys = raw.split(separator: "-")
    guard rawKeys.count == 2 else { return false }
    let first = String(rawKeys[0])
    guard modifiersMap[first] == nil else { return false }
    return mapping[first] != nil
}
