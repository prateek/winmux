public struct ConfigCmdArgs: CmdArgs, Equatable {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public static let parser: CmdParser<Self> = .init(
        kind: .config,
        allowInConfig: false,
        help: config_help_generated,
        flags: [
            "--json": trueBoolFlag(\.json),
            "--keys": trueBoolFlag(\.keys),
            "--major-keys": trueBoolFlag(\.majorKeys),
            "--all-keys": trueBoolFlag(\.allKeys),
            "--config-path": trueBoolFlag(\.configPath),
            "--get": singleValueSubArgParser(\.keyNameToGet, "<name>") { $0 },
        ],
        posArgs: [
            ArgParser(\.action, upcastArgParserFun(parseConfigAction)),
            ArgParser(\.file, upcastArgParserFun(consumeStrCliArg)),
        ],
    )

    public var json: Bool = false
    public var majorKeys: Bool = false
    public var keys: Bool = false
    public var allKeys: Bool = false
    public var configPath: Bool = false
    public var keyNameToGet: String? = nil
    public var action: ConfigAction? = nil
    public var file: String? = nil
}

public enum ConfigAction: String, CaseIterable, Sendable {
    case status, check, convert, schema
}

private func parseConfigAction(i: PosArgParserInput) -> ParsedCliArgs<ConfigAction> {
    .init(parseEnum(i.arg, ConfigAction.self), advanceBy: 1)
}

extension ConfigCmdArgs {
    public enum Mode {
        case getKey(key: String), majorKeys, allKeys, configPath
        /// The state of the config helper.
        case status
        /// Run by the CLI itself, so that they work when the server is not running.
        case check(file: String?), convert(file: String?), schema(json: Bool)
    }

    public var mode: Mode {
        if let keyNameToGet { return .getKey(key: keyNameToGet) }
        if majorKeys { return .majorKeys }
        if allKeys { return .allKeys }
        if configPath { return .configPath }
        switch action {
            case .status: return .status
            case .check: return .check(file: file)
            case .convert: return .convert(file: file)
            case .schema: return .schema(json: json)
            case nil: break
        }
        die("At least one mode must be specified")
    }
}

func parseConfigCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ConfigCmdArgs> {
    parseSpecificCmdArgs(ConfigCmdArgs(commonState: .init(args)), args)
        .flatMap { raw in
            var conflicting: Set<String> = []
            if raw.keyNameToGet != nil { conflicting.insert("--get") }
            if raw.majorKeys { conflicting.insert("--major-keys") }
            if raw.allKeys { conflicting.insert("--all-keys") }
            if raw.configPath { conflicting.insert("--config-path") }
            if let action = raw.action { conflicting.insert(action.rawValue) }
            return switch conflicting.count {
                case 1: .cmd(raw)
                case 0: .failure("Specify one of: status, check, convert, schema, --get, --major-keys, --all-keys, --config-path")
                default: .failure("Conflicting flags are specified: \(conflicting.joined(separator: ", "))")
            }
        }
        .filter("--keys flag requires --get flag") { !$0.keys || $0.keyNameToGet != nil }
        .filter("--json flag requires --get flag or schema") { !$0.json || $0.keyNameToGet != nil || $0.action == .schema }
        .filter("Only check and convert take a file") { $0.file == nil || $0.action == .check || $0.action == .convert }
}
