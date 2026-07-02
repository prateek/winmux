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

private func threeColumnZoneConfig(monitor: MonitorDescription = .main, defaultZone: String = "main") -> ZoneConfig {
    ZoneConfig(
        monitor: monitor,
        layout: .columns,
        defaultZone: defaultZone,
        columns: [
            ZoneColumnConfig(id: "left", name: "Left", width: 1.0 / 3.0),
            ZoneColumnConfig(id: "main", name: "Main", width: 1.0 / 3.0),
            ZoneColumnConfig(id: "right", name: "Right", width: 1.0 / 3.0),
        ],
    )
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

    func testZonesAreDisabledWithoutExplicitConfig() {
        let main = MonitorTopologyTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 900, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 900, height: 800),
            isMain: true,
        )
        setMonitorsForTests([main])

        XCTAssertEqual(workspaceViewports.count, 1)
        XCTAssertNil(workspaceViewports[0].zoneId)
        assertRectsEqual(workspaceViewports.map(\.rect), [main.rect])
    }

    func testExplicitConfigSplitsMainMonitorIntoThreeColumns() {
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
        config.zones = [threeColumnZoneConfig()]

        XCTAssertEqual(workspaceViewports.map(\.zoneId), ["left", "main", "right"])
        XCTAssertEqual(monitors.map(\.zoneId), workspaceViewports.map(\.zoneId))
        assertRectsEqual(workspaceViewports.map(\.rect), [
            Rect(topLeftX: 0, topLeftY: 0, width: 300, height: 800),
            Rect(topLeftX: 300, topLeftY: 0, width: 300, height: 800),
            Rect(topLeftX: 600, topLeftY: 0, width: 300, height: 800),
        ])
        XCTAssertEqual(workspaceViewports.map(\.isMain), [false, true, false])
    }

    func testExplicitConfigViewportsCanShowIndependentWorkspaces() {
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
        config.zones = [threeColumnZoneConfig()]
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
        XCTAssertTrue(originalViewports[1].activeWorkspace === center)
        XCTAssertTrue(originalViewports[2].activeWorkspace === right)
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

    func testZoneWorkspacesSurviveDisplayIdChurnAndResolutionChange() {
        let originalUltrawide = MonitorTopologyTestMonitor(
            monitorAppKitNsScreenScreensId: 7,
            name: "Studio Ultrawide",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 3440, height: 1440),
            visibleRect: Rect(topLeftX: 0, topLeftY: 24, width: 3440, height: 1416),
            isMain: true,
        )
        setMonitorsForTests([originalUltrawide])
        config.gaps = .zero
        config.workspaceSidebar.enabled = false
        config.zones = [
            ZoneConfig(
                monitor: MonitorDescription.caseSensitivePattern("Studio Ultrawide"),
                layout: .columns,
                defaultZone: "main",
                columns: [
                    ZoneColumnConfig(id: "left", name: "Reference", width: 0.20),
                    ZoneColumnConfig(id: "main", name: "Work", width: 0.60),
                    ZoneColumnConfig(id: "right", name: "Comms", width: 0.20),
                ],
            ),
        ]
        let originalViewports = workspaceViewports
        XCTAssertEqual(originalViewports.map(\.zoneId), ["left", "main", "right"])
        XCTAssertEqual(originalViewports.map(\.monitorAppKitNsScreenScreensId), [7, 7, 7])

        let reference = Workspace.get(byName: "reference-after-id-churn")
        let work = Workspace.get(byName: "work-after-id-churn")
        let comms = Workspace.get(byName: "comms-after-id-churn")
        XCTAssertTrue(originalViewports[0].setActiveWorkspace(reference))
        XCTAssertTrue(originalViewports[1].setActiveWorkspace(work))
        XCTAssertTrue(originalViewports[2].setActiveWorkspace(comms))

        let returnedUltrawide = MonitorTopologyTestMonitor(
            monitorAppKitNsScreenScreensId: 42,
            name: "Studio Ultrawide",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 3000, height: 1200),
            visibleRect: Rect(topLeftX: 0, topLeftY: 24, width: 3000, height: 1176),
            isMain: true,
        )
        setMonitorsForTests([returnedUltrawide])
        Workspace.reconcileWorkspaceState()
        let returnedViewports = workspaceViewports

        XCTAssertEqual(returnedViewports.map(\.zoneId), ["left", "main", "right"])
        XCTAssertEqual(returnedViewports.map(\.monitorAppKitNsScreenScreensId), [42, 42, 42])
        XCTAssertEqual(returnedViewports.map(\.physicalMonitor.name), ["Studio Ultrawide", "Studio Ultrawide", "Studio Ultrawide"])
        assertRectsEqual(returnedViewports.map(\.rect), [
            Rect(topLeftX: 0, topLeftY: 24, width: 600, height: 1176),
            Rect(topLeftX: 600, topLeftY: 24, width: 1800, height: 1176),
            Rect(topLeftX: 2400, topLeftY: 24, width: 600, height: 1176),
        ])
        XCTAssertTrue(MonitorViewportId(originalViewports[0]).hasSameStableIdentity(as: MonitorViewportId(returnedViewports[0])))
        XCTAssertTrue(MonitorViewportId(originalViewports[1]).hasSameStableIdentity(as: MonitorViewportId(returnedViewports[1])))
        XCTAssertTrue(MonitorViewportId(originalViewports[2]).hasSameStableIdentity(as: MonitorViewportId(returnedViewports[2])))
        XCTAssertTrue(returnedViewports[0].activeWorkspace === reference)
        XCTAssertTrue(returnedViewports[1].activeWorkspace === work)
        XCTAssertTrue(returnedViewports[2].activeWorkspace === comms)
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
        XCTAssertEqual(
            getCurrentZoneTopologySnapshot().configuredZones(for: sortedPhysicalMonitors).map { "\($0.zoneId):\($0.isDefaultZone):\($0.isEnabled)" },
            ["left:true:true", "main:false:false", "right:false:true"],
        )

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
        config.zones = [threeColumnZoneConfig()]

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

    func testZoneHiddenWindowParkingUsesPhysicalMonitorBoundary() {
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
                    ZoneColumnConfig(id: "left", width: 1),
                    ZoneColumnConfig(id: "main", width: 1),
                    ZoneColumnConfig(id: "right", width: 1),
                ],
            ),
        ]

        for zone in monitors {
            let rightPoint = hiddenWindowTopLeft(
                corner: .bottomRightCorner,
                monitor: zone,
                windowSize: nil,
                isZoom: false,
            )
            let leftPoint = hiddenWindowTopLeft(
                corner: .bottomLeftCorner,
                monitor: zone,
                windowSize: CGSize(width: 250, height: 300),
                isZoom: false,
            )

            XCTAssertEqual(rightPoint.x, 1199, "right parking should use the physical monitor edge for \(zone.zoneId ?? "unknown")")
            XCTAssertEqual(rightPoint.y, 799, "right parking should use the physical monitor edge for \(zone.zoneId ?? "unknown")")
            XCTAssertEqual(leftPoint.x, -249, "left parking should use the physical monitor edge and window width for \(zone.zoneId ?? "unknown")")
            XCTAssertEqual(leftPoint.y, 799, "left parking should use the physical monitor edge for \(zone.zoneId ?? "unknown")")
        }
    }
}
