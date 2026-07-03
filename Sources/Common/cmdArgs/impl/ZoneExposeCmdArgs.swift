public enum ZoneExposeScope: String, CaseIterable, Equatable, Sendable {
    case display
    case zone
}

public struct ZoneExposeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .zoneExpose,
        allowInConfig: true,
        help: zone_expose_help_generated,
        flags: [:],
        posArgs: [newMandatoryPosArgParser(\.scope, parseZoneExposeScope, placeholder: ZoneExposeScope.unionLiteral)],
    )

    public init(scope: ZoneExposeScope) {
        self.commonState = .init([])
        self.scope = .initialized(scope)
    }

    public var scope: Lateinit<ZoneExposeScope> = .uninitialized
}

func parseZoneExposeCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ZoneExposeCmdArgs> {
    parseSpecificCmdArgs(ZoneExposeCmdArgs(rawArgs: args), args)
}

private func parseZoneExposeScope(i: PosArgParserInput) -> ParsedCliArgs<ZoneExposeScope> {
    .init(parseEnum(i.arg, ZoneExposeScope.self), advanceBy: 1)
}
