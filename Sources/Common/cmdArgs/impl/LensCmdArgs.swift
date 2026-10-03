public struct LensCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public var name: String?
    public var filter: String?
    public var search: String?
    public var presentation: String?
    public var sort: String?
    public static let parser: CmdParser<Self> = .init(
        kind: .lens, allowInConfig: true,
        help: """
        USAGE: lens <name> [--search <text>] [--presentation list|strip|miniatures]
               lens --filter <name|body|-> [--sort mru,title,...] [--presentation ...]
               lens --presentation list

        Toggle a named Lens, open an ad-hoc Lens, or change the open Presentation.
        Inline Filters bind w and ctx. Quote enum tags with double quotes:
          lens --filter "w.class == 'floating"
        --filter - reads a body from stdin.
        """,
        flags: ["--filter": filterBodySubArgParser(\.filter),
                "--search": singleValueSubArgParser(\.search, "<text>") { $0 },
                "--presentation": singleValueSubArgParser(\.presentation, "<presentation>") { $0 },
                "--sort": singleValueSubArgParser(\.sort, "<sort-keys>") { $0 }],
        posArgs: [ArgParser(\.name, upcastArgParserFun(consumeStrCliArg))]
    )
}

func filterBodySubArgParser<Root>(_ keyPath: SendableWritableKeyPath<Root, String?>) -> SubArgParser<Root, String?> {
    ArgParser(keyPath) { input in
        if input.argOrNil == "-" { return .succ("-", advanceBy: 1) }
        guard let value = input.nonFlagArgOrNil() else { return .fail("'<name|body|->' is mandatory", advanceBy: 0) }
        return .succ(value, advanceBy: 1)
    }
}

func parseLensCmdArgs(_ args: StrArrSlice) -> ParsedCmd<LensCmdArgs> {
    parseSpecificCmdArgs(LensCmdArgs(commonState: .init(args)), args)
        .filter("Specify a Lens name, --filter, or --presentation list") { $0.name != nil || $0.filter != nil || $0.presentation == "list" }
        .filter("A Lens name conflicts with --filter and --sort") { $0.name == nil || ($0.filter == nil && $0.sort == nil) }
        .filter("--sort requires --filter") { $0.sort == nil || $0.filter != nil }
        .filter("Possible presentations: list, strip, miniatures") { $0.presentation == nil || ["list", "strip", "miniatures"].contains($0.presentation!) }
        .filter("Unknown sort key") { $0.sort == nil || $0.sort!.split(separator: ",", omittingEmptySubsequences: false).allSatisfy { ["mru", "previous", "spatial", "workspace", "app", "title", "created"].contains(String($0)) } }
        .filter("--search requires a Lens name or --filter") { $0.search == nil || $0.name != nil || $0.filter != nil }
}

public struct ListLensesCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { commonState = .init(rawArgs) }
    public var json = false
    public static let parser: CmdParser<Self> = .init(
        kind: .listLenses, allowInConfig: false, help: "USAGE: list-lenses [--json]\nPrint the Lenses resolved for the default Display profile.",
        flags: ["--json": trueBoolFlag(\.json)], posArgs: []
    )
}

public struct SummonCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .summon, allowInConfig: true, help: "USAGE: summon [--window-id <id>]\nMove a window to the current workspace and focus it.",
        flags: ["--window-id": optionalWindowIdFlag()], posArgs: []
    )
}
