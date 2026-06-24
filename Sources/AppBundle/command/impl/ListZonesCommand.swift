import Common

struct ListZonesCommand: Command {
    let args: ListZonesCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let result = sortedMonitors.filter { $0.zoneId != nil }
        if args.outputOnlyCount {
            return io.out("\(result.count)")
        } else {
            return result.map { FormatObject.monitor($0) }.writeFormattedOutput(
                to: io,
                format: args.format,
                json: args.json,
                ignoreRightPaddingVar: args._format.isEmpty,
            )
        }
    }
}
