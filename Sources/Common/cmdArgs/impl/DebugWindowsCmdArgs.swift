public struct DebugWindowsCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .debugWindows,
        allowInConfig: false,
        help: debug_windows_help_generated,
        flags: [
            "--window-id": ArgParser(\.windowId, upcastArgParserFun(parseUInt32SubArg)),
            "--filter-context": trueBoolFlag(\.filterContext),
        ],
        posArgs: [],
    )

    /// Also print the Filter context, which holds the records of the focused, hovered and
    /// previously focused windows.
    public var filterContext: Bool = false
}
