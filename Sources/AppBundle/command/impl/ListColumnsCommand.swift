import Common

struct ListColumnsCommand: Command {
    let args: ListColumnsCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let configuredColumns = getCurrentColumnTopologySnapshot().configuredColumns(for: sortedPhysicalMonitors)
        if args.outputOnlyCount {
            return io.out("\(configuredColumns.count)")
        } else {
            let activeColumnMonitors = sortedMonitors.filter { $0.columnId != nil }
            let rows = configuredColumns.map { zone in
                let activeMonitor = activeColumnMonitors.first {
                    $0.columnId == zone.columnId &&
                        $0.physicalMonitor.rect.topLeftCorner == zone.physicalMonitor.rect.topLeftCorner
                }
                return ColumnListRow(summary: zone, activeWorkspaceName: activeMonitor?.activeWorkspace.name)
            }
            return rows.map { FormatObject.column($0) }.writeFormattedOutput(
                to: io,
                format: args.format,
                json: args.json,
                ignoreRightPaddingVar: args._format.isEmpty,
            )
        }
    }
}
