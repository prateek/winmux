@testable import AppBundle
import Common
import XCTest

@MainActor
final class ColumnPlacementWireTest: XCTestCase {
    func testDryRunWireContractForEveryOverflowAndOccupancy() async throws {
        guard nickelHelperUrl() != nil else { throw XCTSkip("Run make helper") }
        for occupied in [false, true] {
            for overflow in OverflowPolicy.allCases.map(\.rawValue) {
                setUpWorkspacesForTests()
                let path = FileManager.default.temporaryDirectory.appending(path: "placement-wire-\(UUID()).ncl")
                defer { try? FileManager.default.removeItem(at: path) }
                try ("let W = import \"winmux/winmux.ncl\" in { columns.place = fun w ctx cols => { column = 2, overflow = '\(overflow) } } | W.Config")
                    .write(to: path, atomically: true, encoding: .utf8)
                let loaded = try await NickelSupervisor.shared.load(path).get()
                NickelSupervisor.shared.adopt(loaded)
                config.columns = ColumnsConfig(loaded.settings["columns"], workspaces: nil)
                config.onFocusedMonitorChanged = []
                let destination = Workspace.get(byName: "Destination")
                destination.columns = ColumnState(count: 3, widths: [0.2, 0.3, 0.5])
                let anchor = TestWindow.new(id: 1, parent: destination.rootTilingContainer)
                anchor.columnSlot = 1
                if occupied {
                    let target = TestWindow.new(id: 2, parent: destination.rootTilingContainer)
                    target.columnSlot = 2
                }
                destination.normalizeContainers()
                XCTAssertTrue(anchor.focusWindow())
                let source = Workspace.get(byName: "Source")
                let window = TestWindow.new(id: 42, parent: source.rootTilingContainer)
                let parent = window.parent
                let text = try await parseCommand("place --dry-run --window-id 42").cmdOrDie.run(.defaultEnv, .emptyStdin)
                let json = try await parseCommand("place --dry-run --json --window-id 42").cmdOrDie.run(.defaultEnv, .emptyStdin)
                XCTAssertEqual(text.exitCode, 0)
                XCTAssertEqual(json.exitCode, 0)
                XCTAssertEqual(text.stdout, ["column 2 (2), overflow \(overflow), hook columns.place"])
                let expected = JSONValue.object(["column": .int(2), "target": .string("2"), "overflow": .string(overflow),
                                                 "hook": .string("columns.place"), "run": .array([]), "failure": .null])
                XCTAssertEqual(json.stdout, [expected.prettyPrinted])
                XCTAssertTrue(window.parent === parent)
                XCTAssertEqual(destination.columns!.widths, [0.2, 0.3, 0.5])
            }
        }
    }
}
