/// `card <subcommand>` — the card verb folds the former workspace, workspace-back-and-forth,
/// summon-workspace, and move-workspace-to-monitor commands. Runtime cards are upstream
/// workspaces; a column viewport is an upstream monitor, so `card move left|right` reuses the
/// move-workspace-to-monitor path across the adjacent column.
public enum CardTarget: Equatable, Sendable {
    /// `card next` / `card prev` — page the focused column's deck.
    case relative(NextPrev)
    /// `card go <name>` or bare `card <N>` — reveal a card by name or deck position.
    case direct(WorkspaceName)
    /// `card back-and-forth` — bounce between the last two cards.
    case backAndForth
    /// `card summon <name>` — move the named card into the focused column.
    case summon(WorkspaceName)
    /// `card move left|right|<monitor-pattern>` — move the focused card to another column.
    case move(MonitorTarget)

    public var isRelative: Bool {
        switch self {
            case .relative: true
            default: false
        }
    }

    public var isMove: Bool {
        switch self {
            case .move: true
            default: false
        }
    }

    public func workspaceNameOrNil() -> WorkspaceName? {
        switch self {
            case .direct(let name), .summon(let name): name
            default: nil
        }
    }
}

public struct CardCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .card,
        allowInConfig: true,
        help: card_help_generated,
        flags: [
            "--auto-back-and-forth": optionalTrueBoolFlag(\._autoBackAndForth),
            "--wrap-around": optionalTrueBoolFlag(\._wrapAround),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
            "--workspace": optionalWorkspaceFlag(),

            "--stdin": optionalTrueBoolFlag(\.explicitStdinFlag),
            "--no-stdin": optionalFalseBoolFlag(\.explicitStdinFlag),
        ],
        posArgs: [newMandatoryPosArgParser(\.target, parseCardTarget, placeholder: cardTargetPlaceholder)],
        conflictingOptions: [
            ["--stdin", "--no-stdin"],
        ],
    )

    public var target: Lateinit<CardTarget> = .uninitialized
    public var _autoBackAndForth: Bool?
    public var failIfNoop: Bool = false
    public var _wrapAround: Bool?
    public var explicitStdinFlag: Bool? = nil
}

func parseCardCmdArgs(_ args: StrArrSlice) -> ParsedCmd<CardCmdArgs> {
    parseSpecificCmdArgs(CardCmdArgs(rawArgs: args), args)
        .filter("--wrap-around requires using (next|prev) or 'move' argument") { ($0._wrapAround != nil).implies($0.target.val.isRelative || $0.target.val.isMove) }
        .filterNot("--auto-back-and-forth is incompatible with (next|prev)") { $0._autoBackAndForth != nil && $0.target.val.isRelative }
        .filterNot("--fail-if-noop is incompatible with (next|prev)") { $0.failIfNoop && $0.target.val.isRelative }
        .filter("--stdin and --no-stdin require using (next|prev) argument") { ($0.explicitStdinFlag != nil).implies($0.target.val.isRelative) }
}

extension CardCmdArgs {
    public var wrapAround: Bool { _wrapAround ?? false }
    public var autoBackAndForth: Bool { _autoBackAndForth ?? false }
    public var useStdin: Bool { explicitStdinFlag ?? false }
}

let cardTargetPlaceholder = "(go <name>|next|prev|<N>|back-and-forth|summon <name>|move <target>)"

private func parseCardTarget(i: PosArgParserInput) -> ParsedCliArgs<CardTarget> {
    switch i.arg {
        case "next":
            return .succ(.relative(.next), advanceBy: 1)
        case "prev":
            return .succ(.relative(.prev), advanceBy: 1)
        case "back-and-forth":
            return .succ(.backAndForth, advanceBy: 1)
        case "go":
            guard let name = i.getOrNil(relativeIndex: 1), !name.starts(with: "-") else {
                return .fail("'card go' requires a card name", advanceBy: 1)
            }
            return .init(WorkspaceName.parse(name).map(CardTarget.direct), advanceBy: 2)
        case "summon":
            guard let name = i.getOrNil(relativeIndex: 1), !name.starts(with: "-") else {
                return .fail("'card summon' requires a card name", advanceBy: 1)
            }
            return .init(WorkspaceName.parse(name).map(CardTarget.summon), advanceBy: 2)
        case "move":
            guard i.getOrNil(relativeIndex: 1) != nil else {
                return .fail("'card move' requires \(MonitorTarget.cases.joinedCliArgs)", advanceBy: 1)
            }
            let parsed = parseTarget(i: PosArgParserInput(index: i.index + 1, args: i.args))
            return .init(parsed.value.map(CardTarget.move), advanceBy: 1 + parsed.advanceBy)
        default:
            return .init(WorkspaceName.parse(i.arg).map(CardTarget.direct), advanceBy: 1)
    }
}

// Retained for `move-node-to-card`, which keeps the upstream next|prev|<name> workspace grammar.
public enum WorkspaceTarget: Equatable, Sendable {
    case relative(NextPrev)
    case direct(WorkspaceName)

    public var isRelative: Bool {
        switch self {
            case .relative: true
            default: false
        }
    }

    public func workspaceNameOrNil() -> WorkspaceName? {
        switch self {
            case .direct(let name): name
            case .relative: nil
        }
    }
}

let workspaceTargetPlaceholder = "(<card-name>|next|prev)"

func parseWorkspaceTarget(i: PosArgParserInput) -> ParsedCliArgs<WorkspaceTarget> {
    switch i.arg {
        case "next": .succ(.relative(.next), advanceBy: 1)
        case "prev": .succ(.relative(.prev), advanceBy: 1)
        default: .init(WorkspaceName.parse(i.arg).map(WorkspaceTarget.direct), advanceBy: 1)
    }
}
