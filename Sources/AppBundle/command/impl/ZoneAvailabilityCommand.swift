import Common

struct EnableZoneCommand: Command {
    let args: EnableZoneCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        runZoneAvailabilityCommand(
            operation: .enable,
            zone: args.zone.val,
            monitor: args.monitor,
            io: io,
        )
    }
}

struct DisableZoneCommand: Command {
    let args: DisableZoneCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        runZoneAvailabilityCommand(
            operation: .disable,
            zone: args.zone.val,
            monitor: args.monitor,
            io: io,
        )
    }
}

struct ToggleZoneCommand: Command {
    let args: ToggleZoneCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        runZoneAvailabilityCommand(
            operation: .toggle,
            zone: args.zone.val,
            monitor: args.monitor,
            io: io,
        )
    }
}

@MainActor
private func runZoneAvailabilityCommand(
    operation: ZoneAvailabilityOperation,
    zone: ZoneSelector,
    monitor: MonitorDescription?,
    io: CmdIo,
) -> Bool {
    switch setZoneAvailability(operation, selector: zone, monitorDescription: monitor) {
        case .success(let change):
            let state = change.isEnabled ? "enabled" : "disabled"
            let verb = change.changed ? state.capitalized : "Already \(state)"
            return io.out("\(verb) zone '\(change.zoneName ?? change.zoneId)' on monitor \(change.physicalMonitor.monitorId_oneBased ?? 0)")
        case .failure(let message):
            return io.err(message)
    }
}
