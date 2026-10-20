import Common

struct LensConfig: Equatable, Sendable {
    var filter: String?
    var presentation = "list"
    var tile: String?
    var badges = true
    var entries = "window"
    var sections = "workspace"
    var sort = ["mru"]
    var popups: [String: Bool] = [:]
    var frozenThumbnail = "dimmed"
    var accessoryWindow = "enlarged"
    var appearance: String?
    var peek = "zoom"
    var hints = "held"
    var hintsKey = "alt"
    var summonHints = ["label", "landing-spot"]
    var miniatures = MiniaturesConfig()
    var grid = GridConfig()
    var enabled = true
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
        if case .object(let values) = value["popups"] { for (key, value) in values { if case .bool(let enabled) = value { popups[key] = enabled } } }
        frozenThumbnail = value["frozen-thumbnail"]?.stringOrNil ?? frozenThumbnail
        accessoryWindow = value["accessory-window"]?.stringOrNil ?? accessoryWindow
        appearance = value["appearance"]?.stringOrNil ?? appearance
        peek = value["peek"]?.stringOrNil ?? peek
        hints = value["hints"]?.stringOrNil ?? hints
        hintsKey = value["hints-key"]?.stringOrNil ?? hintsKey
        summonHints = value["summon-hints"]?.arrayOrNil?.compactMap(\.stringOrNil) ?? summonHints
        if let miniatureSettings = value["miniatures"] { miniatures.apply(miniatureSettings) }
        if let gridSettings = value["grid"] { grid.apply(gridSettings) }
        if case .bool(let enabled) = value["enabled"] { self.enabled = enabled }

    }

    var json: JSONValue {
        .object([
            "tile": .string(TileKind.resolve(configured: tile, presentation: presentation).rawValue), "badges": .bool(badges),
            "filter": filter.map(JSONValue.string) ?? .null,
            "presentation": .string(presentation), "entries": .string(entries), "sections": .string(sections),
            "sort": .array(sort.map(JSONValue.string)), "popups": .object(popups.mapValues(JSONValue.bool)),
            "frozen-thumbnail": .string(frozenThumbnail), "accessory-window": .string(accessoryWindow),
            "appearance": .string(appearance ?? "auto"),
            "peek": .string(peek), "hints": .string(hints), "hints-key": .string(hintsKey),
            "summon-hints": .array(summonHints.map(JSONValue.string)), "enabled": .bool(enabled),
            "miniatures": miniatures.json, "grid": grid.json,
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
