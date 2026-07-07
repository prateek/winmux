import Common
import Foundation

struct ColumnCommand: Command {
    let args: ColumnCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        switch args.target.val {
            case .resize(let amount, let column):
                return runResize(column: column, amount: amount, io: io)
            case .collapse(let column):
                return runAvailability(.disable, column: column, io: io)
            case .expand(let column):
                return runAvailability(.enable, column: column, io: io)
            case .toggle(let column):
                return runAvailability(.toggle, column: column, io: io)
            case .color(let hex, let column):
                return runColor(hex: hex, column: column, io: io)
            case .initialize:
                return runInit(io)
        }
    }

    @MainActor
    private func runResize(column: ColumnSelector, amount: ColumnWidthAmount, io: CmdIo) -> Bool {
        switch resizeColumnWidth(selector: column, amount: amount, monitorDescription: args.monitor) {
            case .success(let change):
                return io.out("Resized column '\(change.columnName ?? change.columnId ?? column.raw)' on monitor \(change.physicalMonitor.monitorId_oneBased ?? 0) by \(amount.displayPercent)")
            case .failure(let message):
                return io.err(message)
        }
    }

    @MainActor
    private func runAvailability(_ operation: ColumnVisibilityOperation, column: ColumnSelector, io: CmdIo) -> Bool {
        switch setColumnVisibility(operation, selector: column, monitorDescription: args.monitor) {
            case .success(let change):
                let state = change.isEnabled ? "expanded" : "collapsed"
                let verb = change.changed ? state.capitalized : "Already \(state)"
                return io.out("\(verb) column '\(change.columnName ?? change.columnId)' on monitor \(change.physicalMonitor.monitorId_oneBased ?? 0)")
            case .failure(let message):
                return io.err(message)
        }
    }

    @MainActor
    private func runColor(hex: String, column: ColumnSelector, io: CmdIo) -> Bool {
        switch setColumnColor(selector: column, colorHex: hex, monitorDescription: args.monitor) {
            case .success(let change):
                return io.out("Colored column '\(change.columnName ?? change.columnId)' on monitor \(change.physicalMonitor.monitorId_oneBased ?? 0) as '\(change.colorHex)'")
            case .failure(let message):
                return io.err(message)
        }
    }

    @MainActor
    private func runInit(_ io: CmdIo) -> Bool {
        let targetMonitor: Monitor
        switch resolveColumnInitMonitor(args.monitor) {
            case .success(let monitor):
                targetMonitor = monitor
            case .failure(let message):
                return io.err(message)
        }

        let monitorId = targetMonitor.monitorId_oneBased ?? targetMonitor.monitorAppKitNsScreenScreensId
        let preset = columnInitPresetDefinition(args.preset)
        let block = renderColumnInitManagedBlock(preset: args.preset, presetDefinition: preset, monitorId: monitorId)

        let originalText: String
        do {
            originalText = try String(contentsOf: configUrl, encoding: .utf8)
        } catch {
            return io.err("Can't read config file '\(configUrl.path)': \(error.localizedDescription)")
        }

        let edit: ColumnInitConfigEditResult
        switch applyColumnInitManagedBlock(to: originalText, block: block, replaceExisting: args.replaceExisting) {
            case .success(let result):
                edit = result
            case .failure(let message):
                return io.err(message)
        }

        let mode = args.write ? "write" : "dry-run"
        let summary = columnInitMonitorSummary(targetMonitor)

        if !args.write {
            return io.out(renderColumnInitOutput(
                title: edit.status == .unchanged
                    ? "Dry run: column init is already configured in \(configUrl.path)"
                    : "Dry run: would append \(args.preset.rawValue) columns to \(configUrl.path)",
                mode: mode,
                preset: args.preset,
                monitorSummary: summary,
                backupPath: nil,
                block: block,
            ))
        }

        if edit.status == .unchanged {
            return io.out(renderColumnInitOutput(
                title: "Column init already configured in \(configUrl.path)",
                mode: mode,
                preset: args.preset,
                monitorSummary: summary,
                backupPath: nil,
                block: block,
            ) + ["No changes needed."])
        }

        let backup = nextColumnInitBackupUrl(for: configUrl)
        do {
            try FileManager.default.copyItem(at: configUrl, to: backup)
            try edit.updatedText.write(to: configUrl, atomically: true, encoding: .utf8)
        } catch {
            return io.err("Can't write column init config to '\(configUrl.path)': \(error.localizedDescription)")
        }

        return io.out(renderColumnInitOutput(
            title: "Wrote \(args.preset.rawValue) columns to \(configUrl.path)",
            mode: mode,
            preset: args.preset,
            monitorSummary: summary,
            backupPath: backup.path,
            block: block,
        ))
    }
}

@MainActor
private func resolveColumnInitMonitor(_ monitorDescription: MonitorDescription?) -> Result<Monitor, String> {
    let physicals = sortedPhysicalMonitors
    if let monitorDescription {
        guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: physicals) else {
            return .failure("Can't resolve monitor selector for column init")
        }
        return .success(monitor)
    }
    guard let monitor = physicals.sorted(by: columnInitMonitorSort).first else {
        return .failure("No physical monitors are available for column init")
    }
    return .success(monitor)
}

private func columnInitMonitorSort(_ lhs: Monitor, _ rhs: Monitor) -> Bool {
    let lhsAspect = lhs.rect.height > 0 ? lhs.rect.width / lhs.rect.height : 0
    let rhsAspect = rhs.rect.height > 0 ? rhs.rect.width / rhs.rect.height : 0
    if lhsAspect != rhsAspect {
        return lhsAspect > rhsAspect
    }
    return lhs.rect.width > rhs.rect.width
}

@MainActor
private func columnInitMonitorSummary(_ monitor: Monitor) -> String {
    let id = monitor.monitorId_oneBased ?? monitor.monitorAppKitNsScreenScreensId
    let width = Int(monitor.rect.width.rounded())
    let height = Int(monitor.rect.height.rounded())
    let aspect = monitor.rect.height > 0 ? Double(monitor.rect.width / monitor.rect.height) : 0
    let name = monitor.name.isEmpty ? "Display \(id)" : monitor.name
    return "monitor \(id) \(name) \(width)x\(height) aspect \(columnInitFormatTomlFloat(aspect))"
}
