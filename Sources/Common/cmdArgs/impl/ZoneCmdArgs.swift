public struct ZoneSelector: Equatable, Sendable, CustomStringConvertible {
    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }

    public var description: String { raw }
}

public enum ZoneCommandAction: String, CaseIterable, Equatable, Sendable {
    case initialize = "init"
}

public enum ZoneInitPreset: String, CaseIterable, Equatable, Sendable {
    case balanced
    case focusOnly = "focus-only"
    case commsOpen = "comms-open"
    case dashboard
}

public struct ZoneCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .zone,
        allowInConfig: false,
        help: zone_help_generated,
        flags: [
            "--dry-run": trueBoolFlag(\.dryRun),
            "--monitor": ArgParser(\.monitor, parseMonitorDescriptionSubArg),
            "--preset": ArgParser(\.preset, parseZoneInitPresetSubArg),
            "--replace-existing": trueBoolFlag(\.replaceExisting),
            "--write": trueBoolFlag(\.write),
        ],
        posArgs: [newMandatoryPosArgParser(\.action, parseZoneCommandAction, placeholder: "init")],
        conflictingOptions: [
            ["--dry-run", "--write"],
        ],
    )

    public init(
        action: ZoneCommandAction = .initialize,
        preset: ZoneInitPreset = .balanced,
        monitor: MonitorDescription? = nil,
        dryRun: Bool = false,
        write: Bool = false,
        replaceExisting: Bool = false,
    ) {
        self.commonState = .init([])
        self.action = .initialized(action)
        self.preset = preset
        self.monitor = monitor
        self.dryRun = dryRun
        self.write = write
        self.replaceExisting = replaceExisting
    }

    public var action: Lateinit<ZoneCommandAction> = .uninitialized
    public var preset: ZoneInitPreset = .balanced
    public var monitor: MonitorDescription?
    public var dryRun: Bool = false
    public var write: Bool = false
    public var replaceExisting: Bool = false
}

func parseZoneCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ZoneCmdArgs> {
    parseSpecificCmdArgs(ZoneCmdArgs(rawArgs: args), args)
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

public struct EnableZoneCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .enableZone,
        allowInConfig: true,
        help: enable_zone_help_generated,
        flags: [
            "--monitor": ArgParser(\.monitor, parseMonitorDescriptionSubArg),
        ],
        posArgs: [newMandatoryPosArgParser(\.zone, parseZoneSelector, placeholder: "<zone>")],
    )

    public init(zone: ZoneSelector, monitor: MonitorDescription? = nil) {
        self.commonState = .init([])
        self.zone = .initialized(zone)
        self.monitor = monitor
    }

    public var monitor: MonitorDescription?
    public var zone: Lateinit<ZoneSelector> = .uninitialized
}

func parseEnableZoneCmdArgs(_ args: StrArrSlice) -> ParsedCmd<EnableZoneCmdArgs> {
    parseSpecificCmdArgs(EnableZoneCmdArgs(rawArgs: args), args)
}

public struct DisableZoneCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .disableZone,
        allowInConfig: true,
        help: disable_zone_help_generated,
        flags: [
            "--monitor": ArgParser(\.monitor, parseMonitorDescriptionSubArg),
        ],
        posArgs: [newMandatoryPosArgParser(\.zone, parseZoneSelector, placeholder: "<zone>")],
    )

    public init(zone: ZoneSelector, monitor: MonitorDescription? = nil) {
        self.commonState = .init([])
        self.zone = .initialized(zone)
        self.monitor = monitor
    }

    public var monitor: MonitorDescription?
    public var zone: Lateinit<ZoneSelector> = .uninitialized
}

func parseDisableZoneCmdArgs(_ args: StrArrSlice) -> ParsedCmd<DisableZoneCmdArgs> {
    parseSpecificCmdArgs(DisableZoneCmdArgs(rawArgs: args), args)
}

public struct ToggleZoneCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .toggleZone,
        allowInConfig: true,
        help: toggle_zone_help_generated,
        flags: [
            "--monitor": ArgParser(\.monitor, parseMonitorDescriptionSubArg),
        ],
        posArgs: [newMandatoryPosArgParser(\.zone, parseZoneSelector, placeholder: "<zone>")],
    )

    public init(zone: ZoneSelector, monitor: MonitorDescription? = nil) {
        self.commonState = .init([])
        self.zone = .initialized(zone)
        self.monitor = monitor
    }

    public var monitor: MonitorDescription?
    public var zone: Lateinit<ZoneSelector> = .uninitialized
}

func parseToggleZoneCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ToggleZoneCmdArgs> {
    parseSpecificCmdArgs(ToggleZoneCmdArgs(rawArgs: args), args)
}

public enum ZoneWidthAmount: Equatable, Sendable {
    case set(Double)
    case add(Double)
    case subtract(Double)

    public var displayPercent: String {
        let value = switch self {
            case .set(let percent), .add(let percent), .subtract(let percent):
                percent * 100.0
        }
        let number = value.rounded() == value ? Int(value).description : value.description
        return switch self {
            case .set: "\(number)%"
            case .add: "+\(number)%"
            case .subtract: "-\(number)%"
        }
    }
}

public struct ResizeZoneCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .resizeZone,
        allowInConfig: true,
        help: resize_zone_help_generated,
        flags: [
            "--monitor": ArgParser(\.monitor, parseMonitorDescriptionSubArg),
        ],
        posArgs: [
            newMandatoryPosArgParser(\.zone, parseZoneSelector, placeholder: "<zone>"),
            newMandatoryPosArgParser(\.dimension, parseZoneResizeDimension, placeholder: "width"),
            newMandatoryPosArgParser(\.amount, parseZoneWidthAmount, placeholder: "[+|-]<percent>%"),
        ],
    )

    public init(zone: ZoneSelector, dimension: Dimension = .width, amount: ZoneWidthAmount, monitor: MonitorDescription? = nil) {
        self.commonState = .init([])
        self.zone = .initialized(zone)
        self.dimension = .initialized(dimension)
        self.amount = .initialized(amount)
        self.monitor = monitor
    }

    public enum Dimension: String, Equatable, CaseIterable, Sendable {
        case width
    }

    public var monitor: MonitorDescription?
    public var zone: Lateinit<ZoneSelector> = .uninitialized
    public var dimension: Lateinit<Dimension> = .uninitialized
    public var amount: Lateinit<ZoneWidthAmount> = .uninitialized
}

func parseResizeZoneCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ResizeZoneCmdArgs> {
    parseSpecificCmdArgs(ResizeZoneCmdArgs(rawArgs: args), args)
}

public struct BalanceZonesCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .balanceZones,
        allowInConfig: true,
        help: balance_zones_help_generated,
        flags: [
            "--monitor": ArgParser(\.monitor, parseMonitorDescriptionSubArg),
        ],
        posArgs: [],
    )

    public init(monitor: MonitorDescription? = nil) {
        self.commonState = .init([])
        self.monitor = monitor
    }

    public var monitor: MonitorDescription?
}

func parseBalanceZonesCmdArgs(_ args: StrArrSlice) -> ParsedCmd<BalanceZonesCmdArgs> {
    parseSpecificCmdArgs(BalanceZonesCmdArgs(rawArgs: args), args)
}

public struct ExportZoneLayoutCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .exportZoneLayout,
        allowInConfig: false,
        help: export_zone_layout_help_generated,
        flags: [
            "--monitor": ArgParser(\.monitor, parseMonitorDescriptionSubArg),
        ],
        posArgs: [
            newMandatoryPosArgParser(\.layoutId, parseZoneLayoutId, placeholder: "<layout-id>"),
        ],
    )

    public init(layoutId: String, monitor: MonitorDescription? = nil) {
        self.commonState = .init([])
        self.layoutId = .initialized(layoutId)
        self.monitor = monitor
    }

    public var monitor: MonitorDescription?
    public var layoutId: Lateinit<String> = .uninitialized
}

func parseExportZoneLayoutCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ExportZoneLayoutCmdArgs> {
    parseSpecificCmdArgs(ExportZoneLayoutCmdArgs(rawArgs: args), args)
}

public struct SaveZoneLayoutCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .saveZoneLayout,
        allowInConfig: true,
        help: save_zone_layout_help_generated,
        flags: [
            "--dry-run": trueBoolFlag(\.dryRun),
            "--layout": ArgParser(\.layoutId, parseZoneLayoutSubArg),
            "--monitor": ArgParser(\.monitor, parseMonitorDescriptionSubArg),
        ],
        posArgs: [],
    )

    public init(monitor: MonitorDescription? = nil, layoutId: String? = nil, dryRun: Bool = false) {
        self.commonState = .init([])
        self.monitor = monitor
        self.layoutId = layoutId
        self.dryRun = dryRun
    }

    public var monitor: MonitorDescription?
    public var layoutId: String?
    public var dryRun: Bool = false
}

func parseSaveZoneLayoutCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SaveZoneLayoutCmdArgs> {
    parseSpecificCmdArgs(SaveZoneLayoutCmdArgs(rawArgs: args), args)
}

public struct SetZoneStyleCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .setZoneStyle,
        allowInConfig: true,
        help: set_zone_style_help_generated,
        flags: [
            "--monitor": ArgParser(\.monitor, parseMonitorDescriptionSubArg),
        ],
        posArgs: [
            newMandatoryPosArgParser(\.zone, parseZoneSelector, placeholder: "<zone>"),
            newMandatoryPosArgParser(\.styleId, parseZoneStyleId, placeholder: "<style-id>"),
        ],
    )

    public init(zone: ZoneSelector, styleId: String, monitor: MonitorDescription? = nil) {
        self.commonState = .init([])
        self.zone = .initialized(zone)
        self.styleId = .initialized(styleId)
        self.monitor = monitor
    }

    public var monitor: MonitorDescription?
    public var zone: Lateinit<ZoneSelector> = .uninitialized
    public var styleId: Lateinit<String> = .uninitialized
}

func parseSetZoneStyleCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SetZoneStyleCmdArgs> {
    parseSpecificCmdArgs(SetZoneStyleCmdArgs(rawArgs: args), args)
}

public struct CycleZoneStyleCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .cycleZoneStyle,
        allowInConfig: true,
        help: cycle_zone_style_help_generated,
        flags: [
            "--monitor": ArgParser(\.monitor, parseMonitorDescriptionSubArg),
        ],
        posArgs: [
            newMandatoryPosArgParser(\.zone, parseZoneSelector, placeholder: "<zone>"),
            newMandatoryPosArgParser(\.styleIds, parseZoneStyleIds, placeholder: "<style-id>..."),
        ],
    )

    public init(zone: ZoneSelector, styleIds: [String], monitor: MonitorDescription? = nil) {
        self.commonState = .init([])
        self.zone = .initialized(zone)
        self.styleIds = .initialized(styleIds)
        self.monitor = monitor
    }

    public var monitor: MonitorDescription?
    public var zone: Lateinit<ZoneSelector> = .uninitialized
    public var styleIds: Lateinit<[String]> = .uninitialized
}

func parseCycleZoneStyleCmdArgs(_ args: StrArrSlice) -> ParsedCmd<CycleZoneStyleCmdArgs> {
    parseSpecificCmdArgs(CycleZoneStyleCmdArgs(rawArgs: args), args)
}

public struct SetZoneSnapPolicyCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .setZoneSnapPolicy,
        allowInConfig: true,
        help: set_zone_snap_policy_help_generated,
        flags: [
            "--monitor": ArgParser(\.monitor, parseMonitorDescriptionSubArg),
        ],
        posArgs: [newMandatoryPosArgParser(\.policyId, parseZoneSnapPolicyId, placeholder: "<policy>")],
    )

    public init(policyId: String, monitor: MonitorDescription? = nil) {
        self.commonState = .init([])
        self.policyId = .initialized(policyId)
        self.monitor = monitor
    }

    public var monitor: MonitorDescription?
    public var policyId: Lateinit<String> = .uninitialized
}

func parseSetZoneSnapPolicyCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SetZoneSnapPolicyCmdArgs> {
    parseSpecificCmdArgs(SetZoneSnapPolicyCmdArgs(rawArgs: args), args)
}

public struct CycleZoneSnapPolicyCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .cycleZoneSnapPolicy,
        allowInConfig: true,
        help: cycle_zone_snap_policy_help_generated,
        flags: [
            "--monitor": ArgParser(\.monitor, parseMonitorDescriptionSubArg),
        ],
        posArgs: [newMandatoryPosArgParser(\.policyIds, parseZoneSnapPolicyIds, placeholder: "<policy>...")],
    )

    public init(policyIds: [String], monitor: MonitorDescription? = nil) {
        self.commonState = .init([])
        self.policyIds = .initialized(policyIds)
        self.monitor = monitor
    }

    public var monitor: MonitorDescription?
    public var policyIds: Lateinit<[String]> = .uninitialized
}

func parseCycleZoneSnapPolicyCmdArgs(_ args: StrArrSlice) -> ParsedCmd<CycleZoneSnapPolicyCmdArgs> {
    parseSpecificCmdArgs(CycleZoneSnapPolicyCmdArgs(rawArgs: args), args)
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
                .literal("availability "), .interVar("monitor-zone-availability-set-id"), .interVar("right-padding"), .literal(" | "),
                .literal("style "), .interVar("monitor-zone-style-id"), .interVar("right-padding"), .literal(" | "),
                .literal("enabled "), .interVar("monitor-zone-enabled"), .interVar("right-padding"), .literal(" | "),
                .literal("width "), .interVar("monitor-zone-effective-width"), .interVar("right-padding"), .literal(" | "),
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

private func parseZoneCommandAction(i: PosArgParserInput) -> ParsedCliArgs<ZoneCommandAction> {
    .init(parseEnum(i.arg, ZoneCommandAction.self), advanceBy: 1)
}

private func parseZoneInitPresetSubArg(i: SubArgParserInput) -> ParsedCliArgs<ZoneInitPreset> {
    guard let arg = i.nonFlagArgOrNil() else {
        return .fail("'\(i.superArg)' must be followed by mandatory preset", advanceBy: 0)
    }
    return .init(parseEnum(arg, ZoneInitPreset.self), advanceBy: 1)
}

private func parseZoneSelector(i: PosArgParserInput) -> ParsedCliArgs<ZoneSelector> {
    i.arg.isEmpty
        ? .fail("<zone> must not be empty", advanceBy: 1)
        : .succ(ZoneSelector(i.arg), advanceBy: 1)
}

private func parseZoneResizeDimension(i: PosArgParserInput) -> ParsedCliArgs<ResizeZoneCmdArgs.Dimension> {
    .init(parseEnum(i.arg, ResizeZoneCmdArgs.Dimension.self), advanceBy: 1)
}

private func parseZoneWidthAmount(i: PosArgParserInput) -> ParsedCliArgs<ZoneWidthAmount> {
    guard i.arg.hasSuffix("%") else {
        return .fail("<percent> must include a % suffix, for example +10%", advanceBy: 1)
    }
    let rawNumber = String(i.arg.dropLast())
    guard !rawNumber.isEmpty else {
        return .fail("<percent> must include a number", advanceBy: 1)
    }
    let sign: Character? = rawNumber.first.flatMap { $0 == "+" || $0 == "-" ? $0 : nil }
    let numberText = sign == nil ? rawNumber : String(rawNumber.dropFirst())
    guard let number = Double(numberText), number > 0 else {
        return .fail("<percent> must be a positive number", advanceBy: 1)
    }
    let percent = number / 100.0
    return switch sign {
        case "+": .succ(.add(percent), advanceBy: 1)
        case "-": .succ(.subtract(percent), advanceBy: 1)
        default: .succ(.set(percent), advanceBy: 1)
    }
}

private func parseZoneLayoutId(i: PosArgParserInput) -> ParsedCliArgs<String> {
    switch parseZoneLayoutIdentifier(i.arg) {
        case .success(let layoutId): .succ(layoutId, advanceBy: 1)
        case .failure(let msg): .fail(msg, advanceBy: 1)
    }
}

private func parseZoneLayoutSubArg(i: SubArgParserInput) -> ParsedCliArgs<String?> {
    guard let arg = i.nonFlagArgOrNil() else {
        return .fail("'\(i.superArg)' must be followed by mandatory layout id", advanceBy: 0)
    }
    return .init(parseZoneLayoutIdentifier(arg).map(Optional.some), advanceBy: 1)
}

private func parseZoneStyleId(i: PosArgParserInput) -> ParsedCliArgs<String> {
    switch parseZoneStyleIdentifier(i.arg) {
        case .success(let styleId): .succ(styleId, advanceBy: 1)
        case .failure(let msg): .fail(msg, advanceBy: 1)
    }
}

private func parseZoneStyleIds(i: PosArgParserInput) -> ParsedCliArgs<[String]> {
    let args = i.nonFlagArgs()
    guard !args.isEmpty else {
        return .fail("<style-id> is mandatory", advanceBy: 0)
    }
    var styleIds: [String] = []
    for (offset, arg) in args.enumerated() {
        switch parseZoneStyleIdentifier(arg) {
            case .success(let styleId):
                styleIds.append(styleId)
            case .failure(let msg):
                return .fail(msg, advanceBy: offset + 1)
        }
    }
    return .succ(styleIds, advanceBy: args.count)
}

private func parseZoneSnapPolicyId(i: PosArgParserInput) -> ParsedCliArgs<String> {
    switch parseZoneSnapPolicyIdentifier(i.arg) {
        case .success(let policyId): .succ(policyId, advanceBy: 1)
        case .failure(let msg): .fail(msg, advanceBy: 1)
    }
}

private func parseZoneSnapPolicyIds(i: PosArgParserInput) -> ParsedCliArgs<[String]> {
    let args = i.nonFlagArgs()
    guard !args.isEmpty else {
        return .fail("<policy> is mandatory", advanceBy: 0)
    }
    var policyIds: [String] = []
    for (offset, arg) in args.enumerated() {
        switch parseZoneSnapPolicyIdentifier(arg) {
            case .success(let policyId):
                policyIds.append(policyId)
            case .failure(let msg):
                return .fail(msg, advanceBy: offset + 1)
        }
    }
    return .succ(policyIds, advanceBy: args.count)
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

private func parseZoneStyleIdentifier(_ raw: String) -> Parsed<String> {
    if raw.isEmpty {
        return .failure("<style-id> must not be empty")
    }
    guard raw.allSatisfy({ char in
        char.isLetter || char.isNumber || char == "-" || char == "_"
    }) else {
        return .failure("<style-id> must use only letters, numbers, hyphens, and underscores")
    }
    return .success(raw)
}

private func parseZoneSnapPolicyIdentifier(_ raw: String) -> Parsed<String> {
    if raw.isEmpty {
        return .failure("<policy> must not be empty")
    }
    guard raw.allSatisfy({ char in
        char.isLetter || char.isNumber || char == "-"
    }) else {
        return .failure("<policy> must use only letters, numbers, and hyphens")
    }
    return .success(raw)
}

private func parseMonitorDescriptionSubArg(i: SubArgParserInput) -> ParsedCliArgs<MonitorDescription?> {
    guard let arg = i.nonFlagArgOrNil() else {
        return .fail("'\(i.superArg)' must be followed by mandatory monitor selector", advanceBy: 0)
    }
    return .init(parseMonitorDescription(arg).map(Optional.some), advanceBy: 1)
}
