@testable import AppBundle
import Common
import XCTest

@MainActor final class ColumnsConfigTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }
    func testFourPathsResolveFieldsAndOnlyDefaultMatches() throws {
        let json = try JSONDecoder().decode(JSONValue.self, from: Data("""
        {"columns":{"count":3,"widths":[0.2,0.3,0.5],"when":{"default":{"count":2,"widths":[0.4,0.6]},"travel":{"count":7}}},
         "workspace":{"Demo":{"columns":{"count":3,"when":{"default":{"widths":[0.1,0.2,0.7]},"travel":{"count":8}}}}}}
        """.utf8))
        let parsed = parseConfig(json)
        XCTAssertTrue(parsed.errors.isEmpty, "\(parsed.errors)")
        XCTAssertEqual(parsed.config.columns.resolved(workspace: "Other")?.count, 2)
        XCTAssertEqual(parsed.config.columns.resolved(workspace: "Other")?.widths, [0.4, 0.6])
        XCTAssertEqual(parsed.config.columns.resolved(workspace: "Demo")?.count, 3)
        XCTAssertEqual(parsed.config.columns.resolved(workspace: "Demo")?.widths, [0.1, 0.2, 0.7])
        XCTAssertEqual(parsed.config.columns.widthPresets, [1.0 / 3, 1.0 / 2, 2.0 / 3] as [CGFloat])
    }
    func testReloadResetsWidthsFoldsCountAndOffClearsSlots() throws {
        let ws = Workspace.get(byName: "Demo")
        func settings(_ body: String) throws -> ColumnsConfig {
            try ColumnsConfig(JSONDecoder().decode(JSONValue.self, from: Data(body.utf8)), workspaces: nil)
        }
        ws.applyColumns(try settings("{\"count\":3,\"widths\":[0.2,0.3,0.5]}"))
        for id in UInt32(1)...4 { TestWindow.new(id: id, parent: ws.rootTilingContainer) }
        ws.normalizeContainers()
        ws.columns!.widths = [0.4, 0.3, 0.3]
        ws.applyColumns(try settings("{\"count\":2,\"widths\":[0.25,0.75]}"))
        ws.normalizeContainers()
        XCTAssertEqual(ws.columns?.widths, [0.25, 0.75])
        XCTAssertEqual(ws.rootTilingContainer.children.count, 2)
        XCTAssertEqual(ws.rootTilingContainer.allLeafWindowsRecursive.count, 4)
        ws.applyColumns(try settings("{\"count\":\"off\"}"))
        XCTAssertNil(ws.columns)
        XCTAssertTrue(ws.rootTilingContainer.children.allSatisfy { $0.columnSlot == nil })
    }
}
