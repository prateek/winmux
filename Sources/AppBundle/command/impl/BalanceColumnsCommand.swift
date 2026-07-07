import Common

struct BalanceColumnsCommand: Command {
    let args: BalanceColumnsCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        switch balanceColumnWidths(monitorDescription: args.monitor) {
            case .success(let change):
                return io.out("Balanced columns on monitor \(change.physicalMonitor.monitorId_oneBased ?? 0)")
            case .failure(let message):
                return io.err(message)
        }
    }
}
