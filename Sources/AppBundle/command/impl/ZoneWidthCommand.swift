import Common

struct ResizeZoneCommand: Command {
    let args: ResizeZoneCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        switch resizeZoneWidth(
            selector: args.zone.val,
            amount: args.amount.val,
            monitorDescription: args.monitor,
        ) {
            case .success(let change):
                return io.out("Resized zone '\(change.zoneName ?? change.zoneId ?? args.zone.val.raw)' on monitor \(change.physicalMonitor.monitorId_oneBased ?? 0) by \(args.amount.val.displayPercent)")
            case .failure(let message):
                return io.err(message)
        }
    }
}

struct BalanceZonesCommand: Command {
    let args: BalanceZonesCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        switch balanceZoneWidths(monitorDescription: args.monitor) {
            case .success(let change):
                return io.out("Balanced zones on monitor \(change.physicalMonitor.monitorId_oneBased ?? 0)")
            case .failure(let message):
                return io.err(message)
        }
    }
}

struct CycleZoneLayoutCommand: Command {
    let args: CycleZoneLayoutCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let targetPhysicalMonitor: Monitor
        if let monitorDescription = args.monitor {
            guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
                return io.err("Can't resolve monitor selector for cycle-zone-layout")
            }
            targetPhysicalMonitor = monitor
        } else {
            targetPhysicalMonitor = focus.workspace.workspaceMonitor.physicalMonitor
        }

        switch cycleZoneLayout(args.layoutIds.val, for: targetPhysicalMonitor) {
            case .success(let layoutId):
                return io.out("Using zone layout '\(layoutId)' on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
            case .failure(let message):
                return io.err(message)
        }
    }
}
