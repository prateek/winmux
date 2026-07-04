public enum SceneTarget: Equatable, Sendable {
    /// `scene <name>` — switch the focused display to a declared scene.
    case switchTo(String)
    /// `scene next` — cycle the focused display's declared scenes.
    case next
    /// `scene new <name>` — name the display's current live arrangement as a scene.
    case new(String)
}

public struct SceneCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .scene,
        allowInConfig: true,
        help: scene_help_generated,
        flags: [
            "--monitor": ArgParser(\.monitor, parseMonitorDescriptionSceneSubArg),
        ],
        posArgs: [newMandatoryPosArgParser(\.target, parseSceneTarget, placeholder: "(<name>|next|new <name>)")],
    )

    public init(target: SceneTarget, monitor: MonitorDescription? = nil) {
        self.commonState = .init([])
        self.target = .initialized(target)
        self.monitor = monitor
    }

    public var monitor: MonitorDescription?
    public var target: Lateinit<SceneTarget> = .uninitialized
}

func parseSceneCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SceneCmdArgs> {
    parseSpecificCmdArgs(SceneCmdArgs(rawArgs: args), args)
}

private func parseSceneTarget(i: PosArgParserInput) -> ParsedCliArgs<SceneTarget> {
    switch i.arg {
        case "next":
            return .succ(.next, advanceBy: 1)
        case "new":
            guard let name = i.getOrNil(relativeIndex: 1), !name.starts(with: "-") else {
                return .fail("'scene new' requires a name", advanceBy: 1)
            }
            return .init(validateSceneName(name).map(SceneTarget.new), advanceBy: 2)
        default:
            return .init(validateSceneName(i.arg).map(SceneTarget.switchTo), advanceBy: 1)
    }
}

private func validateSceneName(_ raw: String) -> Parsed<String> {
    if raw.isEmpty {
        return .failure("<name> must not be empty")
    }
    guard isValidConfigIdentifier(raw) else {
        return .failure("<name> must use only letters, numbers, hyphens, and underscores")
    }
    return .success(raw)
}

/// The shared charset for config identifiers (scene ids, column/zone ids): letters, numbers,
/// hyphens, and underscores. The CLI validator and the config parser both gate on it so a value
/// that round-trips through one accepts through the other.
public func isValidConfigIdentifier(_ raw: String) -> Bool {
    raw.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
}

private func parseMonitorDescriptionSceneSubArg(i: SubArgParserInput) -> ParsedCliArgs<MonitorDescription?> {
    guard let arg = i.nonFlagArgOrNil() else {
        return .fail("'\(i.superArg)' must be followed by mandatory monitor selector", advanceBy: 0)
    }
    return .init(parseMonitorDescription(arg).map(Optional.some), advanceBy: 1)
}
