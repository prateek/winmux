@testable import AppBundle
import Common
import XCTest

@MainActor
final class ZoneCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseCommandSucc("focus-zone left", FocusZoneCmdArgs(zone: ZoneSelector("left")))
        testParseCommandSucc("focus-zone zone:left", FocusZoneCmdArgs(zone: ZoneSelector("zone:left")))
        testParseCommandSucc("move-node-to-zone --window-id 7 --focus-follows-window --fail-if-noop Comms",
                             MoveNodeToZoneCmdArgs(zone: ZoneSelector("Comms"))
                                 .copy(\.windowId, 7)
                                 .copy(\.focusFollowsWindow, true)
                                 .copy(\.failIfNoop, true))
        testParseCommandSucc("list-zones --json", ListZonesCmdArgs(rawArgs: []).copy(\.json, true))
    }

    func testFocusZoneResolvesZoneName() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(work.focusWorkspace())

        let result = try await FocusZoneCommand(args: FocusZoneCmdArgs(zone: ZoneSelector("Reference")))
            .run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(focus.workspace === reference)
    }

    func testDuplicateBareZoneIdsRequirePhysicalQualifier() async throws {
        let zones = configureDuplicateZones()
        let secondaryLeft = Workspace.get(byName: "secondary-left")
        _ = TestWindow.new(id: 31, parent: secondaryLeft.rootTilingContainer)
        XCTAssertTrue(zones["2:left"].orDie().setActiveWorkspace(secondaryLeft))

        let ambiguous = try await FocusZoneCommand(args: FocusZoneCmdArgs(zone: ZoneSelector("left")))
            .run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(ambiguous.exitCode, 1)
        XCTAssertTrue(ambiguous.stderr.joined(separator: "\n").contains("ambiguous"))

        let qualified = try await FocusZoneCommand(args: FocusZoneCmdArgs(zone: ZoneSelector("2:left")))
            .run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(qualified.exitCode, 0)
        XCTAssertTrue(focus.workspace === secondaryLeft)
    }

    func testFocusMonitorNumericSelectorStaysPhysical() async throws {
        let zones = configureThreeZones(defaultZone: "main")
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(reference.focusWorkspace())

        let result = try await parseCommand("focus-monitor 1").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(focus.workspace === work)
    }

    func testMoveNodeToZoneMovesFocusedWindow() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let window = TestWindow.new(id: 41, parent: work.rootTilingContainer)
        XCTAssertTrue(window.focusWindow())

        let result = try await MoveNodeToZoneCommand(args: MoveNodeToZoneCmdArgs(zone: ZoneSelector("Comms")).copy(\.failIfNoop, true))
            .run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(window.nodeWorkspace === comms)
    }

    func testMoveNodeToZoneMovesFocusedTabGroup() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let tabGroup = TilingContainer(parent: work.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .h, .tabGroup, index: INDEX_BIND_LAST)
        let first = TestWindow.new(id: 51, parent: tabGroup)
        let second = TestWindow.new(id: 52, parent: tabGroup)
        XCTAssertTrue(first.focusWindow())

        let result = try await MoveNodeToZoneCommand(args: MoveNodeToZoneCmdArgs(zone: ZoneSelector("right")))
            .run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(tabGroup.nodeWorkspace === comms)
        XCTAssertTrue(first.nodeWorkspace === comms)
        XCTAssertTrue(second.nodeWorkspace === comms)
        XCTAssertFalse(work.rootTilingContainer.allLeafWindowsRecursive.contains(first))
    }

    func testListZonesOutputsZoneNamesAndActiveWorkspaces() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))

        let result = try await parseCommand(
            "list-zones --format '%{monitor-zone-id}|%{monitor-zone-name}|%{monitor-physical-id}|%{monitor-active-workspace}'",
        ).cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("left|Reference|1|reference"))
        XCTAssertTrue(result.stdout.contains { $0.hasPrefix("main|Work|1|") })
        XCTAssertTrue(result.stdout.contains { $0.hasPrefix("right|Comms|1|") })
    }
}

@MainActor
private func configureThreeZones(defaultZone: String = "main") -> [String: Monitor] {
    let main = TestMonitor(
        monitorAppKitNsScreenScreensId: 1,
        name: "Main",
        rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        isMain: true,
    )
    setMonitorsForTests([main])
    config.gaps = .zero
    config.workspaceSidebar.enabled = false
    config.zones = [
        ZoneConfig(
            monitor: .sequenceNumber(1),
            layout: .columns,
            defaultZone: defaultZone,
            columns: [
                ZoneColumnConfig(id: "left", name: "Reference", width: 0.25),
                ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
                ZoneColumnConfig(id: "right", name: "Comms", width: 0.25),
            ],
        ),
    ]
    return Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.zoneId.map { ($0, monitor) }
    })
}

@MainActor
private func configureDuplicateZones() -> [String: Monitor] {
    let main = TestMonitor(
        monitorAppKitNsScreenScreensId: 1,
        name: "Main",
        rect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
        visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
        isMain: true,
    )
    let secondary = TestMonitor(
        monitorAppKitNsScreenScreensId: 2,
        name: "Secondary",
        rect: Rect(topLeftX: 1000, topLeftY: 0, width: 1000, height: 800),
        visibleRect: Rect(topLeftX: 1000, topLeftY: 0, width: 1000, height: 800),
        isMain: false,
    )
    setMonitorsForTests([main, secondary])
    config.gaps = .zero
    config.workspaceSidebar.enabled = false
    config.zones = [
        duplicateZoneConfig(monitor: .sequenceNumber(1)),
        duplicateZoneConfig(monitor: .sequenceNumber(2)),
    ]
    return Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
              let zoneId = monitor.zoneId
        else { return nil }
        return ("\(physicalId):\(zoneId)", monitor)
    })
}

private func duplicateZoneConfig(monitor: MonitorDescription) -> ZoneConfig {
    ZoneConfig(
        monitor: monitor,
        layout: .columns,
        defaultZone: "main",
        columns: [
            ZoneColumnConfig(id: "left", name: "Reference", width: 0.50),
            ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
        ],
    )
}
