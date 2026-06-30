import Common
import Foundation

struct ExportZoneLayoutCommand: Command {
    let args: ExportZoneLayoutCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let targetPhysicalMonitor: Monitor
        if let monitorDescription = args.monitor {
            guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
                return io.err("Can't resolve monitor selector for export-zone-layout")
            }
            targetPhysicalMonitor = monitor
        } else {
            targetPhysicalMonitor = focus.workspace.workspaceMonitor.physicalMonitor
        }

        let rows = getCurrentZoneTopologySnapshot()
            .configuredZones(for: sortedPhysicalMonitors)
            .filter { samePhysicalMonitor($0.physicalMonitor, targetPhysicalMonitor) }

        guard !rows.isEmpty else {
            return io.err("No configured zones found for monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
        }

        let disabledZoneNames = rows
            .filter { !$0.isEnabled }
            .map { $0.zoneName ?? $0.zoneId }
        guard disabledZoneNames.isEmpty else {
            return io.err(
                "Can't export zone layout while zones are disabled on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0): " +
                    "\(disabledZoneNames.joined(separator: ", ")). Enable all zones first.",
            )
        }

        let widthTotal = rows.reduce(0.0) { $0 + $1.effectiveWidth }
        guard widthTotal > 0 else {
            return io.err("Can't export zone layout because effective zone widths are empty")
        }

        let defaultZoneId = rows.first(where: \.isDefaultZone)?.zoneId ?? rows[0].zoneId
        return io.out(renderZoneLayoutToml(
            layoutId: args.layoutId.val,
            defaultZoneId: defaultZoneId,
            rows: rows,
            widthTotal: widthTotal,
        ))
    }
}

private func samePhysicalMonitor(_ lhs: Monitor, _ rhs: Monitor) -> Bool {
    lhs.rect.topLeftCorner == rhs.rect.topLeftCorner
}

private func renderZoneLayoutToml(
    layoutId: String,
    defaultZoneId: String,
    rows: [ConfiguredZoneSummary],
    widthTotal: Double,
) -> [String] {
    let widths = normalizedZoneLayoutWidths(rows.map { $0.effectiveWidth / widthTotal })
    var output = [
        "[[zone-layouts]]",
        "id = \(tomlBasicString(layoutId))",
        "layout = 'columns'",
        "default-zone = \(tomlBasicString(defaultZoneId))",
        "columns = [",
    ]
    for (row, width) in zip(rows, widths) {
        var fields = [
            "id = \(tomlBasicString(row.zoneId))",
        ]
        if let zoneName = row.zoneName {
            fields.append("name = \(tomlBasicString(zoneName))")
        }
        fields.append("width = \(formatTomlFloat(width))")
        output.append("    { \(fields.joined(separator: ", ")) },")
    }
    output.append("]")
    return output
}

private func tomlBasicString(_ value: String) -> String {
    var result = "\""
    for scalar in value.unicodeScalars {
        switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\t": result += "\\t"
            case "\r": result += "\\r"
            default: result.unicodeScalars.append(scalar)
        }
    }
    result += "\""
    return result
}
