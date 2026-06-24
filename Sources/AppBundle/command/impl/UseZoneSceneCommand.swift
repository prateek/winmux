import Common

struct UseZoneSceneCommand: Command {
    let args: UseZoneSceneCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let targetPhysicalMonitor: Monitor
        if let monitorDescription = args.monitor {
            guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
                return io.err("Can't resolve monitor selector for use-zone-scene")
            }
            targetPhysicalMonitor = monitor
        } else {
            targetPhysicalMonitor = focus.workspace.workspaceMonitor.physicalMonitor
        }

        switch setActiveZoneScene(args.sceneId.val, for: targetPhysicalMonitor) {
            case .success(let result):
                let bindings = result.bindings.map { "\($0.zone)=\($0.workspace)" }.joined(separator: ", ")
                return io.out("Using zone scene '\(result.sceneId)' on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0) with layout '\(result.layoutId)': \(bindings)")
            case .failure(let msg):
                return io.err(msg)
        }
    }
}
