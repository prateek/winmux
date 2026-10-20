public struct FocusBackCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .focusBack, allowInConfig: true, help: focus_back_help_generated,
        flags: [:], posArgs: []
    )
}

public struct MarkCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { commonState = .init(rawArgs) }
    public var register: String?
    public static let parser: CmdParser<Self> = .init(
        kind: .mark, allowInConfig: true, help: mark_help_generated,
        flags: [:], posArgs: [ArgParser(\.register, upcastArgParserFun(parseWindowRegister))]
    )
}

public struct JumpCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { commonState = .init(rawArgs) }
    public var register: Lateinit<String> = .uninitialized
    public static let parser: CmdParser<Self> = .init(
        kind: .jump, allowInConfig: true, help: jump_help_generated,
        flags: [:], posArgs: [newMandatoryPosArgParser(\.register, parseWindowRegister, placeholder: "<register>")]
    )
}

public struct ListMarksCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { commonState = .init(rawArgs) }
    public var json = false
    public static let parser: CmdParser<Self> = .init(
        kind: .listMarks, allowInConfig: false, help: list_marks_help_generated,
        flags: ["--json": trueBoolFlag(\.json)], posArgs: []
    )
}

private func parseWindowRegister(_ input: PosArgParserInput) -> ParsedCliArgs<String> {
    let bytes = Array(input.arg.utf8)
    guard bytes.count == 1, let byte = bytes.first, (97...122).contains(byte) else {
        return .fail("Register must be one lowercase letter a to z", advanceBy: 1)
    }
    return .succ(input.arg, advanceBy: 1)
}
