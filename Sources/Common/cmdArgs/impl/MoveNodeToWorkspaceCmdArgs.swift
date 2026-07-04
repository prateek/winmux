public struct MoveNodeToCardCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public static let parser: CmdParser<Self> = .init(
        kind: .moveNodeToCard,
        allowInConfig: true,
        help: move_node_to_card_help_generated,
        flags: [
            "--wrap-around": optionalTrueBoolFlag(\._wrapAround),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
            "--window-id": optionalWindowIdFlag(),
            "--focus-follows-window": trueBoolFlag(\.focusFollowsWindow),

            "--stdin": optionalTrueBoolFlag(\.explicitStdinFlag),
            "--no-stdin": optionalFalseBoolFlag(\.explicitStdinFlag),
        ],
        posArgs: [newMandatoryPosArgParser(\.target, parseWorkspaceTarget, placeholder: workspaceTargetPlaceholder)],
        conflictingOptions: [
            ["--stdin", "--no-stdin"],
        ],
    )

    public var _wrapAround: Bool?
    public var explicitStdinFlag: Bool? = nil
    public var failIfNoop: Bool = false
    public var focusFollowsWindow: Bool = false
    public var target: Lateinit<WorkspaceTarget> = .uninitialized

    public init(rawArgs: StrArrSlice) {
        self.commonState = .init(rawArgs)
    }
}

extension MoveNodeToCardCmdArgs {
    public var wrapAround: Bool { _wrapAround ?? false }
    public var useStdin: Bool { explicitStdinFlag ?? false }
}

func parseMoveNodeToCardCmdArgs(_ args: StrArrSlice) -> ParsedCmd<MoveNodeToCardCmdArgs> {
    parseSpecificCmdArgs(MoveNodeToCardCmdArgs(rawArgs: args), args)
        .filter("--wrapAround requires using (prev|next) argument") { ($0._wrapAround != nil).implies($0.target.val.isRelative) }
        .filterNot("--fail-if-noop is incompatible with (next|prev)") { $0.failIfNoop && $0.target.val.isRelative }
        .filterNot("--window-id is incompatible with (next|prev)") { $0.windowId != nil && $0.target.val.isRelative }
        .filter("--stdin and --no-stdin require using \(NextPrev.unionLiteral) argument") { ($0.explicitStdinFlag != nil).implies($0.target.val.isRelative) }
}
