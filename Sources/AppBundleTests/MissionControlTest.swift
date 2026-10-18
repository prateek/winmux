@testable import AppBundle
import AppKit
import XCTest

@MainActor
final class MissionControlTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        TrayMenuModel.shared.isEnabled = true
        config.windowTabs.enabled = true
    }

    override func tearDown() async throws {
        MissionControlState.shared.dockDidExit()
        TrayMenuModel.shared.windowTabStrips = []
        WindowTabStripPanelController.shared.hideAll()
        focus.workspace.columns = nil
        ColumnDividerPanelController.shared.refresh()
        FocusedEmptyColumnPanel.shared.orderOut(nil)
        WorkspaceSidebarPanel.shared.orderOut(nil)
        for panel in WorkspaceSidebarPanel.visiblePanels { panel.orderOut(nil) }
    }

    func testEveryDockOverviewNotificationAndExit() {
        let state = MissionControlState.shared
        for name in ["AXExposeShowAllWindows", "AXExposeShowFrontWindows", "AXExposeShowDesktop"] {
            state.receive(name)
            XCTAssertTrue(state.isOpen, name)
            state.receive("unrelated")
            XCTAssertTrue(state.isOpen)
            state.receive("AXExposeExit")
            XCTAssertFalse(state.isOpen)
        }
    }

    func testDockExitCannotLeaveChromeSuppressed() {
        let state = MissionControlState.shared
        state.receive("AXExposeShowAllWindows")
        XCTAssertTrue(state.isOpen)
        state.dockDidExit()
        XCTAssertFalse(state.isOpen)
    }

    func testTabRefreshStaysHiddenAndCloseRestoresSameFramesWithoutChangingMouseMode() {
        let owner = NSObject()
        let id = ObjectIdentifier(owner)
        TrayMenuModel.shared.windowTabStrips = [WindowTabStripViewModel(
            id: id, workspaceName: focus.workspace.name,
            frame: CGRect(x: 100, y: 380, width: 400, height: 28),
            groupFrame: CGRect(x: 100, y: 100, width: 400, height: 308),
            activeWindowId: nil, activeWindowCornerRadius: 12, tabs: [], occludingFloatingWindowFrames: []
        )]
        let controller = WindowTabStripPanelController.shared
        controller.refresh()
        let visual = controller.visualPanel(for: id)
        let strip = controller.stripPanel(for: id)
        let frames = [visual.frame, strip.frame]
        XCTAssertTrue(visual.isVisible)
        XCTAssertTrue(strip.isVisible)
        MissionControlState.shared.receive("AXExposeShowAllWindows")
        XCTAssertFalse(visual.isVisible)
        XCTAssertFalse(strip.isVisible)
        controller.refresh()
        XCTAssertFalse(visual.isVisible)
        XCTAssertFalse(strip.isVisible)
        XCTAssertNil(controller.mouseInteractionChromeMode)
        MissionControlState.shared.receive("AXExposeExit")
        XCTAssertTrue(visual.isVisible)
        XCTAssertTrue(strip.isVisible)
        XCTAssertEqual([visual.frame, strip.frame], frames)
    }

    func testDividerAndOutlineRefreshStayHiddenAndCloseRestoresTheirFrames() {
        focus.workspace.columns = ColumnState(count: 3)
        focus.workspace.columns?.focusedSlot = 2
        let controller = ColumnDividerPanelController.shared
        let outline = FocusedEmptyColumnPanel.shared
        controller.refresh()
        outline.refresh()
        let dividers = NSApp.windows.compactMap { $0 as? NSPanelHud }.filter {
            $0.isVisible && $0.level == .normal && $0 !== outline && $0.frame.width == 6
        }
        XCTAssertEqual(dividers.count, 2)
        let panels = dividers + [outline]
        let frames = panels.map(\.frame)
        XCTAssertTrue(outline.isVisible)
        MissionControlState.shared.receive("AXExposeShowFrontWindows")
        controller.refresh()
        outline.refresh()
        for panel in panels { XCTAssertFalse(panel.isVisible) }
        MissionControlState.shared.receive("AXExposeExit")
        XCTAssertTrue(panels.allSatisfy(\.isVisible))
        XCTAssertEqual(panels.map(\.frame), frames)
    }

    func testSidebarRefreshCannotOrderInDuringOverview() {
        WorkspaceSidebarPanel.refreshAll()
        let panel = WorkspaceSidebarPanel.panel(for: workspaceSidebarMonitorScopeId(for: mainMonitor))!
        XCTAssertTrue(panel.isVisible)
        MissionControlState.shared.receive("AXExposeShowAllWindows")
        panel.refresh()
        XCTAssertFalse(panel.isVisible)
        MissionControlState.shared.receive("AXExposeExit")
        XCTAssertTrue(panel.isVisible)
    }

    func testChromeCreatedWhileOpenWaitsForExitAndRetainsMouseSuppression() {
        let controller = WindowTabStripPanelController.shared
        MissionControlState.shared.receive("AXExposeShowAllWindows")
        let owner = NSObject()
        let id = ObjectIdentifier(owner)
        TrayMenuModel.shared.windowTabStrips = [WindowTabStripViewModel(
            id: id, workspaceName: focus.workspace.name,
            frame: CGRect(x: 200, y: 480, width: 400, height: 28),
            groupFrame: CGRect(x: 200, y: 200, width: 400, height: 308),
            activeWindowId: nil, activeWindowCornerRadius: 12, tabs: [], occludingFloatingWindowFrames: []
        )]
        focus.workspace.columns = ColumnState(count: 2)
        focus.workspace.columns?.focusedSlot = 2
        controller.hideChromeDuringMouseInteraction(showFrameOnly: true)
        controller.refresh()
        ColumnDividerPanelController.shared.refresh()
        FocusedEmptyColumnPanel.shared.refresh()
        XCTAssertFalse(controller.visualPanel(for: id).isVisible)
        XCTAssertFalse(controller.stripPanel(for: id).isVisible)
        XCTAssertFalse(FocusedEmptyColumnPanel.shared.isVisible)
        XCTAssertEqual(controller.mouseInteractionChromeMode, .frameOnly)
        MissionControlState.shared.dockDidExit()
        XCTAssertTrue(controller.visualPanel(for: id).isVisible)
        XCTAssertFalse(controller.stripPanel(for: id).isVisible)
        XCTAssertEqual(controller.mouseInteractionChromeMode, .frameOnly)
        controller.showChromeDuringMouseInteraction()
        XCTAssertTrue(controller.stripPanel(for: id).isVisible)
    }

    func testTransientResizeCannotOrderTabChromeInDuringOverview() {
        let group = focus.workspace.rootTilingContainer
        group.layout = .tabGroup
        let active = TestWindow.new(id: 1, parent: group)
        _ = TestWindow.new(id: 2, parent: group)
        XCTAssertTrue(active.focusWindow())
        let id = ObjectIdentifier(group)
        TrayMenuModel.shared.windowTabStrips = [WindowTabStripViewModel(
            id: id, workspaceName: focus.workspace.name,
            frame: CGRect(x: 100, y: 380, width: 400, height: 28),
            groupFrame: CGRect(x: 100, y: 100, width: 400, height: 308),
            activeWindowId: nil, activeWindowCornerRadius: 12, tabs: [], occludingFloatingWindowFrames: []
        )]
        let controller = WindowTabStripPanelController.shared
        controller.refresh()
        MissionControlState.shared.receive("AXExposeShowAllWindows")
        XCTAssertTrue(controller.updateResizingTabGroupChrome(
            window: active, activeWindowRect: Rect(topLeftX: 140, topLeftY: 100, width: 500, height: 300)
        ))
        XCTAssertFalse(controller.visualPanel(for: id).isVisible)
        XCTAssertFalse(controller.stripPanel(for: id).isVisible)
        MissionControlState.shared.receive("AXExposeExit")
        XCTAssertTrue(controller.visualPanel(for: id).isVisible)
        XCTAssertTrue(controller.stripPanel(for: id).isVisible)
    }
}
