import Common

struct LensConfig: Equatable, Sendable {
    var filter: String?
    var presentation = "list"
    var entries = "window"
    var sections = "workspace"
    var sort = ["mru"]
    var popups: [String] = []
    var frozenThumbnail = "dimmed"
    var accessoryWindow = "enlarged"
    var summonHints = ["label", "landing-spot"]
    var enabled = true
    var keys: [String: [String]] = {
        var keys = ["enter": ["focus"], "shift-enter": ["summon"], "alt-enter": ["summon"], "cmd-w": ["close"]]
        for n in 1 ... 9 { keys["cmd-\(n)"] = ["move-node-to-workspace \(n)"] }
        return keys
    }()

    init() {}

    init(_ value: JSONValue) {
        self.init()
        apply(value)
        if let override = value["when"]?["default"] { apply(override) }
    }

    private mutating func apply(_ value: JSONValue) {
        filter = value["filter"]?.stringOrNil ?? filter
        presentation = value["presentation"]?.stringOrNil ?? presentation
        entries = value["entries"]?.stringOrNil ?? entries
        sections = value["sections"]?.stringOrNil ?? sections
        sort = value["sort"]?.arrayOrNil?.compactMap(\.stringOrNil) ?? sort
        popups = value["popups"]?.arrayOrNil?.compactMap(\.stringOrNil) ?? popups
        frozenThumbnail = value["frozen-thumbnail"]?.stringOrNil ?? frozenThumbnail
        accessoryWindow = value["accessory-window"]?.stringOrNil ?? accessoryWindow
        summonHints = value["summon-hints"]?.arrayOrNil?.compactMap(\.stringOrNil) ?? summonHints
        if case .bool(let enabled) = value["enabled"] { self.enabled = enabled }
        if case .object(let keys) = value["keys"] {
            for (key, command) in keys {
                self.keys[key] = command.stringOrNil.map { [$0] } ?? command.arrayOrNil?.compactMap(\.stringOrNil) ?? []
            }
        }
    }

    var json: JSONValue {
        .object([
            "filter": filter.map(JSONValue.string) ?? .null,
            "presentation": .string(presentation), "entries": .string(entries), "sections": .string(sections),
            "sort": .array(sort.map(JSONValue.string)), "popups": .array(popups.map(JSONValue.string)),
            "frozen-thumbnail": .string(frozenThumbnail), "accessory-window": .string(accessoryWindow),
            "summon-hints": .array(summonHints.map(JSONValue.string)), "enabled": .bool(enabled),
            "keys": .object(keys.mapValues { $0.count == 1 ? .string($0[0]) : .array($0.map(JSONValue.string)) }),
        ])
    }
}
