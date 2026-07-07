@testable import AppBundle
import AppKit
import CoreGraphics
import XCTest

@MainActor
final class WindowColumnSnapPolicyTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testFreeformPolicySuppressesZoneDragDestinations() {
        let fixture = configureZoneSnapFixture()
        config.mouse.columnSnap.policy = .freeform

        let resolution = columnSnapDestinationResolution(
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
        config.mouse.columnSnap.policy = .snapOnModifier
        config.mouse.columnSnap.modifier = [.option, .shift]

        let withoutShift = columnSnapDestinationResolution(
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

        let withShift = columnSnapDestinationResolution(
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
        XCTAssertEqual(destination.kind, .moveToZone(columnId: "right", workspaceName: "comms"))
        XCTAssertEqual(destination.previewRect.topLeftX, fixture.commsMonitor.rect.topLeftX)
        XCTAssertEqual(destination.previewRect.width, fixture.commsMonitor.rect.width)
        XCTAssertEqual(destination.dropIntentOverlay?.activeZone, nil)
        XCTAssertEqual(destination.dropIntentOverlay?.label, "Whole column: Comms")
        XCTAssertEqual(destination.dropIntentOverlay?.detail, "Drop to move to Comms")
    }

    func testSnapToColumnDoesNotRequireModifier() {
        let fixture = configureZoneSnapFixture()
        config.mouse.columnSnap.policy = .snapToColumn

        let resolution = columnSnapDestinationResolution(
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
            XCTFail("Expected snap-to-column to create a destination without a modifier")
            return
        }
        XCTAssertEqual(destination.kind, .moveToZone(columnId: "right", workspaceName: "comms"))
        XCTAssertEqual(destination.dropIntentOverlay?.activeZone, nil)
        XCTAssertEqual(destination.dropIntentOverlay?.label, "Whole column: Comms")
    }

    func testActiveZoneGridOverlayDoesNotRequireProductLabel() {
        let overlay = WindowDropIntentOverlayModel(
            targetFrame: Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600),
            activeZone: .right,
            cornerRadius: nil,
        )

        XCTAssertNil(overlay.label)
        XCTAssertNil(overlay.detail)
    }

    func testWindowTargetRequiresActivationAndAllowsOnlyWindowDestinations() {
        let fixture = configureZoneSnapFixture()
        config.mouse.columnSnap.policy = .floatUnlessSnap
        config.mouse.columnSnap.gesture = .secondaryButtonDrag
        config.mouse.columnSnap.target = .window
        let secondaryButtonMask = mouseButtonMask(buttonNumber: 1)

        let inactive = columnSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: fixture.commsMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: fixture.commsMonitor.rect.center,
            subject: .window,
            detachOrigin: .window,
            modifierFlags: [],
            pressedMouseButtons: 0,
        )
        guard case .suppressDefaultDestinations = inactive else {
            XCTFail("Expected inactive window snap target to suppress snap destinations")
            return
        }

        let active = columnSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: fixture.commsMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: fixture.commsMonitor.rect.center,
            subject: .window,
            detachOrigin: .window,
            modifierFlags: [],
            pressedMouseButtons: secondaryButtonMask,
        )
        guard case .allowWindowDestinationsOnly = active else {
            XCTFail("Expected active window snap target to allow only target-window destinations")
            return
        }
    }

    func testWindowTargetDoesNotProduceWholeZoneDestinationWhenActive() {
        let fixture = configureZoneSnapFixture()
        config.mouse.columnSnap.policy = .snapToColumn
        config.mouse.columnSnap.target = .window

        let resolution = columnSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: fixture.commsMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: fixture.commsMonitor.rect.center,
            subject: .window,
            detachOrigin: .window,
            modifierFlags: [],
        )

        guard case .allowWindowDestinationsOnly = resolution else {
            XCTFail("Expected target=window to avoid whole-column moveToZone destination")
            return
        }
    }

    func testWindowSlotOverlayLabelIsOnlyAddedForActiveWindowTargetPath() {
        let fixture = configureZoneSnapFixture()
        let targetFrame = Rect(topLeftX: 900, topLeftY: 100, width: 220, height: 240)
        let targetWindow = TestWindow.new(
            id: 902,
            parent: fixture.comms.rootTilingContainer,
            rect: targetFrame,
            title: "target-window.rtf",
        )
        let pointer = CGPoint(x: targetFrame.maxX - 12, y: targetFrame.center.y)
        guard let resolution = WindowDropIntentResolver().resolve(
            sourceWindowId: fixture.window.windowId,
            targetWindowId: targetWindow.windowId,
            pointer: pointer,
            targetFrame: targetFrame,
        ) else {
            XCTFail("Expected pointer to resolve to the right target-window slot")
            return
        }
        XCTAssertEqual(resolution.intent.zone, .right)

        let unlabeled = destinationFromWindowDropIntent(
            resolution,
            sourceWindow: fixture.window,
            targetWindow: targetWindow,
            mouseLocation: pointer,
            subject: .window,
            detachOrigin: .window,
        )
        XCTAssertNil(unlabeled?.dropIntentOverlay?.label)
        XCTAssertNil(unlabeled?.dropIntentOverlay?.detail)

        let labeled = destinationFromWindowDropIntent(
            resolution,
            sourceWindow: fixture.window,
            targetWindow: targetWindow,
            mouseLocation: pointer,
            subject: .window,
            detachOrigin: .window,
            labelWindowSlot: true,
        )
        XCTAssertEqual(labeled?.kind, .stackSplit(targetWindowId: targetWindow.windowId, position: .right))
        XCTAssertEqual(labeled?.dropIntentOverlay?.activeZone, .right)
        XCTAssertEqual(labeled?.dropIntentOverlay?.label, "Window slot: Right")
        XCTAssertEqual(labeled?.dropIntentOverlay?.detail, "Drop to split this window")
    }

    func testWindowTargetLookupAllowsSameWorkspaceWindowSlotWithoutWholeZoneLeak() {
        let fixture = configureZoneSnapFixture()
        config.mouse.columnSnap.policy = .snapToColumn
        config.mouse.columnSnap.target = .window

        let targetFrame = Rect(
            topLeftX: fixture.workMonitor.rect.topLeftX + 180,
            topLeftY: fixture.workMonitor.rect.topLeftY + 120,
            width: 260,
            height: 240,
        )
        let targetWindow = TestWindow.new(
            id: 904,
            parent: fixture.work.rootTilingContainer,
            rect: targetFrame,
            title: "same-workspace-target.rtf",
        )
        let pointer = CGPoint(x: targetFrame.maxX - 12, y: targetFrame.center.y)

        let destination = currentWindowDragIntentDestination(
            sourceWindow: fixture.window,
            mouseLocation: pointer,
            subject: .window,
            detachOrigin: .window,
        )

        XCTAssertEqual(destination?.kind, .stackSplit(targetWindowId: targetWindow.windowId, position: .right))
        XCTAssertEqual(destination?.dropIntentOverlay?.activeZone, .right)
        XCTAssertEqual(destination?.dropIntentOverlay?.label, "Window slot: Right")
        XCTAssertEqual(destination?.dropIntentOverlay?.detail, "Drop to split this window")
        XCTAssertNotEqual(destination?.kind, .moveToZone(columnId: "main", workspaceName: fixture.work.name))
        XCTAssertNotEqual(destination?.kind, .moveToWorkspace(workspaceName: fixture.work.name))
    }

    func testFloatUnlessSnapRequiresConfiguredModifier() {
        let fixture = configureZoneSnapFixture()
        config.mouse.columnSnap.policy = .floatUnlessSnap
        config.mouse.columnSnap.modifier = .option
        config.mouse.columnSnap.gesture = .drag // template default is secondary-button-drag; this case tests the plain drag

        let withoutModifier = columnSnapDestinationResolution(
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

        let withModifier = columnSnapDestinationResolution(
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
        XCTAssertEqual(destination.kind, .moveToZone(columnId: "right", workspaceName: "comms"))
    }

    func testFloatUnlessSnapSecondaryButtonGestureIgnoresAltUntilButtonPressed() {
        let fixture = configureZoneSnapFixture()
        config.mouse.columnSnap.policy = .floatUnlessSnap
        config.mouse.columnSnap.modifier = .option
        config.mouse.columnSnap.gesture = .secondaryButtonDrag

        let withoutButton = columnSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: fixture.commsMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: fixture.commsMonitor.rect.center,
            subject: .window,
            detachOrigin: .window,
            modifierFlags: .maskAlternate,
            pressedMouseButtons: 0,
        )
        guard case .suppressDefaultDestinations = withoutButton else {
            XCTFail("Expected secondary-button gesture to ignore Alt alone")
            return
        }

        let didFloat = floatTilingWindowForMouseDragIfNeeded(
            window: fixture.window,
            targetWorkspace: fixture.comms,
            subject: .window,
            modifierFlags: .maskAlternate,
            pressedMouseButtons: 0,
        )
        XCTAssertTrue(didFloat)
        XCTAssertTrue(fixture.window.isFloating)
    }

    func testFloatUnlessSnapSecondaryButtonGestureActivatesWholeZoneSnapWithoutModifier() {
        let fixture = configureZoneSnapFixture()
        config.mouse.columnSnap.policy = .floatUnlessSnap
        config.mouse.columnSnap.modifier = .option
        config.mouse.columnSnap.gesture = .secondaryButtonDrag
        let secondaryButtonMask = mouseButtonMask(buttonNumber: 1)

        let didFloat = floatTilingWindowForMouseDragIfNeeded(
            window: fixture.window,
            targetWorkspace: fixture.comms,
            subject: .window,
            modifierFlags: [],
            pressedMouseButtons: secondaryButtonMask,
        )
        XCTAssertFalse(didFloat)
        XCTAssertFalse(fixture.window.isFloating)

        let resolution = columnSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: fixture.commsMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: fixture.commsMonitor.rect.center,
            subject: .window,
            detachOrigin: .window,
            modifierFlags: [],
            pressedMouseButtons: secondaryButtonMask,
        )
        guard case .use(let destination) = resolution else {
            XCTFail("Expected secondary-button gesture to activate a whole-column snap destination")
            return
        }
        XCTAssertEqual(destination.kind, .moveToZone(columnId: "right", workspaceName: "comms"))
        XCTAssertEqual(destination.dropIntentOverlay?.label, "Whole column: Comms")
    }

    func testSnapOnModifierRemainsModifierDrivenWhenGestureIsSecondaryButtonDrag() {
        let fixture = configureZoneSnapFixture()
        config.mouse.columnSnap.policy = .snapOnModifier
        config.mouse.columnSnap.modifier = .option
        config.mouse.columnSnap.gesture = .secondaryButtonDrag
        let secondaryButtonMask = mouseButtonMask(buttonNumber: 1)

        let buttonOnly = columnSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: fixture.commsMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: fixture.commsMonitor.rect.center,
            subject: .window,
            detachOrigin: .window,
            modifierFlags: [],
            pressedMouseButtons: secondaryButtonMask,
        )
        guard case .suppressDefaultDestinations = buttonOnly else {
            XCTFail("Expected snap-on-modifier to ignore secondary button alone")
            return
        }

        let altOnly = columnSnapDestinationResolution(
            sourceWindow: fixture.window,
            targetMonitor: fixture.commsMonitor,
            targetWorkspace: fixture.comms,
            sourceWorkspace: fixture.work,
            mouseLocation: fixture.commsMonitor.rect.center,
            subject: .window,
            detachOrigin: .window,
            modifierFlags: .maskAlternate,
            pressedMouseButtons: 0,
        )
        guard case .use(let destination) = altOnly else {
            XCTFail("Expected snap-on-modifier to remain driven by the configured modifier")
            return
        }
        XCTAssertEqual(destination.kind, .moveToZone(columnId: "right", workspaceName: "comms"))
    }

    func testFloatUnlessSnapNoModifierFloatsTilingWindowInTargetZoneWorkspace() {
        let fixture = configureZoneSnapFixture()
        config.mouse.columnSnap.policy = .floatUnlessSnap
        config.mouse.columnSnap.modifier = .option

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

    func testFloatUnlessSnapWindowTargetWithoutActivationFloatsInCurrentZoneWorkspace() {
        let fixture = configureZoneSnapFixture()
        config.mouse.columnSnap.policy = .floatUnlessSnap
        config.mouse.columnSnap.gesture = .secondaryButtonDrag
        config.mouse.columnSnap.target = .window

        let didFloat = floatTilingWindowForMouseDragIfNeeded(
            window: fixture.window,
            targetWorkspace: fixture.work,
            subject: .window,
            modifierFlags: [],
            pressedMouseButtons: 0,
        )

        XCTAssertTrue(didFloat)
        XCTAssertTrue(fixture.window.isFloating)
        XCTAssertTrue((fixture.window.parent as? Workspace) === fixture.work)
        XCTAssertTrue(fixture.work.floatingWindows.contains { $0 === fixture.window })
    }

    func testFloatUnlessSnapHeldModifierKeepsTilingWindowEligibleForSnap() {
        let fixture = configureZoneSnapFixture()
        config.mouse.columnSnap.policy = .floatUnlessSnap
        config.mouse.columnSnap.modifier = .option
        config.mouse.columnSnap.gesture = .drag // template default is secondary-button-drag; this case tests the plain drag

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
        config.mouse.columnSnap.policy = .floatUnlessSnap
        config.mouse.columnSnap.modifier = .option
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
        config.mouse.columnSnap.policy = .floatUnlessSnap
        config.mouse.columnSnap.modifier = .option
        config.mouse.columnSnap.gesture = .drag // template default is secondary-button-drag; this case tests the plain drag
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
        config.mouse.columnSnap.policy = .floatUnlessSnap
        config.mouse.columnSnap.modifier = .option

        let didFloat = floatTilingWindowForMouseDragIfNeeded(
            window: fixture.window,
            targetWorkspace: fixture.comms,
            subject: .group,
            modifierFlags: [],
        )
        XCTAssertFalse(didFloat)
        XCTAssertFalse(fixture.window.isFloating)
    }

    func testFloatUnlessSnapDoesNotFloatOnNonColumnMonitor() {
        setUpWorkspacesForTests()
        let monitor = TestMonitor(
            monitorAppKitNsScreenScreensId: 11,
            name: "Plain",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
            isMain: true,
        )
        setMonitorsForTests([monitor])
        config.mouse.columnSnap.policy = .floatUnlessSnap
        config.mouse.columnSnap.modifier = .option

        let sourceWorkspace = Workspace.get(byName: "source")
        XCTAssertTrue(monitor.setActiveWorkspace(sourceWorkspace))
        let window = TestWindow.new(id: 20, parent: sourceWorkspace.rootTilingContainer)
        let targetWorkspace = Workspace.get(byName: "target")
        XCTAssertTrue(monitor.setActiveWorkspace(targetWorkspace))
        XCTAssertNil(targetWorkspace.workspaceMonitor.columnId)

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
        config.mouse.columnSnap.policy = .snapToColumn

        let tabStrip = columnSnapDestinationResolution(
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
        let nonZone = columnSnapDestinationResolution(
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
        config.mouse.columnSnap.policy = .freeform

        assertZoneSnapPolicyOverride(.snapToColumn, for: fixture.commsMonitor.physicalMonitor)

        XCTAssertEqual(config.mouse.columnSnap.policy, .freeform)
        let resolution = columnSnapDestinationResolution(
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
            XCTFail("Expected runtime snap-to-column override to create a zone snap destination")
            return
        }
        XCTAssertEqual(destination.kind, .moveToZone(columnId: "right", workspaceName: "comms"))
    }

    func testRuntimePolicyOverridePreservesConfiguredModifier() {
        let fixture = configureZoneSnapFixture()
        config.mouse.columnSnap.policy = .freeform
        config.mouse.columnSnap.modifier = .shift

        assertZoneSnapPolicyOverride(.snapOnModifier, for: fixture.commsMonitor.physicalMonitor)

        let withoutShift = columnSnapDestinationResolution(
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

        let withShift = columnSnapDestinationResolution(
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
        XCTAssertEqual(destination.kind, .moveToZone(columnId: "right", workspaceName: "comms"))
    }
}

private struct ZoneSnapFixture {
    let work: Workspace
    let comms: Workspace
    let workMonitor: Monitor
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
        testDisplayLayoutConfig(
            monitor: .sequenceNumber(1),
            defaultZone: "main",
            columns: [
                ColumnConfig(id: "left", name: "Reference", width: 0.25),
                ColumnConfig(id: "main", name: "Work", width: 0.50),
                ColumnConfig(id: "right", name: "Comms", width: 0.25),
            ],
        ),
    ]

    let work = Workspace.get(byName: "work")
    let comms = Workspace.get(byName: "comms")
    let zonesById = Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.columnId.map { ($0, monitor) }
    })
    XCTAssertTrue(zonesById["main"].orDie().setActiveWorkspace(work))
    XCTAssertTrue(zonesById["right"].orDie().setActiveWorkspace(comms))
    let window = TestWindow.new(id: 901, parent: work.rootTilingContainer)
    return ZoneSnapFixture(
        work: work,
        comms: comms,
        workMonitor: zonesById["main"].orDie(),
        commsMonitor: zonesById["right"].orDie(),
        window: window,
    )
}

@MainActor
private func assertZoneSnapPolicyOverride(
    _ policy: ColumnSnapPolicy,
    for monitor: Monitor,
    file: StaticString = #filePath,
    line: UInt = #line,
) {
    switch setColumnSnapPolicy(policy, for: monitor) {
        case .success:
            break
        case .failure(let message):
            XCTFail(message, file: file, line: line)
    }
}
