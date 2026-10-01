import Common
import Foundation
import TOMLKit

let legacyConfigDotfileName = ".winmux.toml"
let generatedConfigDirectoryName = "winmux"
let generatedConfigFileName = "winmux.ncl"
let legacyConfigFileName = "winmux.toml"
let aerospaceLegacyConfigDotfileName = ".aerospace.toml"
let aerospaceConfigDirectoryName = "aerospace"
let aerospaceConfigFileName = "aerospace.toml"

func xdgConfigHomeUrl() -> URL {
    ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"].map { URL(filePath: $0) }
        ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/")
}

func generatedConfigUrl() -> URL {
    xdgConfigHomeUrl()
        .appending(path: generatedConfigDirectoryName)
        .appending(path: generatedConfigFileName)
}

func legacyConfigCandidateUrls() -> [URL] {
    [
        xdgConfigHomeUrl().appending(path: generatedConfigDirectoryName).appending(path: legacyConfigFileName),
        FileManager.default.homeDirectoryForCurrentUser.appending(path: legacyConfigDotfileName),
    ]
}

func preferredLegacyConfigImportUrl() -> URL? {
    legacyConfigCandidateUrls().first { FileManager.default.fileExists(atPath: $0.path) }
}

func aerospaceConfigCandidateUrls() -> [URL] {
    [
        xdgConfigHomeUrl().appending(path: aerospaceConfigDirectoryName).appending(path: aerospaceConfigFileName),
        FileManager.default.homeDirectoryForCurrentUser.appending(path: aerospaceLegacyConfigDotfileName),
    ]
}

func preferredAerospaceConfigImportUrl() -> URL? {
    aerospaceConfigCandidateUrls().first { FileManager.default.fileExists(atPath: $0.path) }
}

@MainActor
func preferredEditableConfigUrl() -> URL {
    if let configLocation = serverArgs.configLocation {
        return URL(filePath: configLocation)
    }
    if let customConfigUrl = findCustomConfigUrl().urlOrNil {
        return customConfigUrl
    }
    return generatedConfigUrl()
}

/// What a first launch writes: a config that takes every default and changes nothing.
func starterConfigText() -> String {
    """
    # WinMux config. It is Nickel: https://nickel-lang.org
    #
    # `winmux/defaults.ncl` holds the settings and bindings WinMux starts with, and this file
    # merges its own settings over them. `winmux config check` reports mistakes, and
    # `winmux reload-config` applies the file.
    #
    # The `nickel` CLI and its language server find the two imports when NICKEL_IMPORT_PATH is
    # set to the directory that holds `winmux/`: Contents/Resources/nickel inside WinMux.app.
    let W = import "winmux/winmux.ncl" in
    ((import "winmux/defaults.ncl") & {
      # gaps.inner.horizontal = 0,
      # mode.main.binding.alt-enter = "exec-and-forget open -a Terminal",
    }) | W.Config

    """
}

@MainActor
func ensureBootstrapConfigExistsIfNeeded() throws -> URL? {
    guard serverArgs.configLocation == nil else { return nil }
    let targetUrl = generatedConfigUrl()
    let existingLegacyUrls = preferredLegacyConfigImportUrl().map { [$0] } ?? []
    let aerospaceImportUrl = preferredAerospaceConfigImportUrl()
    if try materializeBootstrapConfigIfNeeded(
        targetUrl: targetUrl,
        existingLegacyUrls: existingLegacyUrls,
        aerospaceImportUrl: aerospaceImportUrl,
    ) {
        return targetUrl
    } else {
        return nil
    }
}

/// - Parameter convert: Translates a TOML config file into Nickel source.
func materializeBootstrapConfigIfNeeded(
    targetUrl: URL,
    existingLegacyUrls: [URL],
    aerospaceImportUrl: URL? = nil,
    convert: (URL) throws -> String = convertTomlConfigToNickel,
) throws -> Bool {
    guard !FileManager.default.fileExists(atPath: targetUrl.path) else { return false }
    let parentUrl = targetUrl.deletingLastPathComponent()
    if parentUrl.path != targetUrl.path {
        try FileManager.default.createDirectory(at: parentUrl, withIntermediateDirectories: true)
    }
    let text: String
    if let legacyUrl = existingLegacyUrls.first {
        text = try convert(legacyUrl)
    } else if let aerospaceImportUrl,
              let keyboardConfig = try migrateAerospaceConfigForWinMux(try String(contentsOf: aerospaceImportUrl, encoding: .utf8))
    {
        let migratedUrl = FileManager.default.temporaryDirectory.appending(path: "winmux-aerospace-\(UUID().uuidString).toml")
        try keyboardConfig.write(to: migratedUrl, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: migratedUrl) }
        text = """
            # Migrated from the AeroSpace config \(aerospaceImportUrl.path).
            # WinMux owns this file after import; the AeroSpace config is not read again. Only its
            # keyboard configuration was imported.

            """ + (try convert(migratedUrl))
    } else {
        text = starterConfigText()
    }
    try text.write(to: targetUrl, atomically: true, encoding: .utf8)
    return true
}

/// Runs `winmux-nickel convert` on a TOML config and returns the Nickel source it prints.
func convertTomlConfigToNickel(_ tomlUrl: URL) throws -> String {
    guard let helper = nickelHelperUrl() else {
        throw ConfigConversionError(message: "The config helper winmux-nickel was not found, so \(tomlUrl.path) cannot be converted")
    }
    let process = Process()
    let stdout = Pipe()
    let stderr = Pipe()
    process.executableURL = helper
    process.arguments = ["convert", tomlUrl.path]
    process.standardOutput = stdout
    process.standardError = stderr
    try process.run()
    let output = stdout.fileHandleForReading.readDataToEndOfFile()
    let diagnostic = stderr.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw ConfigConversionError(message: "Cannot convert \(tomlUrl.path)\n\n\(String(decoding: diagnostic, as: UTF8.self))")
    }
    return String(decoding: output, as: UTF8.self)
}

struct ConfigConversionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// The keyboard configuration of an AeroSpace config, as WinMux TOML: its key mapping and its
/// modes, with AeroSpace's names replaced by WinMux's. `nil` if it has none.
func migrateAerospaceConfigForWinMux(_ rawToml: String) throws -> String? {
    _ = try TOMLTable(string: rawToml)

    var migrated = aerospaceKeyboardConfigSections(from: rawToml)
    let literalReplacements = [
        ("AEROSPACE_FOCUSED_WORKSPACE", "WINMUX_FOCUSED_WORKSPACE"),
        ("AEROSPACE_PREV_WORKSPACE", "WINMUX_PREV_WORKSPACE"),
        ("AEROSPACE_WINDOW_ID", "WINMUX_WINDOW_ID"),
        ("AEROSPACE_WORKSPACE", "WINMUX_WORKSPACE"),
        ("accordion-padding", "tab-group-padding"),
        ("h_accordion", "h_tab_group"),
        ("v_accordion", "v_tab_group"),
    ]
    for (old, new) in literalReplacements {
        migrated = migrated.replacingOccurrences(of: old, with: new)
    }
    migrated = migrated.replacingRegex(
        #"(?<![A-Za-z0-9_-])accordion(?![A-Za-z0-9_-])"#,
        with: "tab-group",
    )
    return migrated.isEmpty ? nil : migrated
}

private extension String {
    func replacingRegex(_ pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return self }
        let range = NSRange(startIndex ..< endIndex, in: self)
        return regex.stringByReplacingMatches(in: self, range: range, withTemplate: replacement)
    }
}

private func aerospaceKeyboardConfigSections(from rawToml: String) -> String {
    keyboardConfigSections(from: rawToml, keepMatchingSections: true)
}

private func keyboardConfigSections(from rawToml: String, keepMatchingSections: Bool) -> String {
    let lines = rawToml.components(separatedBy: "\n")
    var sections: [[String]] = []
    var current: [String] = []
    var shouldKeepCurrent = !keepMatchingSections

    func flushCurrentSection() {
        if shouldKeepCurrent {
            sections.append(current)
        }
        current = []
        shouldKeepCurrent = false
    }

    for line in lines {
        if isTomlSectionHeader(line) {
            flushCurrentSection()
            current = [line]
            shouldKeepCurrent = isAerospaceKeyboardSectionHeader(line) == keepMatchingSections
        } else {
            current.append(line)
        }
    }
    flushCurrentSection()

    return sections
        .map { sectionLines in
            sectionLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
}

private func isAerospaceKeyboardSectionHeader(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    return trimmed == "[key-mapping]" ||
        trimmed == "[mode]" ||
        trimmed.hasPrefix("[mode.") ||
        trimmed.hasPrefix("[[mode.")
}

private func isTomlSectionHeader(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    return (trimmed.hasPrefix("[[") && trimmed.hasSuffix("]]")) ||
        (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))
}

func findCustomConfigUrl() -> ConfigFile {
    let candidates: [URL] = if let configLocation = serverArgs.configLocation {
        [URL(filePath: configLocation)]
    } else {
        [generatedConfigUrl()]
    }
    let existingCandidates: [URL] = candidates.filter { (candidate: URL) in FileManager.default.fileExists(atPath: candidate.path) }
    let count = existingCandidates.count
    return switch count {
        case 0: .noCustomConfigExists
        case 1: .file(existingCandidates.first.orDie())
        default: .ambiguousConfigError(existingCandidates)
    }
}

enum ConfigFile {
    case file(URL), ambiguousConfigError(_ candidates: [URL]), noCustomConfigExists

    var urlOrNil: URL? {
        return switch self {
            case .file(let url): url
            case .ambiguousConfigError, .noCustomConfigExists: nil
        }
    }
}
