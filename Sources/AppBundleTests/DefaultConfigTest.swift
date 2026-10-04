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

    func testFiveLensesTriggersAndLeaderEscape() async throws {
        let defaults = defaultConfig
        XCTAssertEqual(Set(defaults.lenses.keys), ["recent", "app-windows", "overview", "floating", "search"])
        XCTAssertEqual(Set(defaults.modes.keys), ["main", "lens"])
        XCTAssertNil(defaults.columns.resolved(workspace: "Demo"))
        let expected = ["cmd-tab": "lens recent", "cmd-shift-tab": "lens recent", "cmd-backtick": "lens app-windows",
                        "alt-slash": "lens search", "alt-semicolon": "mode lens"]
        for (chord, raw) in expected {
            let binding = try XCTUnwrap(defaults.modes["main"]?.bindings[chord])
            XCTAssertTrue(binding.commands.singleOrNil()?.equals(parseCommand(raw).cmdOrDie) == true, chord)
        }
        let leader = try XCTUnwrap(defaults.modes["lens"])
        XCTAssertEqual(Set(leader.bindings.keys), ["o", "f", "s", "r", "esc"])
        // Mode activation in these tests registers no desktop bindings.
        config.modes = ["main": .zero, "lens": .zero]
        for (key, name) in ["o": "overview", "f": "floating", "s": "search", "r": "recent"] {
            let commands = try XCTUnwrap(leader.bindings[key]?.commands)
            XCTAssertEqual(commands.count, 2)
            XCTAssertTrue(commands[1].equals(parseCommand("lens \(name)" + (key == "r" ? " --presentation list" : "")).cmdOrDie))
            XCTAssertTrue(commands[0].equals(parseCommand("mode main").cmdOrDie))
            var disabled = LensConfig(); disabled.enabled = false
            config.lenses = [name: disabled]
            try await activateMode("lens")
            let failed = try await commands.runCmdSeq(.defaultEnv, .emptyStdin)
            XCTAssertEqual(failed.exitCode, 2)
            XCTAssertEqual(activeMode, "main", "a rejected Lens must still leave the leader")
            XCTAssertFalse(SwitcherPalettePanel.shared.isPaletteActive)
        }
        try await activateMode("lens")
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
        XCTAssertEqual(main.bindings["alt-shift-h"]?.descriptionWithKeyNotation, "shift-alt-h")
        XCTAssertTrue(main.bindings["alt-shift-h"]?.commands.singleOrNil()?.equals(parseCommand("move left").cmdOrDie) == true)
        XCTAssertEqual(main.bindings["cmd-tab"]?.descriptionWithKeyNotation, "cmd-mytab")
        XCTAssertTrue(main.bindings["cmd-tab"]?.commands.singleOrNil()?.equals(parseCommand("focus right").cmdOrDie) == true)
        XCTAssertEqual(Set(parsed.config.modes.keys), ["main", "lens", "custom"])
        XCTAssertEqual(Set(parsed.config.lenses.keys), Set(defaultConfig.lenses.keys))
    }

    func testListsPrintValidJSONAndRuntimeFailuresExitOne() async throws {
        config.lenses = defaultConfig.lenses
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
