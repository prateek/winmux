public func parseFailureExitCode(_ args: StrArrSlice) -> Int32 {
    let isConfigAction = args.first == "config" && args.dropFirst().contains { ConfigAction(rawValue: $0) != nil }
    let isLensCommand = ["lens", "list-lenses", "summon"].contains(args.first ?? "")
        || (args.first == "list-windows" && args.contains { ["--lens", "--filter", "--search"].contains($0) })
    let isColumnCommand: Bool
    switch CmdKind(rawValue: args.first ?? "") {
        case .focusColumn, .moveNodeToColumn, .columnWidth, .compact, .listColumns, .columnCount, .place:
            isColumnCommand = true
        default: isColumnCommand = false
    }
    return isConfigAction || isLensCommand || isColumnCommand ? 2 : 1
}
