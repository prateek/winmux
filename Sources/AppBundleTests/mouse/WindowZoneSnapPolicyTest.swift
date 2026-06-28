@testable import AppBundle
import AppKit
import CoreGraphics
import XCTest

@MainActor
final class WindowZoneSnapPolicyTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testFreeformPolicySuppressesZoneDragDestinations() {
        let fixture = configureZoneSnapFixture()
        config.mouse.zoneSnap.policy = .freeform

        let resolution = zoneSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: fixture.commsMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: fixture.commsMonitor.rect.center,
            subject: .window,
            detachOrigin: .window,
            modifierFlags: .maskAlternate,
        )

        guard case .suppressDefaultDestinations = resolution else {
            XCTFail("Expected freeform zone drag to suppress snap destinations")
            return
        }
    }

    func testSnapOnModifierRequiresConfiguredModifier() {
        let fixture = configureZoneSnapFixture()
        config.mouse.zoneSnap.policy = .snapOnModifier
        config.mouse.zoneSnap.modifier = [.option, .shift]

        let withoutShift = zoneSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: fixture.commsMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: fixture.commsMonitor.rect.center,
            subject: .window,
            detachOrigin: .window,
            modifierFlags: .maskAlternate,
        )
        guard case .suppressDefaultDestinations = withoutShift else {
            XCTFail("Expected missing modifier to suppress zone snap")
            return
        }

        let withShift = zoneSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: fixture.commsMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: fixture.commsMonitor.rect.center,
            subject: .window,
            detachOrigin: .window,
            modifierFlags: [.maskAlternate, .maskShift],
        )
        guard case .use(let destination) = withShift else {
            XCTFail("Expected configured modifier to produce a zone snap destination")
            return
        }
        XCTAssertEqual(destination.kind, .moveToZone(zoneId: "right", workspaceName: "comms"))
        XCTAssertEqual(destination.previewRect.topLeftX, fixture.commsMonitor.rect.topLeftX)
        XCTAssertEqual(destination.previewRect.width, fixture.commsMonitor.rect.width)
        XCTAssertEqual(destination.dropIntentOverlay?.activeZone, nil)
    }

    func testSnapToZoneDoesNotRequireModifier() {
        let fixture = configureZoneSnapFixture()
        config.mouse.zoneSnap.policy = .snapToZone

        let resolution = zoneSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: fixture.commsMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: fixture.commsMonitor.rect.center,
            subject: .window,
            detachOrigin: .window,
            modifierFlags: [],
        )

        guard case .use(let destination) = resolution else {
            XCTFail("Expected snap-to-zone to create a destination without a modifier")
            return
        }
        XCTAssertEqual(destination.kind, .moveToZone(zoneId: "right", workspaceName: "comms"))
        XCTAssertEqual(destination.dropIntentOverlay?.activeZone, nil)
    }

    func testFloatUnlessSnapRequiresConfiguredModifier() {
        let fixture = configureZoneSnapFixture()
        config.mouse.zoneSnap.policy = .floatUnlessSnap
        config.mouse.zoneSnap.modifier = .option

        let withoutModifier = zoneSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: fixture.commsMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: fixture.commsMonitor.rect.center,
            subject: .window,
            detachOrigin: .window,
            modifierFlags: [],
        )
        guard case .suppressDefaultDestinations = withoutModifier else {
            XCTFail("Expected float-unless-snap to suppress zone snap without the configured modifier")
            return
        }

        let withModifier = zoneSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: fixture.commsMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: fixture.commsMonitor.rect.center,
            subject: .window,
            detachOrigin: .window,
            modifierFlags: .maskAlternate,
        )
        guard case .use(let destination) = withModifier else {
            XCTFail("Expected float-unless-snap to create a zone snap destination when the modifier is held")
            return
        }
        XCTAssertEqual(destination.kind, .moveToZone(zoneId: "right", workspaceName: "comms"))
    }

    func testFloatUnlessSnapNoModifierFloatsTilingWindowInTargetZoneWorkspace() {
        let fixture = configureZoneSnapFixture()
        config.mouse.zoneSnap.policy = .floatUnlessSnap
        config.mouse.zoneSnap.modifier = .option

        XCTAssertFalse(fixture.window.isFloating)

        let didFloat = floatTilingWindowForMouseDragIfNeeded(
            window: fixture.window,
            targetWorkspace: fixture.comms,
            subject: .window,
            modifierFlags: [],
        )

        XCTAssertTrue(didFloat)
        XCTAssertTrue(fixture.window.isFloating)
        XCTAssertTrue((fixture.window.parent as? Workspace) === fixture.comms)
        XCTAssertTrue(fixture.comms.floatingWindows.contains { $0 === fixture.window })
        XCTAssertFalse(fixture.work.floatingWindows.contains { $0 === fixture.window })
    }

    func testFloatUnlessSnapHeldModifierKeepsTilingWindowEligibleForSnap() {
        let fixture = configureZoneSnapFixture()
        config.mouse.zoneSnap.policy = .floatUnlessSnap
        config.mouse.zoneSnap.modifier = .option

        let didFloat = floatTilingWindowForMouseDragIfNeeded(
            window: fixture.window,
            targetWorkspace: fixture.comms,
            subject: .window,
            modifierFlags: .maskAlternate,
        )

        XCTAssertFalse(didFloat)
        XCTAssertFalse(fixture.window.isFloating)
        XCTAssertTrue(fixture.window.nodeWorkspace === fixture.work)
    }

    func testMoveTilingWindowForMouseDragFloatsAndStartsMoveWithoutSnapModifier() {
        let fixture = configureZoneSnapFixture()
        config.mouse.zoneSnap.policy = .floatUnlessSnap
        config.mouse.zoneSnap.modifier = .option
        let anchorRect = Rect(topLeftX: 10, topLeftY: 20, width: 300, height: 180)
        fixture.window.lastAppliedLayoutPhysicalRect = anchorRect
        var beginCalls: [MouseMoveBeginCall] = []
        var startCalls: [MouseMoveStartCall] = []

        moveTilingWindowForMouseDrag(
            window: fixture.window,
            targetWorkspace: fixture.comms,
            subject: .window,
            anchorRect: anchorRect,
            modifierFlags: [],
            beginSession: { windowId, subject, detachOrigin, startedInSidebar, anchorRect, refreshActualRects in
                beginCalls.append(MouseMoveBeginCall(
                    windowId: windowId,
                    subject: subject,
                    detachOrigin: detachOrigin,
                    startedInSidebar: startedInSidebar,
                    anchorRect: anchorRect,
                    refreshActualRects: refreshActualRects,
                ))
                return true
            },
            startMove: { windowId, subject, detachOrigin, startedInSidebar in
                startCalls.append(MouseMoveStartCall(
                    windowId: windowId,
                    subject: subject,
                    detachOrigin: detachOrigin,
                    startedInSidebar: startedInSidebar,
                ))
            },
        )

        XCTAssertTrue(fixture.window.isFloating)
        XCTAssertTrue((fixture.window.parent as? Workspace) === fixture.comms)
        XCTAssertNil(fixture.window.lastAppliedLayoutPhysicalRect)
        XCTAssertEqual(beginCalls.count, 1)
        XCTAssertEqual(beginCalls.first?.windowId, fixture.window.windowId)
        XCTAssertEqual(beginCalls.first?.subject, .window)
        XCTAssertEqual(beginCalls.first?.detachOrigin, .window)
        XCTAssertEqual(beginCalls.first?.startedInSidebar, false)
        XCTAssertEqual(beginCalls.first?.refreshActualRects, false)
        XCTAssertEqual(beginCalls.first?.anchorRect?.topLeftX, anchorRect.topLeftX)
        XCTAssertEqual(startCalls.count, 1)
        XCTAssertEqual(startCalls.first?.windowId, fixture.window.windowId)
        XCTAssertEqual(startCalls.first?.subject, .window)
        XCTAssertEqual(startCalls.first?.detachOrigin, .window)
        XCTAssertEqual(startCalls.first?.startedInSidebar, false)
    }

    func testMoveTilingWindowForMouseDragWithSnapModifierUsesNormalMovePath() {
        let fixture = configureZoneSnapFixture()
        config.mouse.zoneSnap.policy = .floatUnlessSnap
        config.mouse.zoneSnap.modifier = .option
        let anchorRect = Rect(topLeftX: 10, topLeftY: 20, width: 300, height: 180)
        fixture.window.lastAppliedLayoutPhysicalRect = anchorRect
        var beginCalls: [MouseMoveBeginCall] = []
        var startCalls: [MouseMoveStartCall] = []

        moveTilingWindowForMouseDrag(
            window: fixture.window,
            targetWorkspace: fixture.comms,
            subject: .window,
            anchorRect: anchorRect,
            modifierFlags: .maskAlternate,
            beginSession: { windowId, subject, detachOrigin, startedInSidebar, anchorRect, refreshActualRects in
                beginCalls.append(MouseMoveBeginCall(
                    windowId: windowId,
                    subject: subject,
                    detachOrigin: detachOrigin,
                    startedInSidebar: startedInSidebar,
                    anchorRect: anchorRect,
                    refreshActualRects: refreshActualRects,
                ))
                return true
            },
            startMove: { windowId, subject, detachOrigin, startedInSidebar in
                startCalls.append(MouseMoveStartCall(
                    windowId: windowId,
                    subject: subject,
                    detachOrigin: detachOrigin,
                    startedInSidebar: startedInSidebar,
                ))
            },
        )

        XCTAssertFalse(fixture.window.isFloating)
        XCTAssertTrue(fixture.window.nodeWorkspace === fixture.work)
        XCTAssertNil(fixture.window.lastAppliedLayoutPhysicalRect)
        XCTAssertEqual(beginCalls.count, 1)
        XCTAssertEqual(beginCalls.first?.windowId, fixture.window.windowId)
        XCTAssertEqual(beginCalls.first?.subject, .window)
        XCTAssertEqual(beginCalls.first?.detachOrigin, .window)
        XCTAssertEqual(beginCalls.first?.startedInSidebar, false)
        XCTAssertEqual(beginCalls.first?.refreshActualRects, true)
        XCTAssertEqual(startCalls.count, 1)
        XCTAssertEqual(startCalls.first?.windowId, fixture.window.windowId)
        XCTAssertEqual(startCalls.first?.subject, .window)
        XCTAssertEqual(startCalls.first?.detachOrigin, .window)
        XCTAssertEqual(startCalls.first?.startedInSidebar, false)
    }

    func testFloatUnlessSnapDoesNotFloatGroupDrags() {
        let fixture = configureZoneSnapFixture()
        config.mouse.zoneSnap.policy = .floatUnlessSnap
        config.mouse.zoneSnap.modifier = .option

        let didFloat = floatTilingWindowForMouseDragIfNeeded(
            window: fixture.window,
            targetWorkspace: fixture.comms,
            subject: .group,
            modifierFlags: [],
        )
        XCTAssertFalse(didFloat)
        XCTAssertFalse(fixture.window.isFloating)
    }

    func testFloatUnlessSnapDoesNotFloatOnNonZoneMonitor() {
        setUpWorkspacesForTests()
        let monitor = TestMonitor(
            monitorAppKitNsScreenScreensId: 11,
            name: "Plain",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
            isMain: true,
        )
        setMonitorsForTests([monitor])
        config.mouse.zoneSnap.policy = .floatUnlessSnap
        config.mouse.zoneSnap.modifier = .option

        let sourceWorkspace = Workspace.get(byName: "source")
        XCTAssertTrue(monitor.setActiveWorkspace(sourceWorkspace))
        let window = TestWindow.new(id: 20, parent: sourceWorkspace.rootTilingContainer)
        let targetWorkspace = Workspace.get(byName: "target")
        XCTAssertTrue(monitor.setActiveWorkspace(targetWorkspace))
        XCTAssertNil(targetWorkspace.workspaceMonitor.zoneId)

        let didFloat = floatTilingWindowForMouseDragIfNeeded(
            window: window,
            targetWorkspace: targetWorkspace,
            subject: .window,
            modifierFlags: [],
        )

        XCTAssertFalse(didFloat)
        XCTAssertFalse(window.isFloating)
        XCTAssertTrue(window.nodeWorkspace === sourceWorkspace)
    }

    func testZoneSnapDoesNotInterceptTabStripOrNonZoneDrags() {
        let fixture = configureZoneSnapFixture()
        config.mouse.zoneSnap.policy = .snapToZone

        let tabStrip = zoneSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: fixture.commsMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: fixture.commsMonitor.rect.center,
            subject: .window,
            detachOrigin: .tabStrip,
            modifierFlags: [],
        )
        guard case .allowDefaultDestinations = tabStrip else {
            XCTFail("Expected tab-strip drags to keep existing destination behavior")
            return
        }

        let physicalMonitor = fixture.commsMonitor.physicalMonitor
        let nonZone = zoneSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: physicalMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: physicalMonitor.rect.center,
            subject: .window,
            detachOrigin: .window,
            modifierFlags: [],
        )
        guard case .allowDefaultDestinations = nonZone else {
            XCTFail("Expected non-zone monitors to keep existing destination behavior")
            return
        }
    }

    func testRuntimePolicyOverrideChangesDragResolutionWithoutChangingConfig() {
        let fixture = configureZoneSnapFixture()
        config.mouse.zoneSnap.policy = .freeform

        assertZoneSnapPolicyOverride(.snapToZone, for: fixture.commsMonitor.physicalMonitor)

        XCTAssertEqual(config.mouse.zoneSnap.policy, .freeform)
        let resolution = zoneSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: fixture.commsMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: fixture.commsMonitor.rect.center,
            subject: .window,
            detachOrigin: .window,
            modifierFlags: [],
        )

        guard case .use(let destination) = resolution else {
            XCTFail("Expected runtime snap-to-zone override to create a zone snap destination")
            return
        }
        XCTAssertEqual(destination.kind, .moveToZone(zoneId: "right", workspaceName: "comms"))
    }

    func testRuntimePolicyOverridePreservesConfiguredModifier() {
        let fixture = configureZoneSnapFixture()
        config.mouse.zoneSnap.policy = .freeform
        config.mouse.zoneSnap.modifier = .shift

        assertZoneSnapPolicyOverride(.snapOnModifier, for: fixture.commsMonitor.physicalMonitor)

        let withoutShift = zoneSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: fixture.commsMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: fixture.commsMonitor.rect.center,
            subject: .window,
            detachOrigin: .window,
            modifierFlags: .maskAlternate,
        )
        guard case .suppressDefaultDestinations = withoutShift else {
            XCTFail("Expected runtime snap-on-modifier override to preserve configured Shift modifier")
            return
        }

        let withShift = zoneSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: fixture.commsMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: fixture.commsMonitor.rect.center,
            subject: .window,
            detachOrigin: .window,
            modifierFlags: .maskShift,
        )
        guard case .use(let destination) = withShift else {
            XCTFail("Expected configured Shift modifier to activate runtime snap-on-modifier override")
            return
        }
        XCTAssertEqual(destination.kind, .moveToZone(zoneId: "right", workspaceName: "comms"))
    }
}

private struct ZoneSnapFixture {
    let work: Workspace
    let comms: Workspace
    let commsMonitor: Monitor
    let window: Window
}

private struct MouseMoveBeginCall {
    let windowId: UInt32
    let subject: WindowDragSubject
    let detachOrigin: TabDetachOrigin
    let startedInSidebar: Bool
    let anchorRect: Rect?
    let refreshActualRects: Bool
}

private struct MouseMoveStartCall {
    let windowId: UInt32
    let subject: WindowDragSubject
    let detachOrigin: TabDetachOrigin
    let startedInSidebar: Bool
}

@MainActor
private func configureZoneSnapFixture() -> ZoneSnapFixture {
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
            defaultZone: "main",
            columns: [
                ZoneColumnConfig(id: "left", name: "Reference", width: 0.25),
                ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
                ZoneColumnConfig(id: "right", name: "Comms", width: 0.25),
            ],
        ),
    ]

    let work = Workspace.get(byName: "work")
    let comms = Workspace.get(byName: "comms")
    let zonesById = Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.zoneId.map { ($0, monitor) }
    })
    XCTAssertTrue(zonesById["main"].orDie().setActiveWorkspace(work))
    XCTAssertTrue(zonesById["right"].orDie().setActiveWorkspace(comms))
    let window = TestWindow.new(id: 901, parent: work.rootTilingContainer)
    return ZoneSnapFixture(
        work: work,
        comms: comms,
        commsMonitor: zonesById["right"].orDie(),
        window: window,
    )
}

@MainActor
private func assertZoneSnapPolicyOverride(
    _ policy: ZoneSnapPolicy,
    for monitor: Monitor,
    file: StaticString = #filePath,
    line: UInt = #line,
) {
    switch setZoneSnapPolicy(policy, for: monitor) {
        case .success:
            break
        case .failure(let message):
            XCTFail(message, file: file, line: line)
    }
}
