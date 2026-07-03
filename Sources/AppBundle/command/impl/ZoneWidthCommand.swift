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
