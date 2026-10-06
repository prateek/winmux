import Common

struct LensConfig: Equatable, Sendable {
    var filter: String?
    var presentation = "list"
    var tile: String?
    var badges = true
    var entries = "window"
    var sections = "workspace"
    var sort = ["mru"]
    var popups: [String] = []
    var frozenThumbnail = "dimmed"
    var accessoryWindow = "enlarged"
    var summonHints = ["label", "landing-spot"]
    var miniatures = MiniaturesConfig()
    var grid = GridConfig()
    var enabled = true
    var keys: [String: [String]] = {
        var keys = ["enter": ["focus"], "shift-enter": ["summon"], "alt-enter": ["summon"], "cmd-w": ["close"], "cmd-g": ["sections next"]]
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
        tile = value["tile"]?.stringOrNil ?? tile
        if case .bool(let badges) = value["badges"] { self.badges = badges }
        entries = value["entries"]?.stringOrNil ?? entries
        sections = value["sections"]?.stringOrNil ?? sections
        sort = value["sort"]?.arrayOrNil?.compactMap(\.stringOrNil) ?? sort
        popups = value["popups"]?.arrayOrNil?.compactMap(\.stringOrNil) ?? popups
        frozenThumbnail = value["frozen-thumbnail"]?.stringOrNil ?? frozenThumbnail
        accessoryWindow = value["accessory-window"]?.stringOrNil ?? accessoryWindow
        summonHints = value["summon-hints"]?.arrayOrNil?.compactMap(\.stringOrNil) ?? summonHints
        if let miniatureSettings = value["miniatures"] { miniatures.apply(miniatureSettings) }
        if let gridSettings = value["grid"] { grid.apply(gridSettings) }
        if case .bool(let enabled) = value["enabled"] { self.enabled = enabled }
        if case .object(let keys) = value["keys"] {
            for (key, command) in keys {
                self.keys[key] = command.stringOrNil.map { [$0] } ?? command.arrayOrNil?.compactMap(\.stringOrNil) ?? []
            }
        }
    }

    var json: JSONValue {
        .object([
            "tile": .string(TileKind.resolve(configured: tile, presentation: presentation).rawValue), "badges": .bool(badges),
            "filter": filter.map(JSONValue.string) ?? .null,
            "presentation": .string(presentation), "entries": .string(entries), "sections": .string(sections),
            "sort": .array(sort.map(JSONValue.string)), "popups": .array(popups.map(JSONValue.string)),
            "frozen-thumbnail": .string(frozenThumbnail), "accessory-window": .string(accessoryWindow),
            "summon-hints": .array(summonHints.map(JSONValue.string)), "enabled": .bool(enabled),
            "miniatures": miniatures.json, "grid": grid.json,
            "keys": .object(keys.mapValues { $0.count == 1 ? .string($0[0]) : .array($0.map(JSONValue.string)) }),
        ])
    }
}


struct MiniaturesConfig: Equatable, Sendable {
    var fit = "page"
    var currentWorkspace = "highlight"
    var arrowKeys = "nearest"
    var darkness = 0.6
    var blur = true

    mutating func apply(_ value: JSONValue) {
        fit = value["fit"]?.stringOrNil ?? fit
        currentWorkspace = value["current-workspace"]?.stringOrNil ?? currentWorkspace
        arrowKeys = value["arrow-keys"]?.stringOrNil ?? arrowKeys
        if let backdrop = value["backdrop"] {
            switch backdrop["darkness"] {
                case .double(let number): darkness = number
                case .int(let number): darkness = Double(number)
                default: break
            }
            if case .bool(let value) = backdrop["blur"] { blur = value }
        }
    }
    var json: JSONValue {
        .object(["fit": .string(fit), "current-workspace": .string(currentWorkspace), "arrow-keys": .string(arrowKeys),
                 "backdrop": .object(["darkness": .double(darkness), "blur": .bool(blur)])])
    }
}

struct GridConfig: Equatable, Sendable {
    var tileSize = "real"
    var sectionsArrangement = "flow"
    mutating func apply(_ value: JSONValue) {
        tileSize = value["tile-size"]?.stringOrNil ?? tileSize
        sectionsArrangement = value["sections-arrangement"]?.stringOrNil ?? sectionsArrangement
    }
    var json: JSONValue { .object(["tile-size": .string(tileSize), "sections-arrangement": .string(sectionsArrangement)]) }
}
