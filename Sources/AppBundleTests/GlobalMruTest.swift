@testable import AppBundle
import Common
import XCTest

@MainActor
final class GlobalMruTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testRefocusedWindowOutranksTheOneFocusedBetween() async throws {
        let workspace = focus.workspace
        let a = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let b = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        let neverFocused = TestWindow.new(id: 3, parent: workspace.rootTilingContainer)

        try await refreshWithMacOsFocus(on: a)
        try await refreshWithMacOsFocus(on: b)
        try await refreshWithMacOsFocus(on: a)

        XCTAssertGreaterThan(a.lastFocusedSeq, b.lastFocusedSeq)
        XCTAssertGreaterThan(b.lastFocusedSeq, neverFocused.lastFocusedSeq)
        assertEquals(neverFocused.lastFocusedSeq, 0)
    }

    func testOrderHoldsAcrossWorkspaces() async throws {
        let here = focus.workspace
        let there = Workspace.get(byName: "there")
        let first = TestWindow.new(id: 1, parent: here.rootTilingContainer)
        let elsewhere = TestWindow.new(id: 2, parent: there.rootTilingContainer)
        let last = TestWindow.new(id: 3, parent: here.rootTilingContainer)

        try await refreshWithMacOsFocus(on: first)
        try await refreshWithMacOsFocus(on: elsewhere)
        try await refreshWithMacOsFocus(on: last)

        assertEquals([first, elsewhere, last].sortedByMostRecentUse().map(\.windowId), [3, 2, 1])
    }

    func testFocusRequestThatMacOsDoesNotConfirmChangesNoNumber() async throws {
        let workspace = focus.workspace
        let a = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let b = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        try await refreshWithMacOsFocus(on: b)
        try await refreshWithMacOsFocus(on: a)
        let before = [a.lastFocusedSeq, b.lastFocusedSeq]

        _ = try await [parseCommand("focus --window-id 2").cmdOrDie].runCmdSeq(.defaultEnv, .emptyStdin)
        let afterTheCommand = [a.lastFocusedSeq, b.lastFocusedSeq]
        // macOS still reports the window it had; nothing here hands the request on to it.
        try await runRefreshSessionBlocking(.ax(kAXFocusedWindowChangedNotification as String), layoutWorkspaces: false)

        assertEquals(focus.windowOrNil?.windowId, 2)
        assertEquals(afterTheCommand, before)
        assertEquals([a.lastFocusedSeq, b.lastFocusedSeq], before)
    }

    func testFocusRequestIsNumberedOnceMacOsConfirmsIt() async throws {
        let workspace = focus.workspace
        let a = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let b = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        try await refreshWithMacOsFocus(on: a)
        _ = try await [parseCommand("focus --window-id 2").cmdOrDie].runCmdSeq(.defaultEnv, .emptyStdin)

        try await refreshWithMacOsFocus(on: b)

        XCTAssertGreaterThan(b.lastFocusedSeq, a.lastFocusedSeq)
    }

    func testFocusWinMuxDidNotRequestIsNumberedOnTheNextRefresh() async throws {
        let workspace = focus.workspace
        let a = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let clicked = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        try await refreshWithMacOsFocus(on: a)

        try await refreshWithMacOsFocus(on: clicked)

        assertEquals(focus.windowOrNil?.windowId, 2)
        XCTAssertGreaterThan(clicked.lastFocusedSeq, a.lastFocusedSeq)
    }

    func testWindowFocusedAtLaunchIsNumberedOnTheFirstRefreshAfterStartup() async throws {
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        TrayMenuModel.shared.isEnabled = true
        appForTests = TestApp.shared
        TestApp.shared.focusedWindow = window
        setBlockingRefreshOverridesForTests(refresh: {}, normalizeLayoutReason: {})

        try await runRefreshSessionBlocking(.startup)
        let duringStartup = window.lastFocusedSeq
        try await refreshWithMacOsFocus(on: window)

        assertEquals(duringStartup, 0)
        XCTAssertGreaterThan(window.lastFocusedSeq, 0)
    }

    func testWindowInMacOsNativeFullscreenIsNumberedThoughItNeverHoldsWinMuxFocus() async throws {
        let workspace = focus.workspace
        let tiled = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let fullscreen = TestWindow.new(id: 2, parent: workspace.macOsNativeFullscreenWindowsContainer)
        try await refreshWithMacOsFocus(on: tiled)

        try await refreshWithMacOsFocus(on: fullscreen)

        assertEquals(focus.windowOrNil?.windowId, 1)
        XCTAssertGreaterThan(fullscreen.lastFocusedSeq, tiled.lastFocusedSeq)
    }

    func testRefreshThatFindsTheSameWindowFocusedKeepsItsNumber() async throws {
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        try await refreshWithMacOsFocus(on: window)
        let before = window.lastFocusedSeq

        try await refreshWithMacOsFocus(on: window)

        assertEquals(window.lastFocusedSeq, before)
    }

    func testNeverFocusedWindowsSortLastInRegistrationOrder() async throws {
        let here = focus.workspace
        let there = Workspace.get(byName: "there")
        let registeredFirst = TestWindow.new(id: 9, parent: there.rootTilingContainer)
        let focusedFirst = TestWindow.new(id: 5, parent: here.rootTilingContainer)
        let registeredLast = TestWindow.new(id: 1, parent: here.rootTilingContainer)
        let focusedLast = TestWindow.new(id: 7, parent: there.rootTilingContainer)
        try await refreshWithMacOsFocus(on: focusedFirst)
        try await refreshWithMacOsFocus(on: focusedLast)

        let order = [registeredLast, focusedFirst, registeredFirst, focusedLast].sortedByMostRecentUse()

        assertEquals(order.map(\.windowId), [7, 5, 9, 1])
    }

    func testFocusBackAndForthStillReturnsToThePreviousFocus() async throws {
        let workspace = focus.workspace
        let a = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let b = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        try await refreshWithMacOsFocus(on: a)
        try await refreshWithMacOsFocus(on: b)

        _ = try await [parseCommand("focus-back-and-forth").cmdOrDie].runCmdSeq(.defaultEnv, .emptyStdin)

        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(workspace.mostRecentWindowRecursive?.windowId, 1)
    }

    func testListWindowsPrintsTheNumber() async throws {
        let workspace = focus.workspace
        let a = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let b = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        TestWindow.new(id: 3, parent: workspace.rootTilingContainer)
        try await refreshWithMacOsFocus(on: a)
        try await refreshWithMacOsFocus(on: b)

        let plain = try await parseCommand("list-windows --all --format '%{window-id} %{window-last-focused-seq}'").cmdOrDie
            .run(.defaultEnv, .emptyStdin)
        let json = try await parseCommand("list-windows --focused --format '%{window-last-focused-seq}' --json").cmdOrDie
            .run(.defaultEnv, .emptyStdin)

        assertEquals(plain.stdout, ["1 \(a.lastFocusedSeq)", "2 \(b.lastFocusedSeq)", "3 0"])
        assertEquals(json.stdout.joined().filter { !$0.isWhitespace }, "[{\"window-last-focused-seq\":\(b.lastFocusedSeq)}]")
    }
}
