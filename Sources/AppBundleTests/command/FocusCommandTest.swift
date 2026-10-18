@testable import AppBundle
import Common
import XCTest

// todo write tests
//
// test 1
//     horizontal
//         window1
//         vertical
//             vertical
//                 window2 <-- focused
//             vertical
//                 window5
//                 horizontal
//                     window3
//                     window4
// pre-condition: focus_wrapping force_workspace
// action: focus up
// expected: mru(window3, window4) is focused

@MainActor
final class FocusCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        XCTAssertTrue(parseCommand("focus --boundaries left").errorOrNil?.contains("Possible values") == true)
        var expected = FocusCmdArgs(rawArgs: [], targetArg: .direction(.left))
        expected.rawBoundaries = .workspace
        testParseCommandSucc("focus --boundaries workspace left", expected)

        expected = FocusCmdArgs(rawArgs: [], targetArg: .tabRelative(.tabNext))
        testParseCommandSucc("focus tab-next", expected)
        testParseCommandSucc("focus --tab-index 2", FocusCmdArgs(rawArgs: [], tabIndex: .position(2)))

        assertEquals(
            parseCommand("focus --boundaries workspace --boundaries workspace left").errorOrNil,
            "ERROR: Duplicated option '--boundaries'",
        )
        assertEquals(
            parseCommand("focus --window-id 42 --ignore-floating").errorOrNil,
            "--window-id is incompatible with other options",
        )
        assertEquals(
            parseCommand("focus --boundaries all-monitors-outer-frame dfs-next").errorOrNil,
            "(dfs-next|dfs-prev|tab-next|tab-prev) only supports --boundaries workspace",
        )
        assertEquals(
            parseCommand("focus --boundaries all-monitors-outer-frame tab-next").errorOrNil,
            "(dfs-next|dfs-prev|tab-next|tab-prev) only supports --boundaries workspace",
        )

        assertEquals(
            parseCommand("focus --window-id 42 --wrap-around").errorOrNil,
            "--window-id is incompatible with other options",
        )
        assertEquals(
            parseCommand("focus --tab-index 2 --wrap-around").errorOrNil,
            "--tab-index is incompatible with other options",
        )
        assertEquals(
            parseCommand("focus left --boundaries-action wrap-around-the-workspace --wrap-around").errorOrNil,
            "ERROR: Conflicting options: --boundaries-action, --wrap-around",
        )
    }

    func testParseLastTabIndex() {
        testParseCommandSucc("focus --tab-index last", FocusCmdArgs(rawArgs: [], tabIndex: .last))
        for value in ["0", "Last", "first", "4294967296"] {
            XCTAssertEqual(parseCommand("focus --tab-index \(value)").errorOrNil,
                           "ERROR: '--tab-index' must be followed by a UInt32 greater than zero or 'last'", value)
        }
        XCTAssertEqual(parseCommand("focus --tab-index last --wrap-around").errorOrNil,
                       "--tab-index is incompatible with other options")
        XCTAssertEqual(parseCommand("focus --tab-index -1").errorOrNil,
                       "ERROR: '--tab-index' must be followed by a UInt32 greater than zero or 'last'\nERROR: Unknown flag '-1'")
        for missing in ["focus --tab-index", "focus --tab-index --wrap-around"] {
            XCTAssertEqual(parseCommand(missing).errorOrNil,
                           "ERROR: '--tab-index' must be followed by a UInt32 greater than zero or 'last'", missing)
        }
    }

    func testFocus() {
        assertEquals(focus.windowOrNil, nil)
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0)
        }
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testFocusOverFloatingWindows() async throws {
        assertEquals(focus.windowOrNil, nil)
        Workspace.get(byName: name).apply {
            TestWindow.new(id: 1, parent: $0, rect: Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100))
            assertEquals(TestWindow.new(id: 2, parent: $0, rect: Rect(topLeftX: 10, topLeftY: 10, width: 100, height: 100)).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0, rect: Rect(topLeftX: 20, topLeftY: 20, width: 100, height: 100))
        }

        assertEquals(focus.windowOrNil?.windowId, 2)
        try await FocusCommand.new(direction: .right).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 3)
    }

    func testFocusAlongTheContainerOrientation() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)
        try await FocusCommand.new(direction: .right).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testFocusAcrossTheContainerOrientation() async throws {
        Workspace.get(byName: name).apply {
            TestWindow.new(id: 1, parent: $0.rootTilingContainer)
            TestWindow.new(id: 2, parent: $0.rootTilingContainer)
            assertEquals($0.focusWorkspace(), true)
        }

        assertEquals(focus.windowOrNil?.windowId, 2)
        try await FocusCommand.new(direction: .up).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
        try await FocusCommand.new(direction: .down).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testFocusNoWrapping() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)
        try await FocusCommand.new(direction: .left).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFocusWrapping() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)
        var args = FocusCmdArgs(rawArgs: [], targetArg: .direction(.left))
        args.rawBoundaries = .workspace
        args.rawBoundariesAction = .wrapAroundTheWorkspace
        try await FocusCommand(args: args).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testFocusFindMruLeaf() async throws {
        let workspace = Workspace.get(byName: name)
        var startWindow: Window!
        var window2: Window!
        var window3: Window!
        var unrelatedWindow: Window!
        workspace.rootTilingContainer.apply {
            startWindow = TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    window2 = TestWindow.new(id: 2, parent: $0)
                    unrelatedWindow = TestWindow.new(id: 5, parent: $0)
                }
                window3 = TestWindow.new(id: 3, parent: $0)
            }
        }

        assertEquals(workspace.mostRecentWindowRecursive?.windowId, 3) // The latest bound
        _ = startWindow.focusWindow()
        try await FocusCommand.new(direction: .right).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 3)

        window2.markAsMostRecentChild()
        _ = startWindow.focusWindow()
        try await FocusCommand.new(direction: .right).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)

        window3.markAsMostRecentChild()
        unrelatedWindow.markAsMostRecentChild()
        _ = startWindow.focusWindow()
        try await FocusCommand.new(direction: .right).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testFocusOutsideOfTheContainer() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            }
        }

        try await FocusCommand.new(direction: .left).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFocusOutsideOfTheContainer2() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            }
        }

        try await FocusCommand.new(direction: .left).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFocusDfsRelative() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow.new(id: 2, parent: $0)
                    TestWindow.new(id: 3, parent: $0)
                }
            }
            TestWindow.new(id: 4, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)

        try await FocusCommand.new(dfsRelative: .dfsNext).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
        try await FocusCommand.new(dfsRelative: .dfsNext).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 3)
        try await FocusCommand.new(dfsRelative: .dfsNext).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 4)

        try await FocusCommand.new(dfsRelative: .dfsPrev).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 3)
        try await FocusCommand.new(dfsRelative: .dfsPrev).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
        try await FocusCommand.new(dfsRelative: .dfsPrev).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFocusDfsRelativeWrapping() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)

        var args = FocusCmdArgs(rawArgs: [], targetArg: .dfsRelative(.dfsPrev))

        args.rawBoundariesAction = .stop
        assertEquals(try await FocusCommand(args: args).run(.defaultEnv, .emptyStdin).exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 1)

        args.rawBoundariesAction = .fail
        assertEquals(try await FocusCommand(args: args).run(.defaultEnv, .emptyStdin).exitCode, 1)
        assertEquals(focus.windowOrNil?.windowId, 1)

        args.rawBoundariesAction = .wrapAroundTheWorkspace
        assertEquals(try await FocusCommand(args: args).run(.defaultEnv, .emptyStdin).exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 2)

        args.targetArg = .dfsRelative(.dfsNext)

        args.rawBoundariesAction = .stop
        assertEquals(try await FocusCommand(args: args).run(.defaultEnv, .emptyStdin).exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 2)

        args.rawBoundariesAction = .fail
        assertEquals(try await FocusCommand(args: args).run(.defaultEnv, .emptyStdin).exitCode, 1)
        assertEquals(focus.windowOrNil?.windowId, 2)

        args.rawBoundariesAction = .wrapAroundTheWorkspace
        assertEquals(try await FocusCommand(args: args).run(.defaultEnv, .emptyStdin).exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFocusTabRelativeStaysInsideCurrentTabGroup() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        var middleTab: Window!
        var lastTab: Window!
        root.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer(parent: $0, adaptiveWeight: 1, .v, .tabGroup, index: INDEX_BIND_LAST).apply {
                TestWindow.new(id: 2, parent: $0)
                middleTab = TestWindow.new(id: 3, parent: $0)
                lastTab = TestWindow.new(id: 4, parent: $0)
            }
            TestWindow.new(id: 5, parent: $0)
        }

        XCTAssertTrue(middleTab.focusWindow())

        try await FocusCommand.new(tabRelative: .tabNext).run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(focus.windowOrNil?.windowId, lastTab.windowId)
    }

    func testFocusTabRelativeWrapsInsideCurrentTabGroup() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        var firstTab: Window!
        var lastTab: Window!
        root.apply {
            TilingContainer(parent: $0, adaptiveWeight: 1, .v, .tabGroup, index: INDEX_BIND_LAST).apply {
                firstTab = TestWindow.new(id: 1, parent: $0)
                TestWindow.new(id: 2, parent: $0)
                lastTab = TestWindow.new(id: 3, parent: $0)
            }
        }

        XCTAssertTrue(lastTab.focusWindow())

        var args = FocusCmdArgs(rawArgs: [], targetArg: .tabRelative(.tabNext))
        args.rawBoundariesAction = .wrapAroundTheWorkspace
        let exitCode = try await FocusCommand(args: args).run(.defaultEnv, .emptyStdin).exitCode
        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(focus.windowOrNil?.windowId, firstTab.windowId)
    }

    func testFocusTabRelativeFailsOutsideTabGroupWhenRequested() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            XCTAssertTrue(TestWindow.new(id: 1, parent: $0).focusWindow())
            TestWindow.new(id: 2, parent: $0)
        }

        var args = FocusCmdArgs(rawArgs: [], targetArg: .tabRelative(.tabNext))
        args.rawBoundariesAction = .fail

        let exitCode = try await FocusCommand(args: args).run(.defaultEnv, .emptyStdin).exitCode
        XCTAssertEqual(exitCode, 1)
        XCTAssertEqual(focus.windowOrNil?.windowId, 1)
    }

    func testFocusTabIndexTargetsSpecificTabInsideCurrentGroup() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        var firstTab: Window!
        var secondTab: Window!
        root.apply {
            TilingContainer(parent: $0, adaptiveWeight: 1, .v, .tabGroup, index: INDEX_BIND_LAST).apply {
                firstTab = TestWindow.new(id: 1, parent: $0)
                secondTab = TestWindow.new(id: 2, parent: $0)
                _ = TestWindow.new(id: 3, parent: $0)
            }
        }

        XCTAssertTrue(firstTab.focusWindow())

        let exitCode = try await FocusCommand(args: FocusCmdArgs(rawArgs: [], tabIndex: .position(2))).run(.defaultEnv, .emptyStdin).exitCode
        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(focus.windowOrNil?.windowId, secondTab.windowId)
    }

    func testLastTabOnOneTab() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer
        let group = TilingContainer(parent: root, adaptiveWeight: 1, .h, .tabGroup, index: INDEX_BIND_LAST)
        let window = TestWindow.new(id: 1, parent: group)
        XCTAssertTrue(window.focusWindow())
        let result = try await FocusCommand(args: .init(rawArgs: [], tabIndex: .last)).run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(focus.windowOrNil?.windowId, 1)
    }

    func testLastAndEighthTabOnTwelveTabs() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer
        let group = TilingContainer(parent: root, adaptiveWeight: 1, .h, .tabGroup, index: INDEX_BIND_LAST)
        let windows = (1...12).map { TestWindow.new(id: UInt32($0), parent: group) }
        XCTAssertTrue(windows[0].focusWindow())
        let last = try await FocusCommand(args: .init(rawArgs: [], tabIndex: .last)).run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(last.exitCode, 0)
        XCTAssertEqual(focus.windowOrNil?.windowId, 12)
        let eighth = try await FocusCommand(args: .init(rawArgs: [], tabIndex: .position(8))).run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(eighth.exitCode, 0)
        XCTAssertEqual(focus.windowOrNil?.windowId, 8)
    }

    func testPositionPastEndPreservesFocus() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer
        let group = TilingContainer(parent: root, adaptiveWeight: 1, .h, .tabGroup, index: INDEX_BIND_LAST)
        let windows = (1...3).map { TestWindow.new(id: UInt32($0), parent: group) }
        XCTAssertTrue(windows[1].focusWindow())
        let result = try await FocusCommand(args: .init(rawArgs: [], tabIndex: .position(9))).run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertEqual(result.stderr, ["Can't find tab with index 9 in the current tab group"])
        XCTAssertEqual(focus.windowOrNil?.windowId, 2)
    }

    func testLastOutsideTabGroupFails() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer
        XCTAssertTrue(TestWindow.new(id: 1, parent: root).focusWindow())
        let result = try await FocusCommand(args: .init(rawArgs: [], tabIndex: .last)).run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertEqual(result.stderr, ["Can't find the last tab in the current tab group"])
        XCTAssertEqual(focus.windowOrNil?.windowId, 1)
    }

    func testLastPrefersTheEnclosingGroupOverASingleTabLayoutInsideIt() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer
        let group = TilingContainer(parent: root, adaptiveWeight: 1, .h, .tabGroup, index: INDEX_BIND_LAST)
        let single = TilingContainer(parent: group, adaptiveWeight: 1, .h, .tabGroup, index: INDEX_BIND_LAST)
        let inner = TestWindow.new(id: 1, parent: single)
        TestWindow.new(id: 2, parent: group)
        let last = TestWindow.new(id: 3, parent: group)
        XCTAssertTrue(inner.focusWindow())
        let result = try await FocusCommand(args: .init(rawArgs: [], tabIndex: .last)).run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(focus.windowOrNil?.windowId, last.windowId)
    }

    func testTabTargetsDoNotTakeAFloatingWindowRightOfTheActiveTabAsATab() async throws {
        let workspace = Workspace.get(byName: name)
        let group = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: 1, .h, .tabGroup, index: INDEX_BIND_LAST)
        group.lastAppliedLayoutVirtualRect = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        TestWindow.new(id: 1, parent: group, rect: rect)
        TestWindow.new(id: 2, parent: group, rect: rect)
        let third = TestWindow.new(id: 3, parent: group, rect: rect)
        TestWindow.new(id: 4, parent: workspace, rect: Rect(topLeftX: 500, topLeftY: 0, width: 100, height: 100))
        let commands = [FocusCommand(args: .init(rawArgs: [], tabIndex: .last)), .new(tabRelative: .tabNext)]
        for command in commands {
            XCTAssertTrue(third.focusWindow())
            _ = try await command.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(focus.windowOrNil?.windowId, 3, "\(command.args)")
        }
    }

    func testTabTargetsDoNotTakeAFloatingWindowLeftOfTheFirstTabAsATab() async throws {
        let workspace = Workspace.get(byName: name)
        let group = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: 1, .h, .tabGroup, index: INDEX_BIND_LAST)
        group.lastAppliedLayoutVirtualRect = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        let rect = Rect(topLeftX: 400, topLeftY: 0, width: 100, height: 100)
        let first = TestWindow.new(id: 1, parent: group, rect: rect)
        TestWindow.new(id: 2, parent: group, rect: rect)
        TestWindow.new(id: 3, parent: workspace, rect: Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100))
        for command in [FocusCommand(args: .init(rawArgs: [], tabIndex: .position(1))), .new(tabRelative: .tabPrev)] {
            XCTAssertTrue(first.focusWindow())
            _ = try await command.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(focus.windowOrNil?.windowId, 1, "\(command.args)")
        }
    }

    func testLastNestedTabResolvesMostRecentWindow() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer
        let group = TilingContainer(parent: root, adaptiveWeight: 1, .h, .tabGroup, index: INDEX_BIND_LAST)
        let first = TestWindow.new(id: 1, parent: group)
        let nested = TilingContainer(parent: group, adaptiveWeight: 1, .v, .tiles, index: INDEX_BIND_LAST)
        TestWindow.new(id: 2, parent: nested)
        let recent = TestWindow.new(id: 3, parent: nested)
        XCTAssertTrue(recent.focusWindow())
        XCTAssertTrue(first.focusWindow())
        let result = try await FocusCommand(args: .init(rawArgs: [], tabIndex: .last)).run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(focus.windowOrNil?.windowId, recent.windowId)
    }
}

extension FocusCommand {
    static func new(direction: CardinalDirection) -> FocusCommand {
        FocusCommand(args: FocusCmdArgs(rawArgs: [], targetArg: .direction(direction)))
    }
    static func new(dfsRelative: DfsNextPrev) -> FocusCommand {
        FocusCommand(args: FocusCmdArgs(rawArgs: [], targetArg: .dfsRelative(dfsRelative)))
    }
    static func new(tabRelative: TabNextPrev) -> FocusCommand {
        FocusCommand(args: FocusCmdArgs(rawArgs: [], targetArg: .tabRelative(tabRelative)))
    }
}
