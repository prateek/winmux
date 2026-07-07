import AppKit
import AppBundle
import Common
import CoreGraphics
import Foundation

struct LocalCliResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String

    static func out(_ lines: [String]) -> LocalCliResult {
        LocalCliResult(exitCode: 0, stdout: lines.joined(separator: "\n"), stderr: "")
    }

    static func err(_ message: String) -> LocalCliResult {
        LocalCliResult(exitCode: 1, stdout: "", stderr: message)
    }
}

func printLocalCliResultAndExit(_ result: LocalCliResult) -> Never {
    if !result.stdout.isEmpty { print(result.stdout) }
    if !result.stderr.isEmpty { eprint(result.stderr) }
    exit(result.exitCode)
}

@MainActor
func runPreServerLocalCommandIfAvailable(_ parsedArgs: any CmdArgs) -> LocalCliResult? {
    switch parsedArgs {
        case let args as ColumnCmdArgs where args.target.val == .initialize:
            runLocalColumnInit(args)
        default:
            nil
    }
}

@MainActor
func runServerUnavailableLocalFallbackIfAvailable(_ parsedArgs: any CmdArgs) -> LocalCliResult? {
    guard let args = parsedArgs as? ConfigCmdArgs else { return nil }
    switch args.mode {
        case .check(let path):
            return runLocalConfigCheck(path: path)
        case .restoreBackup(let path):
            return runLocalConfigRestoreBackup(path: path)
        default:
            return nil
    }
}

@MainActor
private func runLocalColumnInit(_ args: ColumnCmdArgs) -> LocalCliResult {
    let targetMonitor: LocalColumnInitMonitor
    switch resolveLocalColumnInitMonitor(args.monitor) {
        case .success(let monitor):
            targetMonitor = monitor
        case .failure(let message):
            return .err(message)
    }

    let preset = columnInitPresetDefinition(args.preset)
    let block = renderColumnInitManagedBlock(preset: args.preset, presetDefinition: preset, monitorId: targetMonitor.id)
    let configUrl = localGeneratedConfigUrl()
    let configExists = FileManager.default.fileExists(atPath: configUrl.path)

    let originalText: String
    do {
        originalText = configExists
            ? try String(contentsOf: configUrl, encoding: .utf8)
            : try localStarterConfigText()
    } catch {
        return .err("Can't read config file '\(configUrl.path)': \(error.localizedDescription)")
    }

    let edit: ColumnInitConfigEditResult
    switch applyColumnInitManagedBlockToConfigText(
        to: originalText,
        block: block,
        replaceExisting: args.replaceExisting,
        validateConfig: validateLocalColumnInitConfig,
    ) {
        case .success(let result):
            edit = result
        case .failure(let message):
            return .err(message)
    }

    let mode = args.write ? "write" : "dry-run"
    if !args.write {
        return .out(renderColumnInitOutput(
            title: localColumnInitDryRunTitle(configUrl: configUrl, preset: args.preset, configExists: configExists, status: edit.status),
            mode: mode,
            preset: args.preset,
            monitorSummary: localColumnInitMonitorSummary(targetMonitor),
            backupPath: nil,
            block: block,
        ))
    }

    if edit.status == .unchanged, configExists {
        return .out(renderColumnInitOutput(
            title: "Column init already configured in \(configUrl.path)",
            mode: mode,
            preset: args.preset,
            monitorSummary: localColumnInitMonitorSummary(targetMonitor),
            backupPath: nil,
            block: block,
        ) + ["No changes needed."])
    }

    let backup = configExists ? nextColumnInitBackupUrl(for: configUrl) : nil
    do {
        let parentUrl = configUrl.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentUrl, withIntermediateDirectories: true)
        if let backup {
            try FileManager.default.copyItem(at: configUrl, to: backup)
        }
        try edit.updatedText.write(to: configUrl, atomically: true, encoding: .utf8)
    } catch {
        return .err("Can't write column init config to '\(configUrl.path)': \(error.localizedDescription)")
    }

    return .out(renderColumnInitOutput(
        title: "\(configExists ? "Wrote" : "Created") \(args.preset.rawValue) columns to \(configUrl.path)",
        mode: mode,
        preset: args.preset,
        monitorSummary: localColumnInitMonitorSummary(targetMonitor),
        backupPath: backup?.path,
        block: block,
    ))
}

@MainActor
private func runLocalConfigCheck(path: String) -> LocalCliResult {
    let url = URL(filePath: path)
    do {
        let text = try String(contentsOf: url, encoding: .utf8)
        switch validateConfigWithAppParser(text) {
            case .success:
                return .out(["Config OK: \(url.path)"])
            case .failure(let message):
                return .err("Config has errors:\n\(message)")
        }
    } catch {
        return .err("Can't check config file '\(path)': \(error.localizedDescription)")
    }
}

@MainActor
private func runLocalConfigRestoreBackup(path: String) -> LocalCliResult {
    switch restoreConfigFromBackup(
        targetUrl: localGeneratedConfigUrl(),
        backupUrl: URL(filePath: path),
        validateConfig: validateConfigWithAppParser,
    ) {
        case .success(let result):
            return .out(renderConfigRestoreBackupOutput(result))
        case .failure(let message):
            return .err(message)
    }
}

private struct LocalColumnInitMonitor {
    let id: Int
    let name: String
    let minX: CGFloat
    let minY: CGFloat
    let width: CGFloat
    let height: CGFloat
    let isMain: Bool
}

@MainActor
private func resolveLocalColumnInitMonitor(_ monitorDescription: MonitorDescription?) -> Result<LocalColumnInitMonitor, String> {
    let physicals = localSortedPhysicalMonitors()
    if let monitorDescription {
        guard let monitor = localResolvePhysicalMonitor(monitorDescription, sortedPhysicalMonitors: physicals) else {
            return .failure("Can't resolve monitor selector for column init")
        }
        return .success(monitor)
    }
    guard let monitor = physicals.sorted(by: localColumnInitMonitorSort).first else {
        return .failure("No physical monitors are available for column init")
    }
    return .success(monitor)
}

@MainActor
private func localSortedPhysicalMonitors() -> [LocalColumnInitMonitor] {
    let mainDisplayId = CGMainDisplayID()
    return NSScreen.screens
        .enumerated()
        .map { index, screen in
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            let displayId = screenNumber.map { CGDirectDisplayID(truncating: $0) }
            let frame = screen.frame
            return LocalColumnInitMonitor(
                id: index + 1,
                name: screen.localizedName,
                minX: frame.minX,
                minY: frame.minY,
                width: frame.width,
                height: frame.height,
                isMain: displayId == mainDisplayId,
            )
        }
        .sorted {
            if $0.minX != $1.minX { return $0.minX < $1.minX }
            if $0.minY != $1.minY { return $0.minY < $1.minY }
            return $0.id < $1.id
        }
        .enumerated()
        .map { index, monitor in
            LocalColumnInitMonitor(
                id: index + 1,
                name: monitor.name,
                minX: monitor.minX,
                minY: monitor.minY,
                width: monitor.width,
                height: monitor.height,
                isMain: monitor.isMain,
            )
        }
}

private func localResolvePhysicalMonitor(
    _ description: MonitorDescription,
    sortedPhysicalMonitors: [LocalColumnInitMonitor],
) -> LocalColumnInitMonitor? {
    switch description {
        case .sequenceNumber(let number):
            sortedPhysicalMonitors.getOrNil(atIndex: number - 1)
        case .main:
            sortedPhysicalMonitors.first(where: \.isMain) ?? sortedPhysicalMonitors.first
        case .pattern(_, let regex):
            sortedPhysicalMonitors.first { monitor in monitor.name.contains(regex.val) }
        case .secondary:
            sortedPhysicalMonitors.takeIf { $0.count == 2 }?
                .first { !$0.isMain }
    }
}

private func localColumnInitMonitorSort(_ lhs: LocalColumnInitMonitor, _ rhs: LocalColumnInitMonitor) -> Bool {
    let lhsAspect = lhs.height > 0 ? lhs.width / lhs.height : 0
    let rhsAspect = rhs.height > 0 ? rhs.width / rhs.height : 0
    if lhsAspect != rhsAspect {
        return lhsAspect > rhsAspect
    }
    return lhs.width > rhs.width
}

private func localColumnInitMonitorSummary(_ monitor: LocalColumnInitMonitor) -> String {
    let width = Int(monitor.width.rounded())
    let height = Int(monitor.height.rounded())
    let aspect = monitor.height > 0 ? Double(monitor.width / monitor.height) : 0
    let name = monitor.name.isEmpty ? "Display \(monitor.id)" : monitor.name
    return "monitor \(monitor.id) \(name) \(width)x\(height) aspect \(columnInitFormatTomlFloat(aspect))"
}

private func localColumnInitDryRunTitle(
    configUrl: URL,
    preset: ColumnInitPreset,
    configExists: Bool,
    status: ColumnInitConfigEditStatus,
) -> String {
    if status == .unchanged {
        return "Dry run: column init is already configured in \(configUrl.path)"
    }
    let verb = configExists ? "append" : "create"
    return "Dry run: would \(verb) \(preset.rawValue) columns to \(configUrl.path)"
}

@MainActor
private func validateLocalColumnInitConfig(_ text: String) -> Result<ColumnInitConfigValidation, String> {
    validateColumnInitConfigWithAppParser(text)
}

private func localGeneratedConfigUrl() -> URL {
    localXdgConfigHomeUrl()
        .appending(path: "winmux")
        .appending(path: "winmux.toml")
}

private func localXdgConfigHomeUrl() -> URL {
    ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"].map { URL(filePath: $0) }
        ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/")
}

private func localStarterConfigText() throws -> String {
    if let envPath = ProcessInfo.processInfo.environment["WINMUX_DEFAULT_CONFIG_PATH"],
       !envPath.isEmpty,
       FileManager.default.fileExists(atPath: envPath)
    {
        return try String(contentsOf: URL(filePath: envPath), encoding: .utf8)
    }
    if let projectDefaultConfigUrl = localDefaultConfigUrlFromProject() {
        return try String(contentsOf: projectDefaultConfigUrl, encoding: .utf8)
    }
    return """
        config-version = 2

        [mode.main.binding]
        """
}

private func localDefaultConfigUrlFromProject() -> URL? {
    let starts = [
        URL(filePath: #filePath),
        URL(filePath: FileManager.default.currentDirectoryPath),
    ]
    for start in starts {
        if let url = findLocalDefaultConfigUrlFromProject(startingAt: start) {
            return url
        }
    }
    return nil
}

private func findLocalDefaultConfigUrlFromProject(startingAt startUrl: URL) -> URL? {
    var url = startUrl
    var isDirectory = ObjCBool(false)
    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue {
        url.deleteLastPathComponent()
    }

    while url.path != url.deletingLastPathComponent().path {
        let configUrl = url.appending(component: "resources/default-config.toml")
        if FileManager.default.fileExists(atPath: url.appending(component: ".git").path),
           FileManager.default.fileExists(atPath: configUrl.path)
        {
            return configUrl
        }
        url.deleteLastPathComponent()
    }
    return nil
}
