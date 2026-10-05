public struct DebugLensTraceCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { commonState = .init(rawArgs) }
    public var json = false
    public var last: Int?
    public static let parser: CmdParser<Self> = .init(
        kind: .debugLensTrace, allowInConfig: false, help: debug_lens_trace_help_generated,
        flags: ["--json": trueBoolFlag(\.json), "--last": singleValueSubArgParser(\.last, "<n>") { value in
            guard let n = Int(value), n > 0 else { return nil }
            return n
        }], posArgs: []
    )
}
