public func parseFailureExitCode(_ args: StrArrSlice) -> Int32 {
    let isConfigAction = args.first == "config" && args.dropFirst().contains { ConfigAction(rawValue: $0) != nil }
    let isLensListWindows = args.first == "list-windows" && args.contains { ["--lens", "--filter", "--search"].contains($0) }
    switch CmdKind(rawValue: args.first ?? "") {
        case .lens, .listLenses, .summon, .sections,
             .focusColumn, .moveNodeToColumn, .columnWidth, .compact, .listColumns, .columnCount, .place:
            return 2
        default:
            return isConfigAction || isLensListWindows ? 2 : 1
    }
}
