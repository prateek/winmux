import Common

struct UseZoneSceneCommand: Command {
    let args: UseZoneSceneCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let targetPhysicalMonitor = resolveZoneScenePhysicalMonitor(args.monitor, commandName: "use-zone-scene", io: io) else { return false }

        switch setActiveZoneScene(args.sceneId.val, for: targetPhysicalMonitor) {
            case .success(let result):
                return io.out(formatZoneSceneActivation(result, monitor: targetPhysicalMonitor))
            case .failure(let msg):
                return io.err(msg)
        }
    }
}

struct CycleZoneSceneCommand: Command {
    let args: CycleZoneSceneCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let targetPhysicalMonitor = resolveZoneScenePhysicalMonitor(args.monitor, commandName: "cycle-zone-scene", io: io) else { return false }

        switch cycleZoneScene(args.sceneIds.val, for: targetPhysicalMonitor) {
            case .success(let result):
                return io.out(formatZoneSceneActivation(result, monitor: targetPhysicalMonitor))
            case .failure(let msg):
                return io.err(msg)
        }
    }
}

@MainActor
private func resolveZoneScenePhysicalMonitor(
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
private func formatZoneSceneActivation(_ result: ZoneSceneActivationResult, monitor: Monitor) -> String {
    let bindings = result.bindings.map { "\($0.zone)=\($0.workspace)" }.joined(separator: ", ")
    return "Using zone scene '\(result.sceneId)' on monitor \(monitor.monitorId_oneBased ?? 0) with layout '\(result.layoutId)': \(bindings)"
}
