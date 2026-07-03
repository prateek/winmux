import Common
import Foundation

struct SceneCommand: Command {
    let args: SceneCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let targetPhysicalMonitor = resolveScenePhysicalMonitor(args.monitor, io: io) else { return false }

        switch args.target.val {
            case .switchTo(let sceneId):
                return activate(setActiveScene(sceneId, for: targetPhysicalMonitor), io: io)
            case .next:
                return activate(cycleScene(for: targetPhysicalMonitor), io: io)
            case .new(let name):
                return createScene(named: name, on: targetPhysicalMonitor, io: io)
        }
    }

    @MainActor
    private func activate(_ result: Result<SceneActivationResult, String>, io: CmdIo) -> Bool {
        switch result {
            case .success(let activation):
                let columns = activation.columnIds.joined(separator: ", ")
                return io.out("Switched monitor \(activation.physicalMonitor.monitorId_oneBased ?? 0) to scene '\(activation.sceneId)' (columns: \(columns))")
            case .failure(let message):
                return io.err(message)
        }
    }
}

@MainActor
private func resolveScenePhysicalMonitor(_ monitorDescription: MonitorDescription?, io: CmdIo) -> Monitor? {
    if let monitorDescription {
        guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
            _ = io.err("Can't resolve monitor selector for scene")
            return nil
        }
        return monitor
    }
    return focus.workspace.workspaceMonitor.physicalMonitor
}

/// The `[scene.<name>]` block `scene new` would write, or a preflight error. Factored from the
/// file write so it is testable without touching the config on disk: a scene name must be
/// unreserved and unused, and the display must have columns to capture.
@MainActor
func buildSceneBlock(named name: String, on physicalMonitor: Monitor) -> Result<String, String> {
    if reservedSceneNames.contains(name) {
        return .failure("'\(name)' is a reserved scene name")
    }
    if config.scenes.contains(where: { $0.id == name }) {
        return .failure("Scene '\(name)' already exists")
    }
    let monitorId = physicalMonitor.monitorId_oneBased ?? 0
    if displayIsGovernedByUserZones(physicalMonitor) {
        return .failure("Monitor \(monitorId) is configured by [[zones]]; migrate it to [scene.*] before creating scenes")
    }
    let snapshot = liveSceneColumns(on: physicalMonitor)
    guard !snapshot.columns.isEmpty else {
        return .failure("No columns to capture on monitor \(monitorId)")
    }
    return .success(renderSceneConfigBlock(name: name, display: monitorId, defaultColumn: snapshot.defaultColumn, columns: snapshot.columns))
}

/// Whether a physical monitor is governed by a user `[[zones]]` entry rather than a scene's
/// synthesized backing zone. Scenes append one `ZoneConfig` per display keyed to the scene's
/// backing layout id; those are not user zones. Everything else targeting the monitor is a user
/// `[[zones]]` block, matched by physical identity so a `1`-vs-`'main'` selector mismatch between a
/// `[[zones]]` entry and a scene `display` still collides.
@MainActor
private func displayIsGovernedByUserZones(_ physicalMonitor: Monitor) -> Bool {
    let targetTopLeft = physicalMonitor.physicalMonitor.rect.topLeftCorner
    let sortedPhysicals = sortedPhysicalMonitors
    let sceneBackingLayoutIds = Set(config.scenes.map(\.layoutId))
    return config.zones.contains { zone in
        guard let description = zone.monitor,
              let resolved = description.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicals),
              resolved.rect.topLeftCorner == targetTopLeft
        else { return false }
        if let preset = zone.layoutPreset, sceneBackingLayoutIds.contains(preset) { return false }
        return true
    }
}

@MainActor
private func createScene(named name: String, on physicalMonitor: Monitor, io: CmdIo) -> Bool {
    let block: String
    switch buildSceneBlock(named: name, on: physicalMonitor) {
        case .success(let rendered): block = rendered
        case .failure(let message): return io.err(message)
    }
    let monitorId = physicalMonitor.monitorId_oneBased ?? 0

    let originalText: String
    do {
        originalText = try String(contentsOf: configUrl, encoding: .utf8)
    } catch {
        return io.err("Can't read config file '\(configUrl.path)': \(error.localizedDescription)")
    }

    let lineSeparator = originalText.contains("\r\n") ? "\r\n" : "\n"
    let prefix: String
    if originalText.isEmpty {
        prefix = ""
    } else if originalText.hasSuffix(lineSeparator) {
        prefix = lineSeparator
    } else {
        prefix = lineSeparator + lineSeparator
    }
    let updatedText = originalText + prefix + block + lineSeparator

    let parsed = parseConfig(updatedText)
    guard parsed.errors.isEmpty else {
        return io.err("Edited config would not parse:\n\(parsed.errors.map(\.description).joined(separator: "\n"))")
    }

    let backup = nextSceneConfigBackupUrl(for: configUrl)
    do {
        try FileManager.default.copyItem(at: configUrl, to: backup)
        try updatedText.write(to: configUrl, atomically: true, encoding: .utf8)
    } catch {
        return io.err("Can't save scene to '\(configUrl.path)': \(error.localizedDescription)")
    }

    return io.out([
        "Saved scene '\(name)' on monitor \(monitorId) to \(configUrl.path)",
        "Backup: \(backup.path)",
        "TOML:",
        block,
    ])
}

/// The display's live columns, snapshotted for `scene new`. A configured display maps its active
/// columns; an implicit-scene display captures its single full-width column.
@MainActor
private func liveSceneColumns(on physicalMonitor: Monitor) -> (columns: [SceneBlockColumn], defaultColumn: String?) {
    let targetTopLeft = physicalMonitor.physicalMonitor.rect.topLeftCorner
    let rows = getCurrentZoneTopologySnapshot()
        .configuredZones(for: sortedPhysicalMonitors)
        .filter { $0.physicalMonitor.rect.topLeftCorner == targetTopLeft && $0.isEnabled }
    guard !rows.isEmpty else {
        return ([SceneBlockColumn(id: "main", name: "Work", width: 1.0, color: nil)], nil)
    }
    let columns = rows.map { row in
        SceneBlockColumn(id: row.zoneId, name: row.zoneName, width: row.effectiveWidth, color: row.zoneStyleColorHex)
    }
    return (columns, rows.first(where: \.isDefaultZone)?.zoneId)
}

private func nextSceneConfigBackupUrl(for url: URL) -> URL {
    let stamp = sceneConfigBackupTimestamp()
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

private func sceneConfigBackupTimestamp(date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
    return formatter.string(from: date)
}
