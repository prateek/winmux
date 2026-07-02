import AppKit
import Common
import Foundation

struct ZoneSupportBundleOptions: Equatable, Sendable {
    let outputPath: String?
    let includeWindowTitles: Bool
}

struct ZoneSupportBundleResult: Equatable, Sendable {
    let directory: URL
    let files: [String]
}

@MainActor
func writeZoneSupportBundle(options: ZoneSupportBundleOptions) async throws -> ZoneSupportBundleResult {
    let writer = ZoneSupportBundleWriter(options: options)
    return try await writer.write()
}

@MainActor
private struct ZoneSupportBundleWriter {
    let options: ZoneSupportBundleOptions
    let fileManager = FileManager.default
    let generatedAt = ISO8601DateFormatter().string(from: Date())
    let redactor: ZoneSupportBundleRedactor

    init(options: ZoneSupportBundleOptions) {
        self.options = options
        self.redactor = ZoneSupportBundleRedactor(includeWindowTitles: options.includeWindowTitles)
    }

    func write() async throws -> ZoneSupportBundleResult {
        let directory = try prepareOutputDirectory()
        var files: [String] = []

        func writeFile(_ name: String, _ text: String) throws {
            try writeSupportBundleFile(name, text, in: directory)
            files.append(name)
        }

        let configSnapshot = readConfigSnapshot()
        try writeFile("redaction-summary.txt", redactionSummary())
        try writeFile("config-redacted.toml", redactedConfigText(configSnapshot))
        try writeFile("config-doctor.txt", configDoctorText(configSnapshot))
        try writeFile("permissions.txt", permissionsText())
        try writeFile("monitor-topology.tsv", monitorTopologyText())
        try writeFile("active-workspaces.tsv", activeWorkspacesText())
        try writeFile("zone-runtime-overlay.tsv", runtimeOverlayText())
        try writeFile("zone-affinities.tsv", zoneAffinitiesText())
        try writeFile("node-zone-bindings.tsv", nodeZoneBindingsText())
        try writeFile("recent-window-routing-decisions.tsv", recentWindowRoutingDecisionsText())
        try writeFile("command-failures.tsv", commandFailuresText())
        try writeFile("logs.txt", logsText())

        let manifestFiles = files + ["manifest.txt"]
        try writeSupportBundleFile("manifest.txt", manifestText(files: manifestFiles), in: directory)
        return ZoneSupportBundleResult(directory: directory, files: manifestFiles.sorted())
    }

    private func prepareOutputDirectory() throws -> URL {
        let directory = options.outputPath.map { URL(fileURLWithPath: $0) } ?? defaultOutputDirectory()
        var isDirectory = ObjCBool(false)
        if fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw ZoneSupportBundleError("Output path exists and is not a directory: \(directory.path)")
            }
            let contents = try fileManager.contentsOfDirectory(atPath: directory.path)
            guard contents.isEmpty else {
                throw ZoneSupportBundleError("Output directory must be empty: \(directory.path)")
            }
        } else {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func defaultOutputDirectory() -> URL {
        let safeTimestamp = generatedAt
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
        return fileManager.temporaryDirectory
            .appending(component: "winmux-zone-support-\(safeTimestamp)-\(UUID().uuidString.prefix(8))")
    }

    private func readConfigSnapshot() -> ConfigSnapshot {
        do {
            return ConfigSnapshot(text: try String(contentsOf: configUrl, encoding: .utf8), readError: nil)
        } catch {
            return ConfigSnapshot(text: nil, readError: error.localizedDescription)
        }
    }

    private func redactionSummary() -> String {
        """
        Zone support bundle redaction
        generated-at=\(generatedAt)
        home-paths=<home>
        usernames=<user>
        window-titles=\(options.includeWindowTitles ? "included by --include-window-titles" : "<redacted-window-title>")
        app-identifiers=<redacted-app-identifier>
        secret-like-config-values=<redacted>
        non-config-paths=<path-redacted>
        """
    }

    private func redactedConfigText(_ snapshot: ConfigSnapshot) -> String {
        guard let text = snapshot.text else {
            return "config-read-error=\(redactor.redact(snapshot.readError ?? "Config file could not be read"))"
        }
        return redactor.redactConfigText(text)
    }

    private func configDoctorText(_ snapshot: ConfigSnapshot) -> String {
        renderConfigDoctorLines(
            configPath: configUrl.absoluteURL.path,
            configText: snapshot.text,
            readError: snapshot.readError,
            runtimeOverlays: zoneRuntimeOverlaysSnapshot(),
        )
        .map(redactor.redactConfigDiagnostic)
        .joined(separator: "\n")
    }

    private func permissionsText() -> String {
        [
            "permission\tstatus\tnote",
            "accessibility\t\(AXIsProcessTrusted() ? "granted" : "missing")\trequired",
            "screen-recording\t\(CGPreflightScreenCaptureAccess() ? "granted" : "missing")\ttab previews and radius estimation",
            "automation\tmacOS-managed\tSystem Settings > Privacy & Security > Automation",
            "input-monitoring\tmacOS-managed\tglobal mouse and keyboard capture",
        ].joined(separator: "\n")
    }

    private func monitorTopologyText() -> String {
        let header = "kind\tmonitor-id\tname\tphysical-identity\tx\ty\twidth\theight\tvisible-x\tvisible-y\tvisible-width\tvisible-height\tzone-id\tzone-name\tlayout-id\tavailability-set-id\tstyle-id\tstyle-color\tdefault-zone"
        let physicalRows = sortedPhysicalMonitors.map { monitor in
            monitorRow(kind: "physical", monitor: monitor)
        }
        let viewportRows = sortedMonitors.map { monitor in
            monitorRow(kind: monitor.zoneId == nil ? "workspace" : "zone", monitor: monitor)
        }
        return ([header] + physicalRows + viewportRows).joined(separator: "\n")
    }

    private func monitorRow(kind: String, monitor: Monitor) -> String {
        tsv([
            kind,
            String(monitor.monitorAppKitNsScreenScreensId),
            redactor.redact(monitor.name),
            redactor.redact(zoneLayoutPhysicalIdentity(for: monitor.physicalMonitor)),
            number(monitor.rect.topLeftX),
            number(monitor.rect.topLeftY),
            number(monitor.rect.width),
            number(monitor.rect.height),
            number(monitor.visibleRect.topLeftX),
            number(monitor.visibleRect.topLeftY),
            number(monitor.visibleRect.width),
            number(monitor.visibleRect.height),
            monitor.zoneId ?? "",
            monitor.zoneName ?? "",
            monitor.zoneLayoutId ?? "",
            monitor.zoneAvailabilitySetId ?? "",
            monitor.zoneStyleId ?? "",
            monitor.zoneStyleColorHex ?? "",
            String(monitor.isDefaultZone),
        ])
    }

    private func activeWorkspacesText() -> String {
        let rows = sortedMonitors.map { monitor in
            tsv([
                String(monitor.monitorAppKitNsScreenScreensId),
                monitor.zoneId ?? "",
                monitor.zoneName ?? "",
                redactor.redact(zoneLayoutPhysicalIdentity(for: monitor.physicalMonitor)),
                monitor.activeWorkspace.name,
                String(monitor.activeWorkspace.isVisible),
            ])
        }
        return (["monitor-id\tzone-id\tzone-name\tphysical-identity\tactive-workspace\tworkspace-visible"] + rows)
            .joined(separator: "\n")
    }

    private func runtimeOverlayText() -> String {
        let header = "physical-identity\tactive-layout\tactive-scene\tactive-availability\tsnap-policy\tdisabled-zones\tparked-workspaces\twidth-overrides\tstyle-overrides\ttoggle-restore-zone"
        let overlays = zoneRuntimeOverlaysSnapshot()
        guard !overlays.isEmpty else {
            return [header, "none\t\t\t\t\t\t\t\t\t"].joined(separator: "\n")
        }
        let rows = overlays.keys.sorted().map { physicalIdentity in
            let overlay = overlays[physicalIdentity] ?? ZoneRuntimeOverlay()
            return tsv([
                redactor.redact(physicalIdentity),
                overlay.activeLayoutId ?? "",
                overlay.activeSceneId ?? "",
                overlay.activeAvailabilitySetId ?? "",
                overlay.zoneSnapPolicyOverride?.rawValue ?? "",
                overlay.disabledZoneIds.sorted().joined(separator: ","),
                overlay.parkedWorkspaceByZoneId.keys.sorted().map { "\($0):\(overlay.parkedWorkspaceByZoneId[$0]?.description ?? "")" }.joined(separator: ","),
                widthOverrideSummary(overlay.widthOverridesByLayoutIdentity),
                overlay.styleOverridesByZoneId.keys.sorted().map { "\($0):\(overlay.styleOverridesByZoneId[$0] ?? "")" }.joined(separator: ","),
                overlay.currentToggleRestoreZoneId ?? "",
            ])
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private func zoneAffinitiesText() -> String {
        let header = "index\tzone\tapp-id-configured\tapp-name-configured\twindow-title-configured\tworkspace\tstartup\tfocus-follows-window\tfail-if-noop\tcheck-further-callbacks"
        guard !config.zoneAffinities.isEmpty else {
            return [header, "none\t\t\t\t\t\t\t\t\t"].joined(separator: "\n")
        }
        let rows = config.zoneAffinities.enumerated().map { index, affinity in
            let matcher = affinity.matcher
            return tsv([
                String(index),
                affinity.zone?.raw ?? "",
                matcher.appId == nil ? "false" : "true:<redacted-app-identifier>",
                matcher.appNameRegexSubstring == nil ? "false" : "true:<redacted-app-identifier>",
                matcher.windowTitleRegexSubstring == nil
                    ? "false"
                    : (options.includeWindowTitles ? "true:configured" : "true:<redacted-window-title>"),
                matcher.workspace ?? "",
                matcher.duringWinMuxStartup.map(String.init) ?? "",
                String(affinity.focusFollowsWindow),
                String(affinity.failIfNoop),
                String(affinity.checkFurtherCallbacks),
            ])
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private func nodeZoneBindingsText() -> String {
        let header = "node-id\tnode-type\twindow-ids\ttitle\tzone\tzone-name\tworkspace\tmonitor\tphysical"
        let rows = nodeZoneBindingRows().map { row in
            let binding = row.binding
            return tsv([
                binding.key.description,
                binding.key.kind.rawValue,
                binding.key.windowIds.map(String.init).joined(separator: ","),
                redactor.redactWindowTitle(binding.title),
                binding.zoneId,
                binding.zoneName ?? "",
                row.currentWorkspaceName,
                binding.physicalMonitorId.map(String.init) ?? "",
                redactor.redact(binding.physicalIdentity),
            ])
        }
        return ([header] + (rows.isEmpty ? ["none\t\t\t\t\t\t\t\t"] : rows)).joined(separator: "\n")
    }

    private func recentWindowRoutingDecisionsText() -> String {
        let header = "source\tindex-or-node\tzone\tworkspace\tmatched\tdebug"
        var rows: [String] = []
        rows += nodeZoneBindingRows().map { row in
            tsv([
                "node-zone-binding",
                row.binding.key.description,
                row.binding.zoneId,
                row.currentWorkspaceName,
                "true",
                "explicit binding retained in current runtime state; title=\(redactor.redactWindowTitle(row.binding.title))",
            ])
        }
        rows += config.zoneAffinities.enumerated().map { index, affinity in
            tsv([
                "zone-affinity-config",
                String(index),
                affinity.zone?.raw ?? "",
                affinity.matcher.workspace ?? "",
                "not-evaluated",
                "rule configured; live window match history is not retained",
            ])
        }
        if rows.isEmpty {
            rows.append("unavailable\t\t\t\tnot-retained\tWinMux does not retain a recent window-routing decision log yet")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private func commandFailuresText() -> String {
        [
            "source\tcommand\tstatus\tdebug",
            "unavailable\t\tunretained\tWinMux does not retain command failure history yet",
        ].joined(separator: "\n")
    }

    private func logsText() -> String {
        [
            "source\tstatus\tdebug",
            "stderr\tunavailable\tWinMux debug logs are emitted to the owning process stderr and are not retained in-app yet",
            "unified-log\tnot-collected\tSlice 48 support bundles do not query macOS unified logs yet",
        ].joined(separator: "\n")
    }

    private func manifestText(files: [String]) -> String {
        """
        winmux-zone-support-bundle
        schema-version=1
        generated-at=\(generatedAt)
        winmux-git=\(gitShortHash)
        command=doctor zones --support-bundle
        bundle-directory=\(redactor.redactPath(directoryLabel))
        config-path=\(redactor.redactConfigPath(configUrl.absoluteURL.path))
        app-path=\(redactor.redactPath(Bundle.main.bundlePath))
        executable-path=\(redactor.redactPath(Bundle.main.executablePath ?? "unknown"))
        files=\(files.sorted().joined(separator: ","))
        """
    }

    private var directoryLabel: String {
        options.outputPath ?? "<temporary-directory>"
    }

    private func writeSupportBundleFile(_ name: String, _ text: String, in directory: URL) throws {
        let normalized = text.hasSuffix("\n") ? text : text + "\n"
        try normalized.write(to: directory.appending(component: name), atomically: true, encoding: .utf8)
    }

    private func widthOverrideSummary(_ overrides: [String: [String: Double]]) -> String {
        overrides.keys.sorted().map { layoutId in
            let zones = overrides[layoutId] ?? [:]
            let zoneValues = zones.keys.sorted().map { zoneId in
                "\(zoneId)=\(String(format: "%.4f", zones[zoneId] ?? 0))"
            }
            return "\(layoutId)[\(zoneValues.joined(separator: ","))]"
        }.joined(separator: ";")
    }

    private func tsv(_ values: [String]) -> String {
        values.map { redactor.redact($0).replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: "\\n") }
            .joined(separator: "\t")
    }

    private func number(_ value: CGFloat) -> String {
        String(format: "%.0f", Double(value))
    }
}

private struct ConfigSnapshot {
    let text: String?
    let readError: String?
}

private struct ZoneSupportBundleRedactor {
    let includeWindowTitles: Bool
    let userName = NSUserName()
    let homePath = FileManager.default.homeDirectoryForCurrentUser.path

    func redact(_ value: String) -> String {
        var redacted = value
        if !homePath.isEmpty {
            redacted = redacted.replacingOccurrences(of: homePath, with: "<home>")
        }
        if !userName.isEmpty {
            redacted = redacted.replacingOccurrences(of: userName, with: "<user>")
        }
        return redacted
    }

    func redactPath(_ value: String) -> String {
        guard value != "unknown" else { return value }
        return "<path-redacted>"
    }

    func redactConfigPath(_ value: String) -> String {
        redact(value)
    }

    func redactWindowTitle(_ value: String) -> String {
        includeWindowTitles ? redact(value) : "<redacted-window-title>"
    }

    func redactConfigText(_ text: String) -> String {
        redact(redactSensitiveConfigAssignments(in: text))
    }

    func redactConfigDiagnostic(_ value: String) -> String {
        let redacted = redact(redactSensitiveConfigAssignments(in: value))
        guard redacted.localizedCaseInsensitiveContains("error") ||
              redacted.localizedCaseInsensitiveContains("can't parse") ||
              isSensitiveConfigKey(redacted)
        else {
            return redacted
        }
        let parseValueRedacted = redactConfigParseErrorValues(in: redacted)
        let quotedValuesRedacted = redactQuotedConfigValues(in: parseValueRedacted)
        guard isSensitiveConfigKey(quotedValuesRedacted) else { return quotedValuesRedacted }
        return replaceMatches(
            in: quotedValuesRedacted,
            pattern: #"(?i)((?:window-title|app-id|app-name|bundle-id|password|secret|token|credential|api-key|apikey)[^:\n]*:\s*).+"#,
            replacement: #"$1<redacted-config-value>"#,
        )
    }

    private func redactConfigParseErrorValues(in value: String) -> String {
        let parseValueRedacted = replaceMatches(
            in: value,
            pattern: #"(?i)(can't parse\s+).+?(\s+regex)"#,
            replacement: #"$1<redacted-config-value>$2"#,
        )
        return replaceMatches(in: parseValueRedacted, pattern: #"(?i)(cannot parse\s+).+?(\s+regex)"#, replacement: #"$1<redacted-config-value>$2"#)
    }

    private func redactSensitiveConfigAssignments(in text: String) -> String {
        var result = text
        let assignments = sensitiveConfigValueIndexRanges(in: text)
            .sorted { $0.lowerBound > $1.lowerBound }
        for range in assignments {
            result.replaceSubrange(range, with: #""<redacted>""#)
        }
        return result
    }

    private func sensitiveConfigValueIndexRanges(in text: String) -> [Range<String.Index>] {
        sensitiveConfigValueIndexRanges(
            in: text,
            within: text.startIndex ..< text.endIndex,
            treatsHashAsComment: true,
        )
    }

    private func sensitiveConfigValueIndexRanges(
        in text: String,
        within bounds: Range<String.Index>,
        treatsHashAsComment: Bool,
    ) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var index = bounds.lowerBound
        while index < bounds.upperBound {
            let char = text[index]
            if treatsHashAsComment, char == "#" {
                let commentEnd = lineEnd(startingAt: index, in: text, upperBound: bounds.upperBound)
                let commentBodyStart = text.index(after: index)
                ranges += sensitiveConfigValueIndexRanges(
                    in: text,
                    within: commentBodyStart ..< commentEnd,
                    treatsHashAsComment: false,
                )
                index = commentEnd
            } else if char == "\"" || char == "'" {
                index = configStringEnd(startingAt: index, in: text, upperBound: bounds.upperBound)
            } else if char == "=",
                      let keyRange = configAssignmentKeyRange(endingAt: index, in: text, lowerBound: bounds.lowerBound),
                      isSensitiveConfigKey(String(text[keyRange])),
                      let valueRange = configAssignmentValueRange(startingAfter: index, in: text, upperBound: bounds.upperBound)
            {
                ranges.append(valueRange)
                index = valueRange.upperBound
            } else {
                index = text.index(after: index)
            }
        }
        return ranges
    }

    private func configAssignmentKeyRange(
        endingAt equalsIndex: String.Index,
        in text: String,
        lowerBound: String.Index,
    ) -> Range<String.Index>? {
        var start = equalsIndex
        while start > lowerBound {
            let previous = text.index(before: start)
            if "\n,#{[".contains(text[previous]) {
                break
            }
            start = previous
        }
        let range = start ..< equalsIndex
        let trimmed = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return range
    }

    private func normalizedConfigKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = ""
        var index = trimmed.startIndex
        while index < trimmed.endIndex {
            switch trimmed[index] {
                case "\"":
                    let decoded = decodeTomlBasicStringContent(startingAt: index, in: trimmed)
                    result += decoded.value
                    index = decoded.end
                case "'":
                    let decoded = decodeTomlLiteralStringContent(startingAt: index, in: trimmed)
                    result += decoded.value
                    index = decoded.end
                default:
                    result.append(trimmed[index])
                    index = trimmed.index(after: index)
            }
        }
        return result.lowercased()
    }

    private func decodeTomlBasicStringContent(
        startingAt start: String.Index,
        in text: String,
    ) -> (value: String, end: String.Index) {
        var result = ""
        var index = text.index(after: start)
        while index < text.endIndex {
            let char = text[index]
            if char == "\"" {
                return (result, text.index(after: index))
            }
            if char == "\\" {
                let escapeStart = index
                index = text.index(after: index)
                guard index < text.endIndex else {
                    result.append("\\")
                    return (result, index)
                }
                switch text[index] {
                    case "b":
                        result.append("\u{08}")
                        index = text.index(after: index)
                    case "t":
                        result.append("\t")
                        index = text.index(after: index)
                    case "n":
                        result.append("\n")
                        index = text.index(after: index)
                    case "f":
                        result.append("\u{0C}")
                        index = text.index(after: index)
                    case "r":
                        result.append("\r")
                        index = text.index(after: index)
                    case "\"":
                        result.append("\"")
                        index = text.index(after: index)
                    case "\\":
                        result.append("\\")
                        index = text.index(after: index)
                    case "u":
                        let decoded = decodeUnicodeEscape(length: 4, afterMarkerAt: index, in: text)
                        result += decoded.value ?? String(text[escapeStart ... index])
                        index = decoded.end
                    case "U":
                        let decoded = decodeUnicodeEscape(length: 8, afterMarkerAt: index, in: text)
                        result += decoded.value ?? String(text[escapeStart ... index])
                        index = decoded.end
                    default:
                        result.append(text[index])
                        index = text.index(after: index)
                }
            } else {
                result.append(char)
                index = text.index(after: index)
            }
        }
        return (result, text.endIndex)
    }

    private func decodeUnicodeEscape(
        length: Int,
        afterMarkerAt marker: String.Index,
        in text: String,
    ) -> (value: String?, end: String.Index) {
        let hexStart = text.index(after: marker)
        var hexEnd = hexStart
        for _ in 0 ..< length {
            guard hexEnd < text.endIndex else { return (nil, hexStart) }
            hexEnd = text.index(after: hexEnd)
        }
        let hex = String(text[hexStart ..< hexEnd])
        guard let value = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(value) else {
            return (nil, hexEnd)
        }
        return (String(Character(scalar)), hexEnd)
    }

    private func decodeTomlLiteralStringContent(
        startingAt start: String.Index,
        in text: String,
    ) -> (value: String, end: String.Index) {
        var result = ""
        var index = text.index(after: start)
        while index < text.endIndex {
            if text[index] == "'" {
                return (result, text.index(after: index))
            }
            result.append(text[index])
            index = text.index(after: index)
        }
        return (result, text.endIndex)
    }

    private func configAssignmentValueRange(
        startingAfter equalsIndex: String.Index,
        in text: String,
        upperBound: String.Index,
    ) -> Range<String.Index>? {
        var start = text.index(after: equalsIndex)
        while start < upperBound, text[start].isWhitespace, text[start] != "\n" {
            start = text.index(after: start)
        }
        guard start < upperBound else { return nil }
        var index = start
        var squareDepth = 0
        var braceDepth = 0
        while index < upperBound {
            let char = text[index]
            if char == "\"" || char == "'" {
                index = configStringEnd(startingAt: index, in: text, upperBound: upperBound)
                continue
            }
            switch char {
                case "[":
                    squareDepth += 1
                case "]":
                    if squareDepth == 0 && braceDepth == 0 {
                        return start ..< index
                    }
                    squareDepth = max(0, squareDepth - 1)
                    if squareDepth == 0 && braceDepth == 0 {
                        index = text.index(after: index)
                        return start ..< index
                    }
                case "{":
                    braceDepth += 1
                case "}":
                    if squareDepth == 0 && braceDepth == 0 {
                        return start ..< index
                    }
                    braceDepth = max(0, braceDepth - 1)
                    if squareDepth == 0 && braceDepth == 0 {
                        index = text.index(after: index)
                        return start ..< index
                    }
                case ",", "#":
                    if squareDepth == 0 && braceDepth == 0 {
                        return sensitiveConfigValueRangeWithTrailingComment(
                            start: start,
                            end: index,
                            in: text,
                            upperBound: upperBound,
                        )
                    }
                case "\n":
                    if squareDepth == 0 && braceDepth == 0 {
                        return sensitiveConfigValueRangeWithTrailingComment(
                            start: start,
                            end: index,
                            in: text,
                            upperBound: upperBound,
                        )
                    }
                default:
                    break
            }
            index = text.index(after: index)
        }
        return sensitiveConfigValueRangeWithTrailingComment(start: start, end: upperBound, in: text, upperBound: upperBound)
    }

    private func sensitiveConfigValueRangeWithTrailingComment(
        start: String.Index,
        end: String.Index,
        in text: String,
        upperBound: String.Index,
    ) -> Range<String.Index> {
        var cursor = end
        while cursor < upperBound, text[cursor].isWhitespace, text[cursor] != "\n" {
            cursor = text.index(after: cursor)
        }
        guard cursor < upperBound, text[cursor] == "#" else {
            return start ..< end
        }
        return start ..< lineEnd(startingAt: cursor, in: text, upperBound: upperBound)
    }

    private func configStringEnd(
        startingAt start: String.Index,
        in text: String,
        upperBound: String.Index,
    ) -> String.Index {
        let quote = text[start]
        let afterFirst = text.index(after: start)
        let isTriple = afterFirst < upperBound &&
            text[afterFirst] == quote &&
            text.index(after: afterFirst) < upperBound &&
            text[text.index(after: afterFirst)] == quote
        var index = isTriple ? text.index(start, offsetBy: 3) : afterFirst
        while index < upperBound {
            if text[index] == quote {
                if isTriple {
                    let second = text.index(after: index)
                    let third = second < upperBound ? text.index(after: second) : upperBound
                    if second < upperBound, third < upperBound, text[second] == quote, text[third] == quote {
                        return text.index(after: third)
                    }
                } else {
                    return text.index(after: index)
                }
            }
            if quote == "\"", text[index] == "\\", !isTriple {
                index = text.index(after: index)
                if index < upperBound {
                    index = text.index(after: index)
                    continue
                }
            } else {
                index = text.index(after: index)
            }
        }
        return upperBound
    }

    private func lineEnd(startingAt start: String.Index, in text: String, upperBound: String.Index) -> String.Index {
        var index = start
        while index < upperBound, text[index] != "\n" {
            index = text.index(after: index)
        }
        return index
    }

    private func redactQuotedConfigValues(in value: String) -> String {
        let singleQuoted = replaceMatches(
            in: value,
            pattern: #"'(?:\\.|[^'])*'"#,
            replacement: #"'<redacted-config-value>'"#,
        )
        return replaceMatches(
            in: singleQuoted,
            pattern: #""(?:\\.|[^"])*""#,
            replacement: #""<redacted-config-value>""#,
        )
    }

    private func replaceMatches(in value: String, pattern: String, replacement: String) -> String {
        let regex = try! NSRegularExpression(pattern: pattern)
        return regex.stringByReplacingMatches(
            in: value,
            range: NSRange(location: 0, length: (value as NSString).length),
            withTemplate: replacement,
        )
    }

    private func isSensitiveConfigKey(_ key: String) -> Bool {
        let normalized = normalizedConfigKey(key)
        if normalized.contains("window-title") {
            return !includeWindowTitles
        }
        return [
            "password",
            "secret",
            "token",
            "credential",
            "api-key",
            "apikey",
            "app-id",
            "app-name",
            "bundle-id",
        ].contains { normalized.contains($0) }
    }
}

private struct ZoneSupportBundleError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
