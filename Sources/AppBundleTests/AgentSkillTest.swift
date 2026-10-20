@testable import AppBundle
import Common
import XCTest

@MainActor
final class AgentSkillTest: XCTestCase {
    func testOfflineCheckNamesInvalidBlockAndMigrationReplacement() throws {
        guard let helper = nickelHelperUrl() else { throw XCTSkip("Build the helper") }
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "winmux.ncl")
        for (fields, expected) in [
            (#"keymap.problem = W.when "unknown == x" { h = "focus left" }"#, "problem"),
            (#"keymap.problem = W.when "mode = main" { h = "focus left" }"#, "problem"),
            (#"keymap.problem = W.when "profile == default" { bogus-key = "focus left" }"#, "problem"),
            (#"keymap.a = W.when "mode == main" { h = "focus left" }, keymap.b = W.when "app == editor" { h = "focus right" }"#, "conflicting"),
            (#"lenses.demo.keys.enter = "focus""#, "mode bindings"),
            (#"lenses.demo.starts-in = 'search"#, "unbound"),
            (#"lenses.demo.on-release = 'commit"#, "mode on-release"),
            (#"lenses.demo.popups = ['app-popup]"#, "record of booleans"),
            (#"lenses.step = {}"#, "reserved Lens verb"),
            (#"mode.demo.on-enter = "unknown-command""#, "unknown-command"),
        ] {
            try "let W = import \"winmux/winmux.ncl\" in { \(fields) } | W.Config".write(to: file, atomically: true, encoding: .utf8)
            let result = try cli(["config", "check", file.path], helper: helper.path)
            XCTAssertEqual(result.status, 2, fields)
            XCTAssertTrue(result.output.contains(expected), result.output)
        }
    }
    func testEveryNickelRecipePassesConfigCheck() throws {
        guard let helper = nickelHelperUrl() else { throw XCTSkip("Build the helper") }
        guard FileManager.default.isExecutableFile(atPath: builtCli.path) else { throw XCTSkip("Run swift build") }
        let blocks = agentSkillText.components(separatedBy: "```nickel\n").dropFirst()
        XCTAssertGreaterThanOrEqual(blocks.count, 4, "Include the starter, binding, Filter/Lens and hook recipes")
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "winmux.ncl")
        for (index, block) in blocks.enumerated() {
            let snippet = try XCTUnwrap(block.components(separatedBy: "```").first)
            XCTAssertNil(snippet.range(of: #"=\s*\[\s*\]"#, options: .regularExpression),
                         "Nickel recipe \(index + 1) sets an empty list, which frees a shipped chord the person did not ask to free")
            try snippet.write(to: file, atomically: true, encoding: .utf8)
            let result = try cli(["config", "check", file.path], helper: helper.path)
            XCTAssertEqual(result.status, 0, "Nickel recipe \(index + 1): \(result.output)")
        }
        // The prose shows how to free a chord without a recipe that does it; check that field too.
        let freeChord = try XCTUnwrap(agentSkillText.firstMatch(of: #/`(keymap\.free-search = W\.when[^`]+)`/#)?.1)
        try """
            let W = import "winmux/winmux.ncl" in
            ((import "winmux/defaults.ncl") & { \(freeChord) }) | W.Config
            """.write(to: file, atomically: true, encoding: .utf8)
        let freed = try cli(["config", "check", file.path], helper: helper.path)
        XCTAssertEqual(freed.status, 0, "\(freeChord): \(freed.output)")
    }

    func testCliPrintsSkillWithoutServerOrHelper() throws {
        guard FileManager.default.isExecutableFile(atPath: builtCli.path) else { throw XCTSkip("Run swift build") }
        // A live debug server would answer `agent skill` too, and hide a CLI that stopped answering it.
        guard try cli(["list-modes", "--current"]).status == 1 else { throw XCTSkip("Missing-server check requires no live debug server") }
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appending(path: "winmux")
        try FileManager.default.copyItem(at: builtCli, to: executable)
        let result = try cli(["agent", "skill"], helper: "/missing/helper", executable: executable)
        XCTAssertEqual(result.status, 0, result.output)
        XCTAssertTrue(result.output.contains("name: winmux\n"))
        XCTAssertTrue(result.output.contains("winmux debug-hooks on"))
        for heading in ["What is focused", "Reading state", "Config is Nickel", "Recipes", "Arranging windows", "Who can drive WinMux"] {
            XCTAssertTrue(result.output.contains("## \(heading)"), heading)
        }
        XCTAssertEqual(try cli(["agent", "skill", "--path", "/tmp/unused"]).status, 1)
    }

    private var builtCli: URL { projectRoot.appending(path: ".build/debug/winmux") }

    private func cli(_ arguments: [String], helper: String? = nil, executable: URL? = nil) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = executable ?? builtCli
        process.arguments = arguments
        let inherited = ProcessInfo.processInfo.environment
        process.environment = ["XDG_CONFIG_HOME": "/tmp/winmux-skill-test-\(UUID().uuidString)"]
        for name in ["HOME", "PATH"] { process.environment?[name] = inherited[name] }
        if let helper { process.environment?["WINMUX_NICKEL_HELPER"] = helper }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
