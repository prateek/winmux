public struct ZoneSelector: Equatable, Sendable, CustomStringConvertible {
    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }

    public var description: String { raw }
}

public enum ZoneInitPreset: String, CaseIterable, Equatable, Sendable {
    case balanced
    case focusOnly = "focus-only"
    case commsOpen = "comms-open"
    case dashboard
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

/// `column <subcommand>` — the column verb folds the former resize-zone, enable/disable/toggle-zone,
/// set-zone-style, and `zone init` commands. An omitted column id targets the focused column.
public enum ColumnTarget: Equatable, Sendable {
    case resize(amount: ZoneWidthAmount, column: ZoneSelector)
    case collapse(column: ZoneSelector)
    case expand(column: ZoneSelector)
    case toggle(column: ZoneSelector)
    case color(hex: String, column: ZoneSelector)
    case initialize
}

public struct ColumnCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .column,
        allowInConfig: true,
        help: column_help_generated,
        flags: [
            "--dry-run": trueBoolFlag(\.dryRun),
            "--monitor": ArgParser(\.monitor, parseColumnMonitorSubArg),
            "--preset": ArgParser(\.preset, parseZoneInitPresetSubArg),
            "--replace-existing": trueBoolFlag(\.replaceExisting),
            "--write": trueBoolFlag(\.write),
        ],
        posArgs: [newMandatoryPosArgParser(\.target, parseColumnTarget, placeholder: "(resize|collapse|expand|toggle|color|init)")],
        conflictingOptions: [
            ["--dry-run", "--write"],
        ],
    )

    public init(
        target: ColumnTarget,
        preset: ZoneInitPreset = .balanced,
        monitor: MonitorDescription? = nil,
        dryRun: Bool = false,
        write: Bool = false,
        replaceExisting: Bool = false,
    ) {
        self.commonState = .init([])
        self.target = .initialized(target)
        self.preset = preset
        self.monitor = monitor
        self.dryRun = dryRun
        self.write = write
        self.replaceExisting = replaceExisting
    }

    public var target: Lateinit<ColumnTarget> = .uninitialized
    public var preset: ZoneInitPreset = .balanced
    public var monitor: MonitorDescription?
    public var dryRun: Bool = false
    public var write: Bool = false
    public var replaceExisting: Bool = false
}

func parseColumnCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ColumnCmdArgs> {
    parseSpecificCmdArgs(ColumnCmdArgs(rawArgs: args), args)
}

private let focusedColumnSelector = ZoneSelector("focused")

private func parseColumnTarget(i: PosArgParserInput) -> ParsedCliArgs<ColumnTarget> {
    func optionalColumn(at relativeIndex: Int) -> ZoneSelector? {
        guard let raw = i.getOrNil(relativeIndex: relativeIndex), !raw.starts(with: "-"), !raw.isEmpty else { return nil }
        return ZoneSelector(raw)
    }

    switch i.arg {
        case "resize":
            guard let amountArg = i.getOrNil(relativeIndex: 1) else {
                return .fail("'column resize' requires a width like -10%, +10%, or 60%", advanceBy: 1)
            }
            switch parseColumnWidthAmount(amountArg) {
                case .failure(let msg):
                    return .fail(msg, advanceBy: optionalColumn(at: 2) == nil ? 2 : 3)
                case .success(let amount):
                    if let column = optionalColumn(at: 2) {
                        return .succ(.resize(amount: amount, column: column), advanceBy: 3)
                    }
                    return .succ(.resize(amount: amount, column: focusedColumnSelector), advanceBy: 2)
            }
        case "collapse", "expand", "toggle":
            let column = optionalColumn(at: 1)
            let selector = column ?? focusedColumnSelector
            let advanceBy = column == nil ? 1 : 2
            let target: ColumnTarget = switch i.arg {
                case "collapse": .collapse(column: selector)
                case "expand": .expand(column: selector)
                default: .toggle(column: selector)
            }
            return .succ(target, advanceBy: advanceBy)
        case "color":
            guard let hexArg = i.getOrNil(relativeIndex: 1) else {
                return .fail("'column color' requires a hex like #3EA2FF", advanceBy: 1)
            }
            switch parseColorHexValue(hexArg) {
                case .failure(let msg):
                    return .fail(msg, advanceBy: optionalColumn(at: 2) == nil ? 2 : 3)
                case .success(let hex):
                    if let column = optionalColumn(at: 2) {
                        return .succ(.color(hex: hex, column: column), advanceBy: 3)
                    }
                    return .succ(.color(hex: hex, column: focusedColumnSelector), advanceBy: 2)
            }
        case "init":
            return .succ(.initialize, advanceBy: 1)
        default:
            return .fail("Unknown column subcommand '\(i.arg)'. Expected (resize|collapse|expand|toggle|color|init)", advanceBy: 1)
    }
}

public struct FocusColumnCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .focusColumn,
        allowInConfig: true,
        help: focus_column_help_generated,
        flags: [:],
        posArgs: [newMandatoryPosArgParser(\.column, parseZoneSelector, placeholder: "<column>")],
    )

    public init(column: ZoneSelector) {
        self.commonState = .init([])
        self.column = .initialized(column)
    }

    public var column: Lateinit<ZoneSelector> = .uninitialized
}

func parseFocusColumnCmdArgs(_ args: StrArrSlice) -> ParsedCmd<FocusColumnCmdArgs> {
    parseSpecificCmdArgs(FocusColumnCmdArgs(rawArgs: args), args)
}

public struct MoveNodeToColumnCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .moveNodeToColumn,
        allowInConfig: true,
        help: move_node_to_column_help_generated,
        flags: [
            "--window-id": optionalWindowIdFlag(),
            "--focus-follows-window": trueBoolFlag(\.focusFollowsWindow),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        posArgs: [newMandatoryPosArgParser(\.column, parseZoneSelector, placeholder: "<column>")],
    )

    public init(column: ZoneSelector) {
        self.commonState = .init([])
        self.column = .initialized(column)
    }

    public var failIfNoop: Bool = false
    public var focusFollowsWindow: Bool = false
    public var column: Lateinit<ZoneSelector> = .uninitialized
}

func parseMoveNodeToColumnCmdArgs(_ args: StrArrSlice) -> ParsedCmd<MoveNodeToColumnCmdArgs> {
    parseSpecificCmdArgs(MoveNodeToColumnCmdArgs(rawArgs: args), args)
}

public struct BalanceColumnsCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .balanceColumns,
        allowInConfig: true,
        help: balance_columns_help_generated,
        flags: [
            "--monitor": ArgParser(\.monitor, parseColumnMonitorSubArg),
        ],
        posArgs: [],
    )

    public init(monitor: MonitorDescription? = nil) {
        self.commonState = .init([])
        self.monitor = monitor
    }

    public var monitor: MonitorDescription?
}

func parseBalanceColumnsCmdArgs(_ args: StrArrSlice) -> ParsedCmd<BalanceColumnsCmdArgs> {
    parseSpecificCmdArgs(BalanceColumnsCmdArgs(rawArgs: args), args)
}

public struct SetColumnSnapPolicyCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .setColumnSnapPolicy,
        allowInConfig: true,
        help: set_column_snap_policy_help_generated,
        flags: [
            "--monitor": ArgParser(\.monitor, parseColumnMonitorSubArg),
        ],
        posArgs: [newMandatoryPosArgParser(\.policyId, parseColumnSnapPolicyId, placeholder: "<policy>")],
    )

    public init(policyId: String, monitor: MonitorDescription? = nil) {
        self.commonState = .init([])
        self.policyId = .initialized(policyId)
        self.monitor = monitor
    }

    public var monitor: MonitorDescription?
    public var policyId: Lateinit<String> = .uninitialized
}

func parseSetColumnSnapPolicyCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SetColumnSnapPolicyCmdArgs> {
    parseSpecificCmdArgs(SetColumnSnapPolicyCmdArgs(rawArgs: args), args)
}

public struct CycleColumnSnapPolicyCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .cycleColumnSnapPolicy,
        allowInConfig: true,
        help: cycle_column_snap_policy_help_generated,
        flags: [
            "--monitor": ArgParser(\.monitor, parseColumnMonitorSubArg),
        ],
        posArgs: [newMandatoryPosArgParser(\.policyIds, parseColumnSnapPolicyIds, placeholder: "<policy>...")],
    )

    public init(policyIds: [String], monitor: MonitorDescription? = nil) {
        self.commonState = .init([])
        self.policyIds = .initialized(policyIds)
        self.monitor = monitor
    }

    public var monitor: MonitorDescription?
    public var policyIds: Lateinit<[String]> = .uninitialized
}

func parseCycleColumnSnapPolicyCmdArgs(_ args: StrArrSlice) -> ParsedCmd<CycleColumnSnapPolicyCmdArgs> {
    parseSpecificCmdArgs(CycleColumnSnapPolicyCmdArgs(rawArgs: args), args)
}

public struct ListColumnsCmdArgs: CmdArgs, JsonFormattableListCmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .listColumns,
        allowInConfig: false,
        help: list_columns_help_generated,
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

extension ListColumnsCmdArgs {
    public var format: [StringInterToken] {
        _format.isEmpty
            ? [
                .interVar("monitor-zone-id"), .interVar("right-padding"), .literal(" | "),
                .interVar("monitor-zone-name"), .interVar("right-padding"), .literal(" | "),
                .literal("enabled "), .interVar("monitor-zone-enabled"), .interVar("right-padding"), .literal(" | "),
                .literal("width "), .interVar("monitor-zone-effective-width"), .interVar("right-padding"), .literal(" | "),
                .literal("color "), .interVar("monitor-zone-style-color"), .interVar("right-padding"), .literal(" | "),
                .literal("monitor "), .interVar("monitor-physical-id"), .interVar("right-padding"), .literal(" | "),
                .interVar("monitor-active-workspace"),
            ]
            : _format
    }
}

func parseListColumnsCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ListColumnsCmdArgs> {
    parseSpecificCmdArgs(ListColumnsCmdArgs(rawArgs: args), args)
        .validateJsonFormat()
}

private func parseZoneInitPresetSubArg(i: SubArgParserInput) -> ParsedCliArgs<ZoneInitPreset> {
    guard let arg = i.nonFlagArgOrNil() else {
        return .fail("'\(i.superArg)' must be followed by mandatory preset", advanceBy: 0)
    }
    return .init(parseEnum(arg, ZoneInitPreset.self), advanceBy: 1)
}

private func parseZoneSelector(i: PosArgParserInput) -> ParsedCliArgs<ZoneSelector> {
    i.arg.isEmpty
        ? .fail("<column> must not be empty", advanceBy: 1)
        : .succ(ZoneSelector(i.arg), advanceBy: 1)
}

private func parseColumnWidthAmount(_ raw: String) -> Parsed<ZoneWidthAmount> {
    guard raw.hasSuffix("%") else {
        return .failure("<percent> must include a % suffix, for example +10%")
    }
    let rawNumber = String(raw.dropLast())
    guard !rawNumber.isEmpty else {
        return .failure("<percent> must include a number")
    }
    let sign: Character? = rawNumber.first.flatMap { $0 == "+" || $0 == "-" ? $0 : nil }
    let numberText = sign == nil ? rawNumber : String(rawNumber.dropFirst())
    guard let number = Double(numberText), number > 0 else {
        return .failure("<percent> must be a positive number")
    }
    let percent = number / 100.0
    return switch sign {
        case "+": .success(.add(percent))
        case "-": .success(.subtract(percent))
        default: .success(.set(percent))
    }
}

private func parseColorHexValue(_ raw: String) -> Parsed<String> {
    guard raw.hasPrefix("#") else {
        return .failure("<hex> must start with '#', for example #3EA2FF")
    }
    let digits = raw.dropFirst()
    guard digits.count == 3 || digits.count == 6,
          digits.allSatisfy(\.isHexDigit)
    else {
        return .failure("<hex> must be #RGB or #RRGGBB, for example #3EA2FF")
    }
    return .success(raw)
}

private func parseColumnSnapPolicyId(i: PosArgParserInput) -> ParsedCliArgs<String> {
    switch parseColumnSnapPolicyIdentifier(i.arg) {
        case .success(let policyId): .succ(policyId, advanceBy: 1)
        case .failure(let msg): .fail(msg, advanceBy: 1)
    }
}

private func parseColumnSnapPolicyIds(i: PosArgParserInput) -> ParsedCliArgs<[String]> {
    let args = i.nonFlagArgs()
    guard !args.isEmpty else {
        return .fail("<policy> is mandatory", advanceBy: 0)
    }
    var policyIds: [String] = []
    for (offset, arg) in args.enumerated() {
        switch parseColumnSnapPolicyIdentifier(arg) {
            case .success(let policyId):
                policyIds.append(policyId)
            case .failure(let msg):
                return .fail(msg, advanceBy: offset + 1)
        }
    }
    return .succ(policyIds, advanceBy: args.count)
}

private func parseColumnSnapPolicyIdentifier(_ raw: String) -> Parsed<String> {
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

private func parseColumnMonitorSubArg(i: SubArgParserInput) -> ParsedCliArgs<MonitorDescription?> {
    guard let arg = i.nonFlagArgOrNil() else {
        return .fail("'\(i.superArg)' must be followed by mandatory monitor selector", advanceBy: 0)
    }
    return .init(parseMonitorDescription(arg).map(Optional.some), advanceBy: 1)
}
