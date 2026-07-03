@testable import AppBundle
import Common
import XCTest

final class ZoneDividerDragPolicyTest: XCTestCase {
    func testDragAllowedByPolicyAndMode() {
        XCTAssertTrue(isZoneDividerDragAllowed(policy: .always, activeMode: "main"))
        XCTAssertTrue(isZoneDividerDragAllowed(policy: .always, activeMode: nil))

        XCTAssertFalse(isZoneDividerDragAllowed(policy: .off, activeMode: "zone"))

        XCTAssertTrue(isZoneDividerDragAllowed(policy: .zoneMode, activeMode: "zone"))
        XCTAssertFalse(isZoneDividerDragAllowed(policy: .zoneMode, activeMode: "main"))
        XCTAssertFalse(isZoneDividerDragAllowed(policy: .zoneMode, activeMode: nil))
    }

    func testDesktopMouseUpEventSkipsWindowRefreshBarrier() {
        // A mouse up over empty desktop must not trigger the heavy refresh path: no window
        // enumeration barrier and no re-assertion of hidden window frames.
        XCTAssertFalse(RefreshSessionEvent.globalObserverLeftMouseUpOutsideWindows.requiresWindowRefreshBarrier)
        XCTAssertTrue(RefreshSessionEvent.globalObserverLeftMouseUpOutsideWindows.canReuseLastAppliedWindowFrames)

        // A mouse up over a window keeps the barrier: it may be a close-button click on an
        // unfocused window or delayed new-window detection.
        XCTAssertTrue(RefreshSessionEvent.globalObserverLeftMouseUp.requiresWindowRefreshBarrier)
        XCTAssertFalse(RefreshSessionEvent.globalObserverLeftMouseUp.canReuseLastAppliedWindowFrames)
    }
}
