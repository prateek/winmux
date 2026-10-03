public struct PaletteCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .palette,
        allowInConfig: true,
        help: """
            USAGE: palette [-h|--help]

            Alias for lens search. Requires the search Lens in the loaded config.
            """,
        flags: [:],
        posArgs: [],
    )
}
