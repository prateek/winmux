@testable import AppBundle
import Common
import XCTest

@MainActor
final class ContractRecordsTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testClassIsTheNodeTheWindowSitsUnder() {
        let workspace = Workspace.get(byName: "a")
        let tiled = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let nested = TestWindow.new(
            id: 2,
            parent: TilingContainer.newVTiles(parent: workspace.rootTilingContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST),
        )
        let floating = TestWindow.new(id: 3, parent: workspace)
        let fullscreen = TestWindow.new(id: 4, parent: workspace.macOsNativeFullscreenWindowsContainer)
        let hiddenApp = TestWindow.new(id: 5, parent: workspace.macOsNativeHiddenAppsWindowsContainer)
        let minimized = TestWindow.new(id: 6, parent: macosMinimizedWindowsContainer)
        let popup = TestWindow.new(id: 7, parent: macosPopupWindowsContainer)

        assertEquals(tiled.windowClass, .tiled)
        assertEquals(nested.windowClass, .tiled)
        assertEquals(floating.windowClass, .floating)
        assertEquals(fullscreen.windowClass, .fullscreen)
        assertEquals(hiddenApp.windowClass, .hiddenApp)
        assertEquals(minimized.windowClass, .minimized)
        assertEquals(popup.windowClass, .appPopup)
    }

    func testWinMuxFullscreenKeepsTheClassTheWindowHad() async throws {
        let workspace = Workspace.get(byName: "a")
        let tiled = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let floating = TestWindow.new(id: 2, parent: workspace)
        check(tiled.focusWindow())

        _ = try await parseCommand("fullscreen on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        floating.isFullscreen = true

        XCTAssertTrue(tiled.isFullscreen)
        assertEquals(tiled.windowClass, .tiled)
        assertEquals(floating.windowClass, .floating)
    }

    func testWindowMinimizedOnAWorkspaceReportsItWhileMinimized() async throws {
        let workspace = Workspace.get(byName: "2")
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        try await normalizeLayoutReason()
        let before = try await window.windowRecord()

        window.nativeIsMacosMinimized = true
        try await normalizeLayoutReason()
        let minimized = try await window.windowRecord()

        assertEquals(before?.windowClass, .tiled)
        assertEquals(before?.workspace, "2")
        XCTAssertTrue(window.parent is MacosMinimizedWindowsContainer)
        assertEquals(minimized?.windowClass, .minimized)
        assertEquals(minimized?.workspace, "2")
        assertEquals(minimized?.project, workspace.projectId.rawValue)
        assertEquals(minimized?.monitor, MonitorRecord(workspace.workspaceMonitor))
    }

    func testMinimizedWindowKeepsReportingAWorkspaceThatWinMuxHasDeleted() async throws {
        let workspace = Workspace.get(byName: "2")
        let projectId = workspace.projectId
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        window.nativeIsMacosMinimized = true
        try await normalizeLayoutReason()
        check(Workspace.get(byName: "elsewhere").focusWorkspace())

        Workspace.reconcileWorkspaceState()
        let record = try await window.windowRecord()

        XCTAssertNil(Workspace.existing(byName: "2"))
        assertEquals(record?.workspace, "2")
        assertEquals(record?.project, projectId.rawValue)
        assertEquals(record?.monitor, .unknown)
    }

    func testMinimizedWindowFollowsItsWorkspacesContentsToAnotherWorkspace() async throws {
        let source = Workspace.get(byName: "2")
        let target = Workspace.get(byName: "3")
        let window = TestWindow.new(id: 1, parent: source.rootTilingContainer)
        window.nativeIsMacosMinimized = true
        try await normalizeLayoutReason()

        moveWorkspaceContents(from: source, to: target)

        let record = try await window.windowRecord()
        assertEquals(record?.workspace, "3")
        assertEquals(workspaceOwnedMinimizedWindows(target), [], additionalMsg: "a detached window does not keep its workspace alive")
    }

    func testWindowOutsideEveryWorkspaceReportsNoWorkspaceProjectOrMonitor() async throws {
        let popup = TestWindow.new(id: 1, parent: macosPopupWindowsContainer)
        let firstSeenMinimized = TestWindow.new(id: 2, parent: macosMinimizedWindowsContainer)

        for window in [popup, firstSeenMinimized] {
            let record = try await window.windowRecord()
            assertEquals(record?.workspace, "")
            assertEquals(record?.project, "")
            assertEquals(record?.monitor, .unknown)
        }
    }

    func testRecordCarriesWhatTheWindowsAxElementReports() async throws {
        let workspace = Workspace.get(byName: "a")
        let document = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        document.testAxRecordAttributes = WindowAxRecordAttributes(
            title: "notes.txt",
            subrole: "AXStandardWindow",
            hasCloseButton: true,
            document: "file:///tmp/notes.txt",
        )
        let plain = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        plain.testAxRecordAttributes = .unknown

        let withDocument = try await document.windowRecord()
        let without = try await plain.windowRecord()

        assertEquals(withDocument?.id, 1)
        assertEquals(withDocument?.title, "notes.txt")
        assertEquals(withDocument?.subrole, "AXStandardWindow")
        assertEquals(withDocument?.hasCloseButton, true)
        assertEquals(withDocument?.document, "file:///tmp/notes.txt")
        assertEquals(withDocument?.app.bundleId, "bobko.WinMux.test-app")
        assertEquals(withDocument?.app.pid, 0)
        assertEquals(without?.document, "")
        assertEquals(without?.hasCloseButton, false)
    }

    func testWindowInNoTreeHasNoRecord() async throws {
        let window = TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        window.unbindFromParent()

        let record = try await window.windowRecord()

        XCTAssertNil(record)
    }

    func testFilterContextHoldsTheFocusedPreviousAndHoveredWindows() async throws {
        let workspace = focus.workspace
        let first = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let second = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        let floating = TestWindow.new(id: 3, parent: workspace, rect: Rect(topLeftX: 100, topLeftY: 100, width: 50, height: 50))
        check(first.focusWindow())
        checkOnFocusChangedCallbacks()
        check(second.focusWindow())
        checkOnFocusChangedCallbacks()

        let context = try await filterContextRecord(mouse: CGPoint(x: 120, y: 120))
        let overNothing = try await filterContextRecord(mouse: CGPoint(x: 10, y: 10))

        assertEquals(context.focused?.id, 2)
        assertEquals(context.previous?.id, 1)
        assertEquals(context.mouse?.id, 3)
        assertEquals(context.mouse?.windowClass, .floating)
        assertEquals(context.workspaceName, workspace.name)
        assertEquals(context.workspaceProject, workspace.projectId.rawValue)
        assertEquals(context.monitor, MonitorRecord(workspace.workspaceMonitor))
        assertEquals(context.profile, "default")
        XCTAssertNil(overNothing.mouse, "\(floating)")
    }

    func testFilterContextWithNoWindowsHasNullWindows() async throws {
        let context = try await filterContextRecord(mouse: CGPoint(x: 10, y: 10))

        XCTAssertNil(context.focused)
        XCTAssertNil(context.previous)
        XCTAssertNil(context.mouse)
        assertEquals(context.json["focused"], .null)
    }

    func testRecordCarriesTheWindowsLevel() async throws {
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        window.testCgWindowLevel = 3

        let record = try await window.windowRecord()

        assertEquals(record?.level, 3)
    }

    func testFailedAxReadFailsTheRecordInsteadOfBlankingIt() async {
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        window.testAxRecordError = CancellationError()

        do {
            _ = try await window.windowRecord()
            XCTFail("Expected the record to fail")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testPreviousIsNullOnceThePreviouslyFocusedWindowIsGone() async throws {
        let first = Workspace.get(byName: "1")
        let second = Workspace.get(byName: "2")
        let previous = TestWindow.new(id: 1, parent: first.rootTilingContainer)
        TestWindow.new(id: 2, parent: first.rootTilingContainer)
        let current = TestWindow.new(id: 3, parent: second.rootTilingContainer)
        check(previous.focusWindow())
        checkOnFocusChangedCallbacks()
        check(current.focusWindow())
        checkOnFocusChangedCallbacks()
        let before = try await filterContextRecord(mouse: .zero)

        previous.unbindFromParent()
        let after = try await filterContextRecord(mouse: .zero)

        assertEquals(before.previous?.id, 1)
        XCTAssertNil(after.previous, "the never-focused window 2 must not stand in")
    }

    func testMouseOverATabGroupIsItsActiveTabOnlyInsideTheLayout() async throws {
        let workspace = focus.workspace
        let layout = Rect(topLeftX: 100, topLeftY: 100, width: 800, height: 600)
        workspace.rootTilingContainer.layout = .tabGroup
        workspace.rootTilingContainer.lastAppliedLayoutPhysicalRect = layout
        TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let active = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        active.markAsMostRecentChild()

        let inside = try await windowUnderMouse(CGPoint(x: 300, y: 300))
        let outside = try await windowUnderMouse(CGPoint(x: 10, y: 10))

        assertEquals(inside?.windowId, 2)
        XCTAssertNil(outside)
    }

    func testMouseOverAWinMuxFullscreenWindowIsThatWindow() async throws {
        let workspace = focus.workspace
        let layout = Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600)
        workspace.rootTilingContainer.lastAppliedLayoutPhysicalRect = layout
        let hidden = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        hidden.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 400, height: 600)
        let fullscreen = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        fullscreen.isFullscreen = true
        fullscreen.markAsMostRecentChild()

        let underMouse = try await windowUnderMouse(CGPoint(x: 100, y: 100))

        assertEquals(underMouse?.windowId, 2)
    }
}
