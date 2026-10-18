@testable import AppBundle
import AppKit
import XCTest

@MainActor
final class OverlayPanelTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    private func checkOverlay(_ panel: NSPanel, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(panel.collectionBehavior.contains(.transient), file: file, line: line)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces), file: file, line: line)
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary), file: file, line: line)
        XCTAssertFalse(panel.collectionBehavior.contains(.stationary), file: file, line: line)
    }

    func testBaseHudStaysOutOfSystemWindowOverviews() {
        checkOverlay(NSPanelHud())
    }

    func testSidebarStaysOutOfSystemWindowOverviews() {
        checkOverlay(WorkspaceSidebarPanel.shared)
    }

    func testLensAndItsLandingStayOutOfSystemWindowOverviews() {
        let panel = SwitcherPalettePanel(emit: { _ in })
        checkOverlay(panel)
        checkOverlay(panel.gridLandingPanel)
    }

    func testFlipAnimationStaysOutOfSystemWindowOverviewsWithoutChangingItsInputOrLevel() {
        let panel = DoubleSidedWindowController.makeAnimationPanel(frame: CGRect(x: 10, y: 20, width: 300, height: 200))
        checkOverlay(panel)
        XCTAssertEqual(panel.level, .floating)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertFalse(panel.hasShadow)
    }
}
