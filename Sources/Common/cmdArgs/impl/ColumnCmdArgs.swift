public struct FocusColumnCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .focusColumn, allowInConfig: true, help: focus_column_help_generated,
        flags: ["--workspace": optionalWorkspaceFlag()], posArgs: [newMandatoryPosArgParser(\.value, parseColumnIndex, placeholder: "<index>")])
    public var value: Lateinit<String> = .uninitialized
}

public struct MoveNodeToColumnCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .moveNodeToColumn, allowInConfig: true, help: move_node_to_column_help_generated,
        flags: ["--window-id": optionalWindowIdFlag()], posArgs: [newMandatoryPosArgParser(\.value, parseColumnIndex, placeholder: "<index>")])
    public var value: Lateinit<String> = .uninitialized
}

public struct ColumnWidthCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .columnWidth, allowInConfig: true, help: column_width_help_generated,
        flags: ["--window-id": optionalWindowIdFlag()], posArgs: [newMandatoryPosArgParser(\.value, parseColumnWidth, placeholder: "<width>")])
    public var value: Lateinit<String> = .uninitialized
}

public struct CompactCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .compact, allowInConfig: true, help: compact_help_generated,
        flags: ["--workspace": optionalWorkspaceFlag()], posArgs: [])
}

public struct ListColumnsCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .listColumns, allowInConfig: false, help: list_columns_help_generated,
        flags: ["--workspace": optionalWorkspaceFlag(), "--json": trueBoolFlag(\.json)], posArgs: [])
    public var json = false
}

public struct ColumnCountCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .columnCount, allowInConfig: true, help: column_count_help_generated,
        flags: ["--workspace": optionalWorkspaceFlag()], posArgs: [newMandatoryPosArgParser(\.value, parseColumnCount, placeholder: "<count>")])
    public var value: Lateinit<String> = .uninitialized
}

public struct PlaceCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .place, allowInConfig: false, help: place_help_generated,
        flags: ["--window-id": optionalWindowIdFlag(), "--json": trueBoolFlag(\.json), "--dry-run": trueBoolFlag(\.dryRun)], posArgs: [])
    public var json = false
    public var dryRun = false
}

private func parseColumnIndex(i: PosArgParserInput) -> ParsedCliArgs<String> {
    if let n = Int(i.arg), n > 0 { return .succ(i.arg, advanceBy: 1) }
    return .fail("Column index must be a positive integer", advanceBy: 1)
}
private func parseColumnCount(i: PosArgParserInput) -> ParsedCliArgs<String> {
    if i.arg == "off" { return .succ(i.arg, advanceBy: 1) }
    return parseColumnIndex(i: i)
}
private func parseColumnWidth(i: PosArgParserInput) -> ParsedCliArgs<String> {
    if ["next", "prev"].contains(i.arg) { return .succ(i.arg, advanceBy: 1) }
    if let n = Double(i.arg), n.isFinite, n > 0, n < 1 { return .succ(i.arg, advanceBy: 1) }
    return .fail("Width must be next, prev or a fraction between 0 and 1", advanceBy: 1)
}
func parsePlaceCmdArgs(_ args: StrArrSlice) -> ParsedCmd<PlaceCmdArgs> {
    parseSpecificCmdArgs(PlaceCmdArgs(rawArgs: args), args)
        .filter("place requires --dry-run and --window-id") { $0.dryRun && $0.windowId != nil }
}
