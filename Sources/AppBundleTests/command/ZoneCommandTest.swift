@testable import AppBundle
import Common
import Foundation
import XCTest

@MainActor
final class ZoneCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseCommandSucc("focus-column left", FocusColumnCmdArgs(column: ColumnSelector("left")))
        testParseCommandSucc("focus-column zone:left", FocusColumnCmdArgs(column: ColumnSelector("zone:left")))
        testParseCommandSucc("focus-column next", FocusColumnCmdArgs(column: ColumnSelector("next")))
        testParseCommandSucc("move-node-to-column --window-id 7 --focus-follows-window --fail-if-noop Comms",
                             MoveNodeToColumnCmdArgs(column: ColumnSelector("Comms"))
                                 .copy(\.windowId, 7)
                                 .copy(\.focusFollowsWindow, true)
                                 .copy(\.failIfNoop, true))
        testParseCommandSucc(
            "move-node-to-column --focus-follows-window prev",
            MoveNodeToColumnCmdArgs(column: ColumnSelector("prev")).copy(\.focusFollowsWindow, true),
        )
        testParseCommandSucc("column expand Comms", ColumnCmdArgs(target: .expand(column: ColumnSelector("Comms"))))
        testParseCommandSucc("column collapse Comms --monitor 1", ColumnCmdArgs(target: .collapse(column: ColumnSelector("Comms")), monitor: .sequenceNumber(1)))
        testParseCommandSucc("column toggle 2:Comms", ColumnCmdArgs(target: .toggle(column: ColumnSelector("2:Comms"))))
        testParseCommandSucc("column toggle", ColumnCmdArgs(target: .toggle(column: ColumnSelector("focused"))))
        testParseCommandSucc(
            "column resize +10% Work",
            ColumnCmdArgs(target: .resize(amount: .add(0.10), column: ColumnSelector("Work"))),
        )
        testParseCommandSucc(
            "column resize -10%",
            ColumnCmdArgs(target: .resize(amount: .subtract(0.10), column: ColumnSelector("focused"))),
        )
        testParseCommandSucc(
            "column resize -10% Work",
            ColumnCmdArgs(target: .resize(amount: .subtract(0.10), column: ColumnSelector("Work"))),
        )
        testParseCommandSucc(
            "column resize 60% Work",
            ColumnCmdArgs(target: .resize(amount: .set(0.60), column: ColumnSelector("Work"))),
        )
        testParseCommandSucc(
            "balance-columns --monitor 1",
            BalanceColumnsCmdArgs(monitor: .sequenceNumber(1)),
        )
        testParseCommandSucc(
            "column init --dry-run --preset balanced",
            ColumnCmdArgs(target: .initialize, preset: .balanced, dryRun: true),
        )
        testParseCommandSucc(
            "column init --write --replace-existing --preset comms-open --monitor 1",
            ColumnCmdArgs(target: .initialize, preset: .commsOpen, monitor: .sequenceNumber(1), write: true, replaceExisting: true),
        )
        testParseCommandFail("column init --dry-run --write", msg: "ERROR: Conflicting options: --dry-run, --write")
        testParseCommandSucc(
            "config --check /tmp/winmux-exported-zone-layout.toml",
            ConfigCmdArgs(commonState: .init([])).copy(\.configPathToCheck, "/tmp/winmux-exported-zone-layout.toml"),
        )
        testParseCommandSucc(
            "config --restore-backup /tmp/winmux.toml.backup-20260702T010203Z",
            ConfigCmdArgs(commonState: .init([])).copy(\.backupPathToRestore, "/tmp/winmux.toml.backup-20260702T010203Z"),
        )
        testParseCommandSucc(
            "column color #D3455B Comms --monitor 1",
            ColumnCmdArgs(target: .color(hex: "#D3455B", column: ColumnSelector("Comms")), monitor: .sequenceNumber(1)),
        )
        testParseCommandSucc(
            "column color #3EA2FF",
            ColumnCmdArgs(target: .color(hex: "#3EA2FF", column: ColumnSelector("focused"))),
        )
        testParseCommandFail("column color oops", msg: "ERROR: <hex> must start with '#', for example #3EA2FF")
        testParseCommandSucc(
            "set-column-snap-policy --monitor 1 snap-to-column",
            SetColumnSnapPolicyCmdArgs(policyId: "snap-to-column", monitor: .sequenceNumber(1)),
        )
        testParseCommandSucc(
            "cycle-column-snap-policy freeform snap-to-column",
            CycleColumnSnapPolicyCmdArgs(policyIds: ["freeform", "snap-to-column"]),
        )
        testParseCommandFail("column resize 10 Work", msg: "ERROR: <percent> must include a % suffix, for example +10%")
        testParseCommandSucc("list-columns --json", ListColumnsCmdArgs(rawArgs: []).copy(\.json, true))
    }

    func testFocusZoneResolvesColumnName() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(work.focusWorkspace())

        let result = try await FocusColumnCommand(args: FocusColumnCmdArgs(column: ColumnSelector("Reference")))
            .run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(focus.workspace === reference)
    }

    func testFocusZoneResolvesColumnIdPrefix() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))

        let result = try await FocusColumnCommand(args: FocusColumnCmdArgs(column: ColumnSelector("zone:left")))
            .run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(focus.workspace === reference)
    }

    func testRelativeZoneSelectorsFocusWithinFocusedPhysicalMonitor() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        XCTAssertTrue(work.focusWorkspace())

        let next = try await parseCommand("focus-column next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(next.exitCode, 0)
        XCTAssertTrue(focus.workspace === comms)

        let previous = try await parseCommand("focus-column prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(previous.exitCode, 0)
        XCTAssertTrue(focus.workspace === work)

        let current = try await parseCommand("focus-column current").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(current.exitCode, 0)
        XCTAssertTrue(focus.workspace === work)
    }

    func testRelativeZoneSelectorsStayWithinFocusedPhysicalMonitorWhenColumnIdsRepeat() async throws {
        let zones = configureDuplicateZones()
        let primaryLeft = Workspace.get(byName: "primary-left")
        let primaryMain = Workspace.get(byName: "primary-main")
        let secondaryLeft = Workspace.get(byName: "secondary-left")
        let secondaryMain = Workspace.get(byName: "secondary-main")
        XCTAssertTrue(zones["1:left"].orDie().setActiveWorkspace(primaryLeft))
        XCTAssertTrue(zones["1:main"].orDie().setActiveWorkspace(primaryMain))
        XCTAssertTrue(zones["2:left"].orDie().setActiveWorkspace(secondaryLeft))
        XCTAssertTrue(zones["2:main"].orDie().setActiveWorkspace(secondaryMain))
        XCTAssertTrue(secondaryMain.focusWorkspace())

        let previous = try await parseCommand("focus-column prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(previous.exitCode, 0)
        XCTAssertTrue(focus.workspace === secondaryLeft)

        let next = try await parseCommand("focus-column next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(next.exitCode, 0)
        XCTAssertTrue(focus.workspace === secondaryMain)
    }

    func testQualifiedRelativeZoneSelectorsResolveWithinQualifiedPhysicalMonitor() async throws {
        let zones = configureDuplicateZones()
        let primaryLeft = Workspace.get(byName: "primary-left")
        let primaryMain = Workspace.get(byName: "primary-main")
        let secondaryLeft = Workspace.get(byName: "secondary-left")
        let secondaryMain = Workspace.get(byName: "secondary-main")
        XCTAssertTrue(zones["1:left"].orDie().setActiveWorkspace(primaryLeft))
        XCTAssertTrue(zones["1:main"].orDie().setActiveWorkspace(primaryMain))
        XCTAssertTrue(zones["2:left"].orDie().setActiveWorkspace(secondaryLeft))
        XCTAssertTrue(zones["2:main"].orDie().setActiveWorkspace(secondaryMain))
        XCTAssertTrue(secondaryMain.focusWorkspace())

        let primaryNext = try await parseCommand("focus-column 1:next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(primaryNext.exitCode, 0)
        XCTAssertTrue(focus.workspace === primaryLeft)

        let primaryCurrent = try await parseCommand("focus-column 1:current").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(primaryCurrent.exitCode, 0)
        XCTAssertTrue(focus.workspace === primaryLeft)

        let secondaryPrevious = try await parseCommand("focus-column 2:prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(secondaryPrevious.exitCode, 0)
        XCTAssertTrue(focus.workspace === secondaryLeft)

        let missingCurrent = try await parseCommand("focus-column 1:current").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(missingCurrent.exitCode, 1)
        XCTAssertTrue(missingCurrent.stderr.joined(separator: "\n").contains("No focused column matches"))
    }

    func testDuplicateBareColumnIdsRequirePhysicalQualifier() async throws {
        let zones = configureDuplicateZones()
        let secondaryLeft = Workspace.get(byName: "secondary-left")
        _ = TestWindow.new(id: 31, parent: secondaryLeft.rootTilingContainer)
        XCTAssertTrue(zones["2:left"].orDie().setActiveWorkspace(secondaryLeft))

        let ambiguous = try await FocusColumnCommand(args: FocusColumnCmdArgs(column: ColumnSelector("left")))
            .run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(ambiguous.exitCode, 1)
        XCTAssertTrue(ambiguous.stderr.joined(separator: "\n").contains("ambiguous"))

        let qualified = try await FocusColumnCommand(args: FocusColumnCmdArgs(column: ColumnSelector("2:left")))
            .run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(qualified.exitCode, 0)
        XCTAssertTrue(focus.workspace === secondaryLeft)
    }

    func testFocusMonitorNumericSelectorStaysPhysical() async throws {
        let zones = configureThreeZones(defaultZone: "main")
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(reference.focusWorkspace())

        let result = try await parseCommand("focus-monitor 1").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(focus.workspace === work)
    }

    func testMoveNodeToZoneMovesFocusedWindow() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let window = TestWindow.new(id: 41, parent: work.rootTilingContainer)
        XCTAssertTrue(window.focusWindow())

        let result = try await MoveNodeToColumnCommand(args: MoveNodeToColumnCmdArgs(column: ColumnSelector("Comms")).copy(\.failIfNoop, true))
            .run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(window.nodeWorkspace === comms)
    }

    func testMoveNodeToRelativeZoneMovesFocusedTabGroup() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let tabGroup = TilingContainer(parent: work.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .h, .tabGroup, index: INDEX_BIND_LAST)
        let first = TestWindow.new(id: 53, parent: tabGroup)
        let second = TestWindow.new(id: 54, parent: tabGroup)
        XCTAssertTrue(first.focusWindow())

        let result = try await parseCommand("move-node-to-column --focus-follows-window next").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(tabGroup.nodeWorkspace === comms)
        XCTAssertTrue(first.nodeWorkspace === comms)
        XCTAssertTrue(second.nodeWorkspace === comms)
        XCTAssertTrue(focus.workspace === comms)
    }

    func testMoveNodeToZoneFailsWhenNoopIsStrict() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        let window = TestWindow.new(id: 42, parent: work.rootTilingContainer)
        XCTAssertTrue(window.focusWindow())

        let result = try await MoveNodeToColumnCommand(args: MoveNodeToColumnCmdArgs(column: ColumnSelector("Work")).copy(\.failIfNoop, true))
            .run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(window.nodeWorkspace === work)
    }

    func testMoveNodeToZoneUsesWindowId() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let targetWindow = TestWindow.new(id: 43, parent: work.rootTilingContainer)
        let focusedWindow = TestWindow.new(id: 44, parent: work.rootTilingContainer)
        XCTAssertTrue(focusedWindow.focusWindow())

        let result = try await MoveNodeToColumnCommand(args: MoveNodeToColumnCmdArgs(column: ColumnSelector("Comms")).copy(\.windowId, 43))
            .run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(targetWindow.nodeWorkspace === comms)
        XCTAssertTrue(focusedWindow.nodeWorkspace === work)
    }

    func testMoveNodeToZoneUsesEnvironmentWindowId() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let targetWindow = TestWindow.new(id: 45, parent: work.rootTilingContainer)
        let focusedWindow = TestWindow.new(id: 46, parent: work.rootTilingContainer)
        XCTAssertTrue(focusedWindow.focusWindow())

        let result = try await MoveNodeToColumnCommand(args: MoveNodeToColumnCmdArgs(column: ColumnSelector("Comms")).copy(\.failIfNoop, true))
            .run(.defaultEnv.copy(\.windowId, 45), .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(targetWindow.nodeWorkspace === comms)
        XCTAssertTrue(focusedWindow.nodeWorkspace === work)
    }

    func testOnWindowDetectedMoveNodeToZoneUsesDetectedWindowId() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let targetWindow = TestWindow.new(id: 47, parent: work.rootTilingContainer, title: "route-comms.rtf")
        let focusedWindow = TestWindow.new(id: 48, parent: work.rootTilingContainer, title: "focused-work.rtf")
        XCTAssertTrue(focusedWindow.focusWindow())
        configureRouteCommsCallback()

        try await tryOnWindowDetected(targetWindow)

        XCTAssertTrue(targetWindow.nodeWorkspace === comms)
        XCTAssertTrue(focusedWindow.nodeWorkspace === work)
    }

    func testOnWindowDetectedMoveNodeToZoneIgnoresNonMatchingTitle() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let targetWindow = TestWindow.new(id: 49, parent: work.rootTilingContainer, title: "notes.rtf")
        let focusedWindow = TestWindow.new(id: 50, parent: work.rootTilingContainer, title: "focused-work.rtf")
        XCTAssertTrue(focusedWindow.focusWindow())
        configureRouteCommsCallback()

        try await tryOnWindowDetected(targetWindow)

        XCTAssertTrue(targetWindow.nodeWorkspace === work)
        XCTAssertTrue(focusedWindow.nodeWorkspace === work)
    }

    func testRulesRouteDetectedWindowBeforeCallbacks() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let targetWindow = TestWindow.new(id: 51, parent: work.rootTilingContainer, title: "mail-inbox.rtf")
        let focusedWindow = TestWindow.new(id: 52, parent: work.rootTilingContainer, title: "focused-work.rtf")
        XCTAssertTrue(focusedWindow.focusWindow())
        configureRouteCommsRule()
        configureRouteReferenceCallback()

        try await tryOnWindowDetected(targetWindow)

        XCTAssertTrue(targetWindow.nodeWorkspace === comms)
        XCTAssertTrue(focusedWindow.nodeWorkspace === work)
    }

    func testMoveNodeToZoneMovesFocusedTabGroup() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let tabGroup = TilingContainer(parent: work.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .h, .tabGroup, index: INDEX_BIND_LAST)
        let first = TestWindow.new(id: 51, parent: tabGroup)
        let second = TestWindow.new(id: 52, parent: tabGroup)
        XCTAssertTrue(first.focusWindow())

        let result = try await MoveNodeToColumnCommand(args: MoveNodeToColumnCmdArgs(column: ColumnSelector("right")))
            .run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(tabGroup.nodeWorkspace === comms)
        XCTAssertTrue(first.nodeWorkspace === comms)
        XCTAssertTrue(second.nodeWorkspace === comms)
        XCTAssertFalse(work.rootTilingContainer.allLeafWindowsRecursive.contains(first))
    }

    func testListZonesOutputsColumnNamesAndActiveWorkspaces() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))

        let result = try await parseCommand(
            "list-columns --format '%{column-id}|%{column-name}|%{monitor-physical-id}|%{monitor-active-workspace}'",
        ).cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("left|Reference|1|reference"))
        XCTAssertTrue(result.stdout.contains { $0.hasPrefix("main|Work|1|") })
        XCTAssertTrue(result.stdout.contains { $0.hasPrefix("right|Comms|1|") })
    }

    func testListZonesCountAndJson() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))

        let countResult = try await parseCommand("list-columns --count").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(countResult.exitCode, 0)
        XCTAssertEqual(countResult.stdout, ["3"])

        let jsonResult = try await parseCommand("list-columns --json").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(jsonResult.exitCode, 0)
        let json = try XCTUnwrap(jsonResult.stdout.first)
        let rows = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]])
        let referenceRow = try XCTUnwrap(rows.first { $0["column-id"] as? String == "left" })
        XCTAssertEqual(referenceRow["column-name"] as? String, "Reference")
        XCTAssertEqual("\(referenceRow["monitor-physical-id"] ?? "")", "1")
        XCTAssertEqual(referenceRow["monitor-active-workspace"] as? String, "reference")
    }

    func testResizeZoneWidthAndBalancePreserveWorkspaces() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        XCTAssertTrue(work.focusWorkspace())

        let resize = try await parseCommand("column resize +10% Work").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(resize.exitCode, 0)
        XCTAssertEqual(resize.stdout, ["Resized column 'Work' on monitor 1 by +10%"])
        XCTAssertEqual(sortedMonitors.map(\.columnId), ["left", "main", "right"])
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [240, 720, 240])
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.columnId == "left" }.orDie().activeWorkspace === reference)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.columnId == "main" }.orDie().activeWorkspace === work)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.columnId == "right" }.orDie().activeWorkspace === comms)

        let list = try await parseCommand(
            "list-columns --format '%{column-id}|%{column-enabled}|%{column-configured-width}|%{column-effective-width}|%{column-runtime-width-override-state}|%{monitor-left}|%{monitor-width}|%{monitor-active-workspace}'",
        ).cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(list.exitCode, 0)
        XCTAssertTrue(list.stdout.contains("main|true|0.5|0.6|runtime|240.0|720.0|work"))
        XCTAssertTrue(list.stdout.contains("left|true|0.25|0.2|runtime|0.0|240.0|reference"))
        XCTAssertTrue(list.stdout.contains("right|true|0.25|0.2|runtime|960.0|240.0|comms"))

        let balance = try await parseCommand("balance-columns").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(balance.exitCode, 0)
        XCTAssertEqual(balance.stdout, ["Balanced columns on monitor 1"])
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [400, 400, 400])
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.columnId == "left" }.orDie().activeWorkspace === reference)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.columnId == "main" }.orDie().activeWorkspace === work)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.columnId == "right" }.orDie().activeWorkspace === comms)
    }

    func testConfigRestoreBackupRestoresValidBackupAndBacksUpBadCurrentConfig() async throws {
        let badCurrentText = """
            [[zones]]
                monitor = 1
                layout = 'columns'
                columns = [
                    { id = 'main', width = 0.2 },
                ]
            """
        let restoredText = columnLayoutPresetConfigText()

        try await withTemporaryConfig(badCurrentText) { url in
            let backup = url.deletingLastPathComponent().appending(component: "winmux.toml.backup-good")
            try restoredText.write(to: backup, atomically: true, encoding: .utf8)

            let result = try await parseCommand("config --restore-backup \(backup.path)").cmdOrDie.run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(result.exitCode, 0, result.stderr.joined(separator: "\n"))
            XCTAssertEqual(result.stdout[0], "Restored config from backup: \(backup.path)")
            XCTAssertEqual(result.stdout[1], "Config path: \(url.path)")
            XCTAssertTrue(result.stdout.contains { $0.hasPrefix("Previous config backup: \(url.path).rollback-") })
            XCTAssertEqual(result.stdout.last, "Restored config OK")
            XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), restoredText)

            let rollbacks = try configRestoreRollbackUrls(for: url)
            XCTAssertEqual(rollbacks.count, 1)
            XCTAssertEqual(try String(contentsOf: rollbacks.singleOrNil().orDie(), encoding: .utf8), badCurrentText)
        }
    }

    func testConfigRestoreBackupRejectsInvalidBackupWithoutMutation() async throws {
        let originalText = columnLayoutPresetConfigText()

        try await withTemporaryConfig(originalText) { url in
            let backup = url.deletingLastPathComponent().appending(component: "bad-backup.toml")
            try """
                [[zone-layouts]]
                    id = 'bad'
                    layout = 'columns'
                    columns = [
                        { id = 'main', width = 0.2 },
                    ]
                """.write(to: backup, atomically: true, encoding: .utf8)

            let result = try await parseCommand("config --restore-backup \(backup.path)").cmdOrDie.run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(result.exitCode, 1)
            XCTAssertTrue(result.stderr.joined(separator: "\n").contains("Backup config is not valid; refusing to restore"))
            XCTAssertTrue(result.stderr.joined(separator: "\n").contains("zone-layouts[0].columns: Column widths must sum to 1.0"))
            XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), originalText)
            XCTAssertEqual(try configRestoreRollbackUrls(for: url), [])
        }
    }

    func testColumnInitDryRunDoesNotWriteConfigOrBackup() async throws {
        configureNoZonesOnUltrawide()
        let originalText = columnInitBaseConfigText()

        try await withTemporaryConfig(originalText) { url in
            let result = try await parseCommand("column init --dry-run --preset balanced").cmdOrDie.run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(result.exitCode, 0, result.stderr.joined(separator: "\n"))
            XCTAssertEqual(result.stdout.first, "Dry run: would append balanced columns to \(url.path)")
            XCTAssertTrue(result.stdout.contains("Mode: dry-run"))
            XCTAssertTrue(result.stdout.contains("Preset: balanced"))
            XCTAssertTrue(result.stdout.contains("Selected monitor: monitor 1 Main 3440x1440 aspect 2.388889"))
            let rendered = result.stdout.joined(separator: "\n")
            XCTAssertTrue(rendered.contains("[scene.balanced]"))
            XCTAssertTrue(rendered.contains(#"{ id = "ref", name = "Reference", width = 0.25 },"#))
            XCTAssertTrue(rendered.contains(#"{ id = "main", name = "Work", width = 0.5 },"#))
            XCTAssertTrue(rendered.contains(#"{ id = "comms", name = "Comms", width = 0.25 },"#))
            XCTAssertTrue(result.stdout.contains("Run with --write to update the config."))
            XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), originalText)
            XCTAssertEqual(try columnLayoutBackupUrls(for: url), [])
        }
    }

    func testColumnInitWritesConfigAndBackup() async throws {
        configureNoZonesOnUltrawide()
        let originalText = columnInitBaseConfigText()

        try await withTemporaryConfig(originalText) { url in
            let result = try await parseCommand("column init --preset balanced --write").cmdOrDie.run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(result.exitCode, 0, result.stderr.joined(separator: "\n"))
            XCTAssertEqual(result.stdout.first, "Wrote balanced columns to \(url.path)")
            XCTAssertTrue(result.stdout.contains("Mode: write"))
            XCTAssertTrue(result.stdout.contains("Preset: balanced"))
            XCTAssertTrue(result.stdout.contains { $0.hasPrefix("Backup: \(url.path).backup-") })
            XCTAssertTrue(result.stdout.joined(separator: "\n").contains(columnInitManagedBlockBegin))

            let backups = try columnLayoutBackupUrls(for: url)
            XCTAssertEqual(backups.count, 1)
            XCTAssertEqual(try String(contentsOf: backups.singleOrNil().orDie(), encoding: .utf8), originalText)

            let updatedText = try String(contentsOf: url, encoding: .utf8)
            let (parsed, errors) = parseConfig(updatedText)
            assertEquals(errors, [])
            let zones = parsed.zones.singleOrNil().orDie()
            XCTAssertEqual(zones.monitor, .sequenceNumber(1))
            let layout = parsed.columnLayouts.singleOrNil().orDie()
            XCTAssertEqual(layout.defaultZone, "main")
            XCTAssertEqual(layout.columns.map(\.id), ["ref", "main", "comms"])
            XCTAssertEqual(layout.columns.map(\.name), ["Reference", "Work", "Comms"])
            XCTAssertEqual(layout.columns.map(\.width), [0.25, 0.50, 0.25])
        }
    }

    func testColumnInitWriteIsIdempotent() async throws {
        configureNoZonesOnUltrawide()

        try await withTemporaryConfig(columnInitBaseConfigText()) { url in
            let first = try await parseCommand("column init --preset balanced --write").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(first.exitCode, 0)
            let firstText = try String(contentsOf: url, encoding: .utf8)
            XCTAssertEqual(try columnLayoutBackupUrls(for: url).count, 1)

            let second = try await parseCommand("column init --preset balanced --write").cmdOrDie.run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(second.exitCode, 0, second.stderr.joined(separator: "\n"))
            XCTAssertEqual(second.stdout.first, "Column init already configured in \(url.path)")
            XCTAssertTrue(second.stdout.contains("No changes needed."))
            XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), firstText)
            XCTAssertEqual(try columnLayoutBackupUrls(for: url).count, 1)
        }
    }

    func testColumnInitRejectsUnmanagedActiveZonesWithoutMutation() async throws {
        configureNoZonesOnUltrawide()
        let originalText = layoutPresetDisplayLayoutConfigText()

        try await withTemporaryConfig(originalText) { url in
            let result = try await parseCommand("column init --preset balanced --write").cmdOrDie.run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(result.exitCode, 1)
            XCTAssertTrue(result.stderr.joined(separator: "\n").contains("Config already has active columns"))
            XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), originalText)
            XCTAssertEqual(try columnLayoutBackupUrls(for: url), [])
        }
    }

    func testColumnInitReplaceExistingManagedBlock() async throws {
        configureNoZonesOnUltrawide()

        try await withTemporaryConfig(columnInitBaseConfigText()) { url in
            let first = try await parseCommand("column init --preset balanced --write").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(first.exitCode, 0)

            let blocked = try await parseCommand("column init --preset focus-only --write").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(blocked.exitCode, 1)
            XCTAssertTrue(blocked.stderr.joined(separator: "\n").contains("--replace-existing"))

            let replaced = try await parseCommand("column init --preset focus-only --write --replace-existing").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(replaced.exitCode, 0, replaced.stderr.joined(separator: "\n"))
            XCTAssertEqual(replaced.stdout.first, "Wrote focus-only columns to \(url.path)")

            let backups = try columnLayoutBackupUrls(for: url)
            XCTAssertEqual(backups.count, 2)
            let updatedText = try String(contentsOf: url, encoding: .utf8)
            XCTAssertEqual(updatedText.components(separatedBy: columnInitManagedBlockBegin).count - 1, 1)

            let (parsed, errors) = parseConfig(updatedText)
            assertEquals(errors, [])
            XCTAssertEqual(parsed.columnLayouts.singleOrNil().orDie().columns.map(\.width), [0.15, 0.70, 0.15])
        }
    }

    func testConfiguredRelativeZoneSelectorTargetsFocusedZone() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(work.focusWorkspace())

        let result = try await parseCommand("column resize +10% current").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, ["Resized column 'Work' on monitor 1 by +10%"])
        XCTAssertEqual(sortedMonitors.map(\.columnId), ["left", "main", "right"])
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [240, 720, 240])
    }

    func testToggleCurrentZoneRestoresLastCurrentToggle() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let commsWindow = TestWindow.new(id: 85, parent: comms.rootTilingContainer)
        XCTAssertTrue(comms.focusWorkspace())

        let hide = try await parseCommand("column toggle current").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(hide.exitCode, 0)
        XCTAssertEqual(hide.stdout, ["Collapsed column 'Comms' on monitor 1"])
        XCTAssertEqual(sortedMonitors.map(\.columnId), ["left", "main"])
        XCTAssertTrue(focus.workspace === work)

        let restore = try await parseCommand("column toggle current").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(restore.exitCode, 0)
        XCTAssertEqual(restore.stdout, ["Expanded column 'Comms' on monitor 1"])
        XCTAssertEqual(sortedMonitors.map(\.columnId), ["left", "main", "right"])
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.columnId == "right" }.orDie().activeWorkspace === comms)
        XCTAssertTrue(commsWindow.nodeWorkspace === comms)
    }

    func testReenabledZoneRestoresTheExactCardItWasShowing() async throws {
        let zones = configureThreeZones()
        let rightZone = zones["right"].orDie()
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        _ = TestWindow.new(id: 86, parent: work.rootTilingContainer)
        XCTAssertTrue(work.focusWorkspace())
        let commsAnchor = Workspace.get(byName: "comms-anchor")
        _ = TestWindow.new(id: 87, parent: commsAnchor.rootTilingContainer)
        winMuxWorkspaceState.columnDecks.adopt(commsAnchor.id, into: columnDeckKey(for: rightZone))
        // The zone shows an empty, non-sole card: without the hidden-active record it would
        // be pruned while hidden and re-enable would surface commsAnchor instead.
        let commsEmpty = Workspace.get(byName: "comms-empty")
        XCTAssertTrue(rightZone.setActiveWorkspace(commsEmpty))

        let disable = try await parseCommand("column collapse Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disable.exitCode, 0)
        Workspace.reconcileWorkspaceState()
        XCTAssertTrue(Workspace.existing(byName: "comms-empty") === commsEmpty)

        let enable = try await parseCommand("column expand Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(enable.exitCode, 0)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.columnId == "right" }.orDie().activeWorkspace === commsEmpty)
    }

    func testResizeZoneRejectsDisabledZoneAndBalanceUsesEnabledZonesOnly() async throws {
        _ = configureThreeZones()

        let disable = try await parseCommand("column collapse Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disable.exitCode, 0)

        let resize = try await parseCommand("column resize +10% Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(resize.exitCode, 1)
        XCTAssertTrue(resize.stderr.joined(separator: "\n").contains("Column 'Comms' is disabled"))

        let balance = try await parseCommand("balance-columns").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(balance.exitCode, 0)
        XCTAssertEqual(sortedMonitors.map(\.columnId), ["left", "main"])
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [600, 600])

        let list = try await parseCommand(
            "list-columns --format '%{column-id}|%{column-enabled}|%{column-effective-width}|%{monitor-width}'",
        ).cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(list.exitCode, 0)
        XCTAssertTrue(list.stdout.contains("left|true|0.375|600.0"))
        XCTAssertTrue(list.stdout.contains("main|true|0.375|600.0"))
        XCTAssertTrue(list.stdout.contains("right|false|0.25|"))
    }

    func testResizeZoneRequiresUnambiguousPhysicalScope() async throws {
        _ = configureDuplicateZones()

        let ambiguous = try await parseCommand("column resize +10% left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(ambiguous.exitCode, 1)
        XCTAssertTrue(ambiguous.stderr.joined(separator: "\n").contains("ambiguous"))
        XCTAssertEqual(zoneWidthsByPhysicalZone(), [
            "1:left": 500,
            "1:main": 500,
            "2:left": 500,
            "2:main": 500,
        ])

        let overspecified = try await parseCommand("column resize +10% 1:left --monitor 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(overspecified.exitCode, 1)
        XCTAssertTrue(overspecified.stderr.joined(separator: "\n").contains("Use either --monitor or a physical monitor qualifier"))
        XCTAssertEqual(zoneWidthsByPhysicalZone(), [
            "1:left": 500,
            "1:main": 500,
            "2:left": 500,
            "2:main": 500,
        ])
    }

    func testZoneWidthCommandsOnlyAffectSelectedPhysicalMonitor() async throws {
        let zones = configureDuplicateZones()
        let primaryLeft = Workspace.get(byName: "primary-left")
        let primaryMain = Workspace.get(byName: "primary-main")
        let secondaryLeft = Workspace.get(byName: "secondary-left")
        let secondaryMain = Workspace.get(byName: "secondary-main")
        XCTAssertTrue(zones["1:left"].orDie().setActiveWorkspace(primaryLeft))
        XCTAssertTrue(zones["1:main"].orDie().setActiveWorkspace(primaryMain))
        XCTAssertTrue(zones["2:left"].orDie().setActiveWorkspace(secondaryLeft))
        XCTAssertTrue(zones["2:main"].orDie().setActiveWorkspace(secondaryMain))
        XCTAssertTrue(secondaryLeft.focusWorkspace())

        let resize = try await parseCommand("column resize +10% next --monitor 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(resize.exitCode, 0)
        XCTAssertEqual(resize.stdout, ["Resized column 'Work' on monitor 2 by +10%"])
        XCTAssertEqual(zoneWidthsByPhysicalZone(), [
            "1:left": 500,
            "1:main": 500,
            "2:left": 400,
            "2:main": 600,
        ])

        let set = try await parseCommand("column resize 70% 2:main").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(set.exitCode, 0)
        XCTAssertEqual(set.stdout, ["Resized column 'Work' on monitor 2 by 70%"])
        XCTAssertEqual(zoneWidthsByPhysicalZone(), [
            "1:left": 500,
            "1:main": 500,
            "2:left": 300,
            "2:main": 700,
        ])

        let balance = try await parseCommand("balance-columns --monitor 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(balance.exitCode, 0)
        XCTAssertEqual(balance.stdout, ["Balanced columns on monitor 2"])
        XCTAssertEqual(zoneWidthsByPhysicalZone(), [
            "1:left": 500,
            "1:main": 500,
            "2:left": 500,
            "2:main": 500,
        ])
    }

    func testMoveZoneDividerChangesAdjacentZonesOnlyAndPreservesWorkspaces() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let workWindow = TestWindow.new(id: 401, parent: work.rootTilingContainer)
        let commsWindow = TestWindow.new(id: 402, parent: comms.rootTilingContainer)

        let preview = try XCTUnwrap(previewColumnDividerMove(
            on: zones["main"].orDie().physicalMonitor,
            leftColumnId: "main",
            rightColumnId: "right",
            deltaPixels: 120,
        ).getOrNil())
        XCTAssertEqual(preview.oldBoundaryX, 900)
        XCTAssertEqual(preview.newBoundaryX, 1020)
        XCTAssertEqual(preview.leftAfterShare, 0.6, accuracy: 0.0001)
        XCTAssertEqual(preview.rightAfterShare, 0.15, accuracy: 0.0001)

        let result = try XCTUnwrap(moveColumnDivider(
            on: zones["main"].orDie().physicalMonitor,
            leftColumnId: "main",
            rightColumnId: "right",
            deltaPixels: 120,
        ).getOrNil())

        XCTAssertEqual(result.appliedDeltaPixels, 120, accuracy: 0.0001)
        XCTAssertEqual(zoneWidthsByPhysicalZone(), [
            "1:left": 300,
            "1:main": 720,
            "1:right": 180,
        ])
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.columnId == "left" }.orDie().activeWorkspace === reference)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.columnId == "main" }.orDie().activeWorkspace === work)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.columnId == "right" }.orDie().activeWorkspace === comms)
        XCTAssertTrue(workWindow.nodeWorkspace === work)
        XCTAssertTrue(commsWindow.nodeWorkspace === comms)
    }

    func testZoneDividerAmbientClickDoesNotStartInsideKnownWindowFrame() {
        let zones = configureThreeZones()
        config.mouse.columnDividerDrag = .always
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        TestWindow.new(
            id: 451,
            parent: work.rootTilingContainer,
            rect: Rect(topLeftX: 880, topLeftY: 100, width: 80, height: 200),
        )
        let controller = ColumnDividerDragController.shared
        controller.cancel()

        XCTAssertNotNil(columnDividerHandle(at: CGPoint(x: 900, y: 150), hitSlop: 16))
        XCTAssertFalse(controller.handleMouseDown(at: CGPoint(x: 900, y: 150)))
        XCTAssertFalse(controller.isDragging)

        XCTAssertTrue(controller.handleMouseDown(at: CGPoint(x: 900, y: 20)))
        XCTAssertTrue(controller.isDragging)
        controller.cancel()
    }

    func testZoneDividerAmbientClickUsesLiveFrameBeforeVetoingStaleCachedFrame() {
        let zones = configureThreeZones()
        config.mouse.columnDividerDrag = .always
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        let window = TestWindow.new(
            id: 454,
            parent: work.rootTilingContainer,
            rect: Rect(topLeftX: 100, topLeftY: 100, width: 80, height: 80),
        )
        window.lastKnownActualRect = Rect(topLeftX: 100, topLeftY: 100, width: 80, height: 80)
        window.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 880, topLeftY: 100, width: 80, height: 200)
        let controller = ColumnDividerDragController.shared
        controller.cancel()

        XCTAssertNotNil(columnDividerHandle(at: CGPoint(x: 900, y: 150), hitSlop: 16))
        XCTAssertTrue(controller.handleMouseDown(at: CGPoint(x: 900, y: 150)))
        XCTAssertTrue(controller.isDragging)
        controller.cancel()
    }

    func testZoneDividerChromeCanStartInsideFullHeightTiledWindowFrame() {
        let zones = configureThreeZones()
        config.mouse.columnDividerDrag = .always
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        TestWindow.new(
            id: 453,
            parent: work.rootTilingContainer,
            rect: Rect(topLeftX: 300, topLeftY: 0, width: 620, height: 800),
        )
        let controller = ColumnDividerDragController.shared
        controller.cancel()

        XCTAssertNotNil(columnDividerHandle(at: CGPoint(x: 900, y: 400), hitSlop: 16))
        XCTAssertFalse(controller.handleMouseDown(at: CGPoint(x: 900, y: 400)))
        XCTAssertFalse(controller.isDragging)

        XCTAssertTrue(controller.handleMouseDown(
            at: CGPoint(x: 900, y: 400),
            source: .dividerChrome,
        ))
        XCTAssertTrue(controller.isDragging)
        controller.cancel()
    }

    func testParseExposeCommand() {
        XCTAssertTrue(parseCommand("expose display").cmdOrNil is ExposeCommand)
        XCTAssertTrue(parseCommand("expose card").cmdOrNil is ExposeCommand)
        XCTAssertNil(parseCommand("expose").cmdOrNil)
        XCTAssertNil(parseCommand("expose everything").cmdOrNil)
    }

    func testMouseUpRefreshEventClassifiesDesktopVsWindowClicks() {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        let window = TestWindow.new(id: 460, parent: work.rootTilingContainer, rect: nil)
        window.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 400, topLeftY: 100, width: 200, height: 200)

        XCTAssertEqual(mouseUpRefreshEvent(at: CGPoint(x: 500, y: 150)).description, "globalObserverLeftMouseUp")
        XCTAssertEqual(mouseUpRefreshEvent(at: CGPoint(x: 50, y: 700)).description, "globalObserverLeftMouseUpOutsideWindows")
    }

    func testMouseUpRefreshEventFailsSafeForWindowWithoutCachedRects() {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        // No cached rect anywhere: the click cannot be proven to miss this window, so even a
        // far-away point must keep the barrier.
        _ = TestWindow.new(id: 461, parent: work.rootTilingContainer, rect: nil)

        XCTAssertEqual(mouseUpRefreshEvent(at: CGPoint(x: 50, y: 700)).description, "globalObserverLeftMouseUp")
    }

    func testZoneDividerAmbientClickConsultsLiveFramesSnapshot() {
        let zones = configureThreeZones()
        config.mouse.columnDividerDrag = .always
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        // rect: nil leaves currentFrameForHitTesting() nil, like a real MacWindow, so the veto
        // falls through to the snapshot lookup.
        let window = TestWindow.new(id: 462, parent: work.rootTilingContainer, rect: nil)
        window.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 880, topLeftY: 100, width: 80, height: 200)
        let controller = ColumnDividerDragController.shared
        controller.cancel()
        let dividerPoint = CGPoint(x: 900, y: 150)
        XCTAssertNotNil(columnDividerHandle(at: dividerPoint, hitSlop: 16))

        // Snapshot says the window moved away: the stale cached rect must not veto the drag.
        controller.setLiveFramesSnapshotForTests([462: Rect(topLeftX: 100, topLeftY: 100, width: 80, height: 200)])
        XCTAssertTrue(controller.handleMouseDown(at: dividerPoint))
        XCTAssertTrue(controller.isDragging)
        controller.cancel()

        // Snapshot confirms the window covers the point: veto.
        controller.setLiveFramesSnapshotForTests([462: Rect(topLeftX: 880, topLeftY: 100, width: 80, height: 200)])
        XCTAssertFalse(controller.handleMouseDown(at: dividerPoint))
        XCTAssertFalse(controller.isDragging)

        // No snapshot at all: fail conservative, veto.
        controller.setLiveFramesSnapshotForTests(nil)
        XCTAssertFalse(controller.handleMouseDown(at: dividerPoint))
        XCTAssertFalse(controller.isDragging)
        controller.cancel()
    }

    func testZoneDividerDragRequiresZoneModeByDefault() {
        _ = configureThreeZones()
        let controller = ColumnDividerDragController.shared
        controller.cancel()
        let dividerPoint = CGPoint(x: 900, y: 20)
        XCTAssertNotNil(columnDividerHandle(at: dividerPoint, hitSlop: 16))

        let previousMode = activeMode
        defer { activeMode = previousMode }

        activeMode = mainModeId
        XCTAssertFalse(controller.updateHover(at: dividerPoint))
        XCTAssertFalse(controller.handleMouseDown(at: dividerPoint))
        XCTAssertFalse(controller.handleMouseDown(at: dividerPoint, source: .dividerChrome))
        XCTAssertFalse(controller.isDragging)

        activeMode = zoneModeId
        XCTAssertTrue(controller.handleMouseDown(at: dividerPoint))
        XCTAssertTrue(controller.isDragging)
        controller.cancel()
    }

    func testZoneDividerChromeHitBandMatchesAdvertisedHitSlop() {
        XCTAssertEqual(columnDividerVisibleBandWidth(for: .hover), 8)
        XCTAssertEqual(columnDividerVisibleBandWidth(for: .dragging), 14)
        XCTAssertEqual(columnDividerVisibleBandWidth(for: .committed), 14)
        XCTAssertEqual(columnDividerChromeHitBandWidth(for: .hover), 32)
        XCTAssertEqual(columnDividerChromeHitBandWidth(for: .dragging), 32)
        XCTAssertEqual(columnDividerChromeHitBandWidth(for: .committed), 0)
    }

    func testColumnDividerHitPanelOnlyClaimsLeftDragEvents() {
        XCTAssertTrue(columnDividerHitPanelHandlesEvent(type: .leftMouseDown, buttonNumber: 0))
        XCTAssertTrue(columnDividerHitPanelHandlesEvent(type: .leftMouseDragged, buttonNumber: 0))
        XCTAssertTrue(columnDividerHitPanelHandlesEvent(type: .leftMouseUp, buttonNumber: 0))
        XCTAssertFalse(columnDividerHitPanelHandlesEvent(type: .rightMouseDown, buttonNumber: 1))
        XCTAssertFalse(columnDividerHitPanelHandlesEvent(type: .scrollWheel, buttonNumber: 0))
        XCTAssertFalse(columnDividerHitPanelHandlesEvent(type: .otherMouseDown, buttonNumber: 2))
    }

    func testZoneDividerDragIgnoresStaleFramesFromInactiveWorkspaces() {
        _ = configureThreeZones()
        config.mouse.columnDividerDrag = .always
        let inactiveWorkspace = Workspace.get(byName: "inactive-with-stale-frame")
        TestWindow.new(
            id: 452,
            parent: inactiveWorkspace.rootTilingContainer,
            rect: Rect(topLeftX: 880, topLeftY: 100, width: 80, height: 200),
        )
        XCTAssertFalse(inactiveWorkspace.isVisible)
        let controller = ColumnDividerDragController.shared
        controller.cancel()

        XCTAssertTrue(controller.handleMouseDown(at: CGPoint(x: 900, y: 150)))
        XCTAssertTrue(controller.isDragging)
        controller.cancel()
    }

    func testForceAssignedWorkspaceCanMoveBetweenZonesOnSamePhysicalMonitor() async throws {
        let zones = configureThreeZones()
        let assigned = Workspace.get(byName: "assigned-to-display-one")
        config.workspaceToMonitorForceAssignment[assigned.name] = [.sequenceNumber(1)]

        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(assigned))
        XCTAssertTrue(assigned.focusWorkspace())

        let moveToMain = try await parseCommand("card move next").cmdOrDie
            .run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(moveToMain.exitCode, 0)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.columnId == "main" }.orDie().activeWorkspace === assigned)

        let moveToRight = try await parseCommand("card move next").cmdOrDie
            .run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(moveToRight.exitCode, 0)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.columnId == "right" }.orDie().activeWorkspace === assigned)
    }


    func testMoveZoneDividerClampsAtMinimumShare() async throws {
        let zones = configureThreeZones()

        let result = try XCTUnwrap(moveColumnDivider(
            on: zones["main"].orDie().physicalMonitor,
            leftColumnId: "main",
            rightColumnId: "right",
            deltaPixels: 1000,
        ).getOrNil())

        XCTAssertEqual(result.requestedDeltaPixels, 1000, accuracy: 0.0001)
        XCTAssertEqual(result.appliedDeltaPixels, 240, accuracy: 0.0001)
        XCTAssertEqual(zoneWidthsByPhysicalZone(), [
            "1:left": 300,
            "1:main": 840,
            "1:right": 60,
        ])
    }

    func testMoveZoneDividerRejectsDisabledTargetAndExposesOnlyEnabledBoundaries() async throws {
        let zones = configureThreeZones()

        let disable = try await parseCommand("column collapse Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disable.exitCode, 0)

        let handles = columnDividerHandles(hitSlop: 12)
        XCTAssertEqual(handles.map { "\($0.leftColumnId)|\($0.rightColumnId)" }, ["left|main"])
        XCTAssertNil(columnDividerHandle(at: CGPoint(x: 900, y: 10), hitSlop: 12))

        switch moveColumnDivider(
            on: zones["main"].orDie().physicalMonitor,
            leftColumnId: "main",
            rightColumnId: "right",
            deltaPixels: 120,
        ) {
            case .success:
                XCTFail("Expected disabled right zone to reject divider movement")
            case .failure(let message):
                XCTAssertTrue(message.contains("not adjacent enabled zones"))
        }
    }

    func testMoveZoneDividerOnlyAffectsSelectedPhysicalMonitorAndActiveLayout() async throws {
        let zones = configureDuplicateColumnLayoutPresets()

        let result = try XCTUnwrap(moveColumnDivider(
            on: zones["2:left"].orDie().physicalMonitor,
            leftColumnId: "left",
            rightColumnId: "main",
            deltaPixels: 100,
        ).getOrNil())

        XCTAssertEqual(result.appliedDeltaPixels, 100, accuracy: 0.0001)
        XCTAssertEqual(zoneWidthsByPhysicalZone(), [
            "1:left": 500,
            "1:main": 500,
            "2:left": 600,
            "2:main": 400,
        ])

        switch setActiveColumnLayout("focus", for: zones["2:left"].orDie().physicalMonitor) {
            case .success: break
            case .failure(let message): XCTFail(message)
        }
        XCTAssertEqual(zoneWidthsByPhysicalZone(), [
            "1:left": 500,
            "1:main": 500,
            "2:left": 300,
            "2:main": 700,
        ])

        switch setActiveColumnLayout("balanced", for: zones["2:left"].orDie().physicalMonitor) {
            case .success: break
            case .failure(let message): XCTFail(message)
        }
        XCTAssertEqual(zoneWidthsByPhysicalZone(), [
            "1:left": 500,
            "1:main": 500,
            "2:left": 600,
            "2:main": 400,
        ])
    }

    func testResizeZoneRejectsWidthsBelowMinimumShare() async throws {
        _ = configureThreeZones()

        let targetTooSmall = try await parseCommand("column resize -46% Work").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(targetTooSmall.exitCode, 1)
        XCTAssertTrue(targetTooSmall.stderr.joined(separator: "\n").contains("below 5%"))
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [300, 600, 300])

        let siblingsTooSmall = try await parseCommand("column resize 95% Work").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(siblingsTooSmall.exitCode, 1)
        XCTAssertTrue(siblingsTooSmall.stderr.joined(separator: "\n").contains("sibling zones would fall below 5%"))
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [300, 600, 300])
    }

    func testColumnColorAppliesToListColumnsAndSidebarTarget() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        XCTAssertTrue(work.focusWorkspace())

        let result = try await parseCommand("column color #D3455B Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, ["Colored column 'Comms' on monitor 1 as '#D3455B'"])
        XCTAssertEqual(sortedMonitors.singleOrNil { $0.columnId == "right" }?.columnColorHex, "#D3455B")

        let list = try await parseCommand(
            "list-columns --format '%{column-id}|%{column-color}|%{monitor-active-workspace}'",
        ).cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(list.exitCode, 0)
        XCTAssertTrue(list.stdout.contains("right|#D3455B|comms"))
        XCTAssertTrue(list.stdout.contains("main||work"))

        let targets = buildWorkspaceSidebarColumnTargetViewModels(
            sortedMonitors: sortedMonitors,
            currentFocus: focus,
        )
        let commsTarget = try XCTUnwrap(targets.singleOrNil { $0.columnId == "right" })
        XCTAssertEqual(commsTarget.styleColorHex, "#D3455B")
    }

    func testColumnColorRejectsCollapsedColumn() async throws {
        _ = configureThreeZones()

        let collapse = try await parseCommand("column collapse Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(collapse.exitCode, 0)

        let collapsed = try await parseCommand("column color #D3455B Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(collapsed.exitCode, 1)
        XCTAssertTrue(collapsed.stderr.joined(separator: "\n").contains("Column 'Comms' is collapsed"))
    }

    func testColumnColorRequiresUnambiguousPhysicalScope() async throws {
        let zones = configureDuplicateZones()
        let primaryLeft = Workspace.get(byName: "primary-left")
        let primaryMain = Workspace.get(byName: "primary-main")
        let secondaryLeft = Workspace.get(byName: "secondary-left")
        let secondaryMain = Workspace.get(byName: "secondary-main")
        XCTAssertTrue(zones["1:left"].orDie().setActiveWorkspace(primaryLeft))
        XCTAssertTrue(zones["1:main"].orDie().setActiveWorkspace(primaryMain))
        XCTAssertTrue(zones["2:left"].orDie().setActiveWorkspace(secondaryLeft))
        XCTAssertTrue(zones["2:main"].orDie().setActiveWorkspace(secondaryMain))
        XCTAssertTrue(secondaryLeft.focusWorkspace())

        let ambiguous = try await parseCommand("column color #D3455B left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(ambiguous.exitCode, 1)
        XCTAssertTrue(ambiguous.stderr.joined(separator: "\n").contains("ambiguous"))

        let scoped = try await parseCommand("column color #D3455B current --monitor 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(scoped.exitCode, 0, scoped.stderr.joined(separator: "\n"))
        XCTAssertEqual(scoped.stdout, ["Colored column 'Reference' on monitor 2 as '#D3455B'"])
        XCTAssertEqual(
            sortedMonitors.singleOrNil { $0.columnId == "left" && $0.physicalMonitor.monitorId_oneBased == 2 }?.columnColorHex,
            "#D3455B",
        )

        let overspecified = try await parseCommand("column color #3EA2FF 1:left --monitor 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(overspecified.exitCode, 1)
        XCTAssertTrue(overspecified.stderr.joined(separator: "\n").contains("Use either --monitor or a physical monitor qualifier"))
    }


    func testSetZoneSnapPolicyOverridesConfigForFocusedMonitor() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(work.focusWorkspace())
        config.mouse.columnSnap.policy = .freeform
        config.mouse.columnSnap.modifier = [.option, .shift]
        config.mouse.columnSnap.gesture = .drag
        config.mouse.columnSnap.target = .column

        let result = try await parseCommand("set-column-snap-policy snap-to-column").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, ["Using column snap policy 'snap-to-column' on monitor 1"])
        XCTAssertEqual(config.mouse.columnSnap.policy, .freeform)
        let effective = effectiveColumnSnapConfig(for: zones["right"].orDie())
        XCTAssertEqual(effective.policy, .snapToColumn)
        XCTAssertEqual(effective.modifier, [.option, .shift])
        XCTAssertEqual(effective.gesture, .drag)
        XCTAssertEqual(effective.target, .column)
    }

    func testCycleZoneSnapPolicyCyclesAndWraps() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(work.focusWorkspace())
        config.mouse.columnSnap.policy = .freeform

        let snap = try await parseCommand("cycle-column-snap-policy freeform snap-to-column").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(snap.exitCode, 0)
        XCTAssertEqual(snap.stdout, ["Using column snap policy 'snap-to-column' on monitor 1"])
        XCTAssertEqual(effectiveColumnSnapConfig(for: zones["left"].orDie()).policy, .snapToColumn)

        let freeform = try await parseCommand("cycle-column-snap-policy freeform snap-to-column").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(freeform.exitCode, 0)
        XCTAssertEqual(freeform.stdout, ["Using column snap policy 'freeform' on monitor 1"])
        XCTAssertEqual(effectiveColumnSnapConfig(for: zones["left"].orDie()).policy, .freeform)
    }

    func testCycleZoneSnapPolicyStartsAtFirstPolicyWhenCurrentPolicyIsOutsideCycle() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(work.focusWorkspace())
        config.mouse.columnSnap.policy = .floatUnlessSnap

        let result = try await parseCommand("cycle-column-snap-policy freeform snap-to-column").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, ["Using column snap policy 'freeform' on monitor 1"])
        XCTAssertEqual(effectiveColumnSnapConfig(for: zones["left"].orDie()).policy, .freeform)
    }

    func testZoneSnapPolicyRejectsUnknownDuplicateAndUnzonedMonitor() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(work.focusWorkspace())

        let unknown = try await parseCommand("set-column-snap-policy snap-to-window").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(unknown.exitCode, 1)
        XCTAssertTrue(unknown.stderr.joined(separator: "\n").contains("Unknown column snap policy 'snap-to-window'"))

        let duplicate = try await parseCommand("cycle-column-snap-policy freeform freeform").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(duplicate.exitCode, 1)
        XCTAssertTrue(duplicate.stderr.joined(separator: "\n").contains("cycle-column-snap-policy requires unique policies: freeform"))

        configureNoZones()
        let noZones = try await parseCommand("set-column-snap-policy snap-to-column").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(noZones.exitCode, 1)
        XCTAssertTrue(noZones.stderr.joined(separator: "\n").contains("No zone config targets monitor 1"))
    }

    func testZoneSnapPolicyIsScopedByPhysicalMonitor() async throws {
        let zones = configureDuplicateZones()
        let secondaryMain = Workspace.get(byName: "secondary-main")
        XCTAssertTrue(zones["2:main"].orDie().setActiveWorkspace(secondaryMain))
        XCTAssertTrue(secondaryMain.focusWorkspace())
        config.mouse.columnSnap.policy = .freeform

        let secondary = try await parseCommand("set-column-snap-policy --monitor 2 snap-to-column").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(secondary.exitCode, 0, secondary.stderr.joined(separator: "\n"))
        XCTAssertEqual(secondary.stdout, ["Using column snap policy 'snap-to-column' on monitor 2"])
        XCTAssertEqual(effectiveColumnSnapConfig(for: zones["1:left"].orDie()).policy, .freeform)
        XCTAssertEqual(effectiveColumnSnapConfig(for: zones["2:left"].orDie()).policy, .snapToColumn)

        let primary = try await parseCommand("set-column-snap-policy --monitor 1 float-unless-snap").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(primary.exitCode, 0, primary.stderr.joined(separator: "\n"))
        XCTAssertEqual(primary.stdout, ["Using column snap policy 'float-unless-snap' on monitor 1"])
        XCTAssertEqual(effectiveColumnSnapConfig(for: zones["1:left"].orDie()).policy, .floatUnlessSnap)
        XCTAssertEqual(effectiveColumnSnapConfig(for: zones["2:left"].orDie()).policy, .snapToColumn)
    }

    func testDisableZoneParksWorkspaceAndEnableZoneRestoresIt() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        _ = TestWindow.new(id: 70, parent: comms.rootTilingContainer)
        XCTAssertTrue(comms.focusWorkspace())

        let disableResult = try await parseCommand("column collapse Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(disableResult.exitCode, 0)
        XCTAssertEqual(disableResult.stdout, ["Collapsed column 'Comms' on monitor 1"])
        XCTAssertEqual(sortedMonitors.map(\.columnId), ["left", "main"])
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [400, 800])
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.columnId == "left" }.orDie().activeWorkspace === reference)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.columnId == "main" }.orDie().activeWorkspace === work)
        XCTAssertFalse(comms.isVisible)
        XCTAssertTrue(focus.workspace !== comms)

        let enableResult = try await parseCommand("column expand Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(enableResult.exitCode, 0)
        XCTAssertEqual(enableResult.stdout, ["Expanded column 'Comms' on monitor 1"])
        XCTAssertEqual(sortedMonitors.map(\.columnId), ["left", "main", "right"])
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.columnId == "right" }.orDie().activeWorkspace === comms)
    }

    func testDisabledZoneCannotBeFocusedOrMovedTo() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let window = TestWindow.new(id: 71, parent: work.rootTilingContainer)
        XCTAssertTrue(window.focusWindow())

        let disableResult = try await parseCommand("column collapse Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disableResult.exitCode, 0)

        let focusResult = try await parseCommand("focus-column Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(focusResult.exitCode, 1)
        XCTAssertTrue(focusResult.stderr.joined(separator: "\n").contains("Column 'Comms' is disabled"))

        let moveResult = try await parseCommand("move-node-to-column Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(moveResult.exitCode, 1)
        XCTAssertTrue(moveResult.stderr.joined(separator: "\n").contains("Column 'Comms' is disabled"))
        XCTAssertTrue(window.nodeWorkspace === work)
    }

    func testDisableZoneRejectsLastEnabledZone() async throws {
        _ = configureThreeZones()

        let disableLeft = try await parseCommand("column collapse left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disableLeft.exitCode, 0)
        let disableMain = try await parseCommand("column collapse main").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disableMain.exitCode, 0)

        let result = try await parseCommand("column collapse right").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.stderr.joined(separator: "\n").contains("at least one zone must stay enabled"))
        XCTAssertEqual(sortedMonitors.map(\.columnId), ["right"])
    }

    func testColumnVisibilityCommandsUseConfiguredColumnSelectorForCollapsedColumns() async throws {
        let zones = configureDuplicateZones()
        let primaryLeft = Workspace.get(byName: "primary-left")
        let primaryMain = Workspace.get(byName: "primary-main")
        let secondaryLeft = Workspace.get(byName: "secondary-left")
        let secondaryMain = Workspace.get(byName: "secondary-main")
        XCTAssertTrue(zones["1:left"].orDie().setActiveWorkspace(primaryLeft))
        XCTAssertTrue(zones["1:main"].orDie().setActiveWorkspace(primaryMain))
        XCTAssertTrue(zones["2:left"].orDie().setActiveWorkspace(secondaryLeft))
        XCTAssertTrue(zones["2:main"].orDie().setActiveWorkspace(secondaryMain))
        XCTAssertTrue(secondaryLeft.focusWorkspace())

        let ambiguous = try await parseCommand("column collapse left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(ambiguous.exitCode, 1)
        XCTAssertTrue(ambiguous.stderr.joined(separator: "\n").contains("ambiguous"))

        let disable = try await parseCommand("column collapse current --monitor 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disable.exitCode, 0, disable.stderr.joined(separator: "\n"))
        XCTAssertEqual(sortedMonitors.compactMap { monitor -> String? in
            guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
                  let columnId = monitor.columnId
            else { return nil }
            return "\(physicalId):\(columnId)"
        }, ["1:left", "1:main", "2:main"])

        XCTAssertTrue(secondaryMain.focusWorkspace())
        let enable = try await parseCommand("column expand prev --monitor 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(enable.exitCode, 0)
        XCTAssertEqual(sortedMonitors.compactMap { monitor -> String? in
            guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
                  let columnId = monitor.columnId
            else { return nil }
            return "\(physicalId):\(columnId)"
        }, ["1:left", "1:main", "2:left", "2:main"])
        XCTAssertEqual(zoneActiveWorkspacesByPhysicalZone(), [
            "1:left": "primary-left",
            "1:main": "primary-main",
            "2:left": "secondary-left",
            "2:main": "secondary-main",
        ])

        XCTAssertTrue(focus.workspace === secondaryMain)
        let toggle = try await parseCommand("column toggle prev --monitor 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(toggle.exitCode, 0)
        XCTAssertEqual(sortedMonitors.compactMap { monitor -> String? in
            guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
                  let columnId = monitor.columnId
            else { return nil }
            return "\(physicalId):\(columnId)"
        }, ["1:left", "1:main", "2:main"])
    }

    func testZoneCommandsFailWhenNoZonesAreConfigured() async throws {
        configureNoZones()
        let workspace = Workspace.get(byName: "work")
        let window = TestWindow.new(id: 61, parent: workspace.rootTilingContainer)
        XCTAssertTrue(window.focusWindow())

        let focusResult = try await FocusColumnCommand(args: FocusColumnCmdArgs(column: ColumnSelector("left")))
            .run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(focusResult.exitCode, 1)
        XCTAssertTrue(focusResult.stderr.joined(separator: "\n").contains("No columns are configured"))

        let moveResult = try await MoveNodeToColumnCommand(args: MoveNodeToColumnCmdArgs(column: ColumnSelector("left")))
            .run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(moveResult.exitCode, 1)
        XCTAssertTrue(moveResult.stderr.joined(separator: "\n").contains("No columns are configured"))
    }
}

@MainActor
private func activeWorkspaceNamesByZone() -> [String: String] {
    Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.columnId.map { ($0, monitor.activeWorkspace.name) }
    })
}

@MainActor
private func configureRouteCommsCallback() {
    var errors: [String] = []
    let regex = parseCaseInsensitiveRegex("route-comms").getOrNil(appendErrorTo: &errors).orDie()
    XCTAssertEqual(errors, [])
    config.onWindowDetected = [
        WindowDetectedCallback(
            matcher: WindowDetectedCallbackMatcher(windowTitleRegexSubstring: regex),
            rawRun: [
                MoveNodeToColumnCommand(args: MoveNodeToColumnCmdArgs(column: ColumnSelector("Comms")).copy(\.failIfNoop, true)),
            ],
        ),
    ]
}

@MainActor
private func configureRouteCommsRule() {
    var errors: [String] = []
    let regex = parseCaseInsensitiveRegex("mail-inbox").getOrNil(appendErrorTo: &errors).orDie()
    XCTAssertEqual(errors, [])
    config.rules = [
        RuleConfig(
            matcher: WindowDetectedCallbackMatcher(windowTitleRegexSubstring: regex),
            card: "comms",
        ),
    ]
}

@MainActor
private func configureRouteReferenceCallback() {
    config.onWindowDetected = [
        WindowDetectedCallback(
            rawRun: [
                MoveNodeToColumnCommand(args: MoveNodeToColumnCmdArgs(column: ColumnSelector("Reference")).copy(\.failIfNoop, true)),
            ],
        ),
    ]
}

@MainActor
private func configureColumnLayoutPresets() {
    let main = TestMonitor(
        monitorAppKitNsScreenScreensId: 1,
        name: "Main",
        rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        isMain: true,
    )
    setMonitorsForTests([main])
    config.gaps = .zero
    config.workspaceSidebar.enabled = false
    config.columnLayouts = [
        ColumnLayoutConfig(
            id: "balanced",
            layout: .columns,
            defaultZone: "main",
            columns: [
                ColumnConfig(id: "left", name: "Reference", width: 0.25),
                ColumnConfig(id: "main", name: "Work", width: 0.50),
                ColumnConfig(id: "right", name: "Comms", width: 0.25),
            ],
        ),
        ColumnLayoutConfig(
            id: "focus",
            layout: .columns,
            defaultZone: "main",
            columns: [
                ColumnConfig(id: "left", name: "Reference", width: 0.15),
                ColumnConfig(id: "main", name: "Work", width: 0.70),
                ColumnConfig(id: "right", name: "Comms", width: 0.15),
            ],
        ),
    ]
    config.zones = [
        DisplayLayoutConfig(
            monitor: .sequenceNumber(1),
            layoutPreset: "balanced",
        ),
    ]
}

@MainActor
private func configureThreeZones(
    defaultZone: String = "main",
    columns: [ColumnConfig]? = nil,
) -> [String: Monitor] {
    let main = TestMonitor(
        monitorAppKitNsScreenScreensId: 1,
        name: "Main",
        rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        isMain: true,
    )
    setMonitorsForTests([main])
    config.gaps = .zero
    config.workspaceSidebar.enabled = false
    config.zones = [
        testDisplayLayoutConfig(
            monitor: .sequenceNumber(1),
            defaultZone: defaultZone,
            columns: columns ?? [
                ColumnConfig(id: "left", name: "Reference", width: 0.25),
                ColumnConfig(id: "main", name: "Work", width: 0.50),
                ColumnConfig(id: "right", name: "Comms", width: 0.25),
            ],
        ),
    ]
    return Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.columnId.map { ($0, monitor) }
    })
}

@MainActor
private func configureNoZones() {
    let main = TestMonitor(
        monitorAppKitNsScreenScreensId: 1,
        name: "Main",
        rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        isMain: true,
    )
    setMonitorsForTests([main])
    config.gaps = .zero
    config.workspaceSidebar.enabled = false
    config.zones = []
}

@MainActor
private func configureNoZonesOnUltrawide() {
    let main = TestMonitor(
        monitorAppKitNsScreenScreensId: 1,
        name: "Main",
        rect: Rect(topLeftX: 0, topLeftY: 0, width: 3440, height: 1440),
        visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 3440, height: 1440),
        isMain: true,
    )
    setMonitorsForTests([main])
    config.gaps = .zero
    config.workspaceSidebar.enabled = false
    config.zones = []
}

@MainActor
private func withTemporaryConfig(_ text: String, _ body: (URL) async throws -> Void) async throws {
    let previousConfigUrl = configUrl
    let directory = FileManager.default.temporaryDirectory
        .appending(component: "winmux-layout-persistence-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appending(component: "winmux.toml")
    try text.write(to: url, atomically: true, encoding: .utf8)
    configUrl = url
    defer {
        configUrl = previousConfigUrl
        try? FileManager.default.removeItem(at: directory)
    }
    try await body(url)
}

private func columnLayoutBackupUrls(for url: URL) throws -> [URL] {
    let directory = url.deletingLastPathComponent()
    let prefix = "\(url.lastPathComponent).backup-"
    return try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
    )
    .filter { $0.lastPathComponent.hasPrefix(prefix) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

private func configRestoreRollbackUrls(for url: URL) throws -> [URL] {
    let directory = url.deletingLastPathComponent()
    let prefix = "\(url.lastPathComponent).rollback-"
    return try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
    )
    .filter { $0.lastPathComponent.hasPrefix(prefix) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

private func columnInitBaseConfigText() -> String {
    """
    # user config stays intact
    enable-normalization-flatten-containers = false

    [mode.main.binding]
    alt-slash = 'layout tiles horizontal vertical'
    """
}

private func columnLayoutPresetConfigText(missingRightColumnInBalanced: Bool = false) -> String {
    let rightColumn = missingRightColumnInBalanced ? "" : "    { id = 'right', name = 'Comms', width = 0.25 },\n"
    return """
        # keep user comments
        [[zone-layouts]]
        id = 'balanced'
        layout = 'columns'
        default-zone = 'main'
        columns = [
            { id = 'left', name = 'Reference', width = 0.25 }, # left comment
            { id = 'main', name = 'Work', width = 0.50 },
        \(rightColumn)    ]

        [[zone-layouts]]
        id = 'focus'
        layout = 'columns'
        default-zone = 'main'
        columns = [
            { id = 'left', name = 'Reference', width = 0.15 },
            { id = 'main', name = 'Work', width = 0.70 },
            { id = 'right', name = 'Comms', width = 0.15 },
        ]

        [[zones]]
        monitor = 1
        layout-preset = 'balanced'
        """
}

private func layoutPresetDisplayLayoutConfigText() -> String {
    """
    [[zone-layouts]]
    id = 'focus'
    layout = 'columns'
    default-zone = 'main'
    columns = [
        { id = 'left', name = 'Reference', width = 0.15 },
        { id = 'main', name = 'Work', width = 0.70 },
        { id = 'right', name = 'Comms', width = 0.15 },
    ]

    [[zones]]
    monitor = 1
    layout-preset = 'focus'
    """
}

@MainActor
private func configureDuplicateZones() -> [String: Monitor] {
    let main = TestMonitor(
        monitorAppKitNsScreenScreensId: 1,
        name: "Main",
        rect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
        visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
        isMain: true,
    )
    let secondary = TestMonitor(
        monitorAppKitNsScreenScreensId: 2,
        name: "Secondary",
        rect: Rect(topLeftX: 1000, topLeftY: 0, width: 1000, height: 800),
        visibleRect: Rect(topLeftX: 1000, topLeftY: 0, width: 1000, height: 800),
        isMain: false,
    )
    setMonitorsForTests([main, secondary])
    config.gaps = .zero
    config.workspaceSidebar.enabled = false
    config.columnLayouts = [
        ColumnLayoutConfig(
            id: "duplicate-layout",
            layout: .columns,
            defaultZone: "main",
            columns: [
                ColumnConfig(id: "left", name: "Reference", width: 0.50),
                ColumnConfig(id: "main", name: "Work", width: 0.50),
            ],
        ),
    ]
    config.zones = [
        DisplayLayoutConfig(monitor: .sequenceNumber(1), layoutPreset: "duplicate-layout"),
        DisplayLayoutConfig(monitor: .sequenceNumber(2), layoutPreset: "duplicate-layout"),
    ]
    return Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
              let columnId = monitor.columnId
        else { return nil }
        return ("\(physicalId):\(columnId)", monitor)
    })
}

@MainActor
@discardableResult
private func configureDuplicateColumnLayoutPresets() -> [String: Monitor] {
    let main = TestMonitor(
        monitorAppKitNsScreenScreensId: 1,
        name: "Main",
        rect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
        visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
        isMain: true,
    )
    let secondary = TestMonitor(
        monitorAppKitNsScreenScreensId: 2,
        name: "Secondary",
        rect: Rect(topLeftX: 1000, topLeftY: 0, width: 1000, height: 800),
        visibleRect: Rect(topLeftX: 1000, topLeftY: 0, width: 1000, height: 800),
        isMain: false,
    )
    setMonitorsForTests([main, secondary])
    config.gaps = .zero
    config.workspaceSidebar.enabled = false
    config.columnLayouts = [
        ColumnLayoutConfig(
            id: "balanced",
            layout: .columns,
            defaultZone: "main",
            columns: [
                ColumnConfig(id: "left", name: "Reference", width: 0.50),
                ColumnConfig(id: "main", name: "Work", width: 0.50),
            ],
        ),
        ColumnLayoutConfig(
            id: "focus",
            layout: .columns,
            defaultZone: "main",
            columns: [
                ColumnConfig(id: "left", name: "Reference", width: 0.30),
                ColumnConfig(id: "main", name: "Work", width: 0.70),
            ],
        ),
    ]
    config.zones = [
        DisplayLayoutConfig(monitor: .sequenceNumber(1), layoutPreset: "balanced"),
        DisplayLayoutConfig(monitor: .sequenceNumber(2), layoutPreset: "balanced"),
    ]
    return Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
              let columnId = monitor.columnId
        else { return nil }
        return ("\(physicalId):\(columnId)", monitor)
    })
}

@MainActor
private func zoneWidthsByPhysicalZone() -> [String: CGFloat] {
    Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
              let columnId = monitor.columnId
        else { return nil }
        let width = (monitor.rect.width * 1000).rounded() / 1000
        return ("\(physicalId):\(columnId)", width)
    })
}

@MainActor
private func columnLayoutIdsByPhysicalZone() -> [String: String] {
    Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
              let columnId = monitor.columnId,
              let columnLayoutId = monitor.columnLayoutId
        else { return nil }
        return ("\(physicalId):\(columnId)", columnLayoutId)
    })
}

@MainActor
private func zoneActiveWorkspacesByPhysicalZone() -> [String: String] {
    Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
              let columnId = monitor.columnId
        else { return nil }
        return ("\(physicalId):\(columnId)", monitor.activeWorkspace.name)
    })
}

@MainActor
private func zoneMonitorsById() -> [String: Monitor] {
    Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.columnId.map { ($0, monitor) }
    })
}

private struct StructuralColumnState: Equatable {
    let layoutId: String?
    let workspaceName: String
    let left: CGFloat
    let width: CGFloat
    let physicalId: Int?
}

private struct ColumnState: Equatable {
    let layoutId: String?
    let workspaceName: String
    let left: CGFloat
    let width: CGFloat
    let physicalId: Int?
    let styleId: String?
    let styleColorHex: String?

    var structural: StructuralColumnState {
        StructuralColumnState(
            layoutId: layoutId,
            workspaceName: workspaceName,
            left: left,
            width: width,
            physicalId: physicalId,
        )
    }
}

@MainActor
private func zoneStateByColumnId() -> [String: ColumnState] {
    Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        guard let columnId = monitor.columnId else { return nil }
        return (columnId, ColumnState(
            layoutId: monitor.columnLayoutId,
            workspaceName: monitor.activeWorkspace.name,
            left: monitor.rect.topLeftX,
            width: monitor.rect.width,
            physicalId: monitor.physicalMonitor.monitorId_oneBased,
            styleId: monitor.zoneStyleId,
            styleColorHex: monitor.columnColorHex,
        ))
    })
}
