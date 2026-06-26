import Common

struct ApplyZoneBindingsCommand: Command {
    let args: ApplyZoneBindingsCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let targetPhysicalMonitor: Monitor
        if let monitorDescription = args.monitor {
            guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
                return io.err("Can't resolve monitor selector for apply-zone-bindings")
            }
            targetPhysicalMonitor = monitor
        } else {
            targetPhysicalMonitor = focus.workspace.workspaceMonitor.physicalMonitor
        }

        switch applyZoneBindings(for: targetPhysicalMonitor) {
            case .success(let result):
                let bindings = result.bindings.map { "\($0.zone)=\($0.workspace)" }.joined(separator: ", ")
                return io.out("Applied zone bindings on monitor \(result.physicalMonitor.monitorId_oneBased ?? 0): \(bindings)")
            case .failure(let message):
                return io.err(message)
        }
    }
}
