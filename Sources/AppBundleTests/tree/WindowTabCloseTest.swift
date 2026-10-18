@testable import AppBundle
import AppKit
import Combine
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
                let gone = await windows[1].requestClose(timeout: 1) == .gone
                XCTAssertEqual(gone, !stays && !refused)
                XCTAssertEqual(windows[1].isBound, !gone)
                XCTAssertEqual(group.children.compactMap { ($0 as? Window)?.windowId }, gone ? [1, 3, 4, 5] : [1, 2, 3, 4, 5])
            }
        }
    }

    func testTabCloseOnlyClosesItsTargetAndKeepsTheGroupAndOrder() async throws {
        let (group, windows) = group()
        try await runLightSession(.menuBarButton, .isServerEnabled!) {}
        let stripWidth = TrayMenuModel.shared.windowTabStrips.first!.frame.width
        let task = closeWindowFromTabStrip(2, fallbackWorkspace: "tabs", pointer: WindowTabClosePointer(stripId: ObjectIdentifier(group), hold: WindowTabWidthHold(width: 160, stripWidth: stripWidth, tabCount: 5)))
        try await task?.value
        XCTAssertEqual(group.children.compactMap { ($0 as? Window)?.windowId }, [1, 3, 4, 5])
        XCTAssertTrue(windows.enumerated().allSatisfy { $0.element.closeAttempts == ($0.offset == 1 ? 1 : 0) })
        XCTAssertTrue(windows.filter { $0.windowId != 2 }.allSatisfy { $0.parent === group })
        XCTAssertEqual(focus.windowOrNil?.windowId, 1)
        XCTAssertFalse(WindowTabCloseModel.shared.closingWindowIds.contains(2))
        XCTAssertEqual(WindowTabCloseModel.shared.widthHolds[ObjectIdentifier(group)]?.width, 160)
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
        XCTAssertNil(WindowTabCloseModel.shared.widthHolds[ObjectIdentifier(group)]?.width)
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

    func testATimeoutOrRefusalKeepsItsIndexWithoutMovingFocus() async throws {
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
                XCTAssertEqual(focus.windowOrNil?.windowId, active ? 2 : 1)
                XCTAssertEqual(TestApp.shared.focusedWindow?.windowId, active ? 2 : 1)
                XCTAssertFalse(WindowTabCloseModel.shared.closingWindowIds.contains(2))
                try await waitForScheduledRefreshForTests()
            }
        }
    }

    func testActiveCloseUsesMostRecentReplacementDespiteFocusDriftBeforeCollection() async throws {
        for otherWorkspace in [false, true] {
            setUpWorkspacesForTests()
            let (_, windows) = group()
            _ = windows[3].focusWindow()
            windows[3].nativeFocus()
            refreshModel()
            _ = windows[1].focusWindow()
            windows[1].nativeFocus()
            refreshModel()
            let drift = otherWorkspace
                ? TestWindow.new(id: 6, parent: Workspace.get(byName: "elsewhere").rootTilingContainer)
                : windows[2]
            windows[1].beforeCloseRequest = {
                drift.nativeFocus()
            }
            try await closeWindowFromTabStrip(2, fallbackWorkspace: "tabs")?.value
            XCTAssertEqual(focus.windowOrNil?.windowId, 4)
            XCTAssertEqual(TestApp.shared.focusedWindow?.windowId, 4)
        }
    }

    func testSheetComesForwardAndClearsBackgroundCloseIntent() async throws {
        let (group, windows) = group()
        windows[1].closeRequestHasSheet = true
        try await closeWindowFromTabStrip(2, fallbackWorkspace: "tabs")?.value
        XCTAssertEqual(group.children.compactMap { ($0 as? Window)?.windowId }, [1, 2, 3, 4, 5])
        XCTAssertEqual(focus.windowOrNil?.windowId, 2)
        XCTAssertEqual(TestApp.shared.focusedWindow?.windowId, 2)
        XCTAssertFalse(WindowTabCloseModel.shared.closingWindowIds.contains(2))
        XCTAssertNil(WindowTabCloseModel.shared.backgroundCloses[2])
    }

    func testFocusedRetryDoesNotInheritABackgroundTimeoutsIntent() async throws {
        let (_, windows) = group()
        windows[1].closeRequestStays = true
        try await closeWindowFromTabStrip(2, fallbackWorkspace: "tabs")?.value
        _ = windows[3].focusWindow()
        windows[3].nativeFocus()
        refreshModel()
        _ = windows[1].focusWindow()
        windows[1].nativeFocus()
        refreshModel()
        windows[1].closeRequestStays = false
        windows[1].beforeCloseRequest = { windows[2].nativeFocus() }
        try await closeWindowFromTabStrip(2, fallbackWorkspace: "tabs")?.value
        XCTAssertEqual(focus.windowOrNil?.windowId, 4)
        XCTAssertNil(WindowTabCloseModel.shared.backgroundCloses[2])
    }

    func testBackgroundCloseIntentSurvivesTimeoutUntilOrdinaryCollection() async throws {
        let (_, windows) = group()
        _ = windows[3].focusWindow()
        windows[3].nativeFocus()
        refreshModel()
        _ = windows[4].focusWindow()
        windows[4].nativeFocus()
        refreshModel()
        windows[1].closeRequestStays = true
        try await closeWindowFromTabStrip(2, fallbackWorkspace: "tabs")?.value
        XCTAssertFalse(WindowTabCloseModel.shared.closingWindowIds.contains(2))
        XCTAssertNotNil(WindowTabCloseModel.shared.backgroundCloses[2])
        windows[1].unbindAndFocusAfterClosure()
        XCTAssertEqual(focus.windowOrNil?.windowId, 5)
        XCTAssertNil(WindowTabCloseModel.shared.backgroundCloses[2])
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
        try await runLightSession(.menuBarButton, .isServerEnabled!) {}
        let stripWidth = TrayMenuModel.shared.windowTabStrips.first!.frame.width
        let width = windowTabStripTabWidth(stripWidth: stripWidth, count: 5)
        let x = windowTabStripContentHorizontalPadding + width - 12
        for expected in [UInt32(1), 2, 3] {
            let ids = group.children.compactMap { ($0 as? Window)?.windowId }
            let drawnWidth = windowTabStripTabWidth(stripWidth: stripWidth, count: ids.count, heldWidth: model.widthHolds[id]?.width)
            let frames = Dictionary(uniqueKeysWithValues: ids.enumerated().map {
                ($0.element, CGRect(x: windowTabStripContentHorizontalPadding + CGFloat($0.offset) * (drawnWidth + windowTabStripTabSpacing), y: 0, width: drawnWidth, height: 26))
            })
            let hit = windowTabAtPoint(CGPoint(x: x, y: 12), frames: frames)
            XCTAssertEqual(hit, expected)
            try await closeWindowFromTabStrip(hit!, fallbackWorkspace: "tabs", pointer: WindowTabClosePointer(stripId: id, hold: WindowTabWidthHold(width: drawnWidth, stripWidth: stripWidth, tabCount: ids.count)))?.value
            XCTAssertEqual(windowTabStripTabWidth(stripWidth: stripWidth, count: ids.count - 1, heldWidth: model.widthHolds[id]?.width), width)
        }
        model.pointerLeftStrip(id)
        XCTAssertNil(model.widthHolds[id]?.width)
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
        XCTAssertTrue(model.begin(2, pointer: WindowTabClosePointer(stripId: id, hold: WindowTabWidthHold(width: 160, stripWidth: 1000, tabCount: 5))))
        let panel = WindowTabStripPanelController.shared.stripPanel(for: id)
        panel.hostingView.strip = WindowTabStripViewModel(id: id, workspaceName: "tabs", frame: .zero,
            groupFrame: .zero, activeWindowId: 1, activeWindowCornerRadius: 16, tabs: [], occludingFloatingWindowFrames: [])
        WindowTabStripPanelController.shared.removeStaleStripPanels(activeIds: [])
        XCTAssertNil(model.widthHolds[id]?.width)
        model.finish(2)
    }

    func testHoverIsTheTabUnderThePointerAfterEachLayout() {
        func frames(_ ids: [UInt32], width: CGFloat = 150, origin: CGFloat = 5) -> [UInt32: CGRect] {
            Dictionary(uniqueKeysWithValues: ids.enumerated().map {
                ($0.element, CGRect(x: origin + CGFloat($0.offset) * (width + 4), y: 4, width: width, height: 26))
            })
        }
        let viewport = CGRect(x: 2, y: 0, width: 900, height: 36)
        let pointer = CGPoint(x: 280, y: 15)
        var order: [UInt32] = [1, 2, 3, 4, 5]
        // A still pointer over the closed tab's slot hovers each tab that slides into it.
        for next: UInt32 in [3, 4, 5] {
            order.remove(at: 1)
            XCTAssertEqual(windowTabHover(pointer: pointer, frames: frames(order), viewport: viewport), next)
        }
        // A scrolled strip: frames shift, and the tab under the pointer follows them.
        XCTAssertEqual(windowTabHover(pointer: pointer, frames: frames([1, 2, 3], origin: -149), viewport: viewport), 3)
        XCTAssertNil(windowTabHover(pointer: CGPoint(x: 950, y: 15), frames: frames([1, 3]), viewport: viewport))
        // No pointer over the strip (it left, or the strip ignores the mouse or is covered): no hover.
        XCTAssertNil(windowTabHover(pointer: nil, frames: frames([1, 3]), viewport: viewport))
    }

    func testBackgroundCloseRecordExpiresOnAClockThatCountsSleep() async throws {
        _ = group()
        let model = WindowTabCloseModel.shared
        let expired = ContinuousClock.now - windowTabBackgroundCloseLifetime - .seconds(1)
        XCTAssertTrue(model.begin(2, pointer: nil, now: expired))
        model.finish(2)
        XCTAssertFalse(model.shouldPreserveFocusOnCollection(2, focusedWindowId: 1))
        XCTAssertNil(model.backgroundCloses[2])
        XCTAssertTrue(model.begin(2, pointer: nil))
        model.finish(2)
        XCTAssertTrue(model.shouldPreserveFocusOnCollection(2, focusedWindowId: 1))
        // An expired record is pruned by the next close rather than kept until its window goes.
        XCTAssertTrue(model.begin(3, pointer: nil, now: expired))
        model.finish(3)
        XCTAssertTrue(model.begin(4, pointer: nil))
        model.finish(4)
        XCTAssertNil(model.backgroundCloses[3])
    }

    func testARefusedPressKeepsItsBackgroundRecordBecauseAnAxTimeoutIsAlsoARefusal() async throws {
        let (_, windows) = group()
        // Primed as testBackgroundTabCloseDoesNotSwitchToTheActiveTabsPreviousFocus, where collecting a
        // background window without the record would move focus to the previous one.
        _ = windows[3].focusWindow()
        windows[3].nativeFocus()
        refreshModel()
        _ = windows[4].focusWindow()
        windows[4].nativeFocus()
        refreshModel()
        windows[1].closeResult = .notClosed(.appRefused)
        try await closeWindowFromTabStrip(2, fallbackWorkspace: "tabs")?.value
        XCTAssertNotNil(WindowTabCloseModel.shared.backgroundCloses[2])
        XCTAssertEqual(focus.windowOrNil?.windowId, 5)
        // The app closes it later after all: focus stays where it was.
        windows[1].unbindAndFocusAfterClosure()
        XCTAssertEqual(focus.windowOrNil?.windowId, 5)
    }

    func testHidingAStripClearsItsHoverAndAnUnchangedHoverPublishesNothing() {
        let (group, _) = group()
        let id = ObjectIdentifier(group)
        let model = WindowTabCloseModel.shared
        var publishes = 0
        let watch = model.objectWillChange.sink { publishes += 1 }
        model.setHoveredTab(3, stripId: id)
        model.setHoveredTab(3, stripId: id)
        XCTAssertEqual(publishes, 1)
        XCTAssertEqual(model.hoveredTabIds[id], 3)
        let panel = WindowTabStripPanelController.shared.stripPanel(for: id)
        panel.hostingView.strip = WindowTabStripViewModel(id: id, workspaceName: "tabs", frame: .zero,
            groupFrame: .zero, activeWindowId: 1, activeWindowCornerRadius: 16, tabs: [], occludingFloatingWindowFrames: [])
        WindowTabStripPanelController.shared.removeStaleStripPanels(activeIds: [])
        XCTAssertNil(model.hoveredTabIds[id])
        watch.cancel()
    }

    func testWidthHoldToleratesSubPointWidthDifferences() {
        let hold = WindowTabWidthHold(width: 150, stripWidth: 1000, tabCount: 5)
        XCTAssertTrue(hold.isValid(stripWidth: 1000.5, tabCount: 4))
        XCTAssertTrue(hold.isValid(stripWidth: 999.5, tabCount: 5))
        XCTAssertFalse(hold.isValid(stripWidth: 1001, tabCount: 4))
        XCTAssertFalse(hold.isValid(stripWidth: 1000, tabCount: 6))
    }

    func testWidthHoldDropsOnResizeOrTabGrowthAndLaterClosesReplaceInvalidHold() {
        let (group, _) = group()
        let id = ObjectIdentifier(group)
        let model = WindowTabCloseModel.shared
        func close(_ windowId: UInt32, width: CGFloat, stripWidth: CGFloat, count: Int) {
            XCTAssertTrue(model.begin(windowId, pointer: WindowTabClosePointer(stripId: id, hold: WindowTabWidthHold(width: width, stripWidth: stripWidth, tabCount: count))))
            model.finish(windowId)
        }
        close(1, width: 150, stripWidth: 1000, count: 5)
        close(2, width: 180, stripWidth: 1000, count: 4)
        XCTAssertEqual(model.widthHolds[id]?.width, 150)
        model.reconcileStrip(id, width: 900, tabCount: 3)
        XCTAssertNil(model.widthHolds[id]?.width)
        close(3, width: 180, stripWidth: 900, count: 3)
        model.reconcileStrip(id, width: 900, tabCount: 4)
        XCTAssertNil(model.widthHolds[id]?.width)
        close(4, width: 180, stripWidth: 900, count: 3)
        close(5, width: 200, stripWidth: 950, count: 2)
        XCTAssertEqual(model.widthHolds[id]?.width, 200)
        close(1, width: 160, stripWidth: 950, count: 4)
        XCTAssertEqual(model.widthHolds[id]?.width, 160)
    }

    func testATitleLeavesClearOnlyTheCloseButtonsPart() {
        XCTAssertEqual(closeButtonTitleClearWidth(isActive: false, isHovered: false), 0)
        for (active, hovered) in [(true, false), (false, true), (true, true)] {
            let clear = closeButtonTitleClearWidth(isActive: active, isHovered: hovered)
            // The button spans the tab's last size + inset points; the title's frame ends one padding in.
            XCTAssertEqual(clear, windowTabCloseButtonSize + windowTabCloseButtonTrailingInset - windowTabItemHorizontalPadding)
        }
    }

    func testCloseSchedulesOnlyTheLightSessionsPostRefresh() async throws {
        let (_, windows) = group()
        windows[1].closeRequestStays = true
        var refreshes = 0
        setScheduledRefreshOverrideForTests { _, _ in refreshes += 1 }
        try await closeWindowFromTabStrip(2, fallbackWorkspace: "tabs")?.value
        try await waitForScheduledRefreshForTests()
        XCTAssertEqual(refreshes, 1)
    }

    func testCloseResultCanBeDiscardedForAnUnavailableWindow() {
        closeWindowFromTabStrip(999, fallbackWorkspace: "tabs")
        XCTAssertFalse(WindowTabCloseModel.shared.closingWindowIds.contains(999))
    }
}
