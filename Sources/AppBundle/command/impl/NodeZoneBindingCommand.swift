import Common

struct BindNodeToZoneCommand: Command {
    let args: BindNodeToZoneCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let window = target.windowOrNil else {
            return io.err(noWindowIsFocused)
        }

        switch await bindNodeToZone(window, zone: args.zone.val) {
            case .success(let binding):
                return io.out("Bound \(binding.key.description) to zone \(binding.zoneId) on monitor \(binding.physicalMonitorId.map(String.init) ?? "")")
            case .failure(let message):
                return io.err(message)
        }
    }
}

struct UnbindNodeZoneBindingCommand: Command {
    let args: UnbindNodeZoneBindingCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let window = target.windowOrNil else {
            return io.err(noWindowIsFocused)
        }

        switch unbindNodeZoneBinding(for: window) {
            case .success(let binding):
                return io.out("Removed node zone binding \(binding.key.description)")
            case .failure(let message):
                return io.err(message)
        }
    }
}

struct ListZoneBindingsCommand: Command {
    let args: ListZoneBindingsCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let rows = nodeZoneBindingRows()
        if args.outputOnlyCount {
            return io.out("\(rows.count)")
        }
        return io.out(rows.map(\.displayLine))
    }
}
