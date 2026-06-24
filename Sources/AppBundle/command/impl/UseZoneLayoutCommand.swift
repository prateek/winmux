import Common

struct UseZoneLayoutCommand: Command {
    let args: UseZoneLayoutCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let targetPhysicalMonitor: Monitor
        if let monitorDescription = args.monitor {
            guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
                return io.err("Can't resolve monitor selector for use-zone-layout")
            }
            targetPhysicalMonitor = monitor
        } else {
            targetPhysicalMonitor = focus.workspace.workspaceMonitor.physicalMonitor
        }

        switch setActiveZoneLayout(args.layoutId.val, for: targetPhysicalMonitor) {
            case .success:
                return io.out("Using zone layout '\(args.layoutId.val)' on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
            case .failure(let msg):
                return io.err(msg)
        }
    }
}
