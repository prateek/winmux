@testable import AppBundle
import Common
import Foundation
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
        testParseCommandSucc(
            "use-zone-layout --monitor 1 focus",
            UseZoneLayoutCmdArgs(layoutId: "focus", monitor: .sequenceNumber(1)),
        )
        testParseCommandSucc(
            "use-zone-scene --monitor 1 deep-work",
            UseZoneSceneCmdArgs(sceneId: "deep-work", monitor: .sequenceNumber(1)),
        )
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

    func testFocusZoneResolvesZoneIdPrefix() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))

        let result = try await FocusZoneCommand(args: FocusZoneCmdArgs(zone: ZoneSelector("zone:left")))
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

    func testMoveNodeToZoneFailsWhenNoopIsStrict() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        let window = TestWindow.new(id: 42, parent: work.rootTilingContainer)
        XCTAssertTrue(window.focusWindow())

        let result = try await MoveNodeToZoneCommand(args: MoveNodeToZoneCmdArgs(zone: ZoneSelector("Work")).copy(\.failIfNoop, true))
            .run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(window.nodeWorkspace === work)
    }

    func testMoveNodeToZoneUsesWindowId() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let targetWindow = TestWindow.new(id: 43, parent: work.rootTilingContainer)
        let focusedWindow = TestWindow.new(id: 44, parent: work.rootTilingContainer)
        XCTAssertTrue(focusedWindow.focusWindow())

        let result = try await MoveNodeToZoneCommand(args: MoveNodeToZoneCmdArgs(zone: ZoneSelector("Comms")).copy(\.windowId, 43))
            .run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(targetWindow.nodeWorkspace === comms)
        XCTAssertTrue(focusedWindow.nodeWorkspace === work)
    }

    func testMoveNodeToZoneUsesEnvironmentWindowId() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let targetWindow = TestWindow.new(id: 45, parent: work.rootTilingContainer)
        let focusedWindow = TestWindow.new(id: 46, parent: work.rootTilingContainer)
        XCTAssertTrue(focusedWindow.focusWindow())

        let result = try await MoveNodeToZoneCommand(args: MoveNodeToZoneCmdArgs(zone: ZoneSelector("Comms")).copy(\.failIfNoop, true))
            .run(.defaultEnv.copy(\.windowId, 45), .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(targetWindow.nodeWorkspace === comms)
        XCTAssertTrue(focusedWindow.nodeWorkspace === work)
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

    func testListZonesCountAndJson() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))

        let countResult = try await parseCommand("list-zones --count").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(countResult.exitCode, 0)
        XCTAssertEqual(countResult.stdout, ["3"])

        let jsonResult = try await parseCommand("list-zones --json").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(jsonResult.exitCode, 0)
        let json = try XCTUnwrap(jsonResult.stdout.first)
        let rows = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]])
        let referenceRow = try XCTUnwrap(rows.first { $0["monitor-zone-id"] as? String == "left" })
        XCTAssertEqual(referenceRow["monitor-zone-name"] as? String, "Reference")
        XCTAssertEqual("\(referenceRow["monitor-physical-id"] ?? "")", "1")
        XCTAssertEqual(referenceRow["monitor-active-workspace"] as? String, "reference")
    }

    func testUseZoneLayoutSwitchesFocusedMonitorPreset() async throws {
        configureZoneLayoutPresets()

        let result = try await parseCommand("use-zone-layout focus").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, ["Using zone layout 'focus' on monitor 1"])
        XCTAssertEqual(sortedMonitors.map(\.zoneLayoutId), ["focus", "focus", "focus"])
        XCTAssertEqual(sortedMonitors.map(\.zoneId), ["left", "main", "right"])
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [180, 840, 180])

        let listResult = try await parseCommand(
            "list-zones --format '%{monitor-zone-layout-id}|%{monitor-zone-id}|%{monitor-width}'",
        ).cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(listResult.exitCode, 0)
        XCTAssertEqual(listResult.stdout, [
            "focus|left|180.0",
            "focus|main|840.0",
            "focus|right|180.0",
        ])
    }

    func testUseZoneLayoutCanOverrideInlineZoneConfig() async throws {
        configureInlineZonesWithLayoutPresets()

        XCTAssertEqual(sortedMonitors.map(\.zoneLayoutId), [nil, nil, nil])
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [300, 600, 300])

        let result = try await parseCommand("use-zone-layout focus").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(sortedMonitors.map(\.zoneLayoutId), ["focus", "focus", "focus"])
        XCTAssertEqual(sortedMonitors.map(\.zoneId), ["left", "main", "right"])
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [180, 840, 180])
    }

    func testUseZoneLayoutRejectsUnknownPreset() async throws {
        configureZoneLayoutPresets()

        let result = try await parseCommand("use-zone-layout missing").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.stderr.joined(separator: "\n").contains("Unknown zone layout preset 'missing'"))
    }

    func testUseZoneSceneActivatesBoundWorkspacesAndLayout() async throws {
        let zones = configureZoneScenes()
        let triageDraft = Workspace.get(byName: "TriageDraft")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(triageDraft))
        XCTAssertTrue(triageDraft.focusWorkspace())

        let result = try await parseCommand("use-zone-scene deep-work").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, ["Using zone scene 'deep-work' on monitor 1 with layout 'focus': left=FocusQueue, main=FocusBuild, right=FocusNotes"])
        XCTAssertEqual(sortedMonitors.map(\.zoneLayoutId), ["focus", "focus", "focus"])
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [180, 840, 180])
        let activeByZone = Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
            monitor.zoneId.map { ($0, monitor.activeWorkspace.name) }
        })
        XCTAssertEqual(activeByZone, [
            "left": "FocusQueue",
            "main": "FocusBuild",
            "right": "FocusNotes",
        ])
    }

    func testUseZoneSceneRejectsUnknownScene() async throws {
        _ = configureZoneScenes()

        let result = try await parseCommand("use-zone-scene missing").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.stderr.joined(separator: "\n").contains("Unknown zone scene 'missing'"))
    }

    func testZoneCommandsFailWhenNoZonesAreConfigured() async throws {
        configureNoZones()
        let workspace = Workspace.get(byName: "work")
        let window = TestWindow.new(id: 61, parent: workspace.rootTilingContainer)
        XCTAssertTrue(window.focusWindow())

        let focusResult = try await FocusZoneCommand(args: FocusZoneCmdArgs(zone: ZoneSelector("left")))
            .run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(focusResult.exitCode, 1)
        XCTAssertTrue(focusResult.stderr.joined(separator: "\n").contains("No zones are configured"))

        let moveResult = try await MoveNodeToZoneCommand(args: MoveNodeToZoneCmdArgs(zone: ZoneSelector("left")))
            .run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(moveResult.exitCode, 1)
        XCTAssertTrue(moveResult.stderr.joined(separator: "\n").contains("No zones are configured"))
    }
}

@MainActor
private func configureZoneScenes() -> [String: Monitor] {
    configureZoneLayoutPresets()
    config.zoneScenes = [
        ZoneSceneConfig(
            id: "deep-work",
            layoutPreset: "focus",
            workspaces: [
                ZoneSceneWorkspaceConfig(zone: "left", workspace: WorkspaceName.parse("FocusQueue").getOrDie()),
                ZoneSceneWorkspaceConfig(zone: "main", workspace: WorkspaceName.parse("FocusBuild").getOrDie()),
                ZoneSceneWorkspaceConfig(zone: "right", workspace: WorkspaceName.parse("FocusNotes").getOrDie()),
            ],
        ),
    ]
    return Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.zoneId.map { ($0, monitor) }
    })
}

@MainActor
private func configureZoneLayoutPresets() {
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
    config.zoneLayouts = [
        ZoneLayoutConfig(
            id: "balanced",
            layout: .columns,
            defaultZone: "main",
            columns: [
                ZoneColumnConfig(id: "left", name: "Reference", width: 0.25),
                ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
                ZoneColumnConfig(id: "right", name: "Comms", width: 0.25),
            ],
        ),
        ZoneLayoutConfig(
            id: "focus",
            layout: .columns,
            defaultZone: "main",
            columns: [
                ZoneColumnConfig(id: "left", name: "Reference", width: 0.15),
                ZoneColumnConfig(id: "main", name: "Work", width: 0.70),
                ZoneColumnConfig(id: "right", name: "Comms", width: 0.15),
            ],
        ),
    ]
    config.zones = [
        ZoneConfig(
            monitor: .sequenceNumber(1),
            layoutPreset: "balanced",
        ),
    ]
}

@MainActor
private func configureInlineZonesWithLayoutPresets() {
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
    config.zoneLayouts = [
        ZoneLayoutConfig(
            id: "focus",
            layout: .columns,
            defaultZone: "main",
            columns: [
                ZoneColumnConfig(id: "left", name: "Reference", width: 0.15),
                ZoneColumnConfig(id: "main", name: "Work", width: 0.70),
                ZoneColumnConfig(id: "right", name: "Comms", width: 0.15),
            ],
        ),
    ]
    config.zones = [
        ZoneConfig(
            monitor: .sequenceNumber(1),
            layout: .columns,
            defaultZone: "main",
            columns: [
                ZoneColumnConfig(id: "left", name: "Reference", width: 0.25),
                ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
                ZoneColumnConfig(id: "right", name: "Comms", width: 0.25),
            ],
        ),
    ]
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
private func configureNoZones() {
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
    config.zones = []
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
