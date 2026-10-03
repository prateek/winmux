@testable import AppBundle
import Common
import XCTest

@MainActor
final class LensCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testLensCommandsAndScriptScopeParse() {
        for command in ["lens search", "lens search --search foo", "lens --presentation list",
                        "lens --filter floating --sort mru,title", "lens --filter -", "list-windows --filter -",
                        "list-lenses --json", "summon --window-id 42",
                        "list-windows --lens search --json", "list-windows --filter floating",
                        "list-windows --search notes --workspace 1"] {
            XCTAssertNil(parseCommand(command).errorOrNil, command)
        }
        for command in ["lens", "lens search --filter floating", "lens search --sort mru", "lens --presentation grid",
                        "lens --filter true --sort unknown", "list-windows --lens search --filter true"] {
            XCTAssertNotNil(parseCommand(command).errorOrNil, command)
        }
    }

    func testSummonMovesSelectedWindowWithoutChangingFloatingClass() async throws {
        let current = Workspace.get(byName: "1")
        let other = Workspace.get(byName: "2")
        _ = TestWindow.new(id: 1, parent: current.rootTilingContainer).focusWindow()
        let tiled = TestWindow.new(id: 2, parent: other.rootTilingContainer)
        let floating = TestWindow.new(id: 3, parent: other)
        for window in [tiled, floating] {
            let command = try XCTUnwrap(parseCommand("summon --window-id \(window.windowId)").cmdOrNil)
            let result = try await command.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(result.exitCode, 0)
            XCTAssertEqual(window.nodeWorkspace, current)
            XCTAssertEqual(focus.windowOrNil?.windowId, window.windowId)
        }
        XCTAssertTrue(floating.isFloating)
    }
}

@MainActor
final class LensScriptTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSearchImpliesAllAndIncludesMinimizedButKeepsExplicitScope() async throws {
        let one = Workspace.get(byName: "1")
        let two = Workspace.get(byName: "2")
        _ = TestWindow.new(id: 1, parent: one.rootTilingContainer).focusWindow()
        _ = TestWindow.new(id: 2, parent: two.rootTilingContainer)
        _ = TestWindow.new(id: 3, parent: macosMinimizedWindowsContainer)
        let all = try XCTUnwrap(parseCommand("list-windows --search TestWindow --json").cmdOrNil)
        let result = try await all.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        let rows = try JSONSerialization.jsonObject(with: Data(result.stdout.joined().utf8)) as! [[String: Any]]
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows.first?["score"] as? Int, 10)
        XCTAssertNotNil(rows.first?["matched-field"])
        let explicitAll = try XCTUnwrap(parseCommand("list-windows --search TestWindow --all --count").cmdOrNil)
        let explicitAllResult = try await explicitAll.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(explicitAllResult.stdout, ["3"])
        let scoped = try XCTUnwrap(parseCommand("list-windows --search TestWindow --workspace 1 --count").cmdOrNil)
        let scopedResult = try await scoped.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(scopedResult.stdout, ["1"])
    }

    func testFilterFailurePrintsNothingAndReturnsBadFilterCode() async throws {
        guard nickelHelperUrl() != nil else { throw XCTSkip("make helper first") }
        let supervisor = NickelSupervisor.shared
        supervisor.adopt(try await supervisor.load(nil).get())
        _ = TestWindow.new(id: 1, parent: Workspace.get(byName: "1").rootTilingContainer).focusWindow()
        let command = try XCTUnwrap(parseCommand(["list-windows", "--filter", "w.nope"]).cmdOrNil)
        let result = try await command.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.stdout, [])
        XCTAssertEqual(result.exitCode, 2)
        XCTAssertTrue(result.stderr.joined().contains("nope"))
    }
}

@MainActor
final class LensSettingsCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testDisabledAndUnknownLensCommandsReportUsageWithoutOpening() async throws {
        var disabled = LensConfig()
        disabled.enabled = false
        config.lenses = ["disabled": disabled]
        for name in ["disabled", "missing"] {
            let command = try XCTUnwrap(parseCommand("lens \(name)").cmdOrNil)
            let result = try await command.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(result.exitCode, 2)
            XCTAssertEqual(result.stdout, [])
            XCTAssertTrue(result.stderr.joined().contains(name))
        }
    }

    func testListLensesPrintsResolvedSettingsAndBindingParsesAsLensCommand() async throws {
        let settings = try JSONDecoder().decode(JSONValue.self, from: Data("""
        {"lenses":{"work":{"sort":["created"],"when":{"default":{"enabled":false}}}},"mode":{"main":{"binding":{"alt-l":"lens work"}}}}
        """.utf8))
        let parsed = parseConfig(settings)
        XCTAssertTrue(parsed.errors.isEmpty)
        XCTAssertNotNil(parsed.config.modes["main"])
        config = parsed.config
        let command = try XCTUnwrap(parseCommand("list-lenses --json").cmdOrNil)
        let result = try await command.run(.defaultEnv, .emptyStdin)
        let json = try JSONDecoder().decode(JSONValue.self, from: Data(result.stdout.joined().utf8))
        XCTAssertEqual(json["work"]?["enabled"], .bool(false))
        XCTAssertEqual(json["work"]?["sort"], .array([.string("created")]))
    }
}

@MainActor
final class LensRestoreTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSummonRestoresMinimizedFloatingWindowWithoutNoopDiagnostic() async throws {
        let ws = Workspace.get(byName: "1")
        _ = TestWindow.new(id: 1, parent: ws.rootTilingContainer).focusWindow()
        let window = TestWindow.new(id: 2, parent: ws)
        window.rememberMacOsLayoutOrigin(detachFromWorkspace: true)
        window.bind(to: macosMinimizedWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        let command = try XCTUnwrap(parseCommand("summon --window-id 2").cmdOrNil)
        let result = try await command.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stderr, [])
        XCTAssertEqual(window.nodeWorkspace, ws)
        XCTAssertTrue(window.isFloating)
        XCTAssertEqual(focus.windowOrNil?.windowId, 2)
    }
}

@MainActor
final class LensEmptyScopeTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testBadFilterStillFailsWhenScopeHasNoWindows() async throws {
        guard nickelHelperUrl() != nil else { throw XCTSkip("make helper first") }
        let loaded = try await NickelSupervisor.shared.load(nil).get()
        NickelSupervisor.shared.adopt(loaded)
        for body in ["w.nope", "42"] {
            let command = try XCTUnwrap(parseCommand(["list-windows", "--filter", body, "--workspace", "missing"]).cmdOrNil)
            let result = try await command.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(result.exitCode, 2)
            XCTAssertEqual(result.stdout, [])
            XCTAssertFalse(result.stderr.isEmpty)
        }
    }
}
