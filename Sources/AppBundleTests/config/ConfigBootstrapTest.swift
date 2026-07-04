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

        // Cards page the deck (config-version-3 keymap).
        XCTAssertEqual(bindingMap["alt-n"], "card next")
        XCTAssertEqual(bindingMap["alt-p"], "card prev")
        XCTAssertEqual(bindingMap["alt-tab"], "card back-and-forth")
        XCTAssertEqual(bindingMap["alt-1"], "card 1")
        XCTAssertEqual(bindingMap["alt-0"], "card 10")
        // Scenes on the ctrl layer.
        XCTAssertEqual(bindingMap["alt-ctrl-1"], "scene desk")
        XCTAssertEqual(bindingMap["alt-ctrl-2"], "scene focus")
        XCTAssertEqual(bindingMap["alt-ctrl-tab"], "scene next")
        // Window focus and move inside the focused card.
        XCTAssertEqual(bindingMap["alt-h"], "focus left")
        XCTAssertEqual(bindingMap["alt-shift-h"], "move left")
        XCTAssertEqual(bindingMap["alt-shift-1"], "move-node-to-card 1")
        // Adjacent-column moves, layout, Exposé, sidebar, modes.
        XCTAssertEqual(bindingMap["ctrl-shift-h"], "move-node-to-column left")
        XCTAssertEqual(bindingMap["ctrl-shift-l"], "move-node-to-column right")
        XCTAssertEqual(bindingMap["alt-space"], "layout tiles tab-group")
        XCTAssertEqual(bindingMap["alt-shift-space"], "layout floating tiling")
        XCTAssertEqual(bindingMap["alt-slash"], "layout horizontal vertical")
        XCTAssertEqual(bindingMap["alt-shift-m"], "fullscreen")
        XCTAssertEqual(bindingMap["cmd-shift-i"], "balance-sizes")
        XCTAssertEqual(bindingMap["ctrl-up"], "expose display")
        XCTAssertEqual(bindingMap["ctrl-down"], "expose card")
        XCTAssertEqual(bindingMap["ctrl-f"], "open-sidebar")
        XCTAssertEqual(bindingMap["alt-z"], "mode column")
        // The retired v2 bindings are gone.
        XCTAssertNil(bindingMap["alt-shift-tab"])
        XCTAssertNil(bindingMap["ctrl-1"])
        XCTAssertNil(bindingMap["cmd-shift-h"])
        XCTAssertNil(bindingMap["alt-cmd-j"])
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
        XCTAssertEqual(parsedConfig.configVersion, 3)

        let columnBindings: [(String, String)] = parsedConfig.modes["column"]?.bindings.values.map {
            ($0.descriptionWithKeyNotation, $0.commands.prettyDescription)
        } ?? []
        let columnBindingMap: [String: String] = Dictionary(uniqueKeysWithValues: columnBindings)
        XCTAssertEqual(columnBindingMap["esc"], "mode main")
        XCTAssertEqual(columnBindingMap["h"], "focus-column prev; mode main")
        XCTAssertEqual(columnBindingMap["l"], "focus-column next; mode main")
        XCTAssertEqual(columnBindingMap["shift-h"], "card move left; mode main")
        XCTAssertEqual(columnBindingMap["shift-l"], "card move right; mode main")
        XCTAssertEqual(columnBindingMap["minus"], "column resize -10%; mode main")
        XCTAssertEqual(columnBindingMap["equal"], "column resize +10%; mode main")
        XCTAssertEqual(columnBindingMap["0"], "balance-columns; mode main")
        XCTAssertEqual(columnBindingMap["t"], "column toggle; mode main")
        XCTAssertEqual(columnBindingMap["s"], "cycle-column-snap-policy float-unless-snap freeform; mode main")
        XCTAssertNil(columnBindingMap["space"])
        XCTAssertNil(columnBindingMap["tab"])
        XCTAssertNil(columnBindingMap["a"])
        // No scenes are configured by default: the laptop gets one implicit column.
        XCTAssertTrue(parsedConfig.scenes.isEmpty)
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

    func testStarterScenesExampleUncommentsIntoConfiguredScenes() {
        let starter = starterConfigText()
        XCTAssertTrue(starter.contains("# BEGIN WINMUX ULTRAWIDE SCENES EXAMPLE"))
        XCTAssertTrue(starter.contains("# END WINMUX ULTRAWIDE SCENES EXAMPLE"))

        // The commented default parses into no scenes: the implicit one-column laptop case.
        let (defaultConfig, defaultErrors) = parseConfig(starter)
        assertEquals(defaultErrors, [])
        XCTAssertTrue(defaultConfig.scenes.isEmpty)
        XCTAssertTrue(defaultConfig.rules.isEmpty)

        // Uncommenting the example splits display 1 into three scenes and adds two rules.
        let (parsedConfig, errors) = parseConfig(uncommentScenesExample(in: starter))
        assertEquals(errors, [])
        guard errors.isEmpty else { return }

        XCTAssertEqual(parsedConfig.scenes.map(\.id), ["desk", "focus", "triage"])
        XCTAssertEqual(parsedConfig.scenes.map(\.defaultColumn), ["main", nil, "comms"])

        // Each scene folds into a backing zone layout keyed by its id.
        let layoutsById = Dictionary(uniqueKeysWithValues: parsedConfig.zoneLayouts.map { ($0.id, $0) })
        XCTAssertEqual(layoutsById[sceneBackingLayoutId("desk")]?.columns.map(\.id), ["ref", "main", "comms"])
        XCTAssertEqual(layoutsById[sceneBackingLayoutId("focus")]?.columns.map(\.id), ["main"])
        XCTAssertEqual(layoutsById[sceneBackingLayoutId("triage")]?.columns.map(\.id), ["comms", "main"])
        XCTAssertEqual(layoutsById[sceneBackingLayoutId("desk")]?.columns.map(\.color), ["#3EA2FF", nil, "#D3455B"])

        XCTAssertEqual(parsedConfig.rules.map(\.card), ["Comms", "Comms"])
        XCTAssertEqual(parsedConfig.rules.first?.matcher.appId, "com.tinyspeck.slackmacgap")
        XCTAssertNotNil(parsedConfig.rules.last?.matcher.windowTitleRegexSubstring)
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
        XCTAssertTrue(migratedText.contains("[window-tabs]"))
        XCTAssertTrue(migratedText.contains("[sidebar]"))
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
        XCTAssertEqual(parsedConfig.configVersion, 3)
        XCTAssertEqual(parsedConfig.modes[mainModeId]?.bindings.values.map(\.descriptionWithKeyNotation).sorted(), ["alt-h", "alt-j", "alt-l"])
    }
}

private func uncommentScenesExample(in text: String) -> String {
    var insideTemplate = false
    return text.components(separatedBy: "\n").map { line in
        if line.contains("# BEGIN WINMUX ULTRAWIDE SCENES EXAMPLE") {
            insideTemplate = true
            return line
        }
        if line.contains("# END WINMUX ULTRAWIDE SCENES EXAMPLE") {
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
