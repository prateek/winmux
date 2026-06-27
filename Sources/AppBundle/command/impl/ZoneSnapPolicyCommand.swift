import Common

struct SetZoneSnapPolicyCommand: Command {
    let args: SetZoneSnapPolicyCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let targetPhysicalMonitor: Monitor
        if let monitorDescription = args.monitor {
            guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
                return io.err("Can't resolve monitor selector for set-zone-snap-policy")
            }
            targetPhysicalMonitor = monitor
        } else {
            targetPhysicalMonitor = focus.workspace.workspaceMonitor.physicalMonitor
        }

        switch setZoneSnapPolicy(args.policyId.val, for: targetPhysicalMonitor) {
            case .success(let change):
                return io.out("Using zone snap policy '\(change.policy.rawValue)' on monitor \(change.physicalMonitor.monitorId_oneBased ?? 0)")
            case .failure(let message):
                return io.err(message)
        }
    }
}

struct CycleZoneSnapPolicyCommand: Command {
    let args: CycleZoneSnapPolicyCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let targetPhysicalMonitor: Monitor
        if let monitorDescription = args.monitor {
            guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
                return io.err("Can't resolve monitor selector for cycle-zone-snap-policy")
            }
            targetPhysicalMonitor = monitor
        } else {
            targetPhysicalMonitor = focus.workspace.workspaceMonitor.physicalMonitor
        }

        switch cycleZoneSnapPolicy(args.policyIds.val, for: targetPhysicalMonitor) {
            case .success(let change):
                return io.out("Using zone snap policy '\(change.policy.rawValue)' on monitor \(change.physicalMonitor.monitorId_oneBased ?? 0)")
            case .failure(let message):
                return io.err(message)
        }
    }
}
