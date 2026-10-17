@testable import AppBundle
import XCTest

@MainActor
final class AccessibilityStartupTest: XCTestCase {
    func testDeniedPermissionStopsStartupWhenDeferredTerminationReturns() {
        var actions: [String] = []
        XCTAssertFalse(checkAccessibilityPermissions(trusted: { false },
            reset: { actions.append("reset") }, terminate: { actions.append("terminate") }))
        XCTAssertEqual(actions, ["reset", "terminate"])
    }

    func testGrantedPermissionContinuesWithoutResetOrTermination() {
        XCTAssertTrue(checkAccessibilityPermissions(trusted: { true },
            reset: { XCTFail("reset granted permission") }, terminate: { XCTFail("terminated") }))
    }
}
