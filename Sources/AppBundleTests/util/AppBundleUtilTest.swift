@testable import AppBundle
import AppKit
import XCTest

final class AppBundleUtilTest: XCTestCase {
    func testRestartRestoreTopLeftUsesMonitorCoordinateSpace() {
        let visibleRect = Rect(topLeftX: 739.2, topLeftY: 30, width: 2025.6, height: 1319)
        let point = restartRestoreTopLeft(
            in: visibleRect,
            windowSize: CGSize(width: 675.2, height: 660),
        )

        XCTAssertEqual(point.x, 1414.4, accuracy: 0.001)
        XCTAssertEqual(point.y, 359.5, accuracy: 0.001)
    }
}
