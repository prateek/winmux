@testable import AppBundle
import Common
import XCTest

@MainActor
final class AgentSkillTest: XCTestCase {
    func testEveryNickelRecipePassesConfigCheck() throws {
        let helper = try XCTUnwrap(nickelHelperUrl(), "Build the helper before checking skill recipes")
        let blocks = agentSkillText.components(separatedBy: "```nickel\n").dropFirst()
        XCTAssertGreaterThanOrEqual(blocks.count, 4, "Include the starter, binding, Filter/Lens and hook recipes")
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "winmux.ncl")
        for (index, block) in blocks.enumerated() {
            let snippet = try XCTUnwrap(block.components(separatedBy: "```").first)
            try snippet.write(to: file, atomically: true, encoding: .utf8)
            let result = try cli(["config", "check", file.path], helper: helper.path)
            XCTAssertEqual(result.status, 0, "Nickel recipe \(index + 1): \(result.output)")
        }
    }

    func testCliPrintsSkillWithoutServerOrHelper() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appending(path: "winmux")
        try FileManager.default.copyItem(at: projectRoot.appending(path: ".build/debug/winmux"), to: executable)
        let result = try cli(["agent", "skill"], helper: "/missing/helper", executable: executable)
        XCTAssertEqual(result.status, 0, result.output)
        XCTAssertTrue(result.output.contains("name: winmux\n"))
        for heading in ["What is focused", "Reading state", "Config is Nickel", "Recipes", "Arranging windows", "Who can drive WinMux"] {
            XCTAssertTrue(result.output.contains("## \(heading)"), heading)
        }
        XCTAssertEqual(try cli(["agent", "skill", "--path", "/tmp/unused"]).status, 1)
    }

    private func cli(_ arguments: [String], helper: String? = nil, executable: URL? = nil) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = executable ?? projectRoot.appending(path: ".build/debug/winmux")
        process.arguments = arguments
        process.environment = ["XDG_CONFIG_HOME": "/tmp/winmux-skill-test-\(UUID().uuidString)"]
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
