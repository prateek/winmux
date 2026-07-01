import Common
import Foundation

struct ZoneCommand: Command {
    let args: ZoneCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        switch args.action.val {
            case .initialize:
                return runInit(io)
        }
    }

    @MainActor
    private func runInit(_ io: CmdIo) -> Bool {
        let targetMonitor: Monitor
        switch resolveZoneInitMonitor(args.monitor) {
            case .success(let monitor):
                targetMonitor = monitor
            case .failure(let message):
                return io.err(message)
        }

        let monitorId = targetMonitor.monitorId_oneBased ?? targetMonitor.monitorAppKitNsScreenScreensId
        let preset = zoneInitPresetDefinition(args.preset)
        let block = renderZoneInitManagedBlock(preset: args.preset, presetDefinition: preset, monitorId: monitorId)

        let originalText: String
        do {
            originalText = try String(contentsOf: configUrl, encoding: .utf8)
        } catch {
            return io.err("Can't read config file '\(configUrl.path)': \(error.localizedDescription)")
        }

        let edit: ZoneInitConfigEditResult
        switch applyZoneInitManagedBlock(to: originalText, block: block, replaceExisting: args.replaceExisting) {
            case .success(let result):
                edit = result
            case .failure(let message):
                return io.err(message)
        }

        let mode = args.write ? "write" : "dry-run"
        let summary = zoneInitMonitorSummary(targetMonitor)

        if !args.write {
            return io.out(renderZoneInitOutput(
                title: edit.status == .unchanged
                    ? "Dry run: zone init is already configured in \(configUrl.path)"
                    : "Dry run: would append \(args.preset.rawValue) zones to \(configUrl.path)",
                mode: mode,
                preset: args.preset,
                monitorSummary: summary,
                backupPath: nil,
                block: block,
            ))
        }

        if edit.status == .unchanged {
            return io.out(renderZoneInitOutput(
                title: "Zone init already configured in \(configUrl.path)",
                mode: mode,
                preset: args.preset,
                monitorSummary: summary,
                backupPath: nil,
                block: block,
            ) + ["No changes needed."])
        }

        let backup = nextZoneInitBackupUrl(for: configUrl)
        do {
            try FileManager.default.copyItem(at: configUrl, to: backup)
            try edit.updatedText.write(to: configUrl, atomically: true, encoding: .utf8)
        } catch {
            return io.err("Can't write zone init config to '\(configUrl.path)': \(error.localizedDescription)")
        }

        return io.out(renderZoneInitOutput(
            title: "Wrote \(args.preset.rawValue) zones to \(configUrl.path)",
            mode: mode,
            preset: args.preset,
            monitorSummary: summary,
            backupPath: backup.path,
            block: block,
        ))
    }
}

@MainActor
private func resolveZoneInitMonitor(_ monitorDescription: MonitorDescription?) -> Result<Monitor, String> {
    let physicals = sortedPhysicalMonitors
    if let monitorDescription {
        guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: physicals) else {
            return .failure("Can't resolve monitor selector for zone init")
        }
        return .success(monitor)
    }
    guard let monitor = physicals.sorted(by: zoneInitMonitorSort).first else {
        return .failure("No physical monitors are available for zone init")
    }
    return .success(monitor)
}

private func zoneInitMonitorSort(_ lhs: Monitor, _ rhs: Monitor) -> Bool {
    let lhsAspect = lhs.rect.height > 0 ? lhs.rect.width / lhs.rect.height : 0
    let rhsAspect = rhs.rect.height > 0 ? rhs.rect.width / rhs.rect.height : 0
    if lhsAspect != rhsAspect {
        return lhsAspect > rhsAspect
    }
    return lhs.rect.width > rhs.rect.width
}

@MainActor
private func zoneInitMonitorSummary(_ monitor: Monitor) -> String {
    let id = monitor.monitorId_oneBased ?? monitor.monitorAppKitNsScreenScreensId
    let width = Int(monitor.rect.width.rounded())
    let height = Int(monitor.rect.height.rounded())
    let aspect = monitor.rect.height > 0 ? Double(monitor.rect.width / monitor.rect.height) : 0
    let name = monitor.name.isEmpty ? "Display \(id)" : monitor.name
    return "monitor \(id) \(name) \(width)x\(height) aspect \(zoneInitFormatTomlFloat(aspect))"
}
