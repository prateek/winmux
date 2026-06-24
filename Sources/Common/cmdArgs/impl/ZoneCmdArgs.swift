public struct ZoneSelector: Equatable, Sendable, CustomStringConvertible {
    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }

    public var description: String { raw }
}

public struct FocusZoneCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .focusZone,
        allowInConfig: true,
        help: focus_zone_help_generated,
        flags: [:],
        posArgs: [newMandatoryPosArgParser(\.zone, parseZoneSelector, placeholder: "<zone>")],
    )

    public init(zone: ZoneSelector) {
        self.commonState = .init([])
        self.zone = .initialized(zone)
    }

    public var zone: Lateinit<ZoneSelector> = .uninitialized
}

func parseFocusZoneCmdArgs(_ args: StrArrSlice) -> ParsedCmd<FocusZoneCmdArgs> {
    parseSpecificCmdArgs(FocusZoneCmdArgs(rawArgs: args), args)
}

public struct MoveNodeToZoneCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .moveNodeToZone,
        allowInConfig: true,
        help: move_node_to_zone_help_generated,
        flags: [
            "--window-id": optionalWindowIdFlag(),
            "--focus-follows-window": trueBoolFlag(\.focusFollowsWindow),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        posArgs: [newMandatoryPosArgParser(\.zone, parseZoneSelector, placeholder: "<zone>")],
    )

    public init(zone: ZoneSelector) {
        self.commonState = .init([])
        self.zone = .initialized(zone)
    }

    public var failIfNoop: Bool = false
    public var focusFollowsWindow: Bool = false
    public var zone: Lateinit<ZoneSelector> = .uninitialized
}

func parseMoveNodeToZoneCmdArgs(_ args: StrArrSlice) -> ParsedCmd<MoveNodeToZoneCmdArgs> {
    parseSpecificCmdArgs(MoveNodeToZoneCmdArgs(rawArgs: args), args)
}

public struct UseZoneLayoutCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .useZoneLayout,
        allowInConfig: true,
        help: use_zone_layout_help_generated,
        flags: [
            "--monitor": ArgParser(\.monitor, parseMonitorDescriptionSubArg),
        ],
        posArgs: [newMandatoryPosArgParser(\.layoutId, parseZoneLayoutId, placeholder: "<layout-id>")],
    )

    public init(layoutId: String, monitor: MonitorDescription? = nil) {
        self.commonState = .init([])
        self.layoutId = .initialized(layoutId)
        self.monitor = monitor
    }

    public var monitor: MonitorDescription?
    public var layoutId: Lateinit<String> = .uninitialized
}

func parseUseZoneLayoutCmdArgs(_ args: StrArrSlice) -> ParsedCmd<UseZoneLayoutCmdArgs> {
    parseSpecificCmdArgs(UseZoneLayoutCmdArgs(rawArgs: args), args)
}

public struct ListZonesCmdArgs: CmdArgs, JsonFormattableListCmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .listZones,
        allowInConfig: false,
        help: list_zones_help_generated,
        flags: [
            "--format": formatParser(\._format, for: .monitor),
            "--count": trueBoolFlag(\.outputOnlyCount),
            "--json": trueBoolFlag(\.json),
        ],
        posArgs: [],
        conflictingOptions: [
            ["--count", "--format"],
            ["--count", "--json"],
        ],
    )

    public var _format: [StringInterToken] = []
    public var outputOnlyCount: Bool = false
    public var json: Bool = false
}

extension ListZonesCmdArgs {
    public var format: [StringInterToken] {
        _format.isEmpty
            ? [
                .interVar("monitor-zone-id"), .interVar("right-padding"), .literal(" | "),
                .interVar("monitor-zone-name"), .interVar("right-padding"), .literal(" | "),
                .literal("monitor "), .interVar("monitor-physical-id"), .interVar("right-padding"), .literal(" | "),
                .interVar("monitor-active-workspace"),
            ]
            : _format
    }
}

func parseListZonesCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ListZonesCmdArgs> {
    parseSpecificCmdArgs(ListZonesCmdArgs(rawArgs: args), args)
        .validateJsonFormat()
}

private func parseZoneSelector(i: PosArgParserInput) -> ParsedCliArgs<ZoneSelector> {
    i.arg.isEmpty
        ? .fail("<zone> must not be empty", advanceBy: 1)
        : .succ(ZoneSelector(i.arg), advanceBy: 1)
}

private func parseZoneLayoutId(i: PosArgParserInput) -> ParsedCliArgs<String> {
    switch parseZoneLayoutIdentifier(i.arg) {
        case .success(let layoutId): .succ(layoutId, advanceBy: 1)
        case .failure(let msg): .fail(msg, advanceBy: 1)
    }
}

private func parseZoneLayoutIdentifier(_ raw: String) -> Parsed<String> {
    if raw.isEmpty {
        return .failure("<layout-id> must not be empty")
    }
    guard raw.allSatisfy({ char in
        char.isLetter || char.isNumber || char == "-" || char == "_"
    }) else {
        return .failure("<layout-id> must use only letters, numbers, hyphens, and underscores")
    }
    return .success(raw)
}

private func parseMonitorDescriptionSubArg(i: SubArgParserInput) -> ParsedCliArgs<MonitorDescription?> {
    guard let arg = i.nonFlagArgOrNil() else {
        return .fail("'\(i.superArg)' must be followed by mandatory monitor selector", advanceBy: 0)
    }
    return .init(parseMonitorDescription(arg).map(Optional.some), advanceBy: 1)
}
