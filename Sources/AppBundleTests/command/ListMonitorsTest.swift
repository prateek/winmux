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
        config.zones = [
            testDisplayLayoutConfig(
                monitor: .sequenceNumber(1),
                defaultZone: "main",
                columns: [
                    ColumnConfig(id: "left", name: "Left", width: 1.0 / 3.0),
                    ColumnConfig(id: "main", name: "Main", width: 1.0 / 3.0),
                    ColumnConfig(id: "right", name: "Right", width: 1.0 / 3.0),
                ],
            ),
        ]

        let result = try await parseCommand(
            "list-monitors --format '%{monitor-id}|%{column-id}|%{monitor-is-column}|%{monitor-physical-id}|%{column-configured-width}|%{column-effective-width}|%{column-runtime-width-override-state}|%{monitor-left},%{monitor-top},%{monitor-width},%{monitor-height}|%{monitor-name}'",
        ).cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.stdout, [
            "1|left|true|1|0.3333333333333333|0.3333333333333333|configured|0.0,0.0,300.0,800.0|Main / Left",
            "1|main|true|1|0.3333333333333333|0.3333333333333333|configured|300.0,0.0,300.0,800.0|Main / Main",
            "1|right|true|1|0.3333333333333333|0.3333333333333333|configured|600.0,0.0,300.0,800.0|Main / Right",
        ])
    }
}
