import AppKit
import Common
import HotKey
import TOMLKit

struct SequenceBinding: Equatable, Sendable {
    let chords: [ModeChord]
    let commands: [any Command]
    let descriptionWithKeyNotation: String

    static func == (lhs: SequenceBinding, rhs: SequenceBinding) -> Bool {
        lhs.chords == rhs.chords &&
            lhs.descriptionWithKeyNotation == rhs.descriptionWithKeyNotation &&
            lhs.commands.count == rhs.commands.count &&
            zip(lhs.commands, rhs.commands).allSatisfy { $0.equals($1) }
    }
}

func tryParseSequenceBinding(
    _ raw: String,
    _ backtrace: TomlBacktrace,
    _ mapping: [String: Key]
) -> ParsedToml<[ModeChord]> {
    do {
        let chords = try parseModeSequence(raw, mapping: mapping)
        guard chords.count > 1 else { return .failure(.semantic(backtrace, "A sequence needs at least two chords")) }
        return .success(chords)
    } catch { return .failure(.semantic(backtrace, String(describing: error))) }
}
