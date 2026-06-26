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

struct UseZoneAvailabilityCommand: Command {
    let args: UseZoneAvailabilityCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let targetPhysicalMonitor: Monitor
        if let monitorDescription = args.monitor {
            guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
                return io.err("Can't resolve monitor selector for use-zone-availability")
            }
            targetPhysicalMonitor = monitor
        } else {
            targetPhysicalMonitor = focus.workspace.workspaceMonitor.physicalMonitor
        }

        switch useZoneAvailabilitySet(args.availabilitySetId.val, for: targetPhysicalMonitor) {
            case .success(let change):
                return io.out("Using zone availability '\(change.setId)' on monitor \(change.physicalMonitor.monitorId_oneBased ?? 0)")
            case .failure(let message):
                return io.err(message)
        }
    }
}

struct CycleZoneAvailabilityCommand: Command {
    let args: CycleZoneAvailabilityCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let targetPhysicalMonitor: Monitor
        if let monitorDescription = args.monitor {
            guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
                return io.err("Can't resolve monitor selector for cycle-zone-availability")
            }
            targetPhysicalMonitor = monitor
        } else {
            targetPhysicalMonitor = focus.workspace.workspaceMonitor.physicalMonitor
        }

        switch cycleZoneAvailability(args.availabilitySetIds.val, for: targetPhysicalMonitor) {
            case .success(let change):
                return io.out("Using zone availability '\(change.setId)' on monitor \(change.physicalMonitor.monitorId_oneBased ?? 0)")
            case .failure(let message):
                return io.err(message)
        }
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
