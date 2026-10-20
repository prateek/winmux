import Common
import HotKey
import TOMLKit

struct Mode: ConvenienceCopyable, Equatable, Sendable {
    enum Lifetime: String, Sendable { case latched, held, transient }
    enum Unbound: String, Sendable { case pass, consume, type, latch }
    var lifetime: Lifetime = .latched
    var unbound: Unbound = .pass
    var onEnter: [String] = [] {
        didSet { opensLens = LensCommandList(onEnter).containsOpener }
    }
    private(set) var opensLens = false
    var onRelease: [String] = []
    var latchTo = "browse"
    var drawDelay = 0
    var count = false
    var passBindings: [String] = []
    var bindings: [String: HotkeyBinding]
    var tapBindings: [String: TapBinding]
    var sequenceBindings: [String: SequenceBinding]

    var requiresLens: Bool { unbound != .pass || opensLens }

    init(
        bindings: [String: HotkeyBinding],
        tapBindings: [String: TapBinding],
        sequenceBindings: [String: SequenceBinding] = [:],
    ) {
        self.bindings = bindings
        self.tapBindings = tapBindings
        self.sequenceBindings = sequenceBindings
    }

    static let zero = Mode(bindings: [:], tapBindings: [:], sequenceBindings: [:])
}

func parseModes(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError], _ mapping: [String: Key]) -> [String: Mode] {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return [:]
    }
    var result: [String: Mode] = [:]
    for (key, value) in rawTable {
        result[key] = parseMode(value, backtrace + .key(key), &errors, mapping)
    }
    let policies = result.mapValues { $0.unbound.rawValue }
    for (name, mode) in result where mode.unbound == .latch || rawTable[name]?.table?.contains(key: "latch-to") == true {
        if let error = modeLatchDiagnostic(mode.latchTo, policies: policies) {
            errors.append(.semantic(backtrace + .key(name) + .key("latch-to"), error))
        }
    }
    return result
}

func parseMode(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError], _ mapping: [String: Key]) -> Mode {
    guard let rawTable: TOMLTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return .zero
    }

    var result: Mode = .zero
    for (key, value) in rawTable {
        let backtrace = backtrace + .key(key)
        switch key {
            case "lifetime":
                if let s = value.string, let v = Mode.Lifetime(rawValue: s) { result.lifetime = v }
                else { errors.append(.semantic(backtrace, "Expected latched, held or transient")) }
            case "unbound":
                if let s = value.string, let v = Mode.Unbound(rawValue: s) { result.unbound = v }
                else { errors.append(.semantic(backtrace, "Expected pass, consume, type or latch")) }
            case "on-enter", "on-release":
                let commands = value.string.map { [$0] } ?? value.array?.compactMap(\.string) ?? []
                for command in commands {
                    if let error = modeCommandDiagnostic(command) { errors.append(.semantic(backtrace, error)) }
                }
                if key == "on-enter" { result.onEnter = commands } else { result.onRelease = commands }
            case "latch-to": result.latchTo = value.string ?? "browse"
            case "draw-delay": result.drawDelay = value.int ?? 0
            case "count": result.count = value.bool ?? false
            case "binding":
                result.passBindings = value.table?.compactMap { $0.1.string == "pass" ? $0.0 : nil } ?? []
                let (chordBindings, seqBindings) = parseBindings(value, backtrace, &errors, mapping)
                result.bindings = chordBindings
                result.sequenceBindings = seqBindings
            case "binding-tap":
                result.tapBindings = parseTapBindings(value, backtrace, &errors)
            default:
                errors += [unknownKeyError(backtrace)]
        }
    }
    if !rawTable.contains(key: "unbound"), result.opensLens { result.unbound = .consume }
    if !rawTable.contains(key: "draw-delay"), result.lifetime == .held, LensCommandList(result.onRelease).containsFocus { result.drawDelay = 100 }
    return result
}
