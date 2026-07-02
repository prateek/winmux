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
            "--check": singleValueSubArgParser(\.configPathToCheck, "<path>") { $0 },
            "--get": singleValueSubArgParser(\.keyNameToGet, "<name>") { $0 },
            "--restore-backup": singleValueSubArgParser(\.backupPathToRestore, "<path>") { $0 },
        ],
        posArgs: [],
    )

    public var json: Bool = false
    public var majorKeys: Bool = false
    public var keys: Bool = false
    public var allKeys: Bool = false
    public var configPath: Bool = false
    public var configPathToCheck: String? = nil
    public var keyNameToGet: String? = nil
    public var backupPathToRestore: String? = nil

    public init(
        commonState: CmdArgsCommonState,
        json: Bool = false,
        majorKeys: Bool = false,
        keys: Bool = false,
        allKeys: Bool = false,
        configPath: Bool = false,
        configPathToCheck: String? = nil,
        keyNameToGet: String? = nil,
        backupPathToRestore: String? = nil,
    ) {
        self.commonState = commonState
        self.json = json
        self.majorKeys = majorKeys
        self.keys = keys
        self.allKeys = allKeys
        self.configPath = configPath
        self.configPathToCheck = configPathToCheck
        self.keyNameToGet = keyNameToGet
        self.backupPathToRestore = backupPathToRestore
    }
}

extension ConfigCmdArgs {
    public enum Mode {
        case getKey(key: String), majorKeys, allKeys, configPath, check(path: String), restoreBackup(path: String)
    }

    public var mode: Mode {
        if let keyNameToGet { return .getKey(key: keyNameToGet) }
        if majorKeys { return .majorKeys }
        if allKeys { return .allKeys }
        if configPath { return .configPath }
        if let configPathToCheck { return .check(path: configPathToCheck) }
        if let backupPathToRestore { return .restoreBackup(path: backupPathToRestore) }
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
            if raw.configPathToCheck != nil { conflicting.insert("--check") }
            if raw.backupPathToRestore != nil { conflicting.insert("--restore-backup") }
            return switch conflicting.count {
                case 1: .cmd(raw)
                case 0: .failure("Mandatory flag is not specified (--get|--major-keys|--all-keys|--config-path|--check|--restore-backup)")
                default: .failure("Conflicting flags are specified: \(conflicting.joined(separator: ", "))")
            }
        }
        .filter("--keys flag requires --get flag") { !$0.keys || $0.keyNameToGet != nil }
        .filter("--json flag requires --get flag") { !$0.json || $0.keyNameToGet != nil }
}
