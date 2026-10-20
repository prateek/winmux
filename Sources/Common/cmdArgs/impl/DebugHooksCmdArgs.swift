public enum DebugHooksAction: String, CaseIterable, Sendable {
    case on, off, status
}

public struct DebugHooksCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { commonState = .init(rawArgs) }
    public var json = false
    public var action: DebugHooksAction?
    public static let parser: CmdParser<Self> = .init(
        kind: .debugHooks, allowInConfig: false, help: debug_hooks_help_generated,
        flags: ["--json": trueBoolFlag(\.json)],
        posArgs: [ArgParser(\.action, upcastArgParserFun { .init(parseEnum($0.arg, DebugHooksAction.self), advanceBy: 1) })]
    )
}
