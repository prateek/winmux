import AppKit
import Common
import XCTest
@testable import AppBundle

@MainActor
private final class SummaryReloadValues {
    var running = defaultConfig
    var next: Result<ReloadCandidate, String> = .success(.init(name: "columns"))
    var summaries: [LoadedConfigSummary] = []
}

@MainActor
final class LoadedConfigSummaryTest: XCTestCase {
    func testRichDeskConfigResolvesThreeAndTwoColumnsThroughRealHelper() async throws {
        guard nickelHelperUrl() != nil else { throw XCTSkip("Build the helper") }
        let supervisor = NickelSupervisor()
        let loaded = try await supervisor.load(projectRootUrl.appending(path: ".claude/skills/demo/desk/rich/winmux.ncl")).get()
        defer { supervisor.discard(loaded) }
        let parsed = parseConfig(loaded.settings)
        XCTAssertTrue(parsed.errors.isEmpty, "\(parsed.errors)")
        let summary = LoadedConfigSummary.build(parsed.config, load: .init(), workspaceNames: [])
        XCTAssertEqual(summary.columns.first { $0.workspace == "2" }?.value, "3 Columns · 28 / 44 / 28 %")
        XCTAssertEqual(summary.columns.first { $0.workspace == "3" }?.value, "2 Columns · 67 / 33 %")
        XCTAssertNil(summary.columns[0].count)
    }

    func testReloadSummaryKeepsGoodColumnsOnFailureAndDryRunThenClearsError() async throws {
        let values = SummaryReloadValues()
        var dependencies = ReloadTestDependencies()
        dependencies.load = { _ in values.next }
        dependencies.helper = .init(adopt: { _ in }, dispose: { _ in }, recordFailure: { _ in })
        dependencies.apply = { candidate in
            values.running = defaultConfig
            if candidate.name == "columns" {
                values.running.columns = ColumnsConfig(.object(["count": .int(3)]), workspaces: nil)
            }
        }
        dependencies.report = .init(show: { _ in }, clear: {}, log: { _, _ in })
        dependencies.watch = { _ in }
        dependencies.emit = { _ in }
        dependencies.configPath = { "/config/test.ncl" }
        dependencies.loadStateChanged = { values.summaries.append(.build(values.running, load: $0, workspaceNames: ["1"])) }
        let owner = dependencies.owner()
        _ = await owner.request()
        XCTAssertTrue(values.summaries.last!.columns.allSatisfy { $0.count == 3 })
        let loaded = values.summaries.last!.load.loaded
        values.next = .failure("unknown field")
        _ = await owner.request()
        XCTAssertTrue(values.summaries.last!.columns.allSatisfy { $0.count == 3 })
        XCTAssertEqual(values.summaries.last!.load.loaded, loaded)
        XCTAssertEqual(values.summaries.last!.load.failure?.diagnostic, "unknown field")
        values.next = .success(.init(name: "off"))
        _ = await owner.request(dryRun: true)
        XCTAssertEqual(values.summaries.count, 2)
        _ = await owner.request()
        XCTAssertNil(values.summaries.last!.load.failure)
        XCTAssertTrue(values.summaries.last!.columns.allSatisfy { $0.count == nil })
    }

    func testShippedConfigIncludesAllLensesTriggersAndBindingsWithColumnsOff() {
        let summary = LoadedConfigSummary.build(defaultConfig, load: .init(), workspaceNames: ["10", "2"])
        XCTAssertEqual(summary.lenses.map(\.name), ["app-windows", "floating", "overview", "recent", "search", "windows"])
        for lens in summary.lenses {
            XCTAssertFalse(lens.triggers.isEmpty, lens.name)
            XCTAssertTrue(lens.triggers.contains { $0.mode == "window" }, lens.name)
        }
        XCTAssertTrue(summary.lenses.first { $0.name == "search" }!.triggers.contains { $0.mode == "main" && $0.notation == "alt-slash" })
        XCTAssertTrue(summary.lenses.first { $0.name == "overview" }!.triggers.contains { $0.mode == "main" && $0.notation == "alt-shift-o" })
        XCTAssertEqual(summary.lenses.first { $0.name == "app-windows" }?.filter, "function")
        XCTAssertTrue(summary.lenses.first { $0.name == "app-windows" }!.triggers.contains { $0.command.contains("--presentation list --tile text") })
        XCTAssertTrue(summary.columns.allSatisfy { $0.count == nil && $0.widths.isEmpty })
        for (name, mode) in defaultConfig.modes {
            XCTAssertEqual(summary.bindings.filter { $0.mode == name }.count, mode.bindings.count + mode.tapBindings.count + mode.sequenceBindings.count)
            for binding in mode.bindings.values {
                XCTAssertTrue(summary.bindings.contains { $0.mode == name && $0.notation == binding.descriptionWithKeyNotation && $0.command == binding.commands.prettyDescription })
            }
        }
        XCTAssertEqual(summary.bindings.first?.mode, "main")
    }

    func testColumnsIncludeEveryConfigAndRuntimeWorkspaceWithResolvedHooks() {
        var config = defaultConfig
        config.persistentWorkspaces = ["2"]
        config.workspaceToMonitorForceAssignment = ["10": []]
        config.columns = ColumnsConfig(.object(["count": .string("off"), "place": .string("columns.place")]), workspaces: .object([
            "2": .object(["columns": .object(["count": .int(3), "widths": .array([.double(0.28), .double(0.44), .double(0.28)])])]),
            "3": .object(["columns": .object(["count": .int(2), "widths": .array([.double(2.0 / 3), .double(1.0 / 3)]), "move-boundary": .string("workspace.3.columns.move-boundary")])]),
            "named": .object([:]),
        ]))
        let summary = LoadedConfigSummary.build(config, load: .init(), workspaceNames: ["4"])
        XCTAssertEqual(summary.columns.map(\.workspace), [nil, "2", "3", "4", "10", "named"])
        XCTAssertEqual(summary.columns[1].count, 3)
        XCTAssertEqual(summary.columns[1].widths.map { Int(($0 * 100).rounded()) }, [28, 44, 28])
        XCTAssertEqual(summary.columns[2].count, 2)
        XCTAssertEqual(summary.columns[2].widths.map { Int(($0 * 100).rounded()) }, [67, 33])
        XCTAssertTrue(summary.hooks.contains { $0.name == "move-boundary · 3" && $0.value.contains("function") })
        XCTAssertTrue(summary.hooks.contains { $0.name == "place · Other workspaces" && $0.value.contains("function") })
        XCTAssertTrue(summary.hooks.contains { $0.name == "place · Other workspaces" && $0.value.contains("inactive: Columns Off") })
    }

    func testTapSequenceAndMissingLensTriggersUseParsedCommands() throws {
        var config = defaultConfig
        func commands(_ text: String) throws -> [any Command] {
            guard case .cmd(let command) = parseCommand(text) else { throw NSError(domain: "parse", code: 1) }
            return [command]
        }
        let tap = TapBinding(.leftAlt, try commands("lens missing --presentation list"))
        config.modes["extra"] = Mode(bindings: [:], tapBindings: ["alt": tap], sequenceBindings: [:])
        let parsed = parseConfig(.object(["mode": .object(["main": .object(["binding": .object(["esc-a": .string("lens search")])])])]))
        XCTAssertTrue(parsed.errors.isEmpty, "\(parsed.errors)")
        config.modes["sequence"] = parsed.config.modes["main"]
        let summary = LoadedConfigSummary.build(config, load: .init(), workspaceNames: [])
        XCTAssertTrue(summary.lenses.first { $0.name == "missing" }!.missing)
        XCTAssertEqual(summary.lenses.first { $0.name == "missing" }?.triggers.first?.mode, "extra")
        XCTAssertTrue(summary.lenses.first { $0.name == "search" }!.triggers.contains { $0.mode == "sequence" })
        XCTAssertEqual(summary.bindings.first { $0.mode == "sequence" }?.glyphs, "⎋ → A")
    }

    func testUntriggeredDisabledLensAndEmptyHooksAreExplicit() {
        var config = Config()
        var lens = LensConfig()
        lens.enabled = false
        lens.filter = "recognisable-name"
        config.lenses = ["unbound": lens]
        let summary = LoadedConfigSummary.build(config, load: .init(), workspaceNames: [])
        XCTAssertEqual(summary.lenses[0].filter, "recognisable-name")
        XCTAssertFalse(summary.lenses[0].enabled)
        XCTAssertTrue(summary.lenses[0].triggers.isEmpty)
        XCTAssertTrue(summary.hooks.allSatisfy { $0.value == "None" })
    }

    func testSearchMatchesNotationGlyphsCommandsAndModeIgnoringCase() throws {
        var config = defaultConfig
        guard case .cmd(let command) = parseCommand("lens search") else { return XCTFail("parse") }
        config.modes["custom"] = Mode(bindings: ["cmd-o": HotkeyBinding(.command, .o, [command], descriptionWithKeyNotation: "cmd-o")], tapBindings: [:])
        let summary = LoadedConfigSummary.build(config, load: .init(), workspaceNames: [])
        XCTAssertEqual(summary.search("cmd").map(\.notation), ["cmd-o"])
        XCTAssertEqual(summary.search("⌘").map(\.notation), ["cmd-o"])
        XCTAssertEqual(summary.search("CUSTOM").map(\.notation), ["cmd-o"])
        XCTAssertTrue(summary.search("LeNs").contains { $0.notation == "alt-slash" })
        XCTAssertTrue(summary.search("⌥⇧").contains { $0.notation == "alt-shift-o" })
        XCTAssertTrue(summary.search("nothing matches this").isEmpty)
        XCTAssertEqual(summary.search("").count, summary.bindings.count)
    }
}
