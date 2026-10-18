public struct FindFocusCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .findFocus,
        allowInConfig: true,
        help: """
        USAGE: find-focus

        Briefly dims every screen except the focused window and draws an accent border inside it.
        Any key or click ends the mark early.
        """,
        flags: [:],
        posArgs: [],
    )
}
