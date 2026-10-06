public struct SectionsCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    public var value: Lateinit<String> = .uninitialized
    public init(rawArgs: StrArrSlice) { commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .sections, allowInConfig: true, help: sections_help_generated,
        flags: [:], posArgs: [newMandatoryPosArgParser(\.value, { input in
            if ["next", "none", "workspace", "project", "monitor", "app"].contains(input.arg) {
                return .succ(input.arg, advanceBy: 1)
            }
            return .fail("Possible sections values: next, none, workspace, project, monitor, app", advanceBy: 1)
        }, placeholder: "<grouping>")]
    )
}
