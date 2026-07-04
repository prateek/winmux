@testable import AppBundle
import Common
import XCTest

final class ListWorkspacesTest: XCTestCase {
    func testParse() {
        assertNotNil(parseCommand("list-cards --all").cmdOrNil)
        assertNil(parseCommand("list-cards --all --visible").cmdOrNil)
        assertNil(parseCommand("list-cards --focused --visible").cmdOrNil)
        assertNil(parseCommand("list-cards --focused --all").cmdOrNil)
        assertNil(parseCommand("list-cards --visible").cmdOrNil)
        assertNotNil(parseCommand("list-cards --visible --monitor 2").cmdOrNil)
        assertNotNil(parseCommand("list-cards --monitor focused").cmdOrNil)
        assertNil(parseCommand("list-cards --focused --monitor 2").cmdOrNil)
        assertNotNil(parseCommand("list-cards --all --format %{workspace}").cmdOrNil)
        assertEquals(parseCommand("list-cards --all --format %{workspace} --count").errorOrNil, "ERROR: Conflicting options: --count, --format")
        assertEquals(parseCommand("list-cards --empty").errorOrNil, "Mandatory option is not specified (--all|--focused|--monitor)")
        assertEquals(parseCommand("list-cards --all --focused --monitor mouse").errorOrNil, "ERROR: Conflicting options: --all, --focused, --monitor")
    }

    @MainActor
    func testListWorkspacesUsesProjectViewportOrderInsteadOfRawNameSort() async throws {
        setUpWorkspacesForTests()
        let first = Workspace.get(byName: "10")
        first.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 1, parent: first.rootTilingContainer)
        let second = Workspace.get(byName: "2")
        second.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 2, parent: second.rootTilingContainer)

        let io = CmdIo(stdin: .emptyStdin)
        let command = parseCommand("list-cards --all --format %{workspace}").cmdOrDie
        let succeeded = try await command.run(.defaultEnv, io)

        XCTAssertTrue(succeeded)
        XCTAssertEqual(io.stdout.filter { $0 != "setUpWorkspacesForTests" }, ["10", "2"])
    }
}
