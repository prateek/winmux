public struct DoctorCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .doctor,
        allowInConfig: false,
        help: """
            USAGE: doctor [-h|--help]
               OR: doctor zones --support-bundle [--output <dir>] [--include-window-titles]

            Print diagnostics: permissions, monitors, per-app accessibility latency,
            and window manager state. Useful for bug reports and performance triage.

            Support bundles collect redacted column config, monitor topology,
            runtime overlays, active workspaces, permission status, and available
            routing diagnostics into an attachable directory.
            """,
        flags: [
            "--support-bundle": trueBoolFlag(\.supportBundle),
            "--output": singleValueSubArgParser(\.outputPath, "<dir>") { $0 },
            "--include-window-titles": trueBoolFlag(\.includeWindowTitles),
        ],
        posArgs: [
            ArgParser(\.subject, parseDoctorSubject),
        ],
    )

    public var subject: DoctorSubject?
    public var supportBundle: Bool = false
    public var outputPath: String?
    public var includeWindowTitles: Bool = false
}

public enum DoctorSubject: String, CaseIterable, Sendable {
    case zones
}

private func parseDoctorSubject(i: PosArgParserInput) -> ParsedCliArgs<DoctorSubject?> {
    .init(parseEnum(i.arg, DoctorSubject.self).map { $0 }, advanceBy: 1)
}

func parseDoctorCmdArgs(_ args: StrArrSlice) -> ParsedCmd<DoctorCmdArgs> {
    parseSpecificCmdArgs(DoctorCmdArgs(rawArgs: args), args)
        .filter("doctor zones requires --support-bundle") { args in
            args.subject != .zones || args.supportBundle
        }
        .filter("--support-bundle requires 'zones'") { args in
            !args.supportBundle || args.subject == .zones
        }
        .filter("--output requires 'zones --support-bundle'") { args in
            args.outputPath == nil || (args.subject == .zones && args.supportBundle)
        }
        .filter("--include-window-titles requires 'zones --support-bundle'") { args in
            !args.includeWindowTitles || (args.subject == .zones && args.supportBundle)
        }
}
