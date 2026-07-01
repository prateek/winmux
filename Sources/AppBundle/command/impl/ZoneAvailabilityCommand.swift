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
        runZoneAvailabilitySetCommand(
            commandName: "use-zone-availability",
            outputNoun: "zone availability",
            setId: args.availabilitySetId.val,
            monitor: args.monitor,
            io: io,
        )
    }
}

struct UseZoneProfileCommand: Command {
    let args: UseZoneProfileCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        runZoneAvailabilitySetCommand(
            commandName: "use-zone-profile",
            outputNoun: "zone profile",
            setId: args.profileId.val,
            monitor: args.monitor,
            io: io,
        )
    }
}

struct CycleZoneAvailabilityCommand: Command {
    let args: CycleZoneAvailabilityCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        runCycleZoneAvailabilityCommand(
            commandName: "cycle-zone-availability",
            outputNoun: "zone availability",
            setIds: args.availabilitySetIds.val,
            monitor: args.monitor,
            io: io,
        )
    }
}

struct CycleZoneProfileCommand: Command {
    let args: CycleZoneProfileCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        runCycleZoneAvailabilityCommand(
            commandName: "cycle-zone-profile",
            outputNoun: "zone profile",
            setIds: args.profileIds.val,
            monitor: args.monitor,
            io: io,
        )
    }
}

@MainActor
private func runZoneAvailabilitySetCommand(
    commandName: String,
    outputNoun: String,
    setId: String,
    monitor: MonitorDescription?,
    io: CmdIo,
) -> Bool {
    guard let targetPhysicalMonitor = resolveTargetPhysicalMonitor(monitor, commandName: commandName, io: io) else {
        return false
    }

    switch useZoneAvailabilitySet(setId, for: targetPhysicalMonitor) {
        case .success(let change):
            return io.out("Using \(outputNoun) '\(change.setId)' on monitor \(change.physicalMonitor.monitorId_oneBased ?? 0)")
        case .failure(let message):
            return io.err(message)
    }
}

@MainActor
private func runCycleZoneAvailabilityCommand(
    commandName: String,
    outputNoun: String,
    setIds: [String],
    monitor: MonitorDescription?,
    io: CmdIo,
) -> Bool {
    guard let targetPhysicalMonitor = resolveTargetPhysicalMonitor(monitor, commandName: commandName, io: io) else {
        return false
    }

    switch cycleZoneAvailability(setIds, for: targetPhysicalMonitor) {
        case .success(let change):
            return io.out("Using \(outputNoun) '\(change.setId)' on monitor \(change.physicalMonitor.monitorId_oneBased ?? 0)")
        case .failure(let message):
            return io.err(message)
    }
}

@MainActor
private func resolveTargetPhysicalMonitor(
    _ monitorDescription: MonitorDescription?,
    commandName: String,
    io: CmdIo,
) -> Monitor? {
    if let monitorDescription {
        guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
            _ = io.err("Can't resolve monitor selector for \(commandName)")
            return nil
        }
        return monitor
    }

    return focus.workspace.workspaceMonitor.physicalMonitor
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
