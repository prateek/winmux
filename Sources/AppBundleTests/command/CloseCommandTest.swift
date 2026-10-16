@testable import AppBundle
import Common
import XCTest

@MainActor
final class CloseCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testFailedCloseReportsEachReasonAndPreservesTheExactBinding() async throws {
        for reason in [WindowCloseFailure.noCloseButton, .appRefused] {
            for explicitTarget in [false, true] {
                setUpWorkspacesForTests()
                let workspace = Workspace.get(byName: "1")
                let parent = workspace.rootTilingContainer
                let first = TestWindow.new(id: 1, parent: parent)
                let target = TestWindow.new(id: 2, parent: parent)
                let last = TestWindow.new(id: 3, parent: parent)
                target.closeResult = .notClosed(reason)
                _ = (explicitTarget ? first : target).focusWindow()
                var args = CloseCmdArgs(rawArgs: [])
                if explicitTarget { args.windowId = target.windowId }
                let io = CmdIo(stdin: .emptyStdin)

                let success = try await CloseCommand(args: args).run(.defaultEnv, io)

                XCTAssertFalse(success)
                XCTAssertEqual(io.stderr, ["Can't close '\(target.app.name!)': \(reason.rawValue)"])
                XCTAssertTrue(io.stdout.isEmpty)
                XCTAssertEqual(io.failureExitCode, 1)
                XCTAssertTrue(target.parent === parent)
                XCTAssertTrue(target.nodeWorkspace === workspace)
                XCTAssertEqual(parent.children.map { ($0 as! Window).windowId }, [first.windowId, target.windowId, last.windowId])
                XCTAssertTrue(Window.get(byId: target.windowId) === target)
            }
        }
    }

    func testAcceptedCloseReturnsSuccessAndRemovesTheWindow() async throws {
        let parent = Workspace.get(byName: "1").rootTilingContainer
        let target = TestWindow.new(id: 1, parent: parent)
        let survivor = TestWindow.new(id: 2, parent: parent)
        _ = target.focusWindow()
        let io = CmdIo(stdin: .emptyStdin)

        let success = try await CloseCommand(args: CloseCmdArgs(rawArgs: [])).run(.defaultEnv, io)

        XCTAssertTrue(success)
        XCTAssertTrue(io.stderr.isEmpty)
        XCTAssertFalse(target.isBound)
        XCTAssertNil(Window.get(byId: target.windowId))
        XCTAssertEqual(parent.children.map { ($0 as! Window).windowId }, [survivor.windowId])
    }

    func testCloseAllContinuesAfterFailureAndKeepsOnlyUnclosedWindows() async throws {
        let parent = Workspace.get(byName: "1").rootTilingContainer
        let current = TestWindow.new(id: 1, parent: parent)
        let failure = TestWindow.new(id: 2, parent: parent)
        let success = TestWindow.new(id: 3, parent: parent)
        failure.closeResult = .notClosed(.appRefused)
        _ = current.focusWindow()
        let io = CmdIo(stdin: .emptyStdin)

        let result = try await parseCommand("close-all-windows-but-current").cmdOrDie.run(.defaultEnv, io)

        XCTAssertFalse(result)
        XCTAssertEqual(io.stderr, ["Can't close '\(failure.app.name!)': the app refused"])
        XCTAssertTrue(current.isBound)
        XCTAssertTrue(failure.parent === parent)
        XCTAssertFalse(success.isBound)
        XCTAssertEqual(parent.children.map { ($0 as! Window).windowId }, [1, 2])
    }

    func testMarkedLensCloseTriesEveryWindowAndReportsFailure() async throws {
        for presentation in ["strip", "list", "grid", "miniatures"] {
            setUpWorkspacesForTests()
            let parent = Workspace.get(byName: "1").rootTilingContainer
            let failed = TestWindow.new(id: 1, parent: parent)
            let closed = TestWindow.new(id: 2, parent: parent)
            failed.closeResult = .notClosed(.noCloseButton)
            var settings = LensConfig(); settings.presentation = presentation
            let items = [failed, closed].map {
                SwitcherPaletteItem(id: $0.windowId, title: "Window", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false)
            }
            let session = LensSession(name: "close", settings: settings, items: items, search: "")
            session.hover(1); session.toggleMark()
            session.hover(2); session.toggleMark()
            session.hover(1)
            let io = CmdIo(stdin: .emptyStdin)

            let result = try await runLensAction(["close"], session: session, io: io)

            XCTAssertFalse(result)
            XCTAssertEqual(io.stderr, ["Can't close '\(failed.app.name!)': the window has no close button"])
            XCTAssertTrue(failed.parent === parent)
            XCTAssertFalse(closed.isBound)
            XCTAssertEqual(session.results.compactMap { Window.get(byId: $0.id)?.windowId }, [1])
            XCTAssertEqual(session.selectedId, 1)
            XCTAssertEqual(session.settings.presentation, presentation)
        }
    }

    func testReadOnlyCloseFailsWithoutAttemptingOrRemovingTheWindow() async throws {
        let parent = Workspace.get(byName: "1").rootTilingContainer
        let window = TestWindow.new(id: 1, parent: parent)
        _ = window.focusWindow()
        let io = CmdIo(stdin: .emptyStdin)

        let success = try await CloseCommand(args: CloseCmdArgs(rawArgs: []), isReadOnly: true).run(.defaultEnv, io)

        XCTAssertFalse(success)
        XCTAssertEqual(io.stderr, ["Can't close '\(window.app.name!)': WinMux is read-only"])
        XCTAssertEqual(window.closeAttempts, 0)
        XCTAssertTrue(window.parent === parent)
        XCTAssertTrue(Window.get(byId: 1) === window)
    }

    func testAgentCloseRetainsFailedWindowAndClosesAnOrdinaryWindow() async throws {
        for reason in [WindowCloseFailure.noCloseButton, .appRefused] {
            setUpWorkspacesForTests()
            let workspace = Workspace.get(byName: "1")
            let failed = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
            let ordinary = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
            failed.closeResult = .notClosed(reason)
            var context = AgentApplyContext()

            try await AgentOperation.closeWindow(windowId: failed.windowId, quitAppIfLastWindow: false).apply(context: &context)
            try await AgentOperation.closeWindow(windowId: ordinary.windowId, quitAppIfLastWindow: false).apply(context: &context)

            XCTAssertTrue(failed.parent === workspace.rootTilingContainer)
            XCTAssertTrue(failed.nodeWorkspace === workspace)
            XCTAssertFalse(ordinary.isBound)
            XCTAssertEqual(failed.closeAttempts, 1)
            XCTAssertEqual(ordinary.closeAttempts, 1)
        }
    }

    func testProjectDeletionPreservesTheProjectWhenAWindowRefusesClose() async throws {
        let defaultWorkspace = Workspace.get(byName: "1")
        _ = TestWindow.new(id: 1, parent: defaultWorkspace.rootTilingContainer)
        let project = createWorkspaceProject()
        let workspace = Workspace.get(byName: "2")
        workspace.assignProject(project.id)
        let failed = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        failed.closeResult = .notClosed(.appRefused)
        let ordinary = TestWindow.new(id: 3, parent: workspace.rootTilingContainer)
        config.workspaceSidebar.projectDeletionAction = .closeWindows

        do {
            try await deleteWorkspaceProjectFromSidebar(project.id)
            XCTFail("A window that remains on the project must block deletion")
        } catch WorkspaceMutationError.projectCloseBlocked(_, let count) {
            XCTAssertEqual(count, 1)
        }

        XCTAssertTrue(workspaceProjects().contains { $0.id == project.id })
        XCTAssertTrue(failed.parent === workspace.rootTilingContainer)
        XCTAssertTrue(failed.nodeWorkspace === workspace)
        XCTAssertFalse(ordinary.isBound)
    }

    func testSimple() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(focus.workspace.rootTilingContainer.children.count, 2)

        try await CloseCommand(args: CloseCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)

        assertEquals(focus.windowOrNil?.windowId, 2)
        assertEquals(focus.workspace.rootTilingContainer.children.count, 1)
    }

    func testCloseViaWindowIdFlag() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(focus.workspace.rootTilingContainer.children.count, 2)

        try await CloseCommand(args: CloseCmdArgs(rawArgs: []).copy(\.windowId, 2)).run(.defaultEnv, .emptyStdin)

        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(focus.workspace.rootTilingContainer.children.count, 1)
    }
}
