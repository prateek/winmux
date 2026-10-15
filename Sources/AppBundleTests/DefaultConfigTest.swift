@testable import AppBundle
import Common
import XCTest

@MainActor
final class DefaultConfigTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testNoConfigLoadsExactlyTheBuiltInStaticDefaultsWithoutAnError() async throws {
        guard nickelHelperUrl() != nil else { throw XCTSkip("Build the helper") }
        let supervisor = NickelSupervisor()
        let loaded = try await supervisor.load(nil).get()
        defer { supervisor.discard(loaded) }
        let staticSettings = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: defaultConfigUrl))
        XCTAssertEqual(loaded.settings, staticSettings)
        let parsed = parseConfig(loaded.settings)
        XCTAssertTrue(parsed.errors.isEmpty)
        supervisor.adopt(loaded)
        XCTAssertNil(supervisor.status.lastError)
        XCTAssertEqual(parsed.config.lenses, defaultConfig.lenses)
        XCTAssertEqual(parsed.config.modes, defaultConfig.modes)
    }

    func testShippedRecentStripUsesPicturesAtOneHeightAndConversionKeepsPictures() throws {
        for name in ["recent"] {
            var settings = try XCTUnwrap(defaultConfig.lenses[name])
            XCTAssertEqual(settings.presentation, "strip")
            XCTAssertEqual(settings.tile, "picture")
            XCTAssertEqual(settings.grid.tileSize, "same-height")
            let session = LensSession(name: name, settings: settings, items: [], search: "")
            XCTAssertEqual(session.tileKind, .picture)
            session.enterSearch()
            XCTAssertEqual(session.settings.presentation, "list")
            XCTAssertEqual(session.tileKind, .picture)
            XCTAssertEqual(session.listLayout.rowHeight, 74 * session.tileMetrics.scale)
            let cliConversion = LensSession(name: name, settings: settings, items: [], search: "")
            cliConversion.changePresentation("list")
            XCTAssertEqual(cliConversion.tileKind, .picture)
            settings.presentation = "list"; settings.tile = "text"
            let textList = LensSession(name: name, settings: settings, items: [], search: "")
            XCTAssertEqual(textList.tileKind, .text)
            XCTAssertEqual(textList.listLayout.rowHeight, 46 * textList.tileMetrics.scale)
        }
        for name in ["overview", "search", "floating", "app-windows", "windows"] {
            let settings = try XCTUnwrap(defaultConfig.lenses[name])
            XCTAssertNil(settings.tile)
            XCTAssertEqual(settings.grid.tileSize, "real")
        }
    }

    func testShippedGridsResolveContractDefaultsAndReleasePolicy() throws {
        for name in ["windows", "app-windows", "floating"] {
            let settings = try XCTUnwrap(defaultConfig.lenses[name])
            XCTAssertEqual(settings.presentation, "grid", name)
            XCTAssertEqual(settings.sort, ["mru"], name)
            XCTAssertEqual(settings.sections, "workspace", name)
            XCTAssertEqual(settings.grid.sectionsArrangement, "flow", name)
            XCTAssertEqual(settings.grid.tileSize, "real", name)
            let session = LensSession(name: name, settings: settings, items: [], search: "")
            XCTAssertEqual(session.tileKind, .card, name)
            XCTAssertEqual(settings.resolvedOnRelease, name == "app-windows" ? "commit" : "stay", name)
            XCTAssertEqual(settings.commitsOnRelease(for: StripGesture(keyCode: 50, invoking: .command)), name == "app-windows", name)
            XCTAssertFalse(settings.commitsOnRelease(for: nil), name)
            XCTAssertFalse(settings.commitsOnRelease(for: StripGesture(keyCode: 50, invoking: [])), name)
        }
    }

    func testDefaultMainBindingsAreExactlyTheShortList() {
        let expected: Set<String> = Set(
            ["alt-h", "alt-j", "alt-k", "alt-l", "alt-shift-h", "alt-shift-j", "alt-shift-k", "alt-shift-l",
             "alt-shift-t", "alt-shift-m", "alt-slash", "alt-semicolon", "alt-shift-o"]
            + (1...9).map { "ctrl-\($0)" }
            + (1...9).map { "alt-shift-\($0)" }
            + (0...9).map { "alt-\($0)" }
        )
        XCTAssertEqual(Set(defaultConfig.modes["main"]!.bindings.keys), expected)
    }

    func testSixLensesTriggersAndLeaderEscape() async throws {
        let defaults = defaultConfig
        XCTAssertEqual(Set(defaults.lenses.keys), ["recent", "app-windows", "overview", "floating", "search", "windows"])
        XCTAssertEqual(Set(defaults.modes.keys), ["main", "window"])
        XCTAssertNil(defaults.columns.resolved(workspace: "Demo"))
        let expected = ["alt-shift-o": "lens overview", "alt-slash": "lens search", "alt-semicolon": "mode window"]
        for (chord, raw) in expected {
            let binding = try XCTUnwrap(defaults.modes["main"]?.bindings[chord])
            XCTAssertTrue(binding.commands.singleOrNil()?.equals(parseCommand(raw).cmdOrDie) == true, chord)
        }
        let leader = try XCTUnwrap(defaults.modes["window"])
        let windowKeys: Set<String> = Set(["h", "j", "k", "l", "shift-h", "shift-j", "shift-k", "shift-l",
            "ctrl-h", "ctrl-j", "ctrl-k", "ctrl-l", "n", "p", "t", "m", "rightSquareBracket", "leftSquareBracket",
            "o", "f", "s", "r", "a", "w", "esc", "alt-semicolon"] + (1...9).map { "\($0)" } + (1...9).map { "shift-\($0)" })
        XCTAssertEqual(Set(leader.bindings.keys), windowKeys)
        // Mode activation in these tests registers no desktop bindings.
        config.modes = ["main": .zero, "window": .zero]
        for (key, name) in ["w": "windows", "o": "overview", "f": "floating", "s": "search", "r": "recent", "a": "app-windows"] {
            let commands = try XCTUnwrap(leader.bindings[key]?.commands)
            XCTAssertEqual(commands.count, 2)
            XCTAssertTrue(commands[1].equals(parseCommand("lens \(name)" + (["r", "a"].contains(key) ? " --presentation list --tile text" : "")).cmdOrDie))
            XCTAssertTrue(commands[0].equals(parseCommand("mode main").cmdOrDie))
            var disabled = LensConfig(); disabled.enabled = false
            config.lenses = [name: disabled]
            try await activateMode("window")
            let failed = try await commands.runCmdSeq(.defaultEnv, .emptyStdin)
            XCTAssertEqual(failed.exitCode, 2)
            XCTAssertEqual(activeMode, "main", "a rejected Lens must still leave the leader")
            XCTAssertFalse(SwitcherPalettePanel.shared.isPaletteActive)
        }
        try await activateMode("window")
        let escaped = try await leader.bindings["esc"]!.commands.runCmdSeq(.defaultEnv, .emptyStdin)
        XCTAssertEqual(escaped.exitCode, 0)
        XCTAssertEqual(activeMode, "main")
        XCTAssertFalse(SwitcherPalettePanel.shared.isPaletteActive)
    }

    func testLensCommandKeepsUsersStickyModeEvenWhenNamedLens() async throws {
        config.modes = ["main": .zero, "lens": .zero, "custom": .zero]
        config.lenses = ["search": LensConfig()]
        defer {
            SwitcherPalettePanel.shared.dismiss()
            activeMode = mainModeId
        }
        for mode in ["lens", "custom"] {
            try await activateMode(mode)
            let result = try await parseCommand("lens search").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(result.exitCode, 0)
            XCTAssertEqual(activeMode, mode)
            SwitcherPalettePanel.shared.dismiss()
        }
    }

    func testEarlierNickelConfigVersionLoadsThroughHelperAndSwift() async throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appending(path: "winmux.ncl")
        try "((import \"winmux/defaults.ncl\") & { config-version = 2 }) | (import \"winmux/winmux.ncl\").Config".write(to: file, atomically: true, encoding: .utf8)
        let supervisor = NickelSupervisor()
        let loaded = try await supervisor.load(file).get()
        defer { supervisor.discard(loaded) }
        XCTAssertTrue(parseConfig(loaded.settings).errors.isEmpty)
    }

    func testConvertedModesKeepTomlMeaningAndLoadThroughSwiftParser() async throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appending(path: "legacy.toml")
        try """
        config-version = 2
        [key-mapping.key-notation-to-key-code]
        mytab = 'tab'
        [mode.main.binding]
        shift-alt-h = 'move left'
        cmd-mytab = 'focus right'
        [mode.custom.binding]
        esc = 'mode main'
        """.write(to: file, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = try XCTUnwrap(nickelHelperUrl())
        process.arguments = ["convert", file.path]
        let pipe = Pipe(); process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        let converted = dir.appending(path: "converted.ncl")
        try data.write(to: converted)
        let supervisor = NickelSupervisor()
        let loaded = try await supervisor.load(converted).get()
        defer { supervisor.discard(loaded) }
        let parsed = parseConfig(loaded.settings)
        XCTAssertTrue(parsed.errors.isEmpty, parsed.errors.descriptions.joined(separator: "\n"))
        let main = try XCTUnwrap(parsed.config.modes["main"])
        XCTAssertNil(main.bindings["alt-tab"])
        XCTAssertNil(main.bindings["cmd-shift-tab"])
        XCTAssertNil(main.bindings["cmd-backtick"])
        XCTAssertEqual(main.bindings["alt-shift-h"]?.descriptionWithKeyNotation, "shift-alt-h")
        XCTAssertTrue(main.bindings["alt-shift-h"]?.commands.singleOrNil()?.equals(parseCommand("move left").cmdOrDie) == true)
        XCTAssertEqual(main.bindings["cmd-tab"]?.descriptionWithKeyNotation, "cmd-mytab")
        XCTAssertTrue(main.bindings["cmd-tab"]?.commands.singleOrNil()?.equals(parseCommand("focus right").cmdOrDie) == true)
        XCTAssertEqual(Set(parsed.config.modes.keys), ["main", "window", "custom"])
        XCTAssertEqual(Set(parsed.config.lenses.keys), Set(defaultConfig.lenses.keys))
    }

    func testListsPrintValidJSONAndRuntimeFailuresExitOne() async throws {
        config.lenses = defaultConfig.lenses
        let names: Set<String> = ["app-windows", "floating", "overview", "recent", "search", "windows"]
        let plain = try await parseCommand("list-lenses").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(plain.exitCode, 0)
        XCTAssertEqual(Set(plain.stdout.map { String($0.prefix { $0 != " " }) }), names)
        let json = try await parseCommand("list-lenses --json").cmdOrDie.run(.defaultEnv, .emptyStdin)
        let lenses = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.stdout.joined().utf8)) as? [String: Any])
        XCTAssertEqual(Set(lenses.keys), names)
        for raw in ["list-lenses --json", "list-columns --json"] {
            let result = try await parseCommand(raw).cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(result.exitCode, 0)
            _ = try JSONSerialization.jsonObject(with: Data(result.stdout.joined().utf8))
        }
        for raw in ["focus-column 1", "move-node-to-column 1", "column-width next", "compact", "summon", "place --dry-run --window-id 999999"] {
            let result = try await parseCommand(raw).cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(result.exitCode, 1, raw)
        }
    }

    func testForkCliUsageAndMissingServerCodes() throws {
        let executable = projectRoot.appending(path: ".build/debug/winmux")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { throw XCTSkip("Run swift build") }
        for args in [["lens"], ["list-lenses", "--bad"], ["summon", "--window-id", "bad"],
                     ["focus-column", "0"], ["move-node-to-column", "0"], ["column-width", "1"],
                     ["compact", "extra"], ["list-columns", "--bad"], ["column-count", "0"], ["place"],
                     ["config", "check", "--bad"], ["config", "convert", "--bad"], ["config", "schema", "--bad"]] {
            XCTAssertEqual(try cli(executable, args), 2, args.joined(separator: " "))
        }
        guard try cli(executable, ["list-modes", "--current"]) == 1 else { throw XCTSkip("Missing-server check requires no live debug server") }
        for args in [["lens", "search"], ["list-lenses", "--json"], ["summon"], ["focus-column", "1"],
                     ["move-node-to-column", "1"], ["column-width", "next"], ["compact"], ["list-columns", "--json"],
                     ["column-count", "3"], ["place", "--dry-run", "--window-id", "42"], ["config", "status"]] {
            XCTAssertEqual(try cli(executable, args), 1, args.joined(separator: " "))
        }
    }

    func testLocalConfigCommandsExitCodesWithoutAHelperOrForBadInput() throws {
        let executable = projectRoot.appending(path: ".build/debug/winmux")
        guard let helper = nickelHelperUrl() else { throw XCTSkip("Build the helper") }
        for args in [["config", "check"], ["config", "schema", "--json"], ["config", "convert", projectRoot.appending(path: "nickel-helper/tests/fixtures/upstream-default-config.toml").path]] {
            XCTAssertEqual(try cli(executable, args, helper: helper.path), 0)
            XCTAssertEqual(try cli(executable, args, helper: "/missing/helper"), 1)
        }
        XCTAssertEqual(try cli(executable, ["config", "check", projectRoot.appending(path: "nickel-helper/tests/fixtures/unknown-key.ncl").path], helper: helper.path), 2)
        XCTAssertEqual(try cli(executable, ["config", "convert", "/missing/config.toml"], helper: helper.path), 1)
    }

    private func cli(_ executable: URL, _ args: [String], helper: String? = nil) throws -> Int32 {
        let process = Process(); process.executableURL = executable; process.arguments = args
        process.environment = ProcessInfo.processInfo.environment
        process.environment?["XDG_CONFIG_HOME"] = "/tmp/winmux-test-no-config-\(UUID().uuidString)"
        if let helper { process.environment?["WINMUX_NICKEL_HELPER"] = helper }
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        return process.terminationStatus
    }
}
