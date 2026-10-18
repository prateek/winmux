@testable import AppBundle
import Common
import XCTest

@MainActor
final class ColumnCommandsTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testCommandSurfaceRejectsBadUsage() {
        for raw in ["focus-column 0", "focus-column nope", "move-node-to-column -1", "column-width 0", "column-width 1", "column-width nan", "compact extra", "list-columns --bad", "column-count 0", "place --window-id 1", "place --dry-run"] {
            if case .failure = parseCommand(raw) {} else { XCTFail("Accepted \(raw)") }
        }
    }

    func testFocusEmptyMoveWidthCompactCountAndList() async throws {
        func assertExit(_ result: CmdResult, _ code: Int32) async { XCTAssertEqual(result.exitCode, code) }
        let ws = focus.workspace
        ws.columns = ColumnState(count: 3)
        let a = TestWindow.new(id: 1, parent: ws.rootTilingContainer)
        let b = TestWindow.new(id: 2, parent: ws.rootTilingContainer)
        ws.normalizeContainers()
        XCTAssertTrue(a.focusWindow())
        func run(_ raw: String) async throws -> CmdResult {
            let command = try XCTUnwrap(parseCommand(raw).cmdOrNil)
            return try await command.run(.defaultEnv, .emptyStdin)
        }
        await assertExit(try await run("focus-column 3"), 0)
        XCTAssertEqual(ws.columns?.focusedSlot, 3)
        await assertExit(try await run("move-node-to-column 3 --window-id 2"), 0)
        XCTAssertEqual(ws.columnSlot(containing: b), 3)
        XCTAssertTrue(b.focusWindow())
        for raw in ["column-width next", "column-width prev", "column-width 0.5"] {
            await assertExit(try await run(raw), 0)
            XCTAssertEqual(ws.columns!.widths.reduce(0, +), 1, accuracy: 0.000001)
        }
        XCTAssertEqual(ws.columns!.widths[2], 0.5, accuracy: 0.000001)
        await assertExit(try await run("compact"), 0)
        XCTAssertEqual(ws.rootTilingContainer.children.compactMap(\.columnSlot), [1, 2])
        let listed = try await run("list-columns --json")
        XCTAssertEqual(listed.exitCode, 0)
        XCTAssertTrue(listed.stdout.joined().contains("window-ids"))
        await assertExit(try await run("focus-column 4"), 2)
        await assertExit(try await run("column-count 2"), 0)
        XCTAssertEqual(ws.columns?.count, 2)
        await assertExit(try await run("column-count off"), 0)
        XCTAssertNil(ws.columns)
        ws.applyColumns(ColumnsConfig(.object(["count": .int(3)]), workspaces: nil))
        XCTAssertEqual(ws.columns?.count, 3)
    }
    func testCliBadUsageExitsTwoBeforeConnecting() throws {
        let executable = projectRoot.appending(path: ".build/debug/winmux")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { throw XCTSkip("Run swift build") }
        for args in [["focus-column", "0"], ["move-node-to-column", "0"], ["column-width", "1"],
                     ["compact", "extra"], ["list-columns", "--bad"], ["column-count", "0"], ["place"]] {
            let process = Process(); process.executableURL = executable; process.arguments = args
            process.standardOutput = Pipe(); process.standardError = Pipe()
            try process.run(); process.waitUntilExit()
            XCTAssertEqual(process.terminationStatus, 2, args.joined(separator: " "))
        }
    }

}
