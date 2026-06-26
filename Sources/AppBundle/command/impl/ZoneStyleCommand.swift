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
