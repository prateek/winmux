@testable import AppBundle
import AppKit
import Common
import XCTest

private struct MonitorTopologyTestMonitor: Monitor {
    let monitorAppKitNsScreenScreensId: Int
    let name: String
    let rect: Rect
    let visibleRect: Rect
    let isMain: Bool

    var width: CGFloat { rect.width }
    var height: CGFloat { rect.height }
}

private func assertRectsEqual(
    _ actual: [Rect],
    _ expected: [Rect],
    file: StaticString = #filePath,
    line: UInt = #line,
) {
    XCTAssertEqual(actual.map(\.topLeftX), expected.map(\.topLeftX), file: file, line: line)
    XCTAssertEqual(actual.map(\.topLeftY), expected.map(\.topLeftY), file: file, line: line)
    XCTAssertEqual(actual.map(\.width), expected.map(\.width), file: file, line: line)
    XCTAssertEqual(actual.map(\.height), expected.map(\.height), file: file, line: line)
}

@MainActor
final class MonitorTopologyTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSortedMonitorsUseSpatialOrderEvenWhenMainDisplayIsOnTheRight() {
        let left = MonitorTopologyTestMonitor(
            monitorAppKitNsScreenScreensId: 2,
            name: "Left",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            isMain: false,
        )
        let main = MonitorTopologyTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            isMain: true,
        )
        setMonitorsForTests([main, left])

        XCTAssertEqual(sortedMonitors.map(\.name), ["Left", "Main"])
        XCTAssertEqual(sortedMonitors.map(\.monitorId_oneBased), [1, 2])
        XCTAssertEqual(sortedMonitors.map(\.monitorAppKitNsScreenScreensId), [2, 1])
        XCTAssertEqual(MonitorDescription.sequenceNumber(1).resolveMonitor(sortedMonitors: sortedMonitors)?.name, "Left")
        XCTAssertEqual(MonitorDescription.main.resolveMonitor(sortedMonitors: sortedMonitors)?.name, "Main")
        XCTAssertEqual(left.findRelativeMonitor(inDirection: .right)?.monitorsInDirection.map(\.name), ["Left", "Main"])
    }

    func testWorkspaceSidebarMainMonitorConfigCreatesPanelOnEveryMonitor() {
        let main = MonitorTopologyTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            isMain: true,
        )
        let secondary = MonitorTopologyTestMonitor(
            monitorAppKitNsScreenScreensId: 2,
            name: "Secondary",
            rect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            isMain: false,
        )
        setMonitorsForTests([main, secondary])
        config.workspaceSidebar.enabled = true
        config.workspaceSidebar.collapsedWidth = 54
        config.workspaceSidebar.monitor = [.main]
        config.gaps = .zero

        XCTAssertEqual(main.visibleRectPaddedByOuterGaps.topLeftX, 54)
        XCTAssertEqual(main.visibleRectPaddedByOuterGaps.width, 1866)
        XCTAssertEqual(secondary.visibleRectPaddedByOuterGaps.topLeftX, 1974)
        XCTAssertEqual(secondary.visibleRectPaddedByOuterGaps.width, 1866)
    }

    func testWorkspaceSidebarMainMonitorConfigResolvesAllMonitors() {
        let main = MonitorTopologyTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            isMain: true,
        )
        let secondary = MonitorTopologyTestMonitor(
            monitorAppKitNsScreenScreensId: 2,
            name: "Secondary",
            rect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            isMain: false,
        )
        setMonitorsForTests([main, secondary])
        config.workspaceSidebar.monitor = [.main]

        XCTAssertEqual(
            config.workspaceSidebar.resolvedMonitors(sortedMonitors: sortedMonitors).map(\.rect.topLeftCorner),
            [main.rect.topLeftCorner, secondary.rect.topLeftCorner],
        )
    }

    func testWorkspaceSidebarExplicitSecondaryConfigOnlyInsetsSecondaryMonitor() {
        let main = MonitorTopologyTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            isMain: true,
        )
        let secondary = MonitorTopologyTestMonitor(
            monitorAppKitNsScreenScreensId: 2,
            name: "Secondary",
            rect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            isMain: false,
        )
        setMonitorsForTests([main, secondary])
        config.workspaceSidebar.enabled = true
        config.workspaceSidebar.collapsedWidth = 54
        config.workspaceSidebar.monitor = [.sequenceNumber(2)]
        config.gaps = .zero

        XCTAssertEqual(main.visibleRectPaddedByOuterGaps.topLeftX, 0)
        XCTAssertEqual(main.visibleRectPaddedByOuterGaps.width, 1920)
        XCTAssertEqual(secondary.visibleRectPaddedByOuterGaps.topLeftX, 1974)
        XCTAssertEqual(secondary.visibleRectPaddedByOuterGaps.width, 1866)
    }

    func testColumnZonesExpandPhysicalMonitorIntoWorkspaceViewports() {
        let main = MonitorTopologyTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
            isMain: true,
        )
        let secondary = MonitorTopologyTestMonitor(
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

        let viewports = monitors

        XCTAssertEqual(viewports.map(\.zoneId), ["left", "main", "right", nil])
        XCTAssertEqual(viewports.map(\.physicalMonitor.name), ["Main", "Main", "Main", "Secondary"])
        XCTAssertEqual(viewports.map(\.monitorId_oneBased), [1, 1, 1, 2])
        assertRectsEqual(viewports.map(\.rect), [
            Rect(topLeftX: 0, topLeftY: 0, width: 250, height: 800),
            Rect(topLeftX: 250, topLeftY: 0, width: 500, height: 800),
            Rect(topLeftX: 750, topLeftY: 0, width: 250, height: 800),
            secondary.rect,
        ])
        XCTAssertEqual(viewports.map(\.isMain), [false, true, false, false])
    }

    func testZoneSpikeIsDisabledByDefault() {
        let main = MonitorTopologyTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 900, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 900, height: 800),
            isMain: true,
        )
        setMonitorsForTests([main])
        setCurrentZoneTopologySnapshot(ZoneTopologySnapshot(config, environment: [:]))

        XCTAssertEqual(workspaceViewports.count, 1)
        XCTAssertNil(workspaceViewports[0].zoneId)
        assertRectsEqual(workspaceViewports.map(\.rect), [main.rect])
    }

    func testZoneSpikeEnvironmentSplitsMainMonitorIntoThreeColumns() {
        let main = MonitorTopologyTestMonitor(
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

        XCTAssertEqual(workspaceViewports.map(\.zoneId), ["left", "main", "right"])
        XCTAssertEqual(monitors.map(\.zoneId), workspaceViewports.map(\.zoneId))
        assertRectsEqual(workspaceViewports.map(\.rect), [
            Rect(topLeftX: 0, topLeftY: 0, width: 300, height: 800),
            Rect(topLeftX: 300, topLeftY: 0, width: 300, height: 800),
            Rect(topLeftX: 600, topLeftY: 0, width: 300, height: 800),
        ])
        XCTAssertEqual(workspaceViewports.map(\.isMain), [false, true, false])
    }

    func testZoneSpikeViewportsCanShowIndependentWorkspaces() {
        let main = MonitorTopologyTestMonitor(
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
        let viewports = workspaceViewports
        XCTAssertEqual(viewports.map(\.zoneId), ["left", "main", "right"])

        let left = Workspace.get(byName: "left-workspace")
        let center = Workspace.get(byName: "center-workspace")
        let right = Workspace.get(byName: "right-workspace")

        XCTAssertTrue(viewports[0].setActiveWorkspace(left))
        XCTAssertTrue(viewports[1].setActiveWorkspace(center))
        XCTAssertTrue(viewports[2].setActiveWorkspace(right))

        XCTAssertTrue(viewports[0].activeWorkspace === left)
        XCTAssertTrue(viewports[1].activeWorkspace === center)
        XCTAssertTrue(viewports[2].activeWorkspace === right)
    }

    func testZoneViewportIdentitySurvivesColumnWidthChange() {
        let main = MonitorTopologyTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
            isMain: true,
        )
        setMonitorsForTests([main])
        config.gaps = .zero
        config.workspaceSidebar.enabled = false
        config.zones = [
            ZoneConfig(
                monitor: .main,
                layout: .columns,
                defaultZone: "main",
                columns: [
                    ZoneColumnConfig(id: "left", name: "Reference", width: 0.25),
                    ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
                    ZoneColumnConfig(id: "right", name: "Comms", width: 0.25),
                ],
            ),
        ]
        let originalViewports = workspaceViewports
        XCTAssertEqual(originalViewports.map(\.zoneId), ["left", "main", "right"])

        let left = Workspace.get(byName: "left-workspace")
        let center = Workspace.get(byName: "center-workspace")
        let right = Workspace.get(byName: "right-workspace")
        XCTAssertTrue(originalViewports[0].setActiveWorkspace(left))
        XCTAssertTrue(originalViewports[1].setActiveWorkspace(center))
        XCTAssertTrue(originalViewports[2].setActiveWorkspace(right))

        config.zones = [
            ZoneConfig(
                monitor: .main,
                layout: .columns,
                defaultZone: "main",
                columns: [
                    ZoneColumnConfig(id: "left", name: "Reference", width: 0.20),
                    ZoneColumnConfig(id: "main", name: "Work", width: 0.60),
                    ZoneColumnConfig(id: "right", name: "Comms", width: 0.20),
                ],
            ),
        ]
        Workspace.reconcileWorkspaceState()
        let updatedViewports = workspaceViewports

        XCTAssertEqual(updatedViewports.map(\.zoneId), ["left", "main", "right"])
        assertRectsEqual(updatedViewports.map(\.rect), [
            Rect(topLeftX: 0, topLeftY: 0, width: 200, height: 800),
            Rect(topLeftX: 200, topLeftY: 0, width: 600, height: 800),
            Rect(topLeftX: 800, topLeftY: 0, width: 200, height: 800),
        ])
        XCTAssertTrue(MonitorViewportId(originalViewports[1]).hasSameStableIdentity(as: MonitorViewportId(updatedViewports[1])))
        XCTAssertTrue(MonitorViewportId(originalViewports[2]).hasSameStableIdentity(as: MonitorViewportId(updatedViewports[2])))
        XCTAssertNotEqual(originalViewports[1].rect.topLeftCorner, updatedViewports[1].rect.topLeftCorner)
        XCTAssertNotEqual(originalViewports[2].rect.topLeftCorner, updatedViewports[2].rect.topLeftCorner)
        XCTAssertTrue(updatedViewports[0].activeWorkspace === left)
        XCTAssertTrue(updatedViewports[1].activeWorkspace === center)
        XCTAssertTrue(updatedViewports[2].activeWorkspace === right)
    }

    func testActiveZoneLayoutPresetSwitchChangesGeometryAndKeepsZoneIdentity() {
        let main = MonitorTopologyTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
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
                monitor: .main,
                layoutPreset: "balanced",
            ),
        ]
        let originalViewports = workspaceViewports
        XCTAssertEqual(originalViewports.map(\.zoneLayoutId), ["balanced", "balanced", "balanced"])
        assertRectsEqual(originalViewports.map(\.rect), [
            Rect(topLeftX: 0, topLeftY: 0, width: 250, height: 800),
            Rect(topLeftX: 250, topLeftY: 0, width: 500, height: 800),
            Rect(topLeftX: 750, topLeftY: 0, width: 250, height: 800),
        ])
        let left = Workspace.get(byName: "left-workspace")
        let center = Workspace.get(byName: "center-workspace")
        let right = Workspace.get(byName: "right-workspace")
        XCTAssertTrue(originalViewports[0].setActiveWorkspace(left))
        XCTAssertTrue(originalViewports[1].setActiveWorkspace(center))
        XCTAssertTrue(originalViewports[2].setActiveWorkspace(right))

        switch setActiveZoneLayout("focus", for: main) {
            case .success: break
            case .failure(let msg): XCTFail(msg)
        }
        let updatedViewports = workspaceViewports

        XCTAssertEqual(updatedViewports.map(\.zoneLayoutId), ["focus", "focus", "focus"])
        XCTAssertEqual(updatedViewports.map(\.zoneId), ["left", "main", "right"])
        assertRectsEqual(updatedViewports.map(\.rect), [
            Rect(topLeftX: 0, topLeftY: 0, width: 150, height: 800),
            Rect(topLeftX: 150, topLeftY: 0, width: 700, height: 800),
            Rect(topLeftX: 850, topLeftY: 0, width: 150, height: 800),
        ])
        XCTAssertTrue(MonitorViewportId(originalViewports[0]).hasSameStableIdentity(as: MonitorViewportId(updatedViewports[0])))
        XCTAssertTrue(MonitorViewportId(originalViewports[1]).hasSameStableIdentity(as: MonitorViewportId(updatedViewports[1])))
        XCTAssertTrue(MonitorViewportId(originalViewports[2]).hasSameStableIdentity(as: MonitorViewportId(updatedViewports[2])))
        XCTAssertTrue(updatedViewports[0].activeWorkspace === left)
        XCTAssertTrue(updatedViewports[1].activeWorkspace === center)
        XCTAssertTrue(updatedViewports[2].activeWorkspace === right)
    }

    func testDisabledMiddleZoneReflowsRemainingColumnsAndCanBeRestored() {
        let main = MonitorTopologyTestMonitor(
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
                monitor: .main,
                layout: .columns,
                defaultZone: "main",
                columns: [
                    ZoneColumnConfig(id: "left", name: "Reference", width: 0.25),
                    ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
                    ZoneColumnConfig(id: "right", name: "Comms", width: 0.25),
                ],
            ),
        ]

        XCTAssertEqual(workspaceViewports.map(\.zoneId), ["left", "main", "right"])
        assertRectsEqual(workspaceViewports.map(\.rect), [
            Rect(topLeftX: 0, topLeftY: 0, width: 300, height: 800),
            Rect(topLeftX: 300, topLeftY: 0, width: 600, height: 800),
            Rect(topLeftX: 900, topLeftY: 0, width: 300, height: 800),
        ])

        switch setZoneAvailability(.disable, selector: ZoneSelector("Work")) {
            case .success(let change):
                XCTAssertFalse(change.isEnabled)
                XCTAssertTrue(change.changed)
            case .failure(let msg):
                XCTFail(msg)
        }

        XCTAssertEqual(workspaceViewports.map(\.zoneId), ["left", "right"])
        assertRectsEqual(workspaceViewports.map(\.rect), [
            Rect(topLeftX: 0, topLeftY: 0, width: 600, height: 800),
            Rect(topLeftX: 600, topLeftY: 0, width: 600, height: 800),
        ])
        XCTAssertEqual(workspaceViewports.map(\.isMain), [true, false])

        switch setZoneAvailability(.enable, selector: ZoneSelector("main")) {
            case .success(let change):
                XCTAssertTrue(change.isEnabled)
                XCTAssertTrue(change.changed)
            case .failure(let msg):
                XCTFail(msg)
        }

        XCTAssertEqual(workspaceViewports.map(\.zoneId), ["left", "main", "right"])
        assertRectsEqual(workspaceViewports.map(\.rect), [
            Rect(topLeftX: 0, topLeftY: 0, width: 300, height: 800),
            Rect(topLeftX: 300, topLeftY: 0, width: 600, height: 800),
            Rect(topLeftX: 900, topLeftY: 0, width: 300, height: 800),
        ])
        XCTAssertEqual(workspaceViewports.map(\.isMain), [false, true, false])
    }

    func testMonitorViewportIdDecodesLegacyPointOnlyIdentity() throws {
        let data = #"{"topLeftCorner":[10,20]}"#.data(using: .utf8).orDie()

        let viewportId = try JSONDecoder().decode(MonitorViewportId.self, from: data)
        let encoded = try JSONEncoder().encode(viewportId)
        let encodedString = String(data: encoded, encoding: .utf8).orDie()

        XCTAssertEqual(viewportId.topLeftCorner, CGPoint(x: 10, y: 20))
        XCTAssertEqual(viewportId.stableIdentity, "physical:10.0,20.0")
        XCTAssertTrue(encodedString.contains("stableIdentity"))
    }

    func testPhysicalMonitorActiveWorkspaceDelegatesToDefaultZoneViewport() {
        let main = MonitorTopologyTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 900, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 25, width: 900, height: 775),
            isMain: true,
        )
        setMonitorsForTests([main])
        config.gaps = .zero
        config.workspaceSidebar.enabled = false
        setCurrentZoneTopologySnapshot(ZoneTopologySnapshot(config, environment: ["WINMUX_ZONES_SPIKE": "1"]))

        Workspace.reconcileWorkspaceState()
        let defaultZone = monitors.singleOrNil { $0.zoneId == "main" }.orDie()
        XCTAssertTrue(defaultZone.isDefaultZone)
        XCTAssertTrue(mainMonitor.activeWorkspace === defaultZone.activeWorkspace)
        XCTAssertEqual(mainMonitor.activeWorkspace.workspaceMonitor.zoneId, "main")

        let workspace = Workspace.get(byName: "default-zone-workspace")
        XCTAssertTrue(mainMonitor.setActiveWorkspace(workspace))
        XCTAssertTrue(defaultZone.activeWorkspace === workspace)
    }

    func testZoneLayoutUsesPhysicalOuterGapsAndSidebarInsetOnce() {
        let main = MonitorTopologyTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
            isMain: true,
        )
        setMonitorsForTests([main])
        config.gaps = Gaps(inner: .zero, outer: Gaps.Outer(left: 10, bottom: 40, top: 30, right: 20))
        config.workspaceSidebar.enabled = true
        config.workspaceSidebar.collapsedWidth = 50
        config.workspaceSidebar.monitor = [.main]
        config.zones = [
            ZoneConfig(
                monitor: .main,
                layout: .columns,
                defaultZone: "left",
                columns: [
                    ZoneColumnConfig(id: "left", width: 0.50),
                    ZoneColumnConfig(id: "right", width: 0.50),
                ],
            ),
        ]

        let viewports = monitors

        assertRectsEqual(viewports.map(\.rect), [
            Rect(topLeftX: 60, topLeftY: 30, width: 460, height: 730),
            Rect(topLeftX: 520, topLeftY: 30, width: 460, height: 730),
        ])
        assertRectsEqual(viewports.map(\.visibleRectPaddedByOuterGaps), viewports.map(\.rect))
    }
}
