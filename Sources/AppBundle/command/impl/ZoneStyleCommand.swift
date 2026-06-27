import Common

struct SetZoneStyleCommand: Command {
    let args: SetZoneStyleCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        switch setZoneStyle(
            selector: args.zone.val,
            styleId: args.styleId.val,
            monitorDescription: args.monitor,
        ) {
            case .success(let change):
                return io.out("Styled zone '\(change.zoneName ?? change.zoneId)' on monitor \(change.physicalMonitor.monitorId_oneBased ?? 0) as '\(change.styleId)'")
            case .failure(let message):
                return io.err(message)
        }
    }
}

struct CycleZoneStyleCommand: Command {
    let args: CycleZoneStyleCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        switch cycleZoneStyle(
            selector: args.zone.val,
            styleIds: args.styleIds.val,
            monitorDescription: args.monitor,
        ) {
            case .success(let change):
                return io.out("Styled zone '\(change.zoneName ?? change.zoneId)' on monitor \(change.physicalMonitor.monitorId_oneBased ?? 0) as '\(change.styleId)'")
            case .failure(let message):
                return io.err(message)
        }
    }
}
