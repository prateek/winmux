@testable import AppBundle
import AppKit
import XCTest

@MainActor
final class QuitWindowFramesTest: XCTestCase {
    let original = Rect(topLeftX: 100, topLeftY: 90, width: 400, height: 300)
    let moved = Rect(topLeftX: 2200, topLeftY: 200, width: 600, height: 400)
    let parked = Rect(topLeftX: 1919, topLeftY: 1079, width: 400, height: 300)
    let primary = TestMonitor(monitorAppKitNsScreenScreensId: 1, name: "Main",
        rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
        visibleRect: Rect(topLeftX: 0, topLeftY: 25, width: 1920, height: 1030), isMain: true)
    let secondary = TestMonitor(monitorAppKitNsScreenScreensId: 2, name: "Second",
        rect: Rect(topLeftX: 1920, topLeftY: -200, width: 1600, height: 1000),
        visibleRect: Rect(topLeftX: 1920, topLeftY: -175, width: 1600, height: 950), isMain: false)

    override func tearDown() {
        startupWindowFrames = [:]
        super.tearDown()
    }

    func testRecordsOnlyStartupNonPopupFramesAndNeverOverwrites() {
        recordStartupWindowFrame(1, rect: original, atStartup: true, isPopup: false)
        recordStartupWindowFrame(1, rect: moved, atStartup: true, isPopup: false)
        recordStartupWindowFrame(2, rect: original, atStartup: false, isPopup: false)
        recordStartupWindowFrame(3, rect: original, atStartup: true, isPopup: true)
        recordStartupWindowFrame(4, rect: nil, atStartup: true, isPopup: false)
        XCTAssertEqual(startupWindowFrames, [1: original])
    }

    func choice(record: Rect?, hidden: Bool = false, parkedOn: Rect? = nil, dragged: Rect? = nil, last: Rect?,
                enabled: Bool = true, displays: [Monitor]? = nil,
                size: CGSize? = CGSize(width: 400, height: 300)) -> QuitFrameAction {
        quitFrameAction(record: record, hidden: hidden, parkedOn: parkedOn, draggedAsideFrom: dragged,
            lastKnownFrame: last, floatingSize: size,
            restoreOriginal: enabled, monitors: displays ?? [primary, secondary], main: primary)
    }

    func testRecordedFrameWinsOverManualMoveResizeAndParking() {
        XCTAssertEqual(choice(record: original, last: moved), .restore(original))
        XCTAssertEqual(choice(record: original, hidden: true, last: parked), .restore(original))
        XCTAssertEqual(choice(record: moved, last: original), .restore(moved))
    }

    func testNewWindowAndMissingDisplayRecordLeaveOnscreenWindowAlone() {
        XCTAssertEqual(choice(record: nil, last: moved), .leave)
        XCTAssertEqual(choice(record: moved, last: original, displays: [primary]), .leave)
    }

    func testHiddenNewWindowAndOffscreenWindowAreCenteredOnNearestDisplay() {
        let centered = Rect(topLeftX: 2520, topLeftY: 150, width: 400, height: 300)
        XCTAssertEqual(choice(record: nil, hidden: true, last: moved), .center(centered))
        XCTAssertEqual(choice(record: nil, last: moved, displays: [primary]),
            .center(Rect(topLeftX: 760, topLeftY: 390, width: 400, height: 300)))
        XCTAssertEqual(choice(record: moved, hidden: true, last: moved, displays: [primary]),
            .center(Rect(topLeftX: 760, topLeftY: 390, width: 400, height: 300)))
    }

    func testUnhiddenWindowWithNoCachedFrameStaysWhereItIs() {
        // A tiled window's cached frame is dropped by every move or resize event.
        XCTAssertEqual(choice(record: nil, last: nil), .leave)
        XCTAssertEqual(choice(record: moved, last: nil, displays: [primary]), .leave)
    }

    func testUnknownFrameUsesMainVisibleRectAndUnknownSizeUsesVisibleSize() {
        XCTAssertEqual(choice(record: nil, hidden: true, last: nil, size: nil), .center(primary.visibleRect))
        XCTAssertEqual(choice(record: nil, last: nil, enabled: false, size: nil), .center(primary.visibleRect))
    }

    func testParkedWindowIsCenteredOnTheMonitorItWasParkedOn() {
        // Parked at the main monitor's right edge, its frame's centre lies on the second monitor.
        let atEdge = Rect(topLeftX: 1919, topLeftY: 500, width: 400, height: 300)
        XCTAssertEqual(choice(record: nil, hidden: true, last: atEdge),
            .center(Rect(topLeftX: 2520, topLeftY: 150, width: 400, height: 300)))
        XCTAssertEqual(choice(record: nil, hidden: true, parkedOn: primary.visibleRect, last: atEdge),
            .center(Rect(topLeftX: 760, topLeftY: 390, width: 400, height: 300)))
        // The Dock or menu bar changed since the window was parked.
        let olderVisible = Rect(topLeftX: 0, topLeftY: 25, width: 1920, height: 980)
        XCTAssertEqual(choice(record: nil, hidden: true, parkedOn: olderVisible, last: atEdge),
            .center(Rect(topLeftX: 760, topLeftY: 390, width: 400, height: 300)))
    }

    func testWindowMovedAsideForADragGoesBackWhereItWas() {
        let aside = Rect(topLeftX: -399, topLeftY: 1079, width: 400, height: 300)
        XCTAssertEqual(choice(record: nil, dragged: moved, last: aside), .restore(moved))
        XCTAssertEqual(choice(record: original, dragged: moved, last: aside), .restore(original))
    }

    func testCenteredFrameLargerThanTheMonitorKeepsItsTitleBarOnScreen() {
        XCTAssertEqual(choice(record: nil, hidden: true, last: nil, size: CGSize(width: 2500, height: 1400)),
            .center(Rect(topLeftX: 0, topLeftY: 25, width: 2500, height: 1400)))
    }

    func testFeatureOffCentersRecordedAndNewWindowsWithDisplayOriginFix() {
        XCTAssertEqual(choice(record: original, last: moved, enabled: false),
            .center(Rect(topLeftX: 2520, topLeftY: 150, width: 400, height: 300)))
        XCTAssertEqual(choice(record: nil, last: original, enabled: false),
            .center(Rect(topLeftX: 760, topLeftY: 390, width: 400, height: 300)))
    }

    func testFailedWindowDoesNotStopItsAppOrAnotherAppAndAppsOverlap() async {
        let firstStarted = expectation(description: "first app suspended")
        let secondStarted = expectation(description: "second app suspended")
        var pending: [CheckedContinuation<Void, Never>] = []
        var released = false
        var written: [UInt32] = []
        var failed: [UInt32] = []
        let plans = [
            QuitWindowFrame(appId: 1, windowId: 1, action: .restore(original)),
            QuitWindowFrame(appId: 1, windowId: 2, action: .restore(original)),
            QuitWindowFrame(appId: 2, windowId: 3, action: .restore(original)),
            QuitWindowFrame(appId: 2, windowId: 4, action: .leave),
        ]
        let task = Task {
            await restoreQuitWindowFrames(plans, write: { id, _ in
                if id == 1 || id == 3 {
                    if !released {
                        await withCheckedContinuation {
                            pending.append($0)
                            (id == 1 ? firstStarted : secondStarted).fulfill()
                        }
                    }
                }
                if id == 1 { throw CancellationError() }
                written.append(id)
            }, failed: { plan, _ in failed.append(plan.windowId) })
        }
        await fulfillment(of: [firstStarted, secondStarted], timeout: 1)
        XCTAssertFalse(written.contains(2))
        released = true
        for continuation in pending { continuation.resume() }
        await task.value
        XCTAssertEqual(Set(written), [2, 3])
        XCTAssertEqual(failed, [1])
    }

    func testQuitWriterWritesRecordedSizePositionAndReassertsSizeWithoutReads() throws {
        var attributes: [String] = []
        try writeQuitFrame(original) { attribute, value in
            attributes.append(attribute)
            if attribute == Ax.sizeAttr.key {
                XCTAssertEqual(Ax.sizeAttr.getter(value as AnyObject), original.size)
            } else {
                XCTAssertEqual(Ax.topLeftCornerAttr.getter(value as AnyObject), original.topLeftCorner)
            }
            return .success
        }
        XCTAssertEqual(attributes, [Ax.sizeAttr.key, Ax.topLeftCornerAttr.key, Ax.sizeAttr.key])
        XCTAssertThrowsError(try writeQuitFrame(original) { _, _ in .invalidUIElement })
    }

    func testQuitWriterAcceptsAFirstSizeWriteThatTheSecondOneFixes() throws {
        var sizeWrites = 0
        try writeQuitFrame(original) { attribute, _ in
            guard attribute == Ax.sizeAttr.key else { return .success }
            sizeWrites += 1
            return sizeWrites == 1 ? .cannotComplete : .success
        }
    }

    func testQuitWriterStillMovesAWindowThatRefusesItsSize() {
        var written: [String] = []
        XCTAssertThrowsError(try writeQuitFrame(original) { attribute, _ in
            written.append(attribute)
            return attribute == Ax.sizeAttr.key ? .attributeUnsupported : .success
        })
        XCTAssertEqual(written, [Ax.sizeAttr.key, Ax.topLeftCornerAttr.key, Ax.sizeAttr.key])
    }
}
