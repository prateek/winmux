public enum ExposeScope: String, CaseIterable, Equatable, Sendable {
    case display
    case card
}

public struct ExposeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .expose,
        allowInConfig: true,
        help: expose_help_generated,
        flags: [:],
        posArgs: [newMandatoryPosArgParser(\.scope, parseExposeScope, placeholder: ExposeScope.unionLiteral)],
    )

    public init(scope: ExposeScope) {
        self.commonState = .init([])
        self.scope = .initialized(scope)
    }

    public var scope: Lateinit<ExposeScope> = .uninitialized
}

func parseExposeCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ExposeCmdArgs> {
    parseSpecificCmdArgs(ExposeCmdArgs(rawArgs: args), args)
}

private func parseExposeScope(i: PosArgParserInput) -> ParsedCliArgs<ExposeScope> {
    .init(parseEnum(i.arg, ExposeScope.self), advanceBy: 1)
}
