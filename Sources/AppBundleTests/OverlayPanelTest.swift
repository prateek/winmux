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

    func testSidebarAndLensKeepThePolicyThroughTheirOwnSetup() {
        checkOverlay(WorkspaceSidebarPanel.shared)
        checkOverlay(SwitcherPalettePanel(emit: { _ in }))
    }

    func testNormalLevelChromeKeepsItsLevelAndTransientPolicy() throws {
        let owner = NSObject()
        let id = ObjectIdentifier(owner)
        focus.workspace.columns = ColumnState(count: 2)
        TrayMenuModel.shared.isEnabled = true
        ColumnDividerPanelController.shared.refresh()
        let divider = try XCTUnwrap(NSApp.windows.first { $0.isVisible && $0.level == .normal && $0.frame.width == 6 } as? NSPanel)
        let panels: [NSPanel] = [WindowTabStripPanel(id: id), WindowTabGroupVisualPanel(id: id), FocusedEmptyColumnPanel.shared, divider]
        for panel in panels {
            checkOverlay(panel)
            XCTAssertEqual(panel.level, .normal)
        }
        focus.workspace.columns = nil
        ColumnDividerPanelController.shared.refresh()
    }

    func testFlipAnimationStaysOutOfSystemWindowOverviewsWithoutChangingItsInputOrLevel() {
        let panel = DoubleSidedWindowController.makeAnimationPanel(frame: CGRect(x: 10, y: 20, width: 300, height: 200))
        checkOverlay(panel)
        XCTAssertTrue(panel is NSPanelHud)
        XCTAssertEqual(panel.level, .floating)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertFalse(panel.hasShadow)
    }
}
