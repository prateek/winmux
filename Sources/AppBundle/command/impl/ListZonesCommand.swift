import Common

struct ListZonesCommand: Command {
    let args: ListZonesCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let configuredZones = getCurrentColumnTopologySnapshot().configuredZones(for: sortedPhysicalMonitors)
        if args.outputOnlyCount {
            return io.out("\(configuredZones.count)")
        } else {
            let activeColumnMonitors = sortedMonitors.filter { $0.zoneId != nil }
            let rows = configuredZones.map { zone in
                let activeMonitor = activeColumnMonitors.first {
                    $0.zoneId == zone.zoneId &&
                        $0.physicalMonitor.rect.topLeftCorner == zone.physicalMonitor.rect.topLeftCorner
                }
                return ZoneListRow(summary: zone, activeWorkspaceName: activeMonitor?.activeWorkspace.name)
            }
            return rows.map { FormatObject.zone($0) }.writeFormattedOutput(
                to: io,
                format: args.format,
                json: args.json,
                ignoreRightPaddingVar: args._format.isEmpty,
            )
        }
    }
}
