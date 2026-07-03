import Common
import TOMLKit

private let zoneParser: [String: any ParserProtocol<ZoneConfig>] = [
    "monitor": Parser(\.monitor) { raw, backtrace in
        parseMonitorDescription(raw, backtrace).map(Optional.some)
    },
    "layout-preset": Parser(\.layoutPreset) { raw, backtrace in
        parseZoneId(raw, backtrace).map(Optional.some)
    },
    "layout": Parser(\.layout) { raw, backtrace in
        parseString(raw, backtrace)
            .flatMap { rawLayout in
                ZoneLayoutKind(rawValue: rawLayout)
                    .orFailure(.semantic(backtrace, "Possible values: columns"))
                    .map(Optional.some)
            }
    },
    "default-zone": Parser(\.defaultZone) { raw, backtrace in
        parseZoneId(raw, backtrace).map(Optional.some)
    },
    "columns": Parser(\.columns, parseZoneColumns),
]

private let zoneLayoutParser: [String: any ParserProtocol<ZoneLayoutConfig>] = [
    "id": Parser(\.id, parseZoneId),
    "layout": Parser(\.layout) { raw, backtrace in
        parseString(raw, backtrace)
            .flatMap { rawLayout in
                ZoneLayoutKind(rawValue: rawLayout)
                    .orFailure(.semantic(backtrace, "Possible values: columns"))
                    .map(Optional.some)
            }
    },
    "default-zone": Parser(\.defaultZone) { raw, backtrace in
        parseZoneId(raw, backtrace).map(Optional.some)
    },
    "columns": Parser(\.columns, parseZoneColumns),
]

private let zoneSceneParser: [String: any ParserProtocol<ZoneSceneConfig>] = [
    "id": Parser(\.id, parseZoneId),
    "layout-preset": Parser(\.layoutPreset) { raw, backtrace in
        parseZoneId(raw, backtrace).map(Optional.some)
    },
    "workspaces": Parser(\.workspaces, parseZoneSceneWorkspaces),
]

private let zoneSceneWorkspaceParser: [String: any ParserProtocol<ZoneSceneWorkspaceConfig>] = [
    "zone": Parser(\.zone, parseZoneId),
    "workspace": Parser(\.workspace) { raw, backtrace in
        parseString(raw, backtrace)
            .flatMap { WorkspaceName.parse($0).toParsedToml(backtrace) }
            .map(Optional.some)
    },
]

private let zoneBindingParser: [String: any ParserProtocol<ZoneBindingConfig>] = [
    "monitor": Parser(\.monitor) { raw, backtrace in
        parseMonitorDescription(raw, backtrace).map(Optional.some)
    },
    "zone": Parser(\.zone, parseZoneId),
    "workspace": Parser(\.workspace) { raw, backtrace in
        parseString(raw, backtrace)
            .flatMap { WorkspaceName.parse($0).toParsedToml(backtrace) }
            .map(Optional.some)
    },
]

private let zoneStyleParser: [String: any ParserProtocol<ZoneStyleConfig>] = [
    "id": Parser(\.id, parseZoneId),
    "color": Parser(\.color, parseZoneStyleColor),
]

private let zoneAvailabilitySetParser: [String: any ParserProtocol<ZoneAvailabilitySetConfig>] = [
    "id": Parser(\.id, parseZoneId),
    "enabled-zones": Parser(\.enabledZones, parseZoneIdArray),
]

private let zoneColumnParser: [String: any ParserProtocol<ZoneColumnConfig>] = [
    "id": Parser(\.id, parseZoneId),
    "name": Parser(\.name) { raw, backtrace in
        parseString(raw, backtrace).map(Optional.some)
    },
    "width": Parser(\.width, parseZoneColumnWidth),
    "color": Parser(\.color) { raw, backtrace in
        parseZoneStyleColor(raw, backtrace).map(Optional.some)
    },
]

func parseZones(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> [ZoneConfig] {
    guard let array = raw.array else {
        errors.append(expectedActualTypeError(expected: .array, actual: raw.type, backtrace))
        return []
    }

    let zones = array.enumerated().map { index, rawZone in
        let zoneBacktrace = backtrace + .index(index)
        var zone = parseTable(rawZone, ZoneConfig(), zoneParser, zoneBacktrace, &errors)
        validateZone(&zone, zoneBacktrace, &errors)
        return zone
    }
    validateZones(zones, backtrace, &errors)
    return zones
}

func parseZoneLayouts(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> [ZoneLayoutConfig] {
    guard let array = raw.array else {
        errors.append(expectedActualTypeError(expected: .array, actual: raw.type, backtrace))
        return []
    }

    let layouts = array.enumerated().map { index, rawLayout in
        let layoutBacktrace = backtrace + .index(index)
        var layout = parseTable(rawLayout, ZoneLayoutConfig(), zoneLayoutParser, layoutBacktrace, &errors)
        validateZoneLayout(&layout, layoutBacktrace, &errors)
        return layout
    }
    validateZoneLayouts(layouts, backtrace, &errors)
    return layouts
}

func parseZoneScenes(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> [ZoneSceneConfig] {
    guard let array = raw.array else {
        errors.append(expectedActualTypeError(expected: .array, actual: raw.type, backtrace))
        return []
    }

    let scenes = array.enumerated().map { index, rawScene in
        let sceneBacktrace = backtrace + .index(index)
        var scene = parseTable(rawScene, ZoneSceneConfig(), zoneSceneParser, sceneBacktrace, &errors)
        validateZoneScene(&scene, sceneBacktrace, &errors)
        return scene
    }
    validateZoneScenes(scenes, backtrace, &errors)
    return scenes
}

func parseZoneStyles(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> [ZoneStyleConfig] {
    guard let array = raw.array else {
        errors.append(expectedActualTypeError(expected: .array, actual: raw.type, backtrace))
        return []
    }

    let styles = array.enumerated().map { index, rawStyle in
        let styleBacktrace = backtrace + .index(index)
        var style = parseTable(rawStyle, ZoneStyleConfig(), zoneStyleParser, styleBacktrace, &errors)
        validateZoneStyle(&style, styleBacktrace, &errors)
        return style
    }
    validateZoneStyles(styles, backtrace, &errors)
    return styles
}

func parseZoneBindings(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> [ZoneBindingConfig] {
    guard let array = raw.array else {
        errors.append(expectedActualTypeError(expected: .array, actual: raw.type, backtrace))
        return []
    }

    let bindings = array.enumerated().map { index, rawBinding in
        let bindingBacktrace = backtrace + .index(index)
        var binding = parseTable(rawBinding, ZoneBindingConfig(), zoneBindingParser, bindingBacktrace, &errors)
        validateZoneBinding(&binding, bindingBacktrace, &errors)
        return binding
    }
    validateZoneBindings(bindings, backtrace, &errors)
    return bindings
}

func parseZoneAvailabilitySets(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> [ZoneAvailabilitySetConfig] {
    guard let array = raw.array else {
        errors.append(expectedActualTypeError(expected: .array, actual: raw.type, backtrace))
        return []
    }

    let sets = array.enumerated().map { index, rawSet in
        let setBacktrace = backtrace + .index(index)
        var set = parseTable(rawSet, ZoneAvailabilitySetConfig(), zoneAvailabilitySetParser, setBacktrace, &errors)
        validateZoneAvailabilitySet(&set, setBacktrace, &errors)
        return set
    }
    validateZoneAvailabilitySets(sets, backtrace, &errors)
    return sets
}

func parseZoneColumns(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> [ZoneColumnConfig] {
    guard let array = raw.array else {
        errors.append(expectedActualTypeError(expected: .array, actual: raw.type, backtrace))
        return []
    }

    return array.enumerated().map { index, rawColumn in
        var column = parseTable(rawColumn, ZoneColumnConfig(), zoneColumnParser, backtrace + .index(index), &errors)
        validateZoneColumn(&column, backtrace + .index(index), &errors)
        return column
    }
}

private func parseZoneIdArray(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> [String] {
    guard let array = raw.array else {
        errors.append(expectedActualTypeError(expected: .array, actual: raw.type, backtrace))
        return []
    }
    return array.enumerated().compactMap { index, rawValue -> String? in
        switch parseZoneId(rawValue, backtrace + .index(index)) {
            case .success(let zoneId):
                return zoneId
            case .failure(let error):
                errors.append(error)
                return nil
        }
    }
}

private func parseZoneSceneWorkspaces(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> [ZoneSceneWorkspaceConfig] {
    guard let array = raw.array else {
        errors.append(expectedActualTypeError(expected: .array, actual: raw.type, backtrace))
        return []
    }

    return array.enumerated().map { index, rawBinding in
        var binding = parseTable(rawBinding, ZoneSceneWorkspaceConfig(), zoneSceneWorkspaceParser, backtrace + .index(index), &errors)
        validateZoneSceneWorkspace(&binding, backtrace + .index(index), &errors)
        return binding
    }
}

func parseZoneId(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<String> {
    parseString(raw, backtrace)
        .filter(.semantic(backtrace, "Must not be empty")) { !$0.isEmpty }
        .filter(.semantic(backtrace, "Use only letters, numbers, hyphens, and underscores")) { rawId in
            rawId.allSatisfy { char in
                char.isLetter || char.isNumber || char == "-" || char == "_"
            }
        }
}

private func parseZoneColumnWidth(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Double> {
    parseDouble(raw, backtrace)
        .filter(.semantic(backtrace, "Must be greater than 0")) { $0 > 0 }
}

private func parseZoneStyleColor(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<String> {
    parseString(raw, backtrace)
        .flatMap { color in
            normalizedWorkspaceSidebarColorHex(color)
                .orFailure(.semantic(backtrace, "Must be a hex color like '#RRGGBB'"))
        }
}

private func validateZone(
    _ zone: inout ZoneConfig,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) {
    if zone.monitor == nil {
        errors.append(.semantic(backtrace + .key("monitor"), "Missing required key"))
    }

    if let _ = zone.layoutPreset {
        if zone.layout != nil {
            errors.append(.semantic(backtrace + .key("layout"), "Cannot be combined with layout-preset"))
        }
        if zone.defaultZone != nil {
            errors.append(.semantic(backtrace + .key("default-zone"), "Cannot be combined with layout-preset"))
        }
        if !zone.columns.isEmpty {
            errors.append(.semantic(backtrace + .key("columns"), "Cannot be combined with layout-preset"))
        }
        return
    }

    if zone.layout == nil {
        errors.append(.semantic(backtrace + .key("layout"), "Missing required key"))
    }
    if zone.columns.isEmpty {
        errors.append(.semantic(backtrace + .key("columns"), "Must contain at least one column"))
    }

    let ids = zone.columns.map(\.id)
    let duplicatedIds = ids.grouped { $0 }.filter { id, columns in !id.isEmpty && columns.count > 1 }.keys.sorted()
    if !duplicatedIds.isEmpty {
        errors.append(.semantic(backtrace + .key("columns"), "Contains duplicated zone ids: \(duplicatedIds.joined(separator: ", "))"))
    }

    if let defaultZone = zone.defaultZone, !ids.contains(defaultZone) {
        errors.append(.semantic(backtrace + .key("default-zone"), "Must name one of the configured zone ids"))
    }

    let widthSum = zone.columns.reduce(0) { $0 + $1.width }
    if !zone.columns.isEmpty, abs(widthSum - 1.0) > 0.0001 {
        errors.append(.semantic(backtrace + .key("columns"), "Column widths must sum to 1.0"))
    }
}

private func validateZoneLayout(
    _ layout: inout ZoneLayoutConfig,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) {
    if layout.id.isEmpty {
        errors.append(.semantic(backtrace + .key("id"), "Missing required key"))
    }
    if layout.layout == nil {
        errors.append(.semantic(backtrace + .key("layout"), "Missing required key"))
    }
    if layout.columns.isEmpty {
        errors.append(.semantic(backtrace + .key("columns"), "Must contain at least one column"))
    }

    let ids = layout.columns.map(\.id)
    let duplicatedIds = ids.grouped { $0 }.filter { id, columns in !id.isEmpty && columns.count > 1 }.keys.sorted()
    if !duplicatedIds.isEmpty {
        errors.append(.semantic(backtrace + .key("columns"), "Contains duplicated zone ids: \(duplicatedIds.joined(separator: ", "))"))
    }

    if let defaultZone = layout.defaultZone, !ids.contains(defaultZone) {
        errors.append(.semantic(backtrace + .key("default-zone"), "Must name one of the configured zone ids"))
    }

    let widthSum = layout.columns.reduce(0) { $0 + $1.width }
    if !layout.columns.isEmpty, abs(widthSum - 1.0) > 0.0001 {
        errors.append(.semantic(backtrace + .key("columns"), "Column widths must sum to 1.0"))
    }
}

private func validateZoneScene(
    _ scene: inout ZoneSceneConfig,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) {
    if scene.id.isEmpty {
        errors.append(.semantic(backtrace + .key("id"), "Missing required key"))
    }
    if scene.layoutPreset == nil {
        errors.append(.semantic(backtrace + .key("layout-preset"), "Missing required key"))
    }
    if scene.workspaces.isEmpty {
        errors.append(.semantic(backtrace + .key("workspaces"), "Must contain at least one workspace binding"))
    }

    let duplicatedZones = scene.workspaces.map(\.zone)
        .grouped { $0 }
        .filter { zone, bindings in !zone.isEmpty && bindings.count > 1 }
        .keys
        .sorted()
    if !duplicatedZones.isEmpty {
        errors.append(.semantic(backtrace + .key("workspaces"), "Contains duplicated zone bindings: \(duplicatedZones.joined(separator: ", "))"))
    }
}

private func validateZoneBinding(
    _ binding: inout ZoneBindingConfig,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) {
    if binding.zone.isEmpty {
        errors.append(.semantic(backtrace + .key("zone"), "Missing required key"))
    }
    if binding.workspace == nil {
        errors.append(.semantic(backtrace + .key("workspace"), "Missing required key"))
    }
}

private func validateZoneStyle(
    _ style: inout ZoneStyleConfig,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) {
    if style.id.isEmpty {
        errors.append(.semantic(backtrace + .key("id"), "Missing required key"))
    }
    if style.color.isEmpty {
        errors.append(.semantic(backtrace + .key("color"), "Missing required key"))
    }
}

private func validateZoneAvailabilitySet(
    _ set: inout ZoneAvailabilitySetConfig,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) {
    if set.id.isEmpty {
        errors.append(.semantic(backtrace + .key("id"), "Missing required key"))
    }
    if set.enabledZones.isEmpty {
        errors.append(.semantic(backtrace + .key("enabled-zones"), "Must contain at least one zone id"))
    }
    let duplicatedZones = set.enabledZones
        .grouped { $0 }
        .filter { zone, zones in !zone.isEmpty && zones.count > 1 }
        .keys
        .sorted()
    if !duplicatedZones.isEmpty {
        errors.append(.semantic(backtrace + .key("enabled-zones"), "Contains duplicated zone ids: \(duplicatedZones.joined(separator: ", "))"))
    }
}

private func validateZones(
    _ zones: [ZoneConfig],
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) {
    var seen: [(monitor: MonitorDescription, label: String)] = []
    var duplicatedLabels: [String] = []
    for zone in zones {
        guard let monitor = zone.monitor else { continue }
        let label = monitorDescriptionLabel(monitor)
        if seen.contains(where: { $0.monitor == monitor }) {
            duplicatedLabels.append(label)
        } else {
            seen.append((monitor, label))
        }
    }
    if !duplicatedLabels.isEmpty {
        errors.append(.semantic(backtrace, "Contains duplicated monitor selectors: \(duplicatedLabels.sorted().joined(separator: ", "))"))
    }
}

private func validateZoneStyles(
    _ styles: [ZoneStyleConfig],
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) {
    let duplicatedIds = styles.map(\.id)
        .grouped { $0 }
        .filter { id, styles in !id.isEmpty && styles.count > 1 }
        .keys
        .sorted()
    if !duplicatedIds.isEmpty {
        errors.append(.semantic(backtrace, "Contains duplicated style ids: \(duplicatedIds.joined(separator: ", "))"))
    }
}

private func validateZoneLayouts(
    _ layouts: [ZoneLayoutConfig],
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) {
    let duplicatedIds = layouts.map(\.id)
        .grouped { $0 }
        .filter { id, layouts in !id.isEmpty && layouts.count > 1 }
        .keys
        .sorted()
    if !duplicatedIds.isEmpty {
        errors.append(.semantic(backtrace, "Contains duplicated layout ids: \(duplicatedIds.joined(separator: ", "))"))
    }
}

private func validateZoneScenes(
    _ scenes: [ZoneSceneConfig],
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) {
    let duplicatedIds = scenes.map(\.id)
        .grouped { $0 }
        .filter { id, scenes in !id.isEmpty && scenes.count > 1 }
        .keys
        .sorted()
    if !duplicatedIds.isEmpty {
        errors.append(.semantic(backtrace, "Contains duplicated scene ids: \(duplicatedIds.joined(separator: ", "))"))
    }
}

private func validateZoneBindings(
    _ bindings: [ZoneBindingConfig],
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) {
    let duplicatedTargets = bindings.map { binding in
        zoneBindingScopeLabel(binding) + ":" + binding.zone
    }
    .grouped { $0 }
    .filter { target, bindings in !target.hasSuffix(":") && bindings.count > 1 }
    .keys
    .sorted()
    if !duplicatedTargets.isEmpty {
        errors.append(.semantic(backtrace, "Contains duplicated zone binding targets: \(duplicatedTargets.joined(separator: ", "))"))
    }

    let duplicatedWorkspaces = bindings.compactMap { binding -> String? in
        binding.workspace.map { zoneBindingScopeLabel(binding) + ":" + $0.raw }
    }
    .grouped { $0 }
    .filter { _, bindings in bindings.count > 1 }
    .keys
    .sorted()
    if !duplicatedWorkspaces.isEmpty {
        errors.append(.semantic(backtrace, "Contains duplicated workspace bindings: \(duplicatedWorkspaces.joined(separator: ", "))"))
    }
}

private func validateZoneAvailabilitySets(
    _ sets: [ZoneAvailabilitySetConfig],
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) {
    let duplicatedIds = sets.map(\.id)
        .grouped { $0 }
        .filter { id, sets in !id.isEmpty && sets.count > 1 }
        .keys
        .sorted()
    if !duplicatedIds.isEmpty {
        errors.append(.semantic(backtrace, "Contains duplicated availability set ids: \(duplicatedIds.joined(separator: ", "))"))
    }
}

func validateZoneLayoutReferences(_ config: Config, _ errors: inout [TomlParseError]) {
    let layoutIds = Set(config.zoneLayouts.map(\.id))
    for (index, zone) in config.zones.enumerated() {
        guard let layoutPreset = zone.layoutPreset, !layoutIds.contains(layoutPreset) else { continue }
        errors.append(.semantic(.rootKey("zones") + .index(index) + .key("layout-preset"), "Unknown zone layout preset '\(layoutPreset)'"))
    }
}

func validateZoneSceneReferences(_ config: Config, _ errors: inout [TomlParseError]) {
    var layoutsById: [String: ZoneLayoutConfig] = [:]
    for layout in config.zoneLayouts where !layout.id.isEmpty && layoutsById[layout.id] == nil {
        layoutsById[layout.id] = layout
    }
    for (sceneIndex, scene) in config.zoneScenes.enumerated() {
        guard let layoutPreset = scene.layoutPreset else { continue }
        guard let layout = layoutsById[layoutPreset] else {
            errors.append(.semantic(.rootKey("zone-scenes") + .index(sceneIndex) + .key("layout-preset"), "Unknown zone layout preset '\(layoutPreset)'"))
            continue
        }

        let layoutZoneIds = Set(layout.columns.map(\.id))
        for (bindingIndex, binding) in scene.workspaces.enumerated() where !binding.zone.isEmpty && !layoutZoneIds.contains(binding.zone) {
            errors.append(.semantic(
                .rootKey("zone-scenes") + .index(sceneIndex) + .key("workspaces") + .index(bindingIndex) + .key("zone"),
                "Must name one of the zones in layout preset '\(layoutPreset)'",
            ))
        }
    }
}

func validateZoneBindingReferences(_ config: Config, _ errors: inout [TomlParseError]) {
    let knownZoneIds = Set(
        config.zones.flatMap(\.columns).map(\.id) +
            config.zoneLayouts.flatMap(\.columns).map(\.id),
    )
    for (bindingIndex, binding) in config.zoneBindings.enumerated() where !binding.zone.isEmpty && !knownZoneIds.contains(binding.zone) {
        errors.append(.semantic(
            .rootKey("zone-bindings") + .index(bindingIndex) + .key("zone"),
            "Unknown zone id '\(binding.zone)'",
        ))
    }
}

func validateZoneAvailabilitySetReferences(_ config: Config, _ errors: inout [TomlParseError]) {
    let knownZoneIds = Set(
        config.zones.flatMap(\.columns).map(\.id) +
            config.zoneLayouts.flatMap(\.columns).map(\.id),
    )
    for (setIndex, set) in config.zoneAvailabilitySets.enumerated() {
        for (zoneIndex, zoneId) in set.enabledZones.enumerated() where !zoneId.isEmpty && !knownZoneIds.contains(zoneId) {
            errors.append(.semantic(
                .rootKey("zone-availability-sets") + .index(setIndex) + .key("enabled-zones") + .index(zoneIndex),
                "Unknown zone id '\(zoneId)'",
            ))
        }
    }
}

func monitorDescriptionLabel(_ monitor: MonitorDescription) -> String {
    switch monitor {
        case .sequenceNumber(let number): "\(number)"
        case .main: "main"
        case .secondary: "secondary"
        case .pattern(let raw, _): raw
    }
}

private func zoneBindingScopeLabel(_ binding: ZoneBindingConfig) -> String {
    binding.monitor.map(monitorDescriptionLabel) ?? "any"
}

private func validateZoneColumn(
    _ column: inout ZoneColumnConfig,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) {
    if column.id.isEmpty {
        errors.append(.semantic(backtrace + .key("id"), "Missing required key"))
    }
}

private func validateZoneSceneWorkspace(
    _ binding: inout ZoneSceneWorkspaceConfig,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) {
    if binding.zone.isEmpty {
        errors.append(.semantic(backtrace + .key("zone"), "Missing required key"))
    }
    if binding.workspace == nil {
        errors.append(.semantic(backtrace + .key("workspace"), "Missing required key"))
    }
}
