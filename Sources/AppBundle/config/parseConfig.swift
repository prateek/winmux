import AppKit
import Common
import HotKey
import TOMLKit
import OrderedCollections

@MainActor
func readConfig(forceConfigUrl: URL? = nil) -> Result<(Config, URL), String> {
    let configUrl: URL
    if let forceConfigUrl {
        configUrl = forceConfigUrl
    } else {
        switch findCustomConfigUrl() {
            case .file(let url): configUrl = url
            case .noCustomConfigExists: configUrl = defaultConfigUrl
            case .ambiguousConfigError(let candidates):
                let msg = """
                    Ambiguous config error. Several configs found:
                    \(candidates.map(\.path).joined(separator: "\n"))
                    """
                return .failure(msg)
        }
    }
    let (parsedConfig, errors) = (try? String(contentsOf: configUrl, encoding: .utf8)).map { parseConfig($0) } ?? (defaultConfig, [])

    if errors.isEmpty {
        return .success((parsedConfig, configUrl))
    } else {
        let msg = """
            Failed to parse \(configUrl.absoluteURL.path)

            \(errors.map(\.description).joined(separator: "\n\n"))
            """
        return .failure(msg)
    }
}

private let keyMappingConfigRootKey = "key-mapping"
private let modeConfigRootKey = "mode"
private let sceneConfigRootKey = "scene"
private let persistentWorkspacesKey = "persistent-workspaces"
private let persistentCardsKey = "persistent-cards"

// For every new config option you add, think:
// 1. Does it make sense to have different value
// 2. Prefer commands and commands flags over toml options if possible
private let configParser: [String: any ParserProtocol<Config>] = [
    "config-version": Parser(\.configVersion, parseConfigVersion),

    "after-login-command": Parser(\.afterLoginCommand, parseAfterLoginCommand),
    "after-startup-command": Parser(\.afterStartupCommand) { parseCommandOrCommands($0).toParsedToml($1) },

    "on-focus-changed": Parser(\.onFocusChanged) { parseCommandOrCommands($0).toParsedToml($1) },
    "on-mode-changed": Parser(\.onModeChanged) { parseCommandOrCommands($0).toParsedToml($1) },
    "on-focused-monitor-changed": Parser(\.onFocusedMonitorChanged) { parseCommandOrCommands($0).toParsedToml($1) },
    // "on-focused-workspace-changed": Parser(\.onFocusedWorkspaceChanged, { parseCommandOrCommands($0).toParsedToml($1) }),

    "enable-normalization-flatten-containers": Parser(\.enableNormalizationFlattenContainers, parseBool),
    "enable-normalization-opposite-orientation-for-nested-containers": Parser(\.enableNormalizationOppositeOrientationForNestedContainers, parseBool),

    "default-root-container-layout": Parser(\.defaultRootContainerLayout, parseLayout),
    "default-root-container-orientation": Parser(\.defaultRootContainerOrientation, parseDefaultContainerOrientation),

    "start-at-login": Parser(\.startAtLogin, parseBool),
    "auto-reload-config": Parser(\.autoReloadConfig, parseBool),
    "automatically-unhide-macos-hidden-apps": Parser(\.automaticallyUnhideMacosHiddenApps, parseBool),
    "shortcuts-preset": Parser(\.shortcutsPreset, parseShortcutsPreset),
    "tab-group-padding": Parser(\.tabGroupPadding, parseInt),
    persistentWorkspacesKey: Parser(\.persistentWorkspaces, parsePersistentWorkspaces),
    persistentCardsKey: Parser(\.persistentWorkspaces, parsePersistentWorkspaces), // config-version 3 spelling
    "exec-on-workspace-change": Parser(\.execOnWorkspaceChange, parseArrayOfStrings),
    "exec": Parser(\.execConfig, parseExecConfig),

    keyMappingConfigRootKey: Parser(\.keyMapping, skipParsing(Config().keyMapping)), // Parsed manually
    modeConfigRootKey: Parser(\.modes, skipParsing(Config().modes)), // Parsed manually
    sceneConfigRootKey: Parser(\.scenes, skipParsing(Config().scenes)), // Parsed manually (needs declaration order + synthesis)

    "auto-add-new-windows-to-tab-group": Parser(\.autoAddNewWindowsToTabGroup, parseBool),
    "gaps": Parser(\.gaps, parseGaps),
    "mouse": Parser(\.mouse, parseMouseConfig),
    "updates": Parser(\.updates, parseUpdatesConfig),
    "workspace-sidebar": Parser(\.workspaceSidebar, parseWorkspaceSidebar),
    "sidebar": Parser(\.workspaceSidebar, parseWorkspaceSidebar), // config-version 3 spelling
    "window-tabs": Parser(\.windowTabs, parseWindowTabs),
    "zone-styles": Parser(\._retiredZoneStyles, skipParsing(Config()._retiredZoneStyles)),
    "zone-layouts": Parser(\.columnLayouts, parseColumnLayouts),
    "zone-scenes": Parser(\._retiredZoneScenes, skipParsing(Config()._retiredZoneScenes)),
    "zone-bindings": Parser(\._retiredZoneBindings, skipParsing(Config()._retiredZoneBindings)),
    "zone-affinities": Parser(\._retiredZoneAffinities, skipParsing(Config()._retiredZoneAffinities)),
    "zone-availability-sets": Parser(\._retiredZoneAvailabilitySets, skipParsing(Config()._retiredZoneAvailabilitySets)),
    "zones": Parser(\.zones, parseZones),
    "rules": Parser(\.rules, parseRules),
    "workspace-to-monitor-force-assignment": Parser(\.workspaceToMonitorForceAssignment, parseWorkspaceToMonitorAssignment),
    "on-window-detected": Parser(\.onWindowDetected, parseOnWindowDetectedArray),

    // Deprecated
    "non-empty-workspaces-root-containers-layout-on-startup": Parser(\._nonEmptyWorkspacesRootContainersLayoutOnStartup, parseStartupRootContainerLayout),
    "indent-for-nested-containers-with-the-same-orientation": Parser(\._indentForNestedContainersWithTheSameOrientation, parseIndentForNestedContainersWithTheSameOrientation),
]

extension ParsedCmd where T == any Command {
    fileprivate func toEither() -> Parsed<T> {
        return switch self {
            case .cmd(let a):
                a.info.allowInConfig
                    ? .success(a)
                    : .failure("Command '\(a.info.kind.rawValue)' cannot be used in config")
            case .help(let a): .failure(a)
            case .failure(let a): .failure(a)
        }
    }
}

extension Command {
    fileprivate var isMacOsNativeCommand: Bool { // Problem ID-B6E178F2
        self is MacosNativeMinimizeCommand || self is MacosNativeFullscreenCommand
    }
}

func parseAfterLoginCommand(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<[any Command]> {
    if let array = raw.array, array.count == 0 {
        return .success([])
    }
    let msg = "after-login-command is deprecated since WinMux 0.19.0. https://github.com/nikitabobko/WinMux/issues/1482"
    return .failure(.semantic(backtrace, msg))
}

func parseCommandOrCommands(_ raw: TOMLValueConvertible) -> Parsed<[any Command]> {
    if let rawString = raw.string {
        return parseCommand(rawString).toEither().map { [$0] }
    } else if let rawArray = raw.array {
        let commands: Parsed<[any Command]> = (0 ..< rawArray.count).mapAllOrFailure { index in
            let rawString: String = rawArray[index].string ?? expectedActualTypeError(expected: .string, actual: rawArray[index].type)
            return parseCommand(rawString).toEither()
        }
        return commands.filter("macos-native-* commands are only allowed to be the last commands in the list") {
            !$0.dropLast().contains(where: { $0.isMacOsNativeCommand })
        }
    } else {
        return .failure(expectedActualTypeError(expected: [.string, .array], actual: raw.type))
    }
}

@MainActor func parseConfig(_ rawToml: String) -> (config: Config, errors: [TomlParseError]) { // todo change return value to Result
    let rawTable: TOMLTable
    do {
        rawTable = try TOMLTable(string: rawToml)
    } catch let e as TOMLParseError {
        return (defaultConfig, [.syntax(e.debugDescription)])
    } catch let e {
        return (defaultConfig, [.syntax(e.localizedDescription)])
    }

    var errors: [TomlParseError] = []

    var config = rawTable.parseTable(Config(), configParser, .emptyRoot, &errors)

    if let mapping = rawTable[keyMappingConfigRootKey].flatMap({ parseKeyMapping($0, .rootKey(keyMappingConfigRootKey), &errors) }) {
        config.keyMapping = mapping
    }

    // Parse modeConfigRootKey after keyMappingConfigRootKey
    if let modes = rawTable[modeConfigRootKey].flatMap({ parseModes($0, .rootKey(modeConfigRootKey), &errors, config.keyMapping.resolve()) }) {
        config.modes = modes
    }
    applyShortcutsPreset(&config, mapping: config.keyMapping.resolve(), errors: &errors)
    let shouldValidateMainMode = rawTable.contains(key: modeConfigRootKey) || config.shortcutsPreset != .none
    if shouldValidateMainMode && !config.modes.keys.contains(mainModeId) {
        errors += [.semantic(.rootKey(modeConfigRootKey), "Please specify '\(mainModeId)' mode")]
    }

    if config.configVersion <= 1 {
        if rawTable.contains(key: persistentWorkspacesKey) {
            errors += [.semantic(.rootKey(persistentWorkspacesKey), "This config option is only available since 'config-version = 2'")]
        }
        config.persistentWorkspaces = (config.modes.values.lazy
            .flatMap { (mode: Mode) -> [HotkeyBinding] in Array(mode.bindings.values) }
            .flatMap { (binding: HotkeyBinding) -> [String] in
                binding.commands.filterIsInstance(of: CardCommand.self).compactMap { $0.args.target.val.workspaceNameOrNil()?.raw } +
                    binding.commands.filterIsInstance(of: MoveNodeToCardCommand.self).compactMap { $0.args.target.val.workspaceNameOrNil()?.raw }
            }
            + (config.workspaceToMonitorForceAssignment).keys)
            .toOrderedSet()
    }

    let errorCountBeforeDeadKeyCheck = errors.count
    if config.configVersion >= 3 {
        reportConfigVersion3DeadKeys(rawTable, &errors)
    }
    let hasConfigVersion3DeadKeys = errors.count != errorCountBeforeDeadKeyCheck

    if let rawScene = rawTable[sceneConfigRootKey] {
        applyParsedScenes(rawToml, rawScene, &config, &errors)
    }

    // A config-version-3 config that names a retired zone key is already rejected. Skip the zone
    // reference validators in that case so the one-line replacement hint is the only diagnostic,
    // instead of stacking "unknown zone" noise from the now-dead parser onto it.
    if !hasConfigVersion3DeadKeys {
        validateColumnLayoutReferences(config, &errors)
    }

    if config.enableNormalizationFlattenContainers {
        let containsSplitCommand = config.modes.values.lazy.flatMap { $0.bindings.values }
            .flatMap { $0.commands }
            .contains { $0 is SplitCommand }
        if containsSplitCommand {
            errors += [.semantic(
                .emptyRoot, // todo Make 'split' + flatten normalization prettier
                """
                The config contains:
                1. usage of 'split' command
                2. enable-normalization-flatten-containers = true
                These two settings don't play nicely together. 'split' command has no effect when enable-normalization-flatten-containers is disabled.

                My recommendation: keep the normalizations enabled, and prefer 'join-with' over 'split'.
                """,
            )]
        }
    }
    return (config, errors)
}

func parseIndentForNestedContainersWithTheSameOrientation(
    _ _: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
) -> ParsedToml<Void> {
    let msg = "Deprecated. Please drop it from the config. See https://github.com/nikitabobko/WinMux/issues/96"
    return .failure(.semantic(backtrace, msg))
}

func parseConfigVersion(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Int> {
    let min = 1
    let max = 3
    return parseInt(raw, backtrace)
        .filter(.semantic(backtrace, "Must be in [\(min), \(max)] range")) { (min ... max).contains($0) }
}

// MARK: - Config-version-3 vocabulary cut
//
// The domain-model rewrite retires the fork's zone-era vocabulary. Under `config-version = 3` each
// dead or renamed key is a hard error whose message names its replacement, so an old config fails
// loudly rather than parsing into a concept that no longer exists. The runtime structs and the
// `[scene.*]`/`[[rules]]` parsers that reuse them (DisplayLayoutConfig, ColumnLayoutConfig, ...) are untouched;
// only these top-level and nested config keys become errors.

/// Retired top-level keys, paired with the one-line hint naming their replacement.
private let configVersion3DeadTopLevelKeys: [(key: String, hint: String)] = [
    ("zones", "'zones' was replaced by [scene.*] (config-version 3)"),
    ("zone-layouts", "'zone-layouts' was replaced by [scene.*] (config-version 3)"),
    ("zone-scenes", "'zone-scenes' was replaced by [scene.*] (config-version 3)"),
    ("zone-availability-sets", "'zone-availability-sets' was replaced by [scene.*] (config-version 3)"),
    ("zone-styles", "'zone-styles' was replaced by the column 'color' attribute (config-version 3)"),
    ("zone-affinities", "'zone-affinities' was replaced by [[rules]] (config-version 3)"),
    ("zone-bindings", "'zone-bindings' was removed; column decks record card membership (config-version 3)"),
    ("workspace-sidebar", "'workspace-sidebar' was renamed to 'sidebar' (config-version 3)"),
    ("persistent-workspaces", "'persistent-workspaces' was renamed to 'persistent-cards' (config-version 3)"),
]

/// Renamed `[mouse]` sub-keys.
private let configVersion3DeadMouseKeys: [(key: String, hint: String)] = [
    ("zone-snap", "'mouse.zone-snap' was renamed to 'mouse.column-snap' (config-version 3)"),
    ("zone-divider-drag", "'mouse.zone-divider-drag' was renamed to 'mouse.column-divider-drag' (config-version 3)"),
]

/// Project-scoped `[sidebar]` sub-keys that went away with projects.
private let configVersion3DeadSidebarKeys: [(key: String, hint: String)] = [
    ("project-deletion-action", "'sidebar.project-deletion-action' was removed; projects are gone in config-version 3"),
    ("project-labels", "'sidebar.project-labels' was removed; projects are gone in config-version 3"),
    ("project-colors", "'sidebar.project-colors' was removed; projects are gone in config-version 3"),
]

private func reportConfigVersion3DeadKeys(_ rawTable: TOMLTable, _ errors: inout [TomlParseError]) {
    for (key, hint) in configVersion3DeadTopLevelKeys where rawTable.contains(key: key) {
        errors.append(.semantic(.rootKey(key), hint))
    }
    if let mouseTable = rawTable["mouse"]?.table {
        for (key, hint) in configVersion3DeadMouseKeys where mouseTable.contains(key: key) {
            errors.append(.semantic(.rootKey("mouse") + .key(key), hint))
        }
    }
    // Only the renamed `[sidebar]` block carries project keys; a legacy `[workspace-sidebar]` block
    // is already rejected wholesale above.
    if let sidebarTable = rawTable["sidebar"]?.table {
        for (key, hint) in configVersion3DeadSidebarKeys where sidebarTable.contains(key: key) {
            errors.append(.semantic(.rootKey("sidebar") + .key(key), hint))
        }
    }
}

func parseInt(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Int> {
    raw.int.orFailure(expectedActualTypeError(expected: .int, actual: raw.type, backtrace))
}

func parseDouble(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Double> {
    if let double = raw.double {
        return .success(double)
    }
    if let int = raw.int {
        return .success(Double(int))
    }
    return .failure(expectedActualTypeError(expected: [.double, .int], actual: raw.type, backtrace))
}

func parseString(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<String> {
    raw.string.orFailure(expectedActualTypeError(expected: .string, actual: raw.type, backtrace))
}

func parseSimpleType<T>(_ raw: TOMLValueConvertible) -> T? {
    (raw.int as? T) ?? (raw.string as? T) ?? (raw.bool as? T)
}

func parseTomlArray(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<TOMLArray> {
    raw.array.orFailure(expectedActualTypeError(expected: .array, actual: raw.type, backtrace))
}

func parseTable<T: ConvenienceCopyable>(
    _ raw: TOMLValueConvertible,
    _ initial: T,
    _ fieldsParser: [String: any ParserProtocol<T>],
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> T {
    guard let table = raw.table else {
        errors.append(expectedActualTypeError(expected: .table, actual: raw.type, backtrace))
        return initial
    }
    return table.parseTable(initial, fieldsParser, backtrace, &errors)
}

private func parseStartupRootContainerLayout(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Void> {
    parseString(raw, backtrace)
        .filter(.semantic(backtrace, "'non-empty-workspaces-root-containers-layout-on-startup' is deprecated. Please drop it from your config")) { raw in raw == "smart" }
        .map { _ in () }
}

private func parseLayout(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Layout> {
    parseString(raw, backtrace)
        .flatMap { $0.parseLayout().orFailure(.semantic(backtrace, "Can't parse layout '\($0)'")) }
}

private func parseShortcutsPreset(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<ShortcutsPreset> {
    parseString(raw, backtrace)
        .flatMap { rawValue in
            ShortcutsPreset(rawValue: rawValue)
                .orFailure(.semantic(backtrace, "Can't parse shortcuts preset '\(rawValue)'. Possible values: (none|rectangle)"))
        }
}

@MainActor
private func applyShortcutsPreset(_ config: inout Config, mapping: [String: Key], errors: inout [TomlParseError]) {
    guard config.shortcutsPreset == .rectangle else { return }
    errors += [.semantic(.rootKey("shortcuts-preset"), "The 'rectangle' shortcuts preset has been removed")]
}

private func skipParsing<T: Sendable>(_ value: T) -> @Sendable (_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<T> {
    { _, _ in .success(value) }
}

private func parsePersistentWorkspaces(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<OrderedSet<String>> {
    parseArrayOfStrings(raw, backtrace)
        .flatMap { arr in
            let set = arr.toOrderedSet()
            return set.count == arr.count ? .success(set) : .failure(.semantic(backtrace, "Contains duplicated workspace names"))
        }
}

private func parseArrayOfStrings(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<[String]> {
    parseTomlArray(raw, backtrace)
        .flatMap { arr in
            arr.enumerated().mapAllOrFailure { (index, elem) in
                parseString(elem, backtrace + .index(index))
            }
        }
}

private func parseDefaultContainerOrientation(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<DefaultContainerOrientation> {
    parseString(raw, backtrace).flatMap {
        DefaultContainerOrientation(rawValue: $0)
            .orFailure(.semantic(backtrace, "Can't parse default container orientation '\($0)'"))
    }
}

extension Parsed where Failure == String {
    func toParsedToml(_ backtrace: TomlBacktrace) -> ParsedToml<Success> {
        mapError { .semantic(backtrace, $0) }
    }
}

func parseBool(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Bool> {
    raw.bool.orFailure(expectedActualTypeError(expected: .bool, actual: raw.type, backtrace))
}
