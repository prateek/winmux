import Common
import Foundation

struct SaveZoneLayoutCommand: Command {
    let args: SaveZoneLayoutCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let targetPhysicalMonitor: Monitor
        if let monitorDescription = args.monitor {
            guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
                return io.err("Can't resolve monitor selector for save-zone-layout")
            }
            targetPhysicalMonitor = monitor
        } else {
            targetPhysicalMonitor = focus.workspace.workspaceMonitor.physicalMonitor
        }

        let rows = getCurrentColumnTopologySnapshot()
            .configuredZones(for: sortedPhysicalMonitors)
            .filter { sameSavePhysicalMonitor($0.physicalMonitor, targetPhysicalMonitor) }

        guard !rows.isEmpty else {
            return io.err("No configured zones found for monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
        }

        let disabledZoneNames = rows
            .filter { !$0.isEnabled }
            .map { $0.zoneName ?? $0.zoneId }
        guard disabledZoneNames.isEmpty else {
            return io.err(
                "Can't save zone layout while zones are disabled on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0): " +
                    "\(disabledZoneNames.joined(separator: ", ")). Enable all zones first.",
            )
        }

        let widthTotal = rows.reduce(0.0) { $0 + $1.effectiveWidth }
        guard widthTotal > 0 else {
            return io.err("Can't save zone layout because effective zone widths are empty")
        }

        let normalizedWidths = normalizedZoneLayoutWidths(rows.map { $0.effectiveWidth / widthTotal })
        let widthsByZoneId = Dictionary(uniqueKeysWithValues: zip(rows.map(\.zoneId), normalizedWidths))

        let target: ZoneLayoutConfigEditTarget
        let targetDescription: String
        if let layoutId = args.layoutId ?? rows.first?.zoneLayoutId {
            target = .namedLayout(id: layoutId)
            targetDescription = "zone layout '\(layoutId)'"
        } else {
            guard let inlineIndex = inlineZoneConfigIndex(for: targetPhysicalMonitor) else {
                return io.err("Can't find editable inline [[zones]] config for monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
            }
            target = .inlineZones(index: inlineIndex)
            targetDescription = "inline [[zones]]"
        }

        let originalText: String
        do {
            originalText = try String(contentsOf: configUrl, encoding: .utf8)
        } catch {
            return io.err("Can't read config file '\(configUrl.path)': \(error.localizedDescription)")
        }

        let edit: ZoneLayoutConfigEditResult
        switch updateZoneLayoutWidthsInConfigText(originalText, target: target, widthsByZoneId: widthsByZoneId) {
            case .success(let result):
                edit = result
            case .failure(let message):
                return io.err(message)
        }

        let parsed = parseConfig(edit.updatedText)
        guard parsed.errors.isEmpty else {
            return io.err("Edited config would not parse:\n\(parsed.errors.map(\.description).joined(separator: "\n"))")
        }

        if args.dryRun {
            return io.out(renderSaveZoneLayoutOutput(
                mode: .dryRun,
                targetDescription: targetDescription,
                monitorId: targetPhysicalMonitor.monitorId_oneBased ?? 0,
                configPath: configUrl.path,
                backupPath: nil,
                changes: edit.changes,
            ))
        }

        let backup = nextZoneLayoutBackupUrl(for: configUrl)
        do {
            try FileManager.default.copyItem(at: configUrl, to: backup)
            try edit.updatedText.write(to: configUrl, atomically: true, encoding: .utf8)
        } catch {
            return io.err("Can't save zone layout to '\(configUrl.path)': \(error.localizedDescription)")
        }

        return io.out(renderSaveZoneLayoutOutput(
            mode: .saved,
            targetDescription: targetDescription,
            monitorId: targetPhysicalMonitor.monitorId_oneBased ?? 0,
            configPath: configUrl.path,
            backupPath: backup.path,
            changes: edit.changes,
        ))
    }
}

private enum SaveZoneLayoutOutputMode {
    case dryRun
    case saved
}

private func renderSaveZoneLayoutOutput(
    mode: SaveZoneLayoutOutputMode,
    targetDescription: String,
    monitorId: Int,
    configPath: String,
    backupPath: String?,
    changes: [ZoneLayoutConfigWidthChange],
) -> [String] {
    var output = switch mode {
        case .dryRun:
            ["Dry run: would save \(targetDescription) on monitor \(monitorId) to \(configPath)"]
        case .saved:
            ["Saved \(targetDescription) on monitor \(monitorId) to \(configPath)"]
    }
    if let backupPath {
        output.append("Backup: \(backupPath)")
    }
    output.append(contentsOf: changes.map { change in
        "\(change.zoneId): \(formatTomlFloat(change.oldWidth)) -> \(formatTomlFloat(change.newWidth))"
    })
    return output
}

@MainActor
private func inlineZoneConfigIndex(for physicalMonitor: Monitor) -> Int? {
    let targetPhysicalMonitor = physicalMonitor.physicalMonitor
    for (index, zone) in config.zones.enumerated() {
        guard zone.layoutPreset == nil,
              let monitorDescription = zone.monitor,
              let resolved = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors),
              sameSavePhysicalMonitor(resolved, targetPhysicalMonitor)
        else { continue }
        return index
    }
    return nil
}

private func nextZoneLayoutBackupUrl(for url: URL) -> URL {
    let stamp = zoneLayoutBackupTimestamp()
    let baseName = "\(url.lastPathComponent).backup-\(stamp)"
    let directory = url.deletingLastPathComponent()
    var candidate = directory.appending(component: baseName)
    var suffix = 2
    while FileManager.default.fileExists(atPath: candidate.path) {
        candidate = directory.appending(component: "\(baseName)-\(suffix)")
        suffix += 1
    }
    return candidate
}

private func zoneLayoutBackupTimestamp(date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
    return formatter.string(from: date)
}

private func sameSavePhysicalMonitor(_ lhs: Monitor, _ rhs: Monitor) -> Bool {
    lhs.physicalMonitor.rect.topLeftCorner == rhs.physicalMonitor.rect.topLeftCorner
}
