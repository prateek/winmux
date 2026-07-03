import Common
import TOMLKit

/// `next` and `new` are `scene` subcommands, so no scene may be named them.
let reservedSceneNames: Set<String> = ["next", "new"]

/// Column ids may not use the direction words `card move` and `focus-column` address by, so a
/// column id never shadows a relative move.
let reservedColumnDirectionWords: Set<String> = ["left", "right", "next", "prev"]

/// The backing zone-layout id synthesized for a scene. Prefixed so it never collides with a user
/// `[[zone-layouts]]` id; deck keys address by the scene id itself, not this layout id.
func sceneBackingLayoutId(_ sceneId: String) -> String { "scene-\(sceneId)" }

private struct ParsedSceneBlock: ConvenienceCopyable {
    var monitor: MonitorDescription?
    var defaultColumn: String?
    var columns: [ZoneColumnConfig] = []
}

private let sceneBlockParser: [String: any ParserProtocol<ParsedSceneBlock>] = [
    "display": Parser(\.monitor) { raw, backtrace in
        parseMonitorDescription(raw, backtrace).map(Optional.some)
    },
    "default-column": Parser(\.defaultColumn) { raw, backtrace in
        parseZoneId(raw, backtrace).map(Optional.some)
    },
    "columns": Parser(\.columns, parseZoneColumns),
]

/// Parses the `[scene.*]` surface and folds it into the config-version-2 zone runtime: appends a
/// `SceneConfig` per block (the runtime scene registry Builder 1 reads), a backing
/// `ZoneLayoutConfig` per block, and one synthesized `ZoneConfig` per display targeting its
/// default (first-declared) scene's layout. `rawToml` recovers declaration order because toml++
/// iterates table keys sorted, and the first declared scene per display is its default.
@MainActor
func applyParsedScenes(
    _ rawToml: String,
    _ rawScene: TOMLValueConvertible,
    _ config: inout Config,
    _ errors: inout [TomlParseError],
) {
    let sceneRootBacktrace: TomlBacktrace = .rootKey("scene")
    guard let sceneTable = rawScene.table else {
        errors.append(expectedActualTypeError(expected: .table, actual: rawScene.type, sceneRootBacktrace))
        return
    }

    let orderedSceneIds = orderedSceneIds(declaredIn: rawToml, presentIn: Set(sceneTable.keys))

    var scenes: [SceneConfig] = []
    var backingLayouts: [ZoneLayoutConfig] = []
    var defaultSceneByDisplayLabel: [String: SceneConfig] = [:]
    var displayLabelOrder: [String] = []

    for sceneId in orderedSceneIds {
        let backtrace = sceneRootBacktrace + .key(sceneId)
        guard let rawBlock = sceneTable[sceneId] else { continue }

        if reservedSceneNames.contains(sceneId) {
            errors.append(.semantic(backtrace, "'\(sceneId)' is a reserved scene name"))
        }
        if !isValidSceneIdentifier(sceneId) {
            errors.append(.semantic(backtrace, "Scene name must use only letters, numbers, hyphens, and underscores"))
        }

        var block = parseTable(rawBlock, ParsedSceneBlock(), sceneBlockParser, backtrace, &errors)
        validateSceneBlock(&block, backtrace, &errors)

        let layoutId = sceneBackingLayoutId(sceneId)
        let scene = SceneConfig(id: sceneId, monitor: block.monitor, layoutId: layoutId, defaultColumn: block.defaultColumn)
        scenes.append(scene)
        backingLayouts.append(ZoneLayoutConfig(
            id: layoutId,
            layout: .columns,
            defaultZone: block.defaultColumn,
            columns: block.columns,
        ))

        if let monitor = block.monitor {
            let label = monitorDescriptionLabel(monitor)
            if defaultSceneByDisplayLabel[label] == nil {
                defaultSceneByDisplayLabel[label] = scene
                displayLabelOrder.append(label)
            }
        }
    }

    validateSceneDisplayOverlap(displayLabelOrder, existingZones: config.zones, errors: &errors)

    config.scenes += scenes
    config.zoneLayouts += backingLayouts
    for label in displayLabelOrder {
        guard let defaultScene = defaultSceneByDisplayLabel[label], let monitor = defaultScene.monitor else { continue }
        config.zones.append(ZoneConfig(monitor: monitor, layoutPreset: defaultScene.layoutId))
    }
}

private func validateSceneBlock(
    _ block: inout ParsedSceneBlock,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) {
    if block.monitor == nil {
        errors.append(.semantic(backtrace + .key("display"), "Missing required key"))
    }
    if block.columns.isEmpty {
        errors.append(.semantic(backtrace + .key("columns"), "Must contain at least one column"))
    }

    let ids = block.columns.map(\.id)
    let duplicatedIds = ids.grouped { $0 }.filter { id, columns in !id.isEmpty && columns.count > 1 }.keys.sorted()
    if !duplicatedIds.isEmpty {
        errors.append(.semantic(backtrace + .key("columns"), "Contains duplicated column ids: \(duplicatedIds.joined(separator: ", "))"))
    }

    let reservedIds = ids.filter { reservedColumnDirectionWords.contains($0) }.sorted()
    if !reservedIds.isEmpty {
        errors.append(.semantic(backtrace + .key("columns"), "Column ids may not use the reserved direction words: \(reservedIds.joined(separator: ", "))"))
    }

    if let defaultColumn = block.defaultColumn, !ids.contains(defaultColumn) {
        errors.append(.semantic(backtrace + .key("default-column"), "Must name one of the configured column ids"))
    }

    let widthSum = block.columns.reduce(0) { $0 + $1.width }
    if !block.columns.isEmpty, abs(widthSum - 1.0) > 0.0001 {
        errors.append(.semantic(backtrace + .key("columns"), "Column widths must sum to 1.0"))
    }
}

private func validateSceneDisplayOverlap(
    _ sceneDisplayLabels: [String],
    existingZones: [ZoneConfig],
    errors: inout [TomlParseError],
) {
    let zoneLabels = Set(existingZones.compactMap { $0.monitor.map(monitorDescriptionLabel) })
    let overlap = sceneDisplayLabels.filter { zoneLabels.contains($0) }.sorted()
    if !overlap.isEmpty {
        errors.append(.semantic(
            .rootKey("scene"),
            "Displays are configured by both [[zones]] and [scene.*]: \(overlap.joined(separator: ", "))",
        ))
    }
}

/// Scene ids in declaration order. toml++ iterates keys sorted, so the source text is the only
/// record of the order the user declared scenes in; ids present in the parsed table but absent
/// from the text scan fall back to sorted order.
private func orderedSceneIds(declaredIn rawToml: String, presentIn presentIds: Set<String>) -> [String] {
    var ordered: [String] = []
    var seen: Set<String> = []
    for line in rawToml.split(separator: "\n", omittingEmptySubsequences: false) {
        guard let sceneId = sceneHeaderId(String(line)), presentIds.contains(sceneId), seen.insert(sceneId).inserted else { continue }
        ordered.append(sceneId)
    }
    for sceneId in presentIds.sorted() where !seen.contains(sceneId) {
        ordered.append(sceneId)
    }
    return ordered
}

/// The scene id from a `[scene.<id>]` table header line, else nil. Column bodies are inline
/// arrays, so `[scene.<id>]` is the only header form scenes produce.
private func sceneHeaderId(_ line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("[scene."), trimmed.hasSuffix("]"), !trimmed.hasPrefix("[[") else { return nil }
    let inner = trimmed.dropFirst("[scene.".count).dropLast()
    let id = String(inner)
    return isValidSceneIdentifier(id) ? id : nil
}

private func isValidSceneIdentifier(_ raw: String) -> Bool {
    !raw.isEmpty && raw.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
}
