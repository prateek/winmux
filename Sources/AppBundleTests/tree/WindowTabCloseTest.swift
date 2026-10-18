@testable import AppBundle
import AppKit
import XCTest

@MainActor
final class WindowTabCloseTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        TrayMenuModel.shared.isEnabled = true
        WindowTabCloseModel.shared = WindowTabCloseModel()
    }

    private func group() -> (TilingContainer, [TestWindow]) {
        setScheduledRefreshOverrideForTests { _, _ in }
        let workspace = Workspace.get(byName: "tabs")
        let group = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .h, .tabGroup, index: INDEX_BIND_LAST)
        let windows = (1...5).map { TestWindow.new(id: UInt32($0), parent: group) }
        _ = windows[0].focusWindow()
        windows[0].nativeFocus()
        return (group, windows)
    }

    override func tearDown() async throws {
        try await waitForScheduledRefreshForTests()
        setScheduledRefreshOverrideForTests(nil)
        WindowTabStripPanelController.shared.hideAll()
    }

    func testRequestCloseReportsDisappearanceAndPreservesARefusedOrSheetWindow() async {
        for stays in [false, true] {
            for refused in [false, true] {
                setUpWorkspacesForTests()
                let (group, windows) = group()
                windows[1].closeRequestStays = stays
                if refused { windows[1].closeResult = .notClosed(.appRefused) }
                let gone = await windows[1].requestClose(timeout: 1)
                XCTAssertEqual(gone, !stays && !refused)
                XCTAssertEqual(windows[1].isBound, !gone)
                XCTAssertEqual(group.children.compactMap { ($0 as? Window)?.windowId }, gone ? [1, 3, 4, 5] : [1, 2, 3, 4, 5])
            }
        }
    }

    func testTabCloseOnlyClosesItsTargetAndKeepsTheGroupAndOrder() async throws {
        let (group, windows) = group()
        let task = closeWindowFromTabStrip(2, fallbackWorkspace: "tabs", pointer: (ObjectIdentifier(group), 160))
        try await task?.value
        XCTAssertEqual(group.children.compactMap { ($0 as? Window)?.windowId }, [1, 3, 4, 5])
        XCTAssertTrue(windows.enumerated().allSatisfy { $0.element.closeAttempts == ($0.offset == 1 ? 1 : 0) })
        XCTAssertTrue(windows.filter { $0.windowId != 2 }.allSatisfy { $0.parent === group })
        XCTAssertEqual(focus.windowOrNil?.windowId, 1)
        XCTAssertFalse(WindowTabCloseModel.shared.closingWindowIds.contains(2))
        XCTAssertEqual(WindowTabCloseModel.shared.heldWidths[ObjectIdentifier(group)], 160)
    }

    func testActiveTabCloseUsesTheExistingMostRecentReplacement() async throws {
        let (group, windows) = group()
        _ = windows[3].focusWindow()
        windows[3].nativeFocus()
        _ = windows[1].focusWindow()
        windows[1].nativeFocus()
        let task = closeWindowFromTabStrip(2, fallbackWorkspace: "tabs")
        try await task?.value
        XCTAssertEqual(focus.windowOrNil?.windowId, 4)
        XCTAssertEqual(group.tabActiveWindow?.windowId, 4)
        XCTAssertNil(WindowTabCloseModel.shared.heldWidths[ObjectIdentifier(group)])
    }

    func testBackgroundTabCloseDoesNotSwitchToTheActiveTabsPreviousFocus() async throws {
        let (_, windows) = group()
        _ = windows[3].focusWindow()
        windows[3].nativeFocus()
        refreshModel()
        _ = windows[4].focusWindow()
        windows[4].nativeFocus()
        refreshModel()
        try await closeWindowFromTabStrip(2, fallbackWorkspace: "tabs")?.value
        XCTAssertEqual(focus.windowOrNil?.windowId, 5)
        XCTAssertEqual(TestApp.shared.focusedWindow?.windowId, 5)
    }

    func testAStayingBackgroundOrActiveWindowKeepsItsIndexAndComesForward() async throws {
        for active in [false, true] {
            for refused in [false, true] {
                setUpWorkspacesForTests()
                let (group, windows) = group()
                windows[1].closeRequestStays = true
                if refused { windows[1].closeResult = .notClosed(.appRefused) }
                if active { _ = windows[1].focusWindow(); windows[1].nativeFocus() }
                let task = closeWindowFromTabStrip(2, fallbackWorkspace: "tabs")
                try await task?.value
                XCTAssertEqual(group.children.compactMap { ($0 as? Window)?.windowId }, [1, 2, 3, 4, 5])
                XCTAssertEqual(focus.windowOrNil?.windowId, 2)
                XCTAssertEqual(TestApp.shared.focusedWindow?.windowId, 2)
                XCTAssertFalse(WindowTabCloseModel.shared.closingWindowIds.contains(2))
                try await waitForScheduledRefreshForTests()
            }
        }
    }

    func testClosingTabRemainsPresentAndIgnoresASecondClose() async throws {
        let (group, windows) = group()
        var resume: CheckedContinuation<Void, Never>?
        let pressed = expectation(description: "press is pending")
        windows[1].beforeCloseRequest = {
            await withCheckedContinuation { continuation in
                resume = continuation
                pressed.fulfill()
            }
        }
        let first = closeWindowFromTabStrip(2, fallbackWorkspace: "tabs")
        await fulfillment(of: [pressed])
        XCTAssertTrue(WindowTabCloseModel.shared.closingWindowIds.contains(2))
        XCTAssertTrue(windows[1].parent === group)
        let second = closeWindowFromTabStrip(2, fallbackWorkspace: "tabs")
        XCTAssertNil(second)
        XCTAssertEqual(windows[1].closeAttempts, 1)
        resume?.resume()
        try await first?.value
        XCTAssertEqual(windows[1].closeAttempts, 1)
        XCTAssertFalse(WindowTabCloseModel.shared.closingWindowIds.contains(2))
    }

    func testWidthHoldSurvivesThreeClosesAtTheSamePointAndClearsOnExit() async throws {
        let (group, _) = group()
        let model = WindowTabCloseModel.shared
        let id = ObjectIdentifier(group)
        let width = windowTabStripTabWidth(stripWidth: 1000, count: 5)
        let x = windowTabStripContentHorizontalPadding + width - 12
        for expected in [UInt32(1), 2, 3] {
            let ids = group.children.compactMap { ($0 as? Window)?.windowId }
            let drawnWidth = windowTabStripTabWidth(stripWidth: 1000, count: ids.count, heldWidth: model.heldWidths[id])
            let frames = Dictionary(uniqueKeysWithValues: ids.enumerated().map {
                ($0.element, CGRect(x: windowTabStripContentHorizontalPadding + CGFloat($0.offset) * (drawnWidth + windowTabStripTabSpacing), y: 0, width: drawnWidth, height: 26))
            })
            let hit = windowTabAtPoint(CGPoint(x: x, y: 12), frames: frames)
            XCTAssertEqual(hit, expected)
            try await closeWindowFromTabStrip(hit!, fallbackWorkspace: "tabs", pointer: (id, drawnWidth))?.value
            XCTAssertEqual(windowTabStripTabWidth(stripWidth: 1000, count: ids.count - 1, heldWidth: model.heldWidths[id]), width)
        }
        model.pointerLeftStrip(id)
        XCTAssertNil(model.heldWidths[id])
        XCTAssertEqual(windowTabStripTabWidth(stripWidth: 1000, count: 2, heldWidth: nil), windowTabStripTabWidth(stripWidth: 1000, count: 2))
    }

    func testMiddleClickHitTestingIgnoresTheGutter() {
        let frames: [UInt32: CGRect] = [1: CGRect(x: 3, y: 5, width: 132, height: 26), 2: CGRect(x: 139, y: 5, width: 132, height: 26)]
        XCTAssertEqual(windowTabAtPoint(CGPoint(x: 170, y: 15), frames: frames), 2)
        XCTAssertNil(windowTabAtPoint(CGPoint(x: 280, y: 15), frames: frames))
        XCTAssertNil(windowTabAtPoint(CGPoint(x: 137, y: 15), frames: frames))
        let clipped = CGRect(x: 0, y: 0, width: 200, height: 36)
        XCTAssertNil(windowTabAtPoint(CGPoint(x: 230, y: 15), frames: frames, viewport: clipped))
        XCTAssertEqual(windowTabAtPoint(CGPoint(x: 170, y: 15), frames: frames, viewport: clipped), 2)
    }

    func testHeldWidthDrivesContentWidthsAndBothDragStartHitTests() {
        let (group, windows) = group()
        let strip = WindowTabStripViewModel(id: ObjectIdentifier(group), workspaceName: "tabs",
            frame: CGRect(x: 0, y: 0, width: 1000, height: 36), groupFrame: .zero,
            activeWindowId: 1, activeWindowCornerRadius: 16,
            tabs: windows.prefix(2).map { WindowTabItemViewModel(windowId: $0.windowId, workspaceName: "tabs", appName: "Demo", appBundleId: nil, appBundlePath: nil, title: "Window", isActive: $0.windowId == 1) },
            occludingFloatingWindowFrames: [])
        let context = WindowTabStripLayoutContext(strip: strip, width: 1000, heldTabWidth: 150)
        XCTAssertEqual(context.tabWidth, 150)
        XCTAssertEqual(context.effectiveTabWidth, 154)
        XCTAssertEqual(context.scrollContentWidth, 310)
        XCTAssertTrue(isWindowTabStripScrollBackgroundDragStart(localX: 320, contentMinX: 0, tabWidth: context.tabWidth, tabCount: 2))
        XCTAssertTrue(isWindowTabStripChromeGroupDragStart(localX: 320, contentMinX: 0, contentMaxX: 900, tabWidth: context.tabWidth, tabCount: 2))
        XCTAssertEqual(windowTabStripTabWidth(stripWidth: 1000, count: 2, heldWidth: nil), 240)
    }

    func testStripDisappearanceClearsItsWidthHold() {
        let (group, _) = group()
        let id = ObjectIdentifier(group)
        let model = WindowTabCloseModel.shared
        XCTAssertTrue(model.begin(2, pointer: (id, 160)))
        let panel = WindowTabStripPanelController.shared.stripPanel(for: id)
        panel.hostingView.strip = WindowTabStripViewModel(id: id, workspaceName: "tabs", frame: .zero,
            groupFrame: .zero, activeWindowId: 1, activeWindowCornerRadius: 16, tabs: [], occludingFloatingWindowFrames: [])
        WindowTabStripPanelController.shared.removeStaleStripPanels(activeIds: [])
        XCTAssertNil(model.heldWidths[id])
        model.finish(2)
    }
}
