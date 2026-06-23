@testable import AppBundle
import Common
import XCTest

final class ListMonitorsTest: XCTestCase {
    func testParseListMonitorsCommand() {
        testParseCommandSucc("list-monitors", ListMonitorsCmdArgs(rawArgs: []))
        testParseCommandSucc("list-monitors --focused", ListMonitorsCmdArgs(rawArgs: []).copy(\.focused, true))
        testParseCommandSucc("list-monitors --count", ListMonitorsCmdArgs(rawArgs: []).copy(\.outputOnlyCount, true))
        assertEquals(parseCommand("list-monitors --format %{monitor-id} --count").errorOrNil, "ERROR: Conflicting options: --count, --format")
    }

    @MainActor
    func testListMonitorsCanExposeZoneViewports() async throws {
        setUpWorkspacesForTests()
        let main = TestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 900, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 900, height: 800),
            isMain: true,
        )
        setMonitorsForTests([main])
        config.gaps = .zero
        config.workspaceSidebar.enabled = false
        setCurrentZoneTopologySnapshot(ZoneTopologySnapshot(config, environment: ["WINMUX_ZONES_SPIKE": "1"]))

        let result = try await parseCommand(
            "list-monitors --format '%{monitor-id}|%{monitor-zone-id}|%{monitor-is-zone}|%{monitor-physical-id}|%{monitor-name}'",
        ).cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.stdout, [
            "1|left|true|1|Main / Left",
            "1|main|true|1|Main / Main",
            "1|right|true|1|Main / Right",
        ])
    }
}
