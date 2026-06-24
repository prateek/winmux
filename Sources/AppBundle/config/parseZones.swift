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

private let zoneColumnParser: [String: any ParserProtocol<ZoneColumnConfig>] = [
    "id": Parser(\.id, parseZoneId),
    "name": Parser(\.name) { raw, backtrace in
        parseString(raw, backtrace).map(Optional.some)
    },
    "width": Parser(\.width, parseZoneColumnWidth),
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

private func parseZoneColumns(
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

private func parseZoneId(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<String> {
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

func validateZoneLayoutReferences(_ config: Config, _ errors: inout [TomlParseError]) {
    let layoutIds = Set(config.zoneLayouts.map(\.id))
    for (index, zone) in config.zones.enumerated() {
        guard let layoutPreset = zone.layoutPreset, !layoutIds.contains(layoutPreset) else { continue }
        errors.append(.semantic(.rootKey("zones") + .index(index) + .key("layout-preset"), "Unknown zone layout preset '\(layoutPreset)'"))
    }
}

private func monitorDescriptionLabel(_ monitor: MonitorDescription) -> String {
    switch monitor {
        case .sequenceNumber(let number): "\(number)"
        case .main: "main"
        case .secondary: "secondary"
        case .pattern(let raw, _): raw
    }
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
