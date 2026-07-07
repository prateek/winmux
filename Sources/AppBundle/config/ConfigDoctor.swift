import Common
import Foundation

@MainActor
func renderConfigDoctorLines(
    configPath: String,
    configText: String?,
    readError: String? = nil,
    runtimeOverlays: [String: ColumnRuntimeOverlay],
) -> [String] {
    var lines = [
        "Config doctor:",
        "  config path: \(configPath)",
    ]

    guard let configText else {
        lines.append("  config status: ERROR")
        lines.append("  read error: \(readError ?? "Config file could not be read")")
        return lines
    }

    let (parsedConfig, errors) = parseConfig(configText)
    if !errors.isEmpty {
        lines.append("  config status: ERROR")
        lines.append("  parse errors:")
        lines += errors.map { "    \($0)" }
        return lines
    }

    lines.append("  config status: OK")
    lines.append("  \(renderZoneCounts(parsedConfig))")
    lines.append("  zone layout sums: OK")
    lines.append("  zone references: OK")
    if parsedConfig.mouse.columnDividerDrag == .columnMode, parsedConfig.modes[zoneModeId] == nil {
        lines.append("  warning: mouse.column-divider-drag = 'column-mode' but no [mode.\(zoneModeId).binding] exists, so divider dragging is unreachable; define the mode or set the policy to 'always' or 'off'")
    }
    lines += renderRuntimeOverlayLines(runtimeOverlays)
    return lines
}

private func renderZoneCounts(_ config: Config) -> String {
    let layoutColumnCount = config.columnLayouts.reduce(0) { $0 + $1.columns.count }
    return "zones: displays=\(config.zones.count) layouts=\(config.columnLayouts.count) layout-columns=\(layoutColumnCount)"
}

private func renderRuntimeOverlayLines(_ runtimeOverlays: [String: ColumnRuntimeOverlay]) -> [String] {
    guard !runtimeOverlays.isEmpty else { return ["  runtime overlays: none"] }

    var lines = ["  runtime overlays:"]
    for physicalIdentity in runtimeOverlays.keys.sorted() {
        guard let overlay = runtimeOverlays[physicalIdentity] else { continue }
        lines.append("    \(physicalIdentity): active-layout=\(overlay.activeLayoutId ?? "none") active-scene=\(overlay.activeSceneId ?? "none") snap-policy=\(overlay.columnSnapPolicyOverride?.rawValue ?? "none")")
        lines.append("      disabled=\(renderStringSet(overlay.disabledColumnIds))")
        lines.append("      width-overrides=\(renderWidthOverrides(overlay.widthOverridesByLayoutIdentity))")
        lines.append("      styles=\(renderStringMap(overlay.styleOverridesByColumnId))")
        lines.append("      toggle-restore-zone=\(overlay.currentToggleRestoreColumnId ?? "none")")
    }
    return lines
}

private func renderStringSet(_ values: Set<String>) -> String {
    guard !values.isEmpty else { return "none" }
    return values.sorted().joined(separator: ",")
}

private func renderStringMap(_ values: [String: String]) -> String {
    guard !values.isEmpty else { return "none" }
    return values.keys.sorted().map { key in
        "\(key):\(values[key] ?? "")"
    }.joined(separator: ",")
}

private func renderWidthOverrides(_ values: [String: [String: Double]]) -> String {
    guard !values.isEmpty else { return "none" }
    return values.keys.sorted().map { layoutIdentity in
        let zones = values[layoutIdentity] ?? [:]
        let renderedZones = zones.keys.sorted().map { columnId in
            "\(columnId)=\(String(format: "%.4f", zones[columnId] ?? 0))"
        }.joined(separator: ",")
        return "\(layoutIdentity)[\(renderedZones)]"
    }.joined(separator: ";")
}
