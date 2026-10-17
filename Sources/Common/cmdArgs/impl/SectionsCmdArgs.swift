let sectionGroupings = ["none", "workspace", "project", "monitor", "app"]

private let sectionsCommandValues = ["next"] + sectionGroupings

public struct SectionsCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public var value: Lateinit<String> = .uninitialized
    public init(rawArgs: StrArrSlice) { commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .sections, allowInConfig: true, help: sections_help_generated,
        flags: [:], posArgs: [newMandatoryPosArgParser(\.value, { .succ($0.arg, advanceBy: 1) }, placeholder: "<grouping>")]
    )
}

func parseSectionsCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SectionsCmdArgs> {
    parseSpecificCmdArgs(SectionsCmdArgs(rawArgs: args), args)
        .filter("Possible sections values: \(sectionsCommandValues.joined(separator: ", "))") {
            sectionsCommandValues.contains($0.value.val)
        }
}
