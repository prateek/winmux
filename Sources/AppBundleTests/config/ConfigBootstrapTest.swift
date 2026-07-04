@testable import AppBundle
import Common
import Foundation
import XCTest

@MainActor
final class ConfigBootstrapTest: XCTestCase {
    func testStarterConfigParses() {
        let (parsedConfig, errors) = parseConfig(starterConfigText())
        assertEquals(errors, [])

        let bindings: [(String, String)] = parsedConfig.modes["main"]?.bindings.values.map {
            ($0.descriptionWithKeyNotation, $0.commands.prettyDescription)
        } ?? []
        let bindingMap: [String: String] = Dictionary(uniqueKeysWithValues: bindings)

        XCTAssertEqual(bindingMap["alt-space"], "layout horizontal vertical")
        XCTAssertEqual(bindingMap["ctrl-f"], "open-sidebar")
        XCTAssertEqual(bindingMap["alt-z"], "mode column")
        XCTAssertEqual(bindingMap["alt-h"], "focus left")
        XCTAssertEqual(bindingMap["alt-1"], "focus --tab-index 1")
        XCTAssertEqual(bindingMap["alt-0"], "focus --tab-index 10")
        XCTAssertEqual(bindingMap["alt-tab"], "focus tab-next")
        XCTAssertEqual(bindingMap["alt-shift-tab"], "focus tab-prev")
        XCTAssertEqual(bindingMap["alt-n"], "focus dfs-next")
        XCTAssertEqual(bindingMap["alt-shift-h"], "move left")
        XCTAssertEqual(bindingMap["cmd-shift-h"], "join-with left")
        XCTAssertEqual(bindingMap["ctrl-cmd-shift-h"], "stack-with left")
        XCTAssertEqual(bindingMap["alt-cmd-j"], "swap down")
        XCTAssertEqual(bindingMap["alt-cmd-k"], "swap up")
        XCTAssertEqual(bindingMap["cmd-shift-i"], "balance-sizes")
        XCTAssertEqual(bindingMap["ctrl-1"], "card 1")
        XCTAssertEqual(bindingMap["ctrl-0"], "card 10")
        XCTAssertEqual(bindingMap["ctrl-t"], "card 15")
        XCTAssertEqual(bindingMap["ctrl-h"], "card prev")
        XCTAssertEqual(bindingMap["cmd-ctrl-h"], "card prev")
        XCTAssertEqual(bindingMap["alt-shift-1"], "move-node-to-card 1")
        XCTAssertEqual(bindingMap["ctrl-shift-0"], "move-node-to-card 10")
        XCTAssertEqual(bindingMap["ctrl-shift-h"], "move-node-to-card --focus-follows-window prev")
        XCTAssertEqual(bindingMap["alt-shift-t"], "layout floating tiling")
        XCTAssertEqual(bindingMap["alt-shift-m"], "fullscreen")
        XCTAssertNil(bindingMap["alt-slash"])
        XCTAssertNil(bindingMap["alt-comma"])
        XCTAssertTrue(parsedConfig.windowTabs.enabled)
        XCTAssertEqual(parsedConfig.windowTabs.height, 36)
        XCTAssertTrue(parsedConfig.workspaceSidebar.enabled)
        XCTAssertEqual(parsedConfig.workspaceSidebar.width, 240)
        XCTAssertTrue(parsedConfig.autoReloadConfig)
        if case .constant(let horizontalGap) = parsedConfig.gaps.inner.horizontal {
            XCTAssertEqual(horizontalGap, 8)
        } else {
            XCTFail("Expected constant horizontal gap")
        }
        if case .constant(let verticalGap) = parsedConfig.gaps.inner.vertical {
            XCTAssertEqual(verticalGap, 8)
        } else {
            XCTFail("Expected constant vertical gap")
        }
        if case .constant(let outerLeftGap) = parsedConfig.gaps.outer.left {
            XCTAssertEqual(outerLeftGap, 8)
        } else {
            XCTFail("Expected constant outer left gap")
        }
        XCTAssertEqual(parsedConfig.configVersion, 2)

        let columnBindings: [(String, String)] = parsedConfig.modes["column"]?.bindings.values.map {
            ($0.descriptionWithKeyNotation, $0.commands.prettyDescription)
        } ?? []
        let columnBindingMap: [String: String] = Dictionary(uniqueKeysWithValues: columnBindings)
        XCTAssertEqual(columnBindingMap["esc"], "mode main")
        XCTAssertEqual(columnBindingMap["h"], "focus-column prev; mode main")
        XCTAssertEqual(columnBindingMap["l"], "focus-column next; mode main")
        XCTAssertEqual(columnBindingMap["shift-h"], "move-node-to-column --focus-follows-window prev; mode main")
        XCTAssertEqual(columnBindingMap["shift-l"], "move-node-to-column --focus-follows-window next; mode main")
        XCTAssertEqual(columnBindingMap["minus"], "column resize -10%; mode main")
        XCTAssertEqual(columnBindingMap["equal"], "column resize +10%; mode main")
        XCTAssertEqual(columnBindingMap["0"], "balance-columns; mode main")
        XCTAssertEqual(columnBindingMap["t"], "column toggle; mode main")
        XCTAssertEqual(columnBindingMap["space"], "layout floating tiling; mode main")
        XCTAssertEqual(columnBindingMap["s"], "cycle-column-snap-policy freeform snap-to-column; mode main")
        XCTAssertNil(columnBindingMap["tab"])
        XCTAssertNil(columnBindingMap["a"])
        XCTAssertNil(columnBindingMap["y"])
        XCTAssertNil(columnBindingMap["c"])
        XCTAssertEqual(parsedConfig.zones.count, 0)
        XCTAssertEqual(parsedConfig.zoneLayouts.count, 0)
        XCTAssertEqual(parsedConfig.zoneScenes.count, 0)
        XCTAssertEqual(parsedConfig.zoneAvailabilitySets.count, 0)
    }

    func testDefaultConfigUrlResolvesFromProjectWorkingDirectory() {
        let projectRoot = URL(filePath: FileManager.default.currentDirectoryPath)
        let resolved = getDefaultConfigUrlFromProject(startingAt: projectRoot)

        XCTAssertEqual(resolved.lastPathComponent, "default-config.toml")
        XCTAssertTrue(resolved.path.hasSuffix("resources/default-config.toml"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: resolved.path))
    }

    func testDefaultConfigUrlResolvesNextToStagedExecutable() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appending(path: "WinMuxTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let binDir = tempDir.appending(path: "bin", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let executable = binDir.appending(path: "WinMuxApp")
        let config = binDir.appending(path: "default-config.toml")
        try Data().write(to: executable)
        try starterConfigText().write(to: config, atomically: true, encoding: .utf8)

        let resolved = getDefaultConfigUrlNextToExecutable(executablePath: executable.path)

        XCTAssertEqual(resolved?.path, config.path)
    }

    func testStarterUltrawideTemplateUncommentsIntoConfiguredZones() {
        let starter = starterConfigText()
        XCTAssertTrue(starter.contains("# BEGIN WINMUX ULTRAWIDE ZONES TEMPLATE"))
        XCTAssertTrue(starter.contains("# END WINMUX ULTRAWIDE ZONES TEMPLATE"))

        let (parsedConfig, errors) = parseConfig(uncommentUltrawideTemplate(in: starter))

        assertEquals(errors, [])
        guard errors.isEmpty else { return }
        XCTAssertEqual(parsedConfig.zoneStyles.map(\.id), ["urgent", "calm"])
        XCTAssertEqual(parsedConfig.zoneLayouts.map(\.id), ["balanced", "focus"])
        XCTAssertEqual(parsedConfig.zoneLayouts.map { $0.columns.map(\.id) }, [
            ["left", "main", "right"],
            ["left", "main", "right"],
        ])
        XCTAssertEqual(parsedConfig.zoneLayouts.map { $0.columns.map(\.width) }, [
            [0.25, 0.50, 0.25],
            [0.18, 0.64, 0.18],
        ])
        XCTAssertEqual(parsedConfig.zones.count, 1)
        XCTAssertEqual(parsedConfig.zones[0].layoutPreset, "balanced")
        XCTAssertEqual(parsedConfig.zoneScenes.map(\.id), ["triage", "deep-work"])
        XCTAssertEqual(parsedConfig.zoneScenes.map(\.layoutPreset), ["balanced", "focus"])
        XCTAssertEqual(parsedConfig.zoneScenes[0].workspaces.map(\.zone), ["left", "main", "right"])
        XCTAssertEqual(parsedConfig.zoneScenes[1].workspaces.compactMap { $0.workspace?.raw }, [
            "FocusQueue",
            "FocusBuild",
            "FocusNotes",
        ])
        XCTAssertEqual(parsedConfig.zoneAvailabilitySets, [
            ZoneAvailabilitySetConfig(id: "focus-only", enabledZones: ["main"]),
            ZoneAvailabilitySetConfig(id: "communications", enabledZones: ["main", "right"]),
            ZoneAvailabilitySetConfig(id: "full-dashboard", enabledZones: ["left", "main", "right"]),
        ])
        XCTAssertEqual(parsedConfig.zoneAffinities.count, 1)
        XCTAssertEqual(parsedConfig.zoneAffinities[0].zone, ZoneSelector("Comms"))
        XCTAssertNotNil(parsedConfig.zoneAffinities[0].matcher.windowTitleRegexSubstring)
        XCTAssertFalse(parsedConfig.zoneAffinities[0].failIfNoop)
        XCTAssertEqual(parsedConfig.mouse.zoneSnap.policy, .freeform)
        XCTAssertEqual(parsedConfig.mouse.zoneSnap.modifier, .option)
        XCTAssertEqual(parsedConfig.mouse.zoneSnap.gesture, .drag)
        XCTAssertEqual(parsedConfig.mouse.zoneSnap.target, .zone)
    }

    func testEnsureBootstrapConfigCopiesLegacyConfig() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appending(path: "WinMuxTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let legacyUrl = tempDir.appending(path: "legacy.toml")
        let targetUrl = tempDir.appending(path: "winmux.toml")
        let legacyText = """
            config-version = 2

            [mode.main.binding]
            alt-h = 'focus left'
            """
        try legacyText.write(to: legacyUrl, atomically: true, encoding: .utf8)

        let didMaterialize = try materializeBootstrapConfigIfNeeded(
            targetUrl: targetUrl,
            existingLegacyUrls: [legacyUrl],
        )

        XCTAssertTrue(didMaterialize)
        let copiedText = try String(contentsOf: targetUrl, encoding: .utf8)
        XCTAssertEqual(copiedText, legacyText)
    }

    func testEnsureBootstrapConfigPrefersFirstLegacyConfigWithoutFailing() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appending(path: "WinMuxTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let preferredLegacyUrl = tempDir.appending(path: "preferred.toml")
        let secondaryLegacyUrl = tempDir.appending(path: "secondary.toml")
        let targetUrl = tempDir.appending(path: "winmux.toml")
        let preferredText = """
            config-version = 2

            [mode.main.binding]
            alt-h = 'focus left'
            """
        let secondaryText = """
            config-version = 2

            [mode.main.binding]
            alt-l = 'focus right'
            """
        try preferredText.write(to: preferredLegacyUrl, atomically: true, encoding: .utf8)
        try secondaryText.write(to: secondaryLegacyUrl, atomically: true, encoding: .utf8)

        let didMaterialize = try materializeBootstrapConfigIfNeeded(
            targetUrl: targetUrl,
            existingLegacyUrls: [preferredLegacyUrl, secondaryLegacyUrl],
        )

        XCTAssertTrue(didMaterialize)
        let copiedText = try String(contentsOf: targetUrl, encoding: .utf8)
        XCTAssertEqual(copiedText, preferredText)
    }

    func testEnsureBootstrapConfigImportsAerospaceConfigWhenNoWinMuxConfigExists() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appending(path: "WinMuxTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let aerospaceUrl = tempDir.appending(path: "aerospace.toml")
        let targetUrl = tempDir.appending(path: "winmux.toml")
        let aerospaceText = """
            start-at-login = false
            default-root-container-layout = 'accordion'
            accordion-padding = 22
            window-tabs.enabled = false
            exec-on-workspace-change = ['/bin/sh', '-c', 'echo $AEROSPACE_FOCUSED_WORKSPACE $AEROSPACE_PREV_WORKSPACE $AEROSPACE_WORKSPACE']

            [workspace-sidebar]
            enabled = false

            [mode.main.binding]
            alt-h = 'layout accordion tiles'
            alt-j = 'layout h_accordion v_accordion'
            alt-l = 'exec-and-forget echo $AEROSPACE_WINDOW_ID'
            """
        try aerospaceText.write(to: aerospaceUrl, atomically: true, encoding: .utf8)

        let didMaterialize = try materializeBootstrapConfigIfNeeded(
            targetUrl: targetUrl,
            existingLegacyUrls: [],
            aerospaceImportUrl: aerospaceUrl,
        )

        XCTAssertTrue(didMaterialize)
        let migratedText = try String(contentsOf: targetUrl, encoding: .utf8)
        XCTAssertTrue(migratedText.contains("# Migrated from AeroSpace config by WinMux."))
        XCTAssertTrue(migratedText.contains("default-root-container-layout = 'tiles'"))
        XCTAssertTrue(migratedText.contains("tab-group-padding = 30"))
        XCTAssertTrue(migratedText.contains("window-tabs.enabled = true"))
        XCTAssertTrue(migratedText.contains("[workspace-sidebar]"))
        XCTAssertTrue(migratedText.contains("enabled = true"))
        XCTAssertTrue(migratedText.contains("layout tab-group tiles"))
        XCTAssertTrue(migratedText.contains("layout h_tab_group v_tab_group"))
        XCTAssertTrue(migratedText.contains("$WINMUX_WINDOW_ID"))
        XCTAssertFalse(migratedText.contains("exec-on-workspace-change"))
        XCTAssertFalse(migratedText.contains("accordion"))
        XCTAssertFalse(migratedText.contains("AEROSPACE_"))

        let (parsedConfig, errors) = parseConfig(migratedText)
        XCTAssertEqual(errors.descriptions, [])
        XCTAssertTrue(parsedConfig.workspaceSidebar.enabled)
        XCTAssertTrue(parsedConfig.windowTabs.enabled)
        XCTAssertEqual(parsedConfig.configVersion, 2)
        XCTAssertEqual(parsedConfig.modes[mainModeId]?.bindings.values.map(\.descriptionWithKeyNotation).sorted(), ["alt-h", "alt-j", "alt-l"])
    }
}

private func uncommentUltrawideTemplate(in text: String) -> String {
    var insideTemplate = false
    return text.components(separatedBy: "\n").map { line in
        if line.contains("# BEGIN WINMUX ULTRAWIDE ZONES TEMPLATE") {
            insideTemplate = true
            return line
        }
        if line.contains("# END WINMUX ULTRAWIDE ZONES TEMPLATE") {
            insideTemplate = false
            return line
        }
        guard insideTemplate else { return line }

        if line.trimmingCharacters(in: .whitespaces) == "#" {
            return ""
        }
        guard let hashIndex = line.firstIndex(of: "#") else { return line }
        let prefix = line[..<hashIndex]
        guard prefix.allSatisfy({ $0 == " " || $0 == "\t" }) else { return line }
        var suffix = line[line.index(after: hashIndex)...]
        if suffix.first == " " {
            suffix = suffix.dropFirst()
        }
        return "\(prefix)\(suffix)"
    }.joined(separator: "\n")
}
