@testable import AppBundle
import Common
import Foundation
import XCTest

@MainActor
final class WindowMarksTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    private func run(_ text: String, env: CmdEnv = .defaultEnv) async throws -> CmdResult {
        let command = try XCTUnwrap(parseCommand(text).cmdOrNil, text)
        return try await command.run(env, .emptyStdin)
    }

    func testMarkInAHookForAnEmptyWorkspaceMarksNothing() async throws {
        let empty = focus.workspace
        _ = TestWindow.new(id: 1, parent: Workspace.get(byName: "elsewhere").rootTilingContainer)
        let result = try await run("mark a", env: CmdEnv.defaultEnv.copy(\.workspaceName, empty.name))
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertEqual(result.stderr, [noWindowIsFocused])
        XCTAssertNil(WindowMarks.window(for: "a"))
    }

    func testABindingThatJumpsThenMarksMarksTheWindowItJumpedTo() async throws {
        let workspace = focus.workspace
        let here = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let there = TestWindow.new(id: 2, parent: Workspace.get(byName: "there").rootTilingContainer)
        _ = there.focusWindow()
        _ = try await run("mark a")
        _ = here.focusWindow()
        let commands = try ["jump a", "mark b"].map { try XCTUnwrap(parseCommand($0).cmdOrNil) }
        let result = try await commands.runCmdSeq(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(WindowMarks.window(for: "b") === there)
    }

    func testMarkSkipsAMinimizedWindowMacOsStillReportsFocused() async throws {
        let workspace = focus.workspace
        let tiled = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let minimized = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        try await refreshWithMacOsFocus(on: minimized)
        try await refreshWithMacOsFocus(on: tiled)
        minimized.bind(to: macosMinimizedWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        try await refreshWithMacOsFocus(on: minimized)
        _ = tiled.focusWindow()
        _ = try await run("mark a")
        XCTAssertTrue(WindowMarks.window(for: "a") === tiled)
    }


    func testMarkActsOnTheCommandsTargetWindow() async throws {
        let workspace = focus.workspace
        let focused = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let target = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        _ = focused.focusWindow()
        let env = CmdEnv.defaultEnv.copy(\.windowId, 2)
        let marked = try await run("mark a", env: env)
        XCTAssertEqual(marked.exitCode, 0)
        XCTAssertTrue(WindowMarks.window(for: "a") === target)
        let registers = try await run("mark", env: env)
        XCTAssertEqual(registers.stdout, ["a"])
        let gone = try await run("mark a", env: CmdEnv.defaultEnv.copy(\.windowId, 9))
        XCTAssertEqual(gone.exitCode, 1)
    }

    func testFocusBackAgreesWithFilterAndReturnsAfterConfirmedFocusAcrossProjects() async throws {
        let here = focus.workspace
        let there = Workspace.get(byName: "there")
        there.assignProject(WorkspaceProjectId("other"))
        let a = TestWindow.new(id: 1, parent: here.rootTilingContainer)
        let b = TestWindow.new(id: 2, parent: there.rootTilingContainer)
        try await refreshWithMacOsFocus(on: a)
        try await refreshWithMacOsFocus(on: b)
        let context = try await filterContextRecord()
        XCTAssertEqual(context.previous?.id, 1)
        let before = a.lastFocusedSeq
        let first = try await run("focus-back")
        XCTAssertEqual(first.exitCode, 0)
        XCTAssertEqual(focus.windowOrNil?.windowId, 1)
        XCTAssertEqual(focus.workspace, here)
        XCTAssertEqual(a.lastFocusedSeq, before)
        XCTAssertTrue(TestApp.shared.focusedWindow === a)
        try await refreshWithMacOsFocus(on: a)
        let second = try await run("focus-back")
        XCTAssertEqual(second.exitCode, 0)
        XCTAssertEqual(focus.windowOrNil?.windowId, 2)
        XCTAssertEqual(focus.workspace.projectId, there.projectId)
    }

    func testFocusBackHasNoNeverFocusedOrEmptyWorkspaceFallback() async throws {
        _ = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer).focusWindow()
        _ = TestWindow.new(id: 2, parent: focus.workspace.rootTilingContainer)
        let result = try await run("focus-back")
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertEqual(result.stderr, ["No previously focused window"])
    }

    func testRegistersMoveAndBareMarkIsSortedAndJumpToFocusedSucceeds() async throws {
        let a = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        let b = TestWindow.new(id: 2, parent: focus.workspace.rootTilingContainer)
        _ = a.focusWindow()
        let empty = try await run("mark")
        XCTAssertEqual(empty.stdout, [])
        for register in ["z", "a", "c"] {
            let result = try await run("mark \(register)")
            XCTAssertEqual(result.exitCode, 0)
        }
        let marked = try await run("mark")
        XCTAssertEqual(marked.stdout, ["a c z"])
        _ = b.focusWindow()
        _ = try await run("mark a")
        _ = a.focusWindow()
        let moved = try await run("mark")
        XCTAssertEqual(moved.stdout, ["c z"])
        let jumped = try await run("jump a")
        XCTAssertEqual(jumped.exitCode, 0)
        XCTAssertEqual(focus.windowOrNil?.windowId, 2)
        let again = try await run("jump a")
        XCTAssertEqual(again.exitCode, 0)
    }

    func testMarkSurvivesWorkspaceMoveAndJumpSwitchesProject() async throws {
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        _ = window.focusWindow()
        _ = try await run("mark a")
        let destination = Workspace.get(byName: "destination")
        destination.assignProject(WorkspaceProjectId("other"))
        _ = try await run("move-node-to-workspace destination")
        _ = TestWindow.new(id: 2, parent: focus.workspace.rootTilingContainer).focusWindow()
        let result = try await run("jump a")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(focus.workspace, destination)
        XCTAssertEqual(focus.windowOrNil?.windowId, 1)
    }

    func testEmptyAndClosedRegistersFailAndDisappearFromAllReaders() async throws {
        let empty = try await run("jump b")
        XCTAssertEqual(empty.exitCode, 1)
        XCTAssertEqual(empty.stderr, ["Register b is empty"])
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        _ = window.focusWindow()
        _ = try await run("mark a")
        _ = try await run("close")
        let gone = try await run("jump a")
        XCTAssertEqual(gone.exitCode, 1)
        XCTAssertEqual(gone.stderr, ["Register a is empty"])
        let list = try await run("list-marks")
        XCTAssertEqual(list.stdout, [])
        let json = try await run("list-marks --json")
        let rows = try JSONSerialization.jsonObject(with: Data(json.stdout.joined().utf8)) as? [[String: Any]]
        XCTAssertEqual(rows?.count, 0)
    }

    func testNoFocusedWindowFailsMarkAndBareMark() async throws {
        for command in ["mark", "mark a"] {
            let result = try await run(command)
            XCTAssertEqual(result.exitCode, 1)
            XCTAssertEqual(result.stderr, [noWindowIsFocused])
        }
    }

    func testJumpAndFocusBackRestoreMinimizedWindowAtOrigin() async throws {
        for command in ["jump a", "focus-back"] {
            setUpWorkspacesForTests()
            let origin = Workspace.get(byName: "origin")
            origin.assignProject(WorkspaceProjectId("other"))
            let window = TestWindow.new(id: 1, parent: origin.rootTilingContainer)
            try await refreshWithMacOsFocus(on: window)
            _ = try await run("mark a")
            window.rememberMacOsLayoutOrigin(detachFromWorkspace: true)
            window.bind(to: macosMinimizedWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
            let current = TestWindow.new(id: 2, parent: Workspace.get(byName: "current").rootTilingContainer)
            try await refreshWithMacOsFocus(on: current)
            let result = try await run(command)
            XCTAssertEqual(result.exitCode, 0)
            XCTAssertEqual(window.layoutReason, .standard)
            XCTAssertEqual(focus.workspace, origin)
            XCTAssertEqual(focus.windowOrNil?.windowId, 1)
            XCTAssertTrue(TestApp.shared.focusedWindow === window)
        }
    }

    func testListingIsSortedPaddedAndHasListWindowsJsonKeys() async throws {
        let a = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        let b = TestWindow.new(id: 123, parent: focus.workspace.rootTilingContainer)
        _ = b.focusWindow()
        _ = try await run("mark z")
        _ = a.focusWindow()
        _ = try await run("mark a")
        let list = try await run("list-marks")
        XCTAssertEqual(list.stdout, ["a | 1   | bobko.WinMux.test-app | TestWindow(1)", "z | 123 | bobko.WinMux.test-app | TestWindow(123)"])
        let json = try await run("list-marks --json")
        let rows = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.stdout.joined().utf8)) as? [[String: Any]])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["register"] as? String, "a")
        XCTAssertEqual(rows[0]["window-id"] as? Int, 1)
        XCTAssertEqual(rows[0]["app-name"] as? String, "bobko.WinMux.test-app")
        XCTAssertEqual(rows[0]["window-title"] as? String, "TestWindow(1)")
        XCTAssertEqual(Set(rows[0].keys), ["register", "window-id", "app-name", "window-title"])
    }

    func testOnlyLowercaseSingleLetterRegistersAndNoFormatOption() {
        for command in ["mark A", "mark aa", "mark 1", "mark é", "mark a b", "jump", "jump Z", "jump ab", "list-marks --format x"] {
            XCTAssertNotNil(parseCommand(command).errorOrNil, command)
        }
        for command in ["mark", "mark a", "mark z", "jump a", "list-marks", "list-marks --json", "focus-back"] {
            XCTAssertNotNil(parseCommand(command).cmdOrNil, command)
        }
    }

    func testMarksFollowWindowIdsThroughReregistrationAndCacheRetention() async throws {
        let workspace = focus.workspace
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        _ = window.focusWindow()
        _ = try await run("mark a")
        window.unbindFromParent()
        Window.forgetWindows(except: [1])
        let missing = try await run("jump a")
        XCTAssertEqual(missing.exitCode, 1)
        let absent = try await run("list-marks")
        XCTAssertEqual(absent.stdout, [])
        let replacement = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        _ = replacement.focusWindow()
        let kept = try await run("mark")
        XCTAssertEqual(kept.stdout, ["a"])
        let jump = try await run("jump a")
        XCTAssertEqual(jump.exitCode, 0)
        XCTAssertTrue(TestApp.shared.focusedWindow === replacement)
        Window.forgetWindows(except: [])
        let forgotten = try await run("mark")
        XCTAssertEqual(forgotten.stdout, [])
        let empty = try await run("jump a")
        XCTAssertEqual(empty.exitCode, 1)
    }

    func testJumpRestoresHiddenAppAndFocusBackRaisesPopupWithoutReparenting() async throws {
        let origin = focus.workspace
        let window = TestWindow.new(id: 1, parent: origin.rootTilingContainer)
        _ = window.focusWindow()
        _ = try await run("mark a")
        window.rememberMacOsLayoutOrigin()
        window.bind(to: origin.macOsNativeHiddenAppsWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        let result = try await run("jump a")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(window.layoutReason, .standard)
        XCTAssertTrue(window.parent === origin.rootTilingContainer)
        XCTAssertTrue(TestApp.shared.focusedWindow === window)
        let popup = TestWindow.new(id: 2, parent: macosPopupWindowsContainer)
        popup.recordConfirmedFocus()
        let back = try await run("focus-back")
        XCTAssertEqual(back.exitCode, 0)
        XCTAssertTrue(popup.parent === macosPopupWindowsContainer)
        XCTAssertTrue(TestApp.shared.focusedWindow === popup)
        XCTAssertEqual(focus.windowOrNil?.windowId, 1)
    }

    func testUrlGateDistinguishesMarkQueryFromMutation() throws {
        for command in ["mark", "list-marks", "list-marks --json"] {
            let parsed = try XCTUnwrap(parseCommand(command).cmdOrNil)
            XCTAssertNotNil(urlCommandRefusal(kind: parsed.info.kind, args: parsed.args))
        }
        for command in ["mark a", "jump a", "focus-back"] {
            let parsed = try XCTUnwrap(parseCommand(command).cmdOrNil)
            XCTAssertNil(urlCommandRefusal(kind: parsed.info.kind, args: parsed.args))
        }
    }

    func testRestoringFocusCommandsRequirePostCommandRefresh() throws {
        for text in ["focus-back", "jump a"] {
            let command = try XCTUnwrap(parseCommand(text).cmdOrNil)
            XCTAssertFalse(command.canSkipPostCommandRefresh, text)
        }
    }
}
