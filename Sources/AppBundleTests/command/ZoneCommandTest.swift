@testable import AppBundle
import Common
import Foundation
import XCTest

@MainActor
final class ZoneCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseCommandSucc("focus-zone left", FocusZoneCmdArgs(zone: ZoneSelector("left")))
        testParseCommandSucc("focus-zone zone:left", FocusZoneCmdArgs(zone: ZoneSelector("zone:left")))
        testParseCommandSucc("focus-zone next", FocusZoneCmdArgs(zone: ZoneSelector("next")))
        testParseCommandSucc("move-node-to-zone --window-id 7 --focus-follows-window --fail-if-noop Comms",
                             MoveNodeToZoneCmdArgs(zone: ZoneSelector("Comms"))
                                 .copy(\.windowId, 7)
                                 .copy(\.focusFollowsWindow, true)
                                 .copy(\.failIfNoop, true))
        testParseCommandSucc(
            "move-node-to-zone --focus-follows-window prev",
            MoveNodeToZoneCmdArgs(zone: ZoneSelector("prev")).copy(\.focusFollowsWindow, true),
        )
        testParseCommandSucc("enable-zone Comms", EnableZoneCmdArgs(zone: ZoneSelector("Comms")))
        testParseCommandSucc("disable-zone --monitor 1 Comms", DisableZoneCmdArgs(zone: ZoneSelector("Comms"), monitor: .sequenceNumber(1)))
        testParseCommandSucc("toggle-zone 2:Comms", ToggleZoneCmdArgs(zone: ZoneSelector("2:Comms")))
        testParseCommandSucc(
            "resize-zone Work width +10%",
            ResizeZoneCmdArgs(zone: ZoneSelector("Work"), amount: .add(0.10)),
        )
        testParseCommandSucc(
            "resize-zone current width +10%",
            ResizeZoneCmdArgs(zone: ZoneSelector("current"), amount: .add(0.10)),
        )
        testParseCommandSucc(
            "resize-zone Work width -10%",
            ResizeZoneCmdArgs(zone: ZoneSelector("Work"), amount: .subtract(0.10)),
        )
        testParseCommandSucc(
            "resize-zone Work width 60%",
            ResizeZoneCmdArgs(zone: ZoneSelector("Work"), amount: .set(0.60)),
        )
        testParseCommandSucc(
            "balance-zones --monitor 1",
            BalanceZonesCmdArgs(monitor: .sequenceNumber(1)),
        )
        testParseCommandSucc(
            "export-zone-layout saved --monitor 1",
            ExportZoneLayoutCmdArgs(layoutId: "saved", monitor: .sequenceNumber(1)),
        )
        testParseCommandSucc("save-zone-layout", SaveZoneLayoutCmdArgs())
        testParseCommandSucc(
            "save-zone-layout --dry-run --monitor 1 --layout balanced",
            SaveZoneLayoutCmdArgs(monitor: .sequenceNumber(1), layoutId: "balanced", dryRun: true),
        )
        testParseCommandSucc(
            "zone init --dry-run --preset balanced",
            ZoneCmdArgs(action: .initialize, preset: .balanced, dryRun: true),
        )
        testParseCommandSucc(
            "zone init --write --replace-existing --preset comms-open --monitor 1",
            ZoneCmdArgs(action: .initialize, preset: .commsOpen, monitor: .sequenceNumber(1), write: true, replaceExisting: true),
        )
        testParseCommandFail("zone init --dry-run --write", msg: "ERROR: Conflicting options: --dry-run, --write")
        testParseCommandSucc(
            "config --check /tmp/winmux-exported-zone-layout.toml",
            ConfigCmdArgs(commonState: .init([])).copy(\.configPathToCheck, "/tmp/winmux-exported-zone-layout.toml"),
        )
        testParseCommandSucc(
            "config --restore-backup /tmp/winmux.toml.backup-20260702T010203Z",
            ConfigCmdArgs(commonState: .init([])).copy(\.backupPathToRestore, "/tmp/winmux.toml.backup-20260702T010203Z"),
        )
        testParseCommandSucc(
            "set-zone-style --monitor 1 Comms urgent",
            SetZoneStyleCmdArgs(zone: ZoneSelector("Comms"), styleId: "urgent", monitor: .sequenceNumber(1)),
        )
        testParseCommandSucc(
            "cycle-zone-style --monitor 1 Comms urgent calm",
            CycleZoneStyleCmdArgs(zone: ZoneSelector("Comms"), styleIds: ["urgent", "calm"], monitor: .sequenceNumber(1)),
        )
        testParseCommandSucc(
            "set-zone-snap-policy --monitor 1 snap-to-zone",
            SetZoneSnapPolicyCmdArgs(policyId: "snap-to-zone", monitor: .sequenceNumber(1)),
        )
        testParseCommandSucc(
            "cycle-zone-snap-policy freeform snap-to-zone",
            CycleZoneSnapPolicyCmdArgs(policyIds: ["freeform", "snap-to-zone"]),
        )
        testParseCommandFail("resize-zone Work width 10", msg: "ERROR: <percent> must include a % suffix, for example +10%")
        testParseCommandSucc("list-zones --json", ListZonesCmdArgs(rawArgs: []).copy(\.json, true))
    }

    func testFocusZoneResolvesZoneName() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(work.focusWorkspace())

        let result = try await FocusZoneCommand(args: FocusZoneCmdArgs(zone: ZoneSelector("Reference")))
            .run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(focus.workspace === reference)
    }

    func testFocusZoneResolvesZoneIdPrefix() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))

        let result = try await FocusZoneCommand(args: FocusZoneCmdArgs(zone: ZoneSelector("zone:left")))
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

        let next = try await parseCommand("focus-zone next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(next.exitCode, 0)
        XCTAssertTrue(focus.workspace === comms)

        let previous = try await parseCommand("focus-zone prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(previous.exitCode, 0)
        XCTAssertTrue(focus.workspace === work)

        let current = try await parseCommand("focus-zone current").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(current.exitCode, 0)
        XCTAssertTrue(focus.workspace === work)
    }

    func testRelativeZoneSelectorsStayWithinFocusedPhysicalMonitorWhenZoneIdsRepeat() async throws {
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

        let previous = try await parseCommand("focus-zone prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(previous.exitCode, 0)
        XCTAssertTrue(focus.workspace === secondaryLeft)

        let next = try await parseCommand("focus-zone next").cmdOrDie.run(.defaultEnv, .emptyStdin)
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

        let primaryNext = try await parseCommand("focus-zone 1:next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(primaryNext.exitCode, 0)
        XCTAssertTrue(focus.workspace === primaryLeft)

        let primaryCurrent = try await parseCommand("focus-zone 1:current").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(primaryCurrent.exitCode, 0)
        XCTAssertTrue(focus.workspace === primaryLeft)

        let secondaryPrevious = try await parseCommand("focus-zone 2:prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(secondaryPrevious.exitCode, 0)
        XCTAssertTrue(focus.workspace === secondaryLeft)

        let missingCurrent = try await parseCommand("focus-zone 1:current").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(missingCurrent.exitCode, 1)
        XCTAssertTrue(missingCurrent.stderr.joined(separator: "\n").contains("No focused zone matches"))
    }

    func testDuplicateBareZoneIdsRequirePhysicalQualifier() async throws {
        let zones = configureDuplicateZones()
        let secondaryLeft = Workspace.get(byName: "secondary-left")
        _ = TestWindow.new(id: 31, parent: secondaryLeft.rootTilingContainer)
        XCTAssertTrue(zones["2:left"].orDie().setActiveWorkspace(secondaryLeft))

        let ambiguous = try await FocusZoneCommand(args: FocusZoneCmdArgs(zone: ZoneSelector("left")))
            .run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(ambiguous.exitCode, 1)
        XCTAssertTrue(ambiguous.stderr.joined(separator: "\n").contains("ambiguous"))

        let qualified = try await FocusZoneCommand(args: FocusZoneCmdArgs(zone: ZoneSelector("2:left")))
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

        let result = try await MoveNodeToZoneCommand(args: MoveNodeToZoneCmdArgs(zone: ZoneSelector("Comms")).copy(\.failIfNoop, true))
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

        let result = try await parseCommand("move-node-to-zone --focus-follows-window next").cmdOrDie.run(.defaultEnv, .emptyStdin)

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

        let result = try await MoveNodeToZoneCommand(args: MoveNodeToZoneCmdArgs(zone: ZoneSelector("Work")).copy(\.failIfNoop, true))
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

        let result = try await MoveNodeToZoneCommand(args: MoveNodeToZoneCmdArgs(zone: ZoneSelector("Comms")).copy(\.windowId, 43))
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

        let result = try await MoveNodeToZoneCommand(args: MoveNodeToZoneCmdArgs(zone: ZoneSelector("Comms")).copy(\.failIfNoop, true))
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

    func testZoneAffinityRoutesDetectedWindowToZone() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let targetWindow = TestWindow.new(id: 51, parent: work.rootTilingContainer, title: "mail-inbox.rtf")
        let focusedWindow = TestWindow.new(id: 52, parent: work.rootTilingContainer, title: "focused-work.rtf")
        XCTAssertTrue(focusedWindow.focusWindow())
        configureRouteCommsAffinity()

        try await tryOnWindowDetected(targetWindow)

        XCTAssertTrue(targetWindow.nodeWorkspace === comms)
        XCTAssertTrue(focusedWindow.nodeWorkspace === work)
    }

    func testZoneAffinityStopsFurtherCallbacksByDefault() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let targetWindow = TestWindow.new(id: 53, parent: work.rootTilingContainer, title: "mail-inbox.rtf")
        configureRouteCommsAffinity()
        config.onWindowDetected = [
            WindowDetectedCallback(
                rawRun: [
                    MoveNodeToZoneCommand(args: MoveNodeToZoneCmdArgs(zone: ZoneSelector("Reference"))),
                ],
            ),
        ]

        try await tryOnWindowDetected(targetWindow)

        XCTAssertTrue(targetWindow.nodeWorkspace === comms)
    }

    func testZoneAffinityCheckFurtherCallbacksAllowsGenericCallback() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let targetWindow = TestWindow.new(id: 54, parent: work.rootTilingContainer, title: "mail-inbox.rtf")
        configureRouteCommsAffinity(checkFurtherCallbacks: true)
        configureRouteReferenceCallback()

        try await tryOnWindowDetected(targetWindow)

        XCTAssertTrue(targetWindow.nodeWorkspace === reference)
    }

    func testZoneAffinityFailedCommandFallsThroughToGenericCallback() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let targetWindow = TestWindow.new(id: 58, parent: comms.rootTilingContainer, title: "mail-inbox.rtf")
        configureRouteCommsAffinity(failIfNoop: true)
        configureRouteReferenceCallback()

        try await tryOnWindowDetected(targetWindow)

        XCTAssertTrue(targetWindow.nodeWorkspace === reference)
    }

    func testZoneAffinityEvaluationReportsMatchedRuleAndEnabledTarget() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        let targetWindow = TestWindow.new(id: 59, parent: work.rootTilingContainer, title: "mail-inbox.rtf")
        configureRouteCommsAffinity()

        let evaluation = try await config.zoneAffinities.singleOrNil().orDie()
            .evaluate(index: 0, window: targetWindow)

        XCTAssertTrue(evaluation.matched)
        XCTAssertEqual(evaluation.zone, "Comms")
        XCTAssertTrue(evaluation.matcher.matchedTerms.contains { $0.contains("window-title-regex-substring matched title 'mail-inbox.rtf'") })
        XCTAssertEqual(evaluation.target, .enabled(physicalMonitorId: 1, zoneId: "right", zoneName: "Comms"))
        XCTAssertFalse(evaluation.checkFurtherCallbacks)
        XCTAssertFalse(evaluation.focusFollowsWindow)
        XCTAssertFalse(evaluation.failIfNoop)
    }

    func testZoneAffinityEvaluationExplainsNoMatchFields() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        let targetWindow = TestWindow.new(id: 60, parent: work.rootTilingContainer, title: "notes.rtf")
        var errors: [String] = []
        config.zoneAffinities = [
            ZoneAffinityConfig(
                matcher: WindowDetectedCallbackMatcher(
                    appId: "com.apple.mail",
                    appNameRegexSubstring: parseCaseInsensitiveRegex("Mail").getOrNil(appendErrorTo: &errors),
                    windowTitleRegexSubstring: parseCaseInsensitiveRegex("Inbox").getOrNil(appendErrorTo: &errors),
                    workspace: "comms",
                ),
                zone: ZoneSelector("Comms"),
            ),
        ]
        XCTAssertEqual(errors, [])

        let evaluation = try await config.zoneAffinities.singleOrNil().orDie()
            .evaluate(index: 0, window: targetWindow)

        XCTAssertFalse(evaluation.matched)
        XCTAssertTrue(evaluation.matcher.failedTerms.contains("app-id expected 'com.apple.mail' but got 'bobko.WinMux.test-app'"))
        XCTAssertTrue(evaluation.matcher.failedTerms.contains("app-name-regex-substring did not match app name 'bobko.WinMux.test-app'"))
        XCTAssertTrue(evaluation.matcher.failedTerms.contains("window-title-regex-substring did not match title 'notes.rtf'"))
        XCTAssertTrue(evaluation.matcher.failedTerms.contains("workspace expected 'comms' but got 'work'"))
        XCTAssertEqual(evaluation.target, .enabled(physicalMonitorId: 1, zoneId: "right", zoneName: "Comms"))
    }

    func testZoneAffinityDisabledTargetFallsThroughAndInspectionNamesHiddenZone() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let targetWindow = TestWindow.new(id: 61, parent: work.rootTilingContainer, title: "mail-inbox.rtf")
        configureRouteCommsAffinity()
        configureRouteReferenceCallback()

        let disabled = try await DisableZoneCommand(args: DisableZoneCmdArgs(zone: ZoneSelector("Comms")))
            .run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disabled.exitCode, 0)
        let evaluation = try await config.zoneAffinities.singleOrNil().orDie()
            .evaluate(index: 0, window: targetWindow)

        XCTAssertTrue(evaluation.matched)
        XCTAssertEqual(evaluation.target, .disabled(physicalMonitorId: 1, zoneId: "right", zoneName: "Comms"))

        try await tryOnWindowDetected(targetWindow)

        XCTAssertTrue(targetWindow.nodeWorkspace === reference)
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

        let result = try await MoveNodeToZoneCommand(args: MoveNodeToZoneCmdArgs(zone: ZoneSelector("right")))
            .run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(tabGroup.nodeWorkspace === comms)
        XCTAssertTrue(first.nodeWorkspace === comms)
        XCTAssertTrue(second.nodeWorkspace === comms)
        XCTAssertFalse(work.rootTilingContainer.allLeafWindowsRecursive.contains(first))
    }

    func testListZonesOutputsZoneNamesAndActiveWorkspaces() async throws {
        let zones = configureThreeZones()
        let reference = Workspace.get(byName: "reference")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))

        let result = try await parseCommand(
            "list-zones --format '%{monitor-zone-id}|%{monitor-zone-name}|%{monitor-physical-id}|%{monitor-active-workspace}'",
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

        let countResult = try await parseCommand("list-zones --count").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(countResult.exitCode, 0)
        XCTAssertEqual(countResult.stdout, ["3"])

        let jsonResult = try await parseCommand("list-zones --json").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(jsonResult.exitCode, 0)
        let json = try XCTUnwrap(jsonResult.stdout.first)
        let rows = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]])
        let referenceRow = try XCTUnwrap(rows.first { $0["monitor-zone-id"] as? String == "left" })
        XCTAssertEqual(referenceRow["monitor-zone-name"] as? String, "Reference")
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

        let resize = try await parseCommand("resize-zone Work width +10%").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(resize.exitCode, 0)
        XCTAssertEqual(resize.stdout, ["Resized zone 'Work' on monitor 1 by +10%"])
        XCTAssertEqual(sortedMonitors.map(\.zoneId), ["left", "main", "right"])
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [240, 720, 240])
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.zoneId == "left" }.orDie().activeWorkspace === reference)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.zoneId == "main" }.orDie().activeWorkspace === work)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.zoneId == "right" }.orDie().activeWorkspace === comms)

        let list = try await parseCommand(
            "list-zones --format '%{monitor-zone-id}|%{monitor-zone-enabled}|%{monitor-zone-configured-width}|%{monitor-zone-effective-width}|%{monitor-zone-runtime-width-override-state}|%{monitor-left}|%{monitor-width}|%{monitor-active-workspace}'",
        ).cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(list.exitCode, 0)
        XCTAssertTrue(list.stdout.contains("main|true|0.5|0.6|runtime|240.0|720.0|work"))
        XCTAssertTrue(list.stdout.contains("left|true|0.25|0.2|runtime|0.0|240.0|reference"))
        XCTAssertTrue(list.stdout.contains("right|true|0.25|0.2|runtime|960.0|240.0|comms"))

        let balance = try await parseCommand("balance-zones").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(balance.exitCode, 0)
        XCTAssertEqual(balance.stdout, ["Balanced zones on monitor 1"])
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [400, 400, 400])
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.zoneId == "left" }.orDie().activeWorkspace === reference)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.zoneId == "main" }.orDie().activeWorkspace === work)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.zoneId == "right" }.orDie().activeWorkspace === comms)
    }

    func testExportZoneLayoutPrintsCurrentEffectiveWidthsAsParseableToml() async throws {
        _ = configureThreeZones()
        let resize = try await parseCommand("resize-zone Work width +10%").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(resize.exitCode, 0)

        let export = try await parseCommand("export-zone-layout saved-ultrawide --monitor 1").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(export.exitCode, 0, export.stderr.joined(separator: "\n"))
        XCTAssertEqual(export.stdout, [
            "[[zone-layouts]]",
            "id = \"saved-ultrawide\"",
            "layout = 'columns'",
            "default-zone = \"main\"",
            "columns = [",
            "    { id = \"left\", name = \"Reference\", width = 0.2 },",
            "    { id = \"main\", name = \"Work\", width = 0.6 },",
            "    { id = \"right\", name = \"Comms\", width = 0.2 },",
            "]",
        ])

        let (parsed, errors) = parseConfig(export.stdout.joined(separator: "\n"))
        assertEquals(errors, [])
        XCTAssertEqual(parsed.zoneLayouts, [
            ZoneLayoutConfig(
                id: "saved-ultrawide",
                layout: .columns,
                defaultZone: "main",
                columns: [
                    ZoneColumnConfig(id: "left", name: "Reference", width: 0.2),
                    ZoneColumnConfig(id: "main", name: "Work", width: 0.6),
                    ZoneColumnConfig(id: "right", name: "Comms", width: 0.2),
                ],
            ),
        ])

        let exportPath = FileManager.default.temporaryDirectory
            .appending(component: "winmux-exported-zone-layout-\(UUID().uuidString).toml")
        try export.stdout.joined(separator: "\n").write(to: exportPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: exportPath) }

        let check = try await parseCommand("config --check \(exportPath.path)").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(check.exitCode, 0, check.stderr.joined(separator: "\n"))
        XCTAssertEqual(check.stdout, ["Config OK: \(exportPath.path)"])
    }

    func testExportZoneLayoutOnlyUsesSelectedPhysicalMonitor() async throws {
        let zones = configureDuplicateZones()
        let secondaryLeft = Workspace.get(byName: "secondary-left")
        XCTAssertTrue(zones["2:left"].orDie().setActiveWorkspace(secondaryLeft))
        XCTAssertTrue(secondaryLeft.focusWorkspace())
        let resize = try await parseCommand("resize-zone --monitor 2 main width 70%").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(resize.exitCode, 0)

        let export = try await parseCommand("export-zone-layout secondary-saved --monitor 2").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(export.exitCode, 0, export.stderr.joined(separator: "\n"))
        XCTAssertEqual(export.stdout, [
            "[[zone-layouts]]",
            "id = \"secondary-saved\"",
            "layout = 'columns'",
            "default-zone = \"main\"",
            "columns = [",
            "    { id = \"left\", name = \"Reference\", width = 0.3 },",
            "    { id = \"main\", name = \"Work\", width = 0.7 },",
            "]",
        ])
    }

    func testExportZoneLayoutRejectsDisabledZonesWithoutMutation() async throws {
        _ = configureThreeZones()
        let disable = try await parseCommand("disable-zone Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disable.exitCode, 0)

        let export = try await parseCommand("export-zone-layout partial").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(export.exitCode, 1)
        XCTAssertTrue(export.stderr.joined(separator: "\n").contains("Can't export zone layout while zones are disabled on monitor 1: Comms"))
        XCTAssertEqual(sortedMonitors.map(\.zoneId), ["left", "main"])
        XCTAssertEqual(config.zones.singleOrNil().orDie().columns.map(\.width), [0.25, 0.5, 0.25])
    }

    func testExportZoneLayoutSupportsInlineZonesWithoutNamedActiveLayout() async throws {
        configureInlineZonesWithLayoutPresets()
        let export = try await parseCommand("export-zone-layout inline-saved").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(export.exitCode, 0, export.stderr.joined(separator: "\n"))
        let (parsed, errors) = parseConfig(export.stdout.joined(separator: "\n"))
        assertEquals(errors, [])
        XCTAssertEqual(parsed.zoneLayouts.singleOrNil(), ZoneLayoutConfig(
            id: "inline-saved",
            layout: .columns,
            defaultZone: "main",
            columns: [
                ZoneColumnConfig(id: "left", name: "Reference", width: 0.25),
                ZoneColumnConfig(id: "main", name: "Work", width: 0.5),
                ZoneColumnConfig(id: "right", name: "Comms", width: 0.25),
            ],
        ))
    }

    func testExportZoneLayoutEscapesTomlStringsAndParses() async throws {
        let leftName = #"Reference "Docs""#
        let mainName = #"Work\Main"#
        let rightName = "Comms\nAsync"
        _ = configureThreeZones(columns: [
            ZoneColumnConfig(id: "left", name: leftName, width: 0.25),
            ZoneColumnConfig(id: "main", name: mainName, width: 0.50),
            ZoneColumnConfig(id: "right", name: rightName, width: 0.25),
        ])

        let export = try await parseCommand("export-zone-layout escaped --monitor 1").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(export.exitCode, 0, export.stderr.joined(separator: "\n"))
        XCTAssertTrue(export.stdout.contains(#"    { id = "left", name = "Reference \"Docs\"", width = 0.25 },"#))
        XCTAssertTrue(export.stdout.contains(#"    { id = "main", name = "Work\\Main", width = 0.5 },"#))
        XCTAssertTrue(export.stdout.contains(#"    { id = "right", name = "Comms\nAsync", width = 0.25 },"#))

        let (parsed, errors) = parseConfig(export.stdout.joined(separator: "\n"))
        assertEquals(errors, [])
        XCTAssertEqual(parsed.zoneLayouts.singleOrNil()?.columns.map(\.name), [leftName, mainName, rightName])
    }

    func testExportZoneLayoutNormalizesRoundedWidthsAndParses() async throws {
        _ = configureThreeZones(columns: [
            ZoneColumnConfig(id: "left", name: "Reference", width: 0.3333333),
            ZoneColumnConfig(id: "main", name: "Work", width: 0.3333333),
            ZoneColumnConfig(id: "right", name: "Comms", width: 0.3333334),
        ])

        let export = try await parseCommand("export-zone-layout thirds --monitor 1").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(export.exitCode, 0, export.stderr.joined(separator: "\n"))
        XCTAssertTrue(export.stdout.contains(#"    { id = "left", name = "Reference", width = 0.333333 },"#))
        XCTAssertTrue(export.stdout.contains(#"    { id = "main", name = "Work", width = 0.333333 },"#))
        XCTAssertTrue(export.stdout.contains(#"    { id = "right", name = "Comms", width = 0.333334 },"#))

        let (parsed, errors) = parseConfig(export.stdout.joined(separator: "\n"))
        assertEquals(errors, [])
        let widths = parsed.zoneLayouts.singleOrNil().orDie().columns.map(\.width)
        XCTAssertEqual(widths, [0.333333, 0.333333, 0.333334])
        XCTAssertEqual(widths.reduce(0.0, +), 1.0, accuracy: 0.000001)
    }

    func testSaveZoneLayoutDryRunDoesNotWriteConfigOrBackup() async throws {
        configureZoneLayoutPresets()
        let originalText = zoneLayoutPresetConfigText()

        try await withTemporaryConfig(originalText) { url in
            let resize = try await parseCommand("resize-zone Work width +10%").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(resize.exitCode, 0)

            let save = try await parseCommand("save-zone-layout --dry-run").cmdOrDie.run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(save.exitCode, 0, save.stderr.joined(separator: "\n"))
            XCTAssertEqual(save.stdout.first, "Dry run: would save zone layout 'balanced' on monitor 1 to \(url.path)")
            XCTAssertTrue(save.stdout.contains("left: 0.25 -> 0.2"))
            XCTAssertTrue(save.stdout.contains("main: 0.5 -> 0.6"))
            XCTAssertTrue(save.stdout.contains("right: 0.25 -> 0.2"))
            XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), originalText)
            XCTAssertEqual(try zoneLayoutBackupUrls(for: url), [])
        }
    }

    func testSaveZoneLayoutWritesNamedLayoutAndBackup() async throws {
        configureZoneLayoutPresets()
        let originalText = zoneLayoutPresetConfigText()

        try await withTemporaryConfig(originalText) { url in
            let resize = try await parseCommand("resize-zone Work width +10%").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(resize.exitCode, 0)

            let save = try await parseCommand("save-zone-layout").cmdOrDie.run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(save.exitCode, 0, save.stderr.joined(separator: "\n"))
            XCTAssertEqual(save.stdout.first, "Saved zone layout 'balanced' on monitor 1 to \(url.path)")
            XCTAssertTrue(save.stdout.contains("left: 0.25 -> 0.2"))
            XCTAssertTrue(save.stdout.contains("main: 0.5 -> 0.6"))
            XCTAssertTrue(save.stdout.contains("right: 0.25 -> 0.2"))

            let backups = try zoneLayoutBackupUrls(for: url)
            XCTAssertEqual(backups.count, 1)
            XCTAssertEqual(try String(contentsOf: backups.singleOrNil().orDie(), encoding: .utf8), originalText)

            let updatedText = try String(contentsOf: url, encoding: .utf8)
            XCTAssertTrue(updatedText.contains("# keep user comments"))
            XCTAssertTrue(updatedText.contains("{ id = 'left', name = 'Reference', width = 0.2 }, # left comment"))
            XCTAssertTrue(updatedText.contains("{ id = 'main', name = 'Work', width = 0.6 },"))
            XCTAssertTrue(updatedText.contains("{ id = 'right', name = 'Comms', width = 0.2 },"))
            XCTAssertTrue(updatedText.contains("{ id = 'main', name = 'Work', width = 0.70 },"))

            let (parsed, errors) = parseConfig(updatedText)
            assertEquals(errors, [])
            let balanced = parsed.zoneLayouts.singleOrNil { $0.id == "balanced" }.orDie()
            XCTAssertEqual(balanced.columns.map(\.width), [0.2, 0.6, 0.2])
            let focus = parsed.zoneLayouts.singleOrNil { $0.id == "focus" }.orDie()
            XCTAssertEqual(focus.columns.map(\.width), [0.15, 0.70, 0.15])
        }
    }

    func testSaveZoneLayoutWritesCRLFNamedLayoutAndBackup() async throws {
        configureZoneLayoutPresets()
        let originalText = zoneLayoutPresetConfigText()
            .replacingOccurrences(of: "\n", with: "\r\n")

        try await withTemporaryConfig(originalText) { url in
            let resize = try await parseCommand("resize-zone Work width +10%").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(resize.exitCode, 0)

            let save = try await parseCommand("save-zone-layout").cmdOrDie.run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(save.exitCode, 0, save.stderr.joined(separator: "\n"))
            let backups = try zoneLayoutBackupUrls(for: url)
            XCTAssertEqual(backups.count, 1)
            XCTAssertEqual(try String(contentsOf: backups.singleOrNil().orDie(), encoding: .utf8), originalText)

            let updatedText = try String(contentsOf: url, encoding: .utf8)
            XCTAssertTrue(updatedText.contains("\r\n"))
            XCTAssertFalse(updatedText.replacingOccurrences(of: "\r\n", with: "").contains("\n"))
            XCTAssertTrue(updatedText.contains("{ id = 'left', name = 'Reference', width = 0.2 }, # left comment"))
            XCTAssertTrue(updatedText.contains("{ id = 'main', name = 'Work', width = 0.6 },"))
            XCTAssertTrue(updatedText.contains("{ id = 'right', name = 'Comms', width = 0.2 },"))

            let (parsed, errors) = parseConfig(updatedText)
            assertEquals(errors, [])
            let balanced = parsed.zoneLayouts.singleOrNil { $0.id == "balanced" }.orDie()
            XCTAssertEqual(balanced.columns.map(\.width), [0.2, 0.6, 0.2])
        }
    }

    func testSaveZoneLayoutWritesInlineZonesAndBackup() async throws {
        configureInlineZonesWithLayoutPresets()
        let originalText = inlineZoneConfigText()

        try await withTemporaryConfig(originalText) { url in
            let resize = try await parseCommand("resize-zone Work width +10%").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(resize.exitCode, 0)

            let save = try await parseCommand("save-zone-layout").cmdOrDie.run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(save.exitCode, 0, save.stderr.joined(separator: "\n"))
            XCTAssertEqual(save.stdout.first, "Saved inline [[zones]] on monitor 1 to \(url.path)")
            let backups = try zoneLayoutBackupUrls(for: url)
            XCTAssertEqual(backups.count, 1)
            XCTAssertEqual(try String(contentsOf: backups.singleOrNil().orDie(), encoding: .utf8), originalText)

            let updatedText = try String(contentsOf: url, encoding: .utf8)
            let (parsed, errors) = parseConfig(updatedText)
            assertEquals(errors, [])
            XCTAssertEqual(parsed.zones.singleOrNil().orDie().columns.map(\.width), [0.2, 0.6, 0.2])
            XCTAssertEqual(parsed.zoneLayouts.singleOrNil().orDie().columns.map(\.width), [0.15, 0.70, 0.15])
        }
    }

    func testSaveZoneLayoutRejectsMismatchedConfigWithoutMutation() async throws {
        configureZoneLayoutPresets()
        let originalText = zoneLayoutPresetConfigText(missingRightColumnInBalanced: true)

        try await withTemporaryConfig(originalText) { url in
            let resize = try await parseCommand("resize-zone Work width +10%").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(resize.exitCode, 0)

            let save = try await parseCommand("save-zone-layout").cmdOrDie.run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(save.exitCode, 1)
            XCTAssertTrue(save.stderr.joined(separator: "\n").contains("missing active runtime zone ids: right"))
            XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), originalText)
            XCTAssertEqual(try zoneLayoutBackupUrls(for: url), [])
        }
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
        let restoredText = zoneLayoutPresetConfigText()

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
        let originalText = zoneLayoutPresetConfigText()

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

    func testZoneInitDryRunDoesNotWriteConfigOrBackup() async throws {
        configureNoZonesOnUltrawide()
        let originalText = zoneInitBaseConfigText()

        try await withTemporaryConfig(originalText) { url in
            let result = try await parseCommand("zone init --dry-run --preset balanced").cmdOrDie.run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(result.exitCode, 0, result.stderr.joined(separator: "\n"))
            XCTAssertEqual(result.stdout.first, "Dry run: would append balanced zones to \(url.path)")
            XCTAssertTrue(result.stdout.contains("Mode: dry-run"))
            XCTAssertTrue(result.stdout.contains("Preset: balanced"))
            XCTAssertTrue(result.stdout.contains("Selected monitor: monitor 1 Main 3440x1440 aspect 2.388889"))
            let rendered = result.stdout.joined(separator: "\n")
            XCTAssertTrue(rendered.contains("[[zones]]"))
            XCTAssertTrue(rendered.contains(#"{ id = "left", name = "Reference", width = 0.25 },"#))
            XCTAssertTrue(rendered.contains(#"{ id = "main", name = "Work", width = 0.5 },"#))
            XCTAssertTrue(rendered.contains(#"{ id = "right", name = "Comms", width = 0.25 },"#))
            XCTAssertTrue(result.stdout.contains("Run with --write to update the config."))
            XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), originalText)
            XCTAssertEqual(try zoneLayoutBackupUrls(for: url), [])
        }
    }

    func testZoneInitWritesConfigAndBackup() async throws {
        configureNoZonesOnUltrawide()
        let originalText = zoneInitBaseConfigText()

        try await withTemporaryConfig(originalText) { url in
            let result = try await parseCommand("zone init --preset balanced --write").cmdOrDie.run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(result.exitCode, 0, result.stderr.joined(separator: "\n"))
            XCTAssertEqual(result.stdout.first, "Wrote balanced zones to \(url.path)")
            XCTAssertTrue(result.stdout.contains("Mode: write"))
            XCTAssertTrue(result.stdout.contains("Preset: balanced"))
            XCTAssertTrue(result.stdout.contains { $0.hasPrefix("Backup: \(url.path).backup-") })
            XCTAssertTrue(result.stdout.joined(separator: "\n").contains(zoneInitManagedBlockBegin))

            let backups = try zoneLayoutBackupUrls(for: url)
            XCTAssertEqual(backups.count, 1)
            XCTAssertEqual(try String(contentsOf: backups.singleOrNil().orDie(), encoding: .utf8), originalText)

            let updatedText = try String(contentsOf: url, encoding: .utf8)
            let (parsed, errors) = parseConfig(updatedText)
            assertEquals(errors, [])
            let zones = parsed.zones.singleOrNil().orDie()
            XCTAssertEqual(zones.monitor, .sequenceNumber(1))
            XCTAssertEqual(zones.defaultZone, "main")
            XCTAssertEqual(zones.columns.map(\.id), ["left", "main", "right"])
            XCTAssertEqual(zones.columns.map(\.name), ["Reference", "Work", "Comms"])
            XCTAssertEqual(zones.columns.map(\.width), [0.25, 0.50, 0.25])
        }
    }

    func testZoneInitWriteIsIdempotent() async throws {
        configureNoZonesOnUltrawide()

        try await withTemporaryConfig(zoneInitBaseConfigText()) { url in
            let first = try await parseCommand("zone init --preset balanced --write").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(first.exitCode, 0)
            let firstText = try String(contentsOf: url, encoding: .utf8)
            XCTAssertEqual(try zoneLayoutBackupUrls(for: url).count, 1)

            let second = try await parseCommand("zone init --preset balanced --write").cmdOrDie.run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(second.exitCode, 0, second.stderr.joined(separator: "\n"))
            XCTAssertEqual(second.stdout.first, "Zone init already configured in \(url.path)")
            XCTAssertTrue(second.stdout.contains("No changes needed."))
            XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), firstText)
            XCTAssertEqual(try zoneLayoutBackupUrls(for: url).count, 1)
        }
    }

    func testZoneInitRejectsUnmanagedActiveZonesWithoutMutation() async throws {
        configureNoZonesOnUltrawide()
        let originalText = inlineZoneConfigText()

        try await withTemporaryConfig(originalText) { url in
            let result = try await parseCommand("zone init --preset balanced --write").cmdOrDie.run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(result.exitCode, 1)
            XCTAssertTrue(result.stderr.joined(separator: "\n").contains("Config already has active [[zones]]"))
            XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), originalText)
            XCTAssertEqual(try zoneLayoutBackupUrls(for: url), [])
        }
    }

    func testZoneInitReplaceExistingManagedBlock() async throws {
        configureNoZonesOnUltrawide()

        try await withTemporaryConfig(zoneInitBaseConfigText()) { url in
            let first = try await parseCommand("zone init --preset balanced --write").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(first.exitCode, 0)

            let blocked = try await parseCommand("zone init --preset focus-only --write").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(blocked.exitCode, 1)
            XCTAssertTrue(blocked.stderr.joined(separator: "\n").contains("--replace-existing"))

            let replaced = try await parseCommand("zone init --preset focus-only --write --replace-existing").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(replaced.exitCode, 0, replaced.stderr.joined(separator: "\n"))
            XCTAssertEqual(replaced.stdout.first, "Wrote focus-only zones to \(url.path)")

            let backups = try zoneLayoutBackupUrls(for: url)
            XCTAssertEqual(backups.count, 2)
            let updatedText = try String(contentsOf: url, encoding: .utf8)
            XCTAssertEqual(updatedText.components(separatedBy: zoneInitManagedBlockBegin).count - 1, 1)

            let (parsed, errors) = parseConfig(updatedText)
            assertEquals(errors, [])
            XCTAssertEqual(parsed.zones.singleOrNil().orDie().columns.map(\.width), [0.15, 0.70, 0.15])
        }
    }

    func testConfiguredRelativeZoneSelectorTargetsFocusedZone() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(work.focusWorkspace())

        let result = try await parseCommand("resize-zone current width +10%").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, ["Resized zone 'Work' on monitor 1 by +10%"])
        XCTAssertEqual(sortedMonitors.map(\.zoneId), ["left", "main", "right"])
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

        let hide = try await parseCommand("toggle-zone current").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(hide.exitCode, 0)
        XCTAssertEqual(hide.stdout, ["Disabled zone 'Comms' on monitor 1"])
        XCTAssertEqual(sortedMonitors.map(\.zoneId), ["left", "main"])
        XCTAssertTrue(focus.workspace === work)

        let restore = try await parseCommand("toggle-zone current").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(restore.exitCode, 0)
        XCTAssertEqual(restore.stdout, ["Enabled zone 'Comms' on monitor 1"])
        XCTAssertEqual(sortedMonitors.map(\.zoneId), ["left", "main", "right"])
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.zoneId == "right" }.orDie().activeWorkspace === comms)
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

        let disable = try await parseCommand("disable-zone Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disable.exitCode, 0)
        Workspace.reconcileWorkspaceState()
        XCTAssertTrue(Workspace.existing(byName: "comms-empty") === commsEmpty)

        let enable = try await parseCommand("enable-zone Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(enable.exitCode, 0)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.zoneId == "right" }.orDie().activeWorkspace === commsEmpty)
    }

    func testResizeZoneRejectsDisabledZoneAndBalanceUsesEnabledZonesOnly() async throws {
        _ = configureThreeZones()

        let disable = try await parseCommand("disable-zone Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disable.exitCode, 0)

        let resize = try await parseCommand("resize-zone Comms width +10%").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(resize.exitCode, 1)
        XCTAssertTrue(resize.stderr.joined(separator: "\n").contains("Zone 'Comms' is disabled"))

        let balance = try await parseCommand("balance-zones").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(balance.exitCode, 0)
        XCTAssertEqual(sortedMonitors.map(\.zoneId), ["left", "main"])
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [600, 600])

        let list = try await parseCommand(
            "list-zones --format '%{monitor-zone-id}|%{monitor-zone-enabled}|%{monitor-zone-effective-width}|%{monitor-width}'",
        ).cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(list.exitCode, 0)
        XCTAssertTrue(list.stdout.contains("left|true|0.375|600.0"))
        XCTAssertTrue(list.stdout.contains("main|true|0.375|600.0"))
        XCTAssertTrue(list.stdout.contains("right|false|0.25|"))
    }

    func testResizeZoneRequiresUnambiguousPhysicalScope() async throws {
        _ = configureDuplicateZones()

        let ambiguous = try await parseCommand("resize-zone left width +10%").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(ambiguous.exitCode, 1)
        XCTAssertTrue(ambiguous.stderr.joined(separator: "\n").contains("ambiguous"))
        XCTAssertEqual(zoneWidthsByPhysicalZone(), [
            "1:left": 500,
            "1:main": 500,
            "2:left": 500,
            "2:main": 500,
        ])

        let overspecified = try await parseCommand("resize-zone --monitor 2 1:left width +10%").cmdOrDie.run(.defaultEnv, .emptyStdin)
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

        let resize = try await parseCommand("resize-zone --monitor 2 next width +10%").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(resize.exitCode, 0)
        XCTAssertEqual(resize.stdout, ["Resized zone 'Work' on monitor 2 by +10%"])
        XCTAssertEqual(zoneWidthsByPhysicalZone(), [
            "1:left": 500,
            "1:main": 500,
            "2:left": 400,
            "2:main": 600,
        ])

        let set = try await parseCommand("resize-zone 2:main width 70%").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(set.exitCode, 0)
        XCTAssertEqual(set.stdout, ["Resized zone 'Work' on monitor 2 by 70%"])
        XCTAssertEqual(zoneWidthsByPhysicalZone(), [
            "1:left": 500,
            "1:main": 500,
            "2:left": 300,
            "2:main": 700,
        ])

        let balance = try await parseCommand("balance-zones --monitor 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(balance.exitCode, 0)
        XCTAssertEqual(balance.stdout, ["Balanced zones on monitor 2"])
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

        let preview = try XCTUnwrap(previewZoneDividerMove(
            on: zones["main"].orDie().physicalMonitor,
            leftZoneId: "main",
            rightZoneId: "right",
            deltaPixels: 120,
        ).getOrNil())
        XCTAssertEqual(preview.oldBoundaryX, 900)
        XCTAssertEqual(preview.newBoundaryX, 1020)
        XCTAssertEqual(preview.leftAfterShare, 0.6, accuracy: 0.0001)
        XCTAssertEqual(preview.rightAfterShare, 0.15, accuracy: 0.0001)

        let result = try XCTUnwrap(moveZoneDivider(
            on: zones["main"].orDie().physicalMonitor,
            leftZoneId: "main",
            rightZoneId: "right",
            deltaPixels: 120,
        ).getOrNil())

        XCTAssertEqual(result.appliedDeltaPixels, 120, accuracy: 0.0001)
        XCTAssertEqual(zoneWidthsByPhysicalZone(), [
            "1:left": 300,
            "1:main": 720,
            "1:right": 180,
        ])
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.zoneId == "left" }.orDie().activeWorkspace === reference)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.zoneId == "main" }.orDie().activeWorkspace === work)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.zoneId == "right" }.orDie().activeWorkspace === comms)
        XCTAssertTrue(workWindow.nodeWorkspace === work)
        XCTAssertTrue(commsWindow.nodeWorkspace === comms)
    }

    func testZoneDividerAmbientClickDoesNotStartInsideKnownWindowFrame() {
        let zones = configureThreeZones()
        config.mouse.zoneDividerDrag = .always
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        TestWindow.new(
            id: 451,
            parent: work.rootTilingContainer,
            rect: Rect(topLeftX: 880, topLeftY: 100, width: 80, height: 200),
        )
        let controller = ZoneDividerDragController.shared
        controller.cancel()

        XCTAssertNotNil(zoneDividerHandle(at: CGPoint(x: 900, y: 150), hitSlop: 16))
        XCTAssertFalse(controller.handleMouseDown(at: CGPoint(x: 900, y: 150)))
        XCTAssertFalse(controller.isDragging)

        XCTAssertTrue(controller.handleMouseDown(at: CGPoint(x: 900, y: 20)))
        XCTAssertTrue(controller.isDragging)
        controller.cancel()
    }

    func testZoneDividerAmbientClickUsesLiveFrameBeforeVetoingStaleCachedFrame() {
        let zones = configureThreeZones()
        config.mouse.zoneDividerDrag = .always
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        let window = TestWindow.new(
            id: 454,
            parent: work.rootTilingContainer,
            rect: Rect(topLeftX: 100, topLeftY: 100, width: 80, height: 80),
        )
        window.lastKnownActualRect = Rect(topLeftX: 100, topLeftY: 100, width: 80, height: 80)
        window.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 880, topLeftY: 100, width: 80, height: 200)
        let controller = ZoneDividerDragController.shared
        controller.cancel()

        XCTAssertNotNil(zoneDividerHandle(at: CGPoint(x: 900, y: 150), hitSlop: 16))
        XCTAssertTrue(controller.handleMouseDown(at: CGPoint(x: 900, y: 150)))
        XCTAssertTrue(controller.isDragging)
        controller.cancel()
    }

    func testZoneDividerChromeCanStartInsideFullHeightTiledWindowFrame() {
        let zones = configureThreeZones()
        config.mouse.zoneDividerDrag = .always
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        TestWindow.new(
            id: 453,
            parent: work.rootTilingContainer,
            rect: Rect(topLeftX: 300, topLeftY: 0, width: 620, height: 800),
        )
        let controller = ZoneDividerDragController.shared
        controller.cancel()

        XCTAssertNotNil(zoneDividerHandle(at: CGPoint(x: 900, y: 400), hitSlop: 16))
        XCTAssertFalse(controller.handleMouseDown(at: CGPoint(x: 900, y: 400)))
        XCTAssertFalse(controller.isDragging)

        XCTAssertTrue(controller.handleMouseDown(
            at: CGPoint(x: 900, y: 400),
            source: .dividerChrome,
        ))
        XCTAssertTrue(controller.isDragging)
        controller.cancel()
    }

    func testParseZoneExposeCommand() {
        XCTAssertTrue(parseCommand("zone-expose display").cmdOrNil is ZoneExposeCommand)
        XCTAssertTrue(parseCommand("zone-expose zone").cmdOrNil is ZoneExposeCommand)
        XCTAssertNil(parseCommand("zone-expose").cmdOrNil)
        XCTAssertNil(parseCommand("zone-expose everything").cmdOrNil)
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
        config.mouse.zoneDividerDrag = .always
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        // rect: nil leaves currentFrameForHitTesting() nil, like a real MacWindow, so the veto
        // falls through to the snapshot lookup.
        let window = TestWindow.new(id: 462, parent: work.rootTilingContainer, rect: nil)
        window.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 880, topLeftY: 100, width: 80, height: 200)
        let controller = ZoneDividerDragController.shared
        controller.cancel()
        let dividerPoint = CGPoint(x: 900, y: 150)
        XCTAssertNotNil(zoneDividerHandle(at: dividerPoint, hitSlop: 16))

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
        let controller = ZoneDividerDragController.shared
        controller.cancel()
        let dividerPoint = CGPoint(x: 900, y: 20)
        XCTAssertNotNil(zoneDividerHandle(at: dividerPoint, hitSlop: 16))

        let previousMode = activeMode
        defer { activeMode = previousMode }

        activeMode = mainModeId
        XCTAssertFalse(controller.updateHover(at: dividerPoint))
        XCTAssertFalse(controller.handleMouseDown(at: dividerPoint))
        XCTAssertFalse(controller.handleMouseDown(at: dividerPoint, source: .dividerChrome))
        XCTAssertFalse(controller.isDragging)

        activeMode = "zone"
        XCTAssertTrue(controller.handleMouseDown(at: dividerPoint))
        XCTAssertTrue(controller.isDragging)
        controller.cancel()
    }

    func testZoneDividerChromeHitBandMatchesAdvertisedHitSlop() {
        XCTAssertEqual(zoneDividerVisibleBandWidth(for: .hover), 8)
        XCTAssertEqual(zoneDividerVisibleBandWidth(for: .dragging), 14)
        XCTAssertEqual(zoneDividerVisibleBandWidth(for: .committed), 14)
        XCTAssertEqual(zoneDividerChromeHitBandWidth(for: .hover), 32)
        XCTAssertEqual(zoneDividerChromeHitBandWidth(for: .dragging), 32)
        XCTAssertEqual(zoneDividerChromeHitBandWidth(for: .committed), 0)
    }

    func testZoneDividerHitPanelOnlyClaimsLeftDragEvents() {
        XCTAssertTrue(zoneDividerHitPanelHandlesEvent(type: .leftMouseDown, buttonNumber: 0))
        XCTAssertTrue(zoneDividerHitPanelHandlesEvent(type: .leftMouseDragged, buttonNumber: 0))
        XCTAssertTrue(zoneDividerHitPanelHandlesEvent(type: .leftMouseUp, buttonNumber: 0))
        XCTAssertFalse(zoneDividerHitPanelHandlesEvent(type: .rightMouseDown, buttonNumber: 1))
        XCTAssertFalse(zoneDividerHitPanelHandlesEvent(type: .scrollWheel, buttonNumber: 0))
        XCTAssertFalse(zoneDividerHitPanelHandlesEvent(type: .otherMouseDown, buttonNumber: 2))
    }

    func testZoneDividerDragIgnoresStaleFramesFromInactiveWorkspaces() {
        _ = configureThreeZones()
        config.mouse.zoneDividerDrag = .always
        let inactiveWorkspace = Workspace.get(byName: "inactive-with-stale-frame")
        TestWindow.new(
            id: 452,
            parent: inactiveWorkspace.rootTilingContainer,
            rect: Rect(topLeftX: 880, topLeftY: 100, width: 80, height: 200),
        )
        XCTAssertFalse(inactiveWorkspace.isVisible)
        let controller = ZoneDividerDragController.shared
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

        let moveToMain = try await parseCommand("move-workspace-to-monitor next").cmdOrDie
            .run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(moveToMain.exitCode, 0)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.zoneId == "main" }.orDie().activeWorkspace === assigned)

        let moveToRight = try await parseCommand("move-workspace-to-monitor next").cmdOrDie
            .run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(moveToRight.exitCode, 0)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.zoneId == "right" }.orDie().activeWorkspace === assigned)
    }

    func testPatternMoveWorkspaceToMonitorNoopsWhenWorkspaceIsInAnotherZoneOnSamePhysicalMonitor() async throws {
        let zones = configureThreeZones()
        let assigned = Workspace.get(byName: "assigned-to-display-one")
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(assigned))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(assigned.focusWorkspace())

        let result = try await parseCommand("move-workspace-to-monitor 1").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(zones["left"].orDie().activeWorkspace === assigned)
        XCTAssertTrue(zones["main"].orDie().activeWorkspace === work)
    }

    func testMoveZoneDividerClampsAtMinimumShare() async throws {
        let zones = configureThreeZones()

        let result = try XCTUnwrap(moveZoneDivider(
            on: zones["main"].orDie().physicalMonitor,
            leftZoneId: "main",
            rightZoneId: "right",
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

        let disable = try await parseCommand("disable-zone Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disable.exitCode, 0)

        let handles = zoneDividerHandles(hitSlop: 12)
        XCTAssertEqual(handles.map { "\($0.leftZoneId)|\($0.rightZoneId)" }, ["left|main"])
        XCTAssertNil(zoneDividerHandle(at: CGPoint(x: 900, y: 10), hitSlop: 12))

        switch moveZoneDivider(
            on: zones["main"].orDie().physicalMonitor,
            leftZoneId: "main",
            rightZoneId: "right",
            deltaPixels: 120,
        ) {
            case .success:
                XCTFail("Expected disabled right zone to reject divider movement")
            case .failure(let message):
                XCTAssertTrue(message.contains("not adjacent enabled zones"))
        }
    }

    func testMoveZoneDividerOnlyAffectsSelectedPhysicalMonitorAndActiveLayout() async throws {
        let zones = configureDuplicateZoneLayoutPresets()

        let result = try XCTUnwrap(moveZoneDivider(
            on: zones["2:left"].orDie().physicalMonitor,
            leftZoneId: "left",
            rightZoneId: "main",
            deltaPixels: 100,
        ).getOrNil())

        XCTAssertEqual(result.appliedDeltaPixels, 100, accuracy: 0.0001)
        XCTAssertEqual(zoneWidthsByPhysicalZone(), [
            "1:left": 500,
            "1:main": 500,
            "2:left": 600,
            "2:main": 400,
        ])

        switch setActiveZoneLayout("focus", for: zones["2:left"].orDie().physicalMonitor) {
            case .success: break
            case .failure(let message): XCTFail(message)
        }
        XCTAssertEqual(zoneWidthsByPhysicalZone(), [
            "1:left": 500,
            "1:main": 500,
            "2:left": 300,
            "2:main": 700,
        ])

        switch setActiveZoneLayout("balanced", for: zones["2:left"].orDie().physicalMonitor) {
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

        let targetTooSmall = try await parseCommand("resize-zone Work width -46%").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(targetTooSmall.exitCode, 1)
        XCTAssertTrue(targetTooSmall.stderr.joined(separator: "\n").contains("below 5%"))
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [300, 600, 300])

        let siblingsTooSmall = try await parseCommand("resize-zone Work width 95%").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(siblingsTooSmall.exitCode, 1)
        XCTAssertTrue(siblingsTooSmall.stderr.joined(separator: "\n").contains("sibling zones would fall below 5%"))
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [300, 600, 300])
    }

    func testSetZoneStyleAppliesConfiguredStyleToListZonesAndSidebarTarget() async throws {
        let zones = configureThreeZonesWithStyles()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        XCTAssertTrue(work.focusWorkspace())

        let result = try await parseCommand("set-zone-style Comms urgent").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, ["Styled zone 'Comms' on monitor 1 as 'urgent'"])
        XCTAssertEqual(sortedMonitors.singleOrNil { $0.zoneId == "right" }?.zoneStyleId, "urgent")
        XCTAssertEqual(sortedMonitors.singleOrNil { $0.zoneId == "right" }?.zoneStyleColorHex, "#D3455B")

        let list = try await parseCommand(
            "list-zones --format '%{monitor-zone-id}|%{monitor-zone-style-id}|%{monitor-zone-style-color}|%{monitor-active-workspace}'",
        ).cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(list.exitCode, 0)
        XCTAssertTrue(list.stdout.contains("right|urgent|#D3455B|comms"))
        XCTAssertTrue(list.stdout.contains("main|||work"))

        let targets = buildWorkspaceSidebarZoneTargetViewModels(
            sortedMonitors: sortedMonitors,
            currentFocus: focus,
        )
        let commsTarget = try XCTUnwrap(targets.singleOrNil { $0.zoneId == "right" })
        XCTAssertEqual(commsTarget.styleId, "urgent")
        XCTAssertEqual(commsTarget.styleColorHex, "#D3455B")
    }

    func testSetZoneStyleRejectsUnknownStyleAndDisabledZone() async throws {
        _ = configureThreeZonesWithStyles()

        let unknown = try await parseCommand("set-zone-style Comms missing").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(unknown.exitCode, 1)
        XCTAssertTrue(unknown.stderr.joined(separator: "\n").contains("Unknown zone style 'missing'"))
        XCTAssertNil(sortedMonitors.singleOrNil { $0.zoneId == "right" }?.zoneStyleId)

        let disable = try await parseCommand("disable-zone Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disable.exitCode, 0)

        let disabled = try await parseCommand("set-zone-style Comms urgent").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disabled.exitCode, 1)
        XCTAssertTrue(disabled.stderr.joined(separator: "\n").contains("Zone 'Comms' is disabled"))
    }

    func testCycleZoneStyleCyclesConfiguredStylesAndWraps() async throws {
        let zones = configureThreeZonesWithStyles()
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))

        let urgent = try await parseCommand("cycle-zone-style Comms urgent calm").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(urgent.exitCode, 0)
        XCTAssertEqual(urgent.stdout, ["Styled zone 'Comms' on monitor 1 as 'urgent'"])
        XCTAssertEqual(sortedMonitors.singleOrNil { $0.zoneId == "right" }?.zoneStyleId, "urgent")

        let calm = try await parseCommand("cycle-zone-style Comms urgent calm").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(calm.exitCode, 0)
        XCTAssertEqual(calm.stdout, ["Styled zone 'Comms' on monitor 1 as 'calm'"])
        XCTAssertEqual(sortedMonitors.singleOrNil { $0.zoneId == "right" }?.zoneStyleId, "calm")
        XCTAssertEqual(sortedMonitors.singleOrNil { $0.zoneId == "right" }?.zoneStyleColorHex, "#3EA2FF")

        let wrapped = try await parseCommand("cycle-zone-style Comms urgent calm").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(wrapped.exitCode, 0)
        XCTAssertEqual(wrapped.stdout, ["Styled zone 'Comms' on monitor 1 as 'urgent'"])
        XCTAssertEqual(sortedMonitors.singleOrNil { $0.zoneId == "right" }?.zoneStyleId, "urgent")
    }

    func testCycleZoneStyleRejectsDuplicateUnknownAndDisabledTargets() async throws {
        _ = configureThreeZonesWithStyles()

        let duplicate = try await parseCommand("cycle-zone-style Comms urgent urgent").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(duplicate.exitCode, 1)
        XCTAssertTrue(duplicate.stderr.joined(separator: "\n").contains("cycle-zone-style requires unique style ids: urgent"))

        let unknown = try await parseCommand("cycle-zone-style Comms urgent missing").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(unknown.exitCode, 1)
        XCTAssertTrue(unknown.stderr.joined(separator: "\n").contains("Unknown zone style 'missing'"))

        let disable = try await parseCommand("disable-zone Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disable.exitCode, 0)

        let disabled = try await parseCommand("cycle-zone-style Comms urgent calm").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disabled.exitCode, 1)
        XCTAssertTrue(disabled.stderr.joined(separator: "\n").contains("Zone 'Comms' is disabled"))
    }

    func testCycleZoneStyleUsesFirstStyleWhenCurrentStyleIsOutsideCycle() async throws {
        let zones = configureThreeZones()
        config.zoneStyles = [
            ZoneStyleConfig(id: "urgent", color: "#D3455B"),
            ZoneStyleConfig(id: "calm", color: "#3EA2FF"),
            ZoneStyleConfig(id: "muted", color: "#8A8F98"),
        ]
        refreshZoneTopologySnapshot()
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))

        let muted = try await parseCommand("set-zone-style Comms muted").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(muted.exitCode, 0)
        XCTAssertEqual(sortedMonitors.singleOrNil { $0.zoneId == "right" }?.zoneStyleId, "muted")

        let result = try await parseCommand("cycle-zone-style Comms urgent calm").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, ["Styled zone 'Comms' on monitor 1 as 'urgent'"])
        XCTAssertEqual(sortedMonitors.singleOrNil { $0.zoneId == "right" }?.zoneStyleId, "urgent")
        XCTAssertEqual(sortedMonitors.singleOrNil { $0.zoneId == "right" }?.zoneStyleColorHex, "#D3455B")
    }

    func testCycleZoneStyleRequiresUnambiguousPhysicalScope() async throws {
        let zones = configureDuplicateZones()
        config.zoneStyles = [
            ZoneStyleConfig(id: "urgent", color: "#D3455B"),
            ZoneStyleConfig(id: "calm", color: "#3EA2FF"),
        ]
        refreshZoneTopologySnapshot()
        let primaryLeft = Workspace.get(byName: "primary-left")
        let primaryMain = Workspace.get(byName: "primary-main")
        let secondaryLeft = Workspace.get(byName: "secondary-left")
        let secondaryMain = Workspace.get(byName: "secondary-main")
        XCTAssertTrue(zones["1:left"].orDie().setActiveWorkspace(primaryLeft))
        XCTAssertTrue(zones["1:main"].orDie().setActiveWorkspace(primaryMain))
        XCTAssertTrue(zones["2:left"].orDie().setActiveWorkspace(secondaryLeft))
        XCTAssertTrue(zones["2:main"].orDie().setActiveWorkspace(secondaryMain))
        XCTAssertTrue(secondaryLeft.focusWorkspace())

        let ambiguous = try await parseCommand("cycle-zone-style left urgent calm").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(ambiguous.exitCode, 1)
        XCTAssertTrue(ambiguous.stderr.joined(separator: "\n").contains("ambiguous"))
        XCTAssertEqual(zoneStyleIdsByPhysicalZone(), [:])

        let scoped = try await parseCommand("cycle-zone-style --monitor 2 current urgent calm").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(scoped.exitCode, 0, scoped.stderr.joined(separator: "\n"))
        XCTAssertEqual(scoped.stdout, ["Styled zone 'Reference' on monitor 2 as 'urgent'"])
        XCTAssertEqual(zoneStyleIdsByPhysicalZone(), ["2:left": "urgent"])

        let overspecified = try await parseCommand("cycle-zone-style --monitor 2 1:left urgent calm").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(overspecified.exitCode, 1)
        XCTAssertTrue(overspecified.stderr.joined(separator: "\n").contains("Use either --monitor or a physical monitor qualifier"))
        XCTAssertEqual(zoneStyleIdsByPhysicalZone(), ["2:left": "urgent"])
    }

    func testSetZoneStyleRequiresUnambiguousPhysicalScope() async throws {
        let zones = configureDuplicateZones()
        config.zoneStyles = [ZoneStyleConfig(id: "urgent", color: "#D3455B")]
        let primaryLeft = Workspace.get(byName: "primary-left")
        let primaryMain = Workspace.get(byName: "primary-main")
        let secondaryLeft = Workspace.get(byName: "secondary-left")
        let secondaryMain = Workspace.get(byName: "secondary-main")
        XCTAssertTrue(zones["1:left"].orDie().setActiveWorkspace(primaryLeft))
        XCTAssertTrue(zones["1:main"].orDie().setActiveWorkspace(primaryMain))
        XCTAssertTrue(zones["2:left"].orDie().setActiveWorkspace(secondaryLeft))
        XCTAssertTrue(zones["2:main"].orDie().setActiveWorkspace(secondaryMain))
        XCTAssertTrue(secondaryLeft.focusWorkspace())

        let ambiguous = try await parseCommand("set-zone-style left urgent").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(ambiguous.exitCode, 1)
        XCTAssertTrue(ambiguous.stderr.joined(separator: "\n").contains("ambiguous"))
        XCTAssertEqual(zoneStyleIdsByPhysicalZone(), [:])

        let scoped = try await parseCommand("set-zone-style --monitor 2 current urgent").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(scoped.exitCode, 0, scoped.stderr.joined(separator: "\n"))
        XCTAssertEqual(scoped.stdout, ["Styled zone 'Reference' on monitor 2 as 'urgent'"])
        XCTAssertEqual(zoneStyleIdsByPhysicalZone(), ["2:left": "urgent"])

        let overspecified = try await parseCommand("set-zone-style --monitor 2 1:left urgent").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(overspecified.exitCode, 1)
        XCTAssertTrue(overspecified.stderr.joined(separator: "\n").contains("Use either --monitor or a physical monitor qualifier"))
        XCTAssertEqual(zoneStyleIdsByPhysicalZone(), ["2:left": "urgent"])
    }

    func testSetZoneSnapPolicyOverridesConfigForFocusedMonitor() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(work.focusWorkspace())
        config.mouse.zoneSnap.policy = .freeform
        config.mouse.zoneSnap.modifier = [.option, .shift]
        config.mouse.zoneSnap.gesture = .drag
        config.mouse.zoneSnap.target = .zone

        let result = try await parseCommand("set-zone-snap-policy snap-to-zone").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, ["Using zone snap policy 'snap-to-zone' on monitor 1"])
        XCTAssertEqual(config.mouse.zoneSnap.policy, .freeform)
        let effective = effectiveZoneSnapConfig(for: zones["right"].orDie())
        XCTAssertEqual(effective.policy, .snapToZone)
        XCTAssertEqual(effective.modifier, [.option, .shift])
        XCTAssertEqual(effective.gesture, .drag)
        XCTAssertEqual(effective.target, .zone)
    }

    func testCycleZoneSnapPolicyCyclesAndWraps() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(work.focusWorkspace())
        config.mouse.zoneSnap.policy = .freeform

        let snap = try await parseCommand("cycle-zone-snap-policy freeform snap-to-zone").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(snap.exitCode, 0)
        XCTAssertEqual(snap.stdout, ["Using zone snap policy 'snap-to-zone' on monitor 1"])
        XCTAssertEqual(effectiveZoneSnapConfig(for: zones["left"].orDie()).policy, .snapToZone)

        let freeform = try await parseCommand("cycle-zone-snap-policy freeform snap-to-zone").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(freeform.exitCode, 0)
        XCTAssertEqual(freeform.stdout, ["Using zone snap policy 'freeform' on monitor 1"])
        XCTAssertEqual(effectiveZoneSnapConfig(for: zones["left"].orDie()).policy, .freeform)
    }

    func testCycleZoneSnapPolicyStartsAtFirstPolicyWhenCurrentPolicyIsOutsideCycle() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(work.focusWorkspace())
        config.mouse.zoneSnap.policy = .floatUnlessSnap

        let result = try await parseCommand("cycle-zone-snap-policy freeform snap-to-zone").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, ["Using zone snap policy 'freeform' on monitor 1"])
        XCTAssertEqual(effectiveZoneSnapConfig(for: zones["left"].orDie()).policy, .freeform)
    }

    func testZoneSnapPolicyRejectsUnknownDuplicateAndUnzonedMonitor() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(work.focusWorkspace())

        let unknown = try await parseCommand("set-zone-snap-policy snap-to-window").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(unknown.exitCode, 1)
        XCTAssertTrue(unknown.stderr.joined(separator: "\n").contains("Unknown zone snap policy 'snap-to-window'"))

        let duplicate = try await parseCommand("cycle-zone-snap-policy freeform freeform").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(duplicate.exitCode, 1)
        XCTAssertTrue(duplicate.stderr.joined(separator: "\n").contains("cycle-zone-snap-policy requires unique policies: freeform"))

        configureNoZones()
        let noZones = try await parseCommand("set-zone-snap-policy snap-to-zone").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(noZones.exitCode, 1)
        XCTAssertTrue(noZones.stderr.joined(separator: "\n").contains("No zone config targets monitor 1"))
    }

    func testZoneSnapPolicyIsScopedByPhysicalMonitor() async throws {
        let zones = configureDuplicateZones()
        let secondaryMain = Workspace.get(byName: "secondary-main")
        XCTAssertTrue(zones["2:main"].orDie().setActiveWorkspace(secondaryMain))
        XCTAssertTrue(secondaryMain.focusWorkspace())
        config.mouse.zoneSnap.policy = .freeform

        let secondary = try await parseCommand("set-zone-snap-policy --monitor 2 snap-to-zone").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(secondary.exitCode, 0, secondary.stderr.joined(separator: "\n"))
        XCTAssertEqual(secondary.stdout, ["Using zone snap policy 'snap-to-zone' on monitor 2"])
        XCTAssertEqual(effectiveZoneSnapConfig(for: zones["1:left"].orDie()).policy, .freeform)
        XCTAssertEqual(effectiveZoneSnapConfig(for: zones["2:left"].orDie()).policy, .snapToZone)

        let primary = try await parseCommand("set-zone-snap-policy --monitor 1 float-unless-snap").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(primary.exitCode, 0, primary.stderr.joined(separator: "\n"))
        XCTAssertEqual(primary.stdout, ["Using zone snap policy 'float-unless-snap' on monitor 1"])
        XCTAssertEqual(effectiveZoneSnapConfig(for: zones["1:left"].orDie()).policy, .floatUnlessSnap)
        XCTAssertEqual(effectiveZoneSnapConfig(for: zones["2:left"].orDie()).policy, .snapToZone)
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

        let disableResult = try await parseCommand("disable-zone Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(disableResult.exitCode, 0)
        XCTAssertEqual(disableResult.stdout, ["Disabled zone 'Comms' on monitor 1"])
        XCTAssertEqual(sortedMonitors.map(\.zoneId), ["left", "main"])
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [400, 800])
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.zoneId == "left" }.orDie().activeWorkspace === reference)
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.zoneId == "main" }.orDie().activeWorkspace === work)
        XCTAssertFalse(comms.isVisible)
        XCTAssertTrue(focus.workspace !== comms)

        let enableResult = try await parseCommand("enable-zone Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(enableResult.exitCode, 0)
        XCTAssertEqual(enableResult.stdout, ["Enabled zone 'Comms' on monitor 1"])
        XCTAssertEqual(sortedMonitors.map(\.zoneId), ["left", "main", "right"])
        XCTAssertTrue(sortedMonitors.singleOrNil { $0.zoneId == "right" }.orDie().activeWorkspace === comms)
    }

    func testDisabledZoneCannotBeFocusedOrMovedTo() async throws {
        let zones = configureThreeZones()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let window = TestWindow.new(id: 71, parent: work.rootTilingContainer)
        XCTAssertTrue(window.focusWindow())

        let disableResult = try await parseCommand("disable-zone Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disableResult.exitCode, 0)

        let focusResult = try await parseCommand("focus-zone Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(focusResult.exitCode, 1)
        XCTAssertTrue(focusResult.stderr.joined(separator: "\n").contains("Zone 'Comms' is disabled"))

        let moveResult = try await parseCommand("move-node-to-zone Comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(moveResult.exitCode, 1)
        XCTAssertTrue(moveResult.stderr.joined(separator: "\n").contains("Zone 'Comms' is disabled"))
        XCTAssertTrue(window.nodeWorkspace === work)
    }

    func testDisableZoneRejectsLastEnabledZone() async throws {
        _ = configureThreeZones()

        let disableLeft = try await parseCommand("disable-zone left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disableLeft.exitCode, 0)
        let disableMain = try await parseCommand("disable-zone main").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disableMain.exitCode, 0)

        let result = try await parseCommand("disable-zone right").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.stderr.joined(separator: "\n").contains("at least one zone must stay enabled"))
        XCTAssertEqual(sortedMonitors.map(\.zoneId), ["right"])
    }

    func testZoneAvailabilityCommandsUseConfiguredZoneSelectorForDisabledZones() async throws {
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

        let ambiguous = try await parseCommand("disable-zone left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(ambiguous.exitCode, 1)
        XCTAssertTrue(ambiguous.stderr.joined(separator: "\n").contains("ambiguous"))

        let disable = try await parseCommand("disable-zone --monitor 2 current").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disable.exitCode, 0, disable.stderr.joined(separator: "\n"))
        XCTAssertEqual(sortedMonitors.compactMap { monitor -> String? in
            guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
                  let zoneId = monitor.zoneId
            else { return nil }
            return "\(physicalId):\(zoneId)"
        }, ["1:left", "1:main", "2:main"])

        XCTAssertTrue(secondaryMain.focusWorkspace())
        let enable = try await parseCommand("enable-zone --monitor 2 prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(enable.exitCode, 0)
        XCTAssertEqual(sortedMonitors.compactMap { monitor -> String? in
            guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
                  let zoneId = monitor.zoneId
            else { return nil }
            return "\(physicalId):\(zoneId)"
        }, ["1:left", "1:main", "2:left", "2:main"])
        XCTAssertEqual(zoneActiveWorkspacesByPhysicalZone(), [
            "1:left": "primary-left",
            "1:main": "primary-main",
            "2:left": "secondary-left",
            "2:main": "secondary-main",
        ])

        XCTAssertTrue(focus.workspace === secondaryMain)
        let toggle = try await parseCommand("toggle-zone --monitor 2 prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(toggle.exitCode, 0)
        XCTAssertEqual(sortedMonitors.compactMap { monitor -> String? in
            guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
                  let zoneId = monitor.zoneId
            else { return nil }
            return "\(physicalId):\(zoneId)"
        }, ["1:left", "1:main", "2:main"])
    }

    func testZoneCommandsFailWhenNoZonesAreConfigured() async throws {
        configureNoZones()
        let workspace = Workspace.get(byName: "work")
        let window = TestWindow.new(id: 61, parent: workspace.rootTilingContainer)
        XCTAssertTrue(window.focusWindow())

        let focusResult = try await FocusZoneCommand(args: FocusZoneCmdArgs(zone: ZoneSelector("left")))
            .run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(focusResult.exitCode, 1)
        XCTAssertTrue(focusResult.stderr.joined(separator: "\n").contains("No zones are configured"))

        let moveResult = try await MoveNodeToZoneCommand(args: MoveNodeToZoneCmdArgs(zone: ZoneSelector("left")))
            .run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(moveResult.exitCode, 1)
        XCTAssertTrue(moveResult.stderr.joined(separator: "\n").contains("No zones are configured"))
    }
}

@MainActor
private func configureZoneScenes() -> [String: Monitor] {
    configureZoneLayoutPresets()
    config.zoneScenes = [
        ZoneSceneConfig(
            id: "triage",
            layoutPreset: "balanced",
            workspaces: [
                ZoneSceneWorkspaceConfig(zone: "left", workspace: WorkspaceName.parse("TriageInbox").getOrDie()),
                ZoneSceneWorkspaceConfig(zone: "main", workspace: WorkspaceName.parse("TriageDraft").getOrDie()),
                ZoneSceneWorkspaceConfig(zone: "right", workspace: WorkspaceName.parse("TriageUpdates").getOrDie()),
            ],
        ),
        ZoneSceneConfig(
            id: "deep-work",
            layoutPreset: "focus",
            workspaces: [
                ZoneSceneWorkspaceConfig(zone: "left", workspace: WorkspaceName.parse("FocusQueue").getOrDie()),
                ZoneSceneWorkspaceConfig(zone: "main", workspace: WorkspaceName.parse("FocusBuild").getOrDie()),
                ZoneSceneWorkspaceConfig(zone: "right", workspace: WorkspaceName.parse("FocusNotes").getOrDie()),
            ],
        ),
    ]
    return Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.zoneId.map { ($0, monitor) }
    })
}

@MainActor
private func activeWorkspaceNamesByZone() -> [String: String] {
    Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.zoneId.map { ($0, monitor.activeWorkspace.name) }
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
                MoveNodeToZoneCommand(args: MoveNodeToZoneCmdArgs(zone: ZoneSelector("Comms")).copy(\.failIfNoop, true)),
            ],
        ),
    ]
}

@MainActor
private func configureRouteCommsAffinity(checkFurtherCallbacks: Bool = false, failIfNoop: Bool = false) {
    var errors: [String] = []
    let regex = parseCaseInsensitiveRegex("mail-inbox").getOrNil(appendErrorTo: &errors).orDie()
    XCTAssertEqual(errors, [])
    config.zoneAffinities = [
        ZoneAffinityConfig(
            matcher: WindowDetectedCallbackMatcher(windowTitleRegexSubstring: regex),
            zone: ZoneSelector("Comms"),
            checkFurtherCallbacks: checkFurtherCallbacks,
            failIfNoop: failIfNoop,
        ),
    ]
}

@MainActor
private func configureRouteReferenceCallback() {
    config.onWindowDetected = [
        WindowDetectedCallback(
            rawRun: [
                MoveNodeToZoneCommand(args: MoveNodeToZoneCmdArgs(zone: ZoneSelector("Reference")).copy(\.failIfNoop, true)),
            ],
        ),
    ]
}

@MainActor
private func configureZoneLayoutPresets() {
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
    config.zoneLayouts = [
        ZoneLayoutConfig(
            id: "balanced",
            layout: .columns,
            defaultZone: "main",
            columns: [
                ZoneColumnConfig(id: "left", name: "Reference", width: 0.25),
                ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
                ZoneColumnConfig(id: "right", name: "Comms", width: 0.25),
            ],
        ),
        ZoneLayoutConfig(
            id: "focus",
            layout: .columns,
            defaultZone: "main",
            columns: [
                ZoneColumnConfig(id: "left", name: "Reference", width: 0.15),
                ZoneColumnConfig(id: "main", name: "Work", width: 0.70),
                ZoneColumnConfig(id: "right", name: "Comms", width: 0.15),
            ],
        ),
    ]
    config.zones = [
        ZoneConfig(
            monitor: .sequenceNumber(1),
            layoutPreset: "balanced",
        ),
    ]
}

@MainActor
private func configureInlineZonesWithLayoutPresets() {
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
    config.zoneLayouts = [
        ZoneLayoutConfig(
            id: "focus",
            layout: .columns,
            defaultZone: "main",
            columns: [
                ZoneColumnConfig(id: "left", name: "Reference", width: 0.15),
                ZoneColumnConfig(id: "main", name: "Work", width: 0.70),
                ZoneColumnConfig(id: "right", name: "Comms", width: 0.15),
            ],
        ),
    ]
    config.zones = [
        ZoneConfig(
            monitor: .sequenceNumber(1),
            layout: .columns,
            defaultZone: "main",
            columns: [
                ZoneColumnConfig(id: "left", name: "Reference", width: 0.25),
                ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
                ZoneColumnConfig(id: "right", name: "Comms", width: 0.25),
            ],
        ),
    ]
}

@MainActor
private func configureThreeZones(
    defaultZone: String = "main",
    columns: [ZoneColumnConfig]? = nil,
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
        ZoneConfig(
            monitor: .sequenceNumber(1),
            layout: .columns,
            defaultZone: defaultZone,
            columns: columns ?? [
                ZoneColumnConfig(id: "left", name: "Reference", width: 0.25),
                ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
                ZoneColumnConfig(id: "right", name: "Comms", width: 0.25),
            ],
        ),
    ]
    return Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.zoneId.map { ($0, monitor) }
    })
}

@MainActor
private func configureThreeZonesWithStyles() -> [String: Monitor] {
    let zones = configureThreeZones()
    config.zoneStyles = [
        ZoneStyleConfig(id: "urgent", color: "#D3455B"),
        ZoneStyleConfig(id: "calm", color: "#3EA2FF"),
    ]
    refreshZoneTopologySnapshot()
    return zones
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
        .appending(component: "winmux-save-zone-layout-\(UUID().uuidString)")
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

private func zoneLayoutBackupUrls(for url: URL) throws -> [URL] {
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

private func zoneInitBaseConfigText() -> String {
    """
    # user config stays intact
    enable-normalization-flatten-containers = false

    [mode.main.binding]
    alt-slash = 'layout tiles horizontal vertical'
    """
}

private func zoneLayoutPresetConfigText(missingRightColumnInBalanced: Bool = false) -> String {
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

private func inlineZoneConfigText() -> String {
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
    layout = 'columns'
    default-zone = 'main'
    columns = [
        { id = 'left', name = 'Reference', width = 0.25 },
        { id = 'main', name = 'Work', width = 0.50 },
        { id = 'right', name = 'Comms', width = 0.25 },
    ]
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
    config.zones = [
        duplicateZoneConfig(monitor: .sequenceNumber(1)),
        duplicateZoneConfig(monitor: .sequenceNumber(2)),
    ]
    return Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
              let zoneId = monitor.zoneId
        else { return nil }
        return ("\(physicalId):\(zoneId)", monitor)
    })
}

private func duplicateZoneConfig(monitor: MonitorDescription) -> ZoneConfig {
    ZoneConfig(
        monitor: monitor,
        layout: .columns,
        defaultZone: "main",
        columns: [
            ZoneColumnConfig(id: "left", name: "Reference", width: 0.50),
            ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
        ],
    )
}

@MainActor
@discardableResult
private func configureDuplicateZoneLayoutPresets() -> [String: Monitor] {
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
    config.zoneLayouts = [
        ZoneLayoutConfig(
            id: "balanced",
            layout: .columns,
            defaultZone: "main",
            columns: [
                ZoneColumnConfig(id: "left", name: "Reference", width: 0.50),
                ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
            ],
        ),
        ZoneLayoutConfig(
            id: "focus",
            layout: .columns,
            defaultZone: "main",
            columns: [
                ZoneColumnConfig(id: "left", name: "Reference", width: 0.30),
                ZoneColumnConfig(id: "main", name: "Work", width: 0.70),
            ],
        ),
    ]
    config.zones = [
        ZoneConfig(monitor: .sequenceNumber(1), layoutPreset: "balanced"),
        ZoneConfig(monitor: .sequenceNumber(2), layoutPreset: "balanced"),
    ]
    return Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
              let zoneId = monitor.zoneId
        else { return nil }
        return ("\(physicalId):\(zoneId)", monitor)
    })
}

@MainActor
private func zoneWidthsByPhysicalZone() -> [String: CGFloat] {
    Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
              let zoneId = monitor.zoneId
        else { return nil }
        let width = (monitor.rect.width * 1000).rounded() / 1000
        return ("\(physicalId):\(zoneId)", width)
    })
}

@MainActor
private func zoneLayoutIdsByPhysicalZone() -> [String: String] {
    Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
              let zoneId = monitor.zoneId,
              let zoneLayoutId = monitor.zoneLayoutId
        else { return nil }
        return ("\(physicalId):\(zoneId)", zoneLayoutId)
    })
}

@MainActor
private func zoneStyleIdsByPhysicalZone() -> [String: String] {
    Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
              let zoneId = monitor.zoneId,
              let zoneStyleId = monitor.zoneStyleId
        else { return nil }
        return ("\(physicalId):\(zoneId)", zoneStyleId)
    })
}

@MainActor
private func zoneActiveWorkspacesByPhysicalZone() -> [String: String] {
    Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
              let zoneId = monitor.zoneId
        else { return nil }
        return ("\(physicalId):\(zoneId)", monitor.activeWorkspace.name)
    })
}

@MainActor
private func zoneMonitorsById() -> [String: Monitor] {
    Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.zoneId.map { ($0, monitor) }
    })
}

private struct StructuralZoneState: Equatable {
    let layoutId: String?
    let workspaceName: String
    let left: CGFloat
    let width: CGFloat
    let physicalId: Int?
}

private struct ZoneState: Equatable {
    let layoutId: String?
    let availabilitySetId: String?
    let workspaceName: String
    let left: CGFloat
    let width: CGFloat
    let physicalId: Int?
    let styleId: String?
    let styleColorHex: String?

    var structural: StructuralZoneState {
        StructuralZoneState(
            layoutId: layoutId,
            workspaceName: workspaceName,
            left: left,
            width: width,
            physicalId: physicalId,
        )
    }
}

@MainActor
private func zoneStateByZoneId() -> [String: ZoneState] {
    Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        guard let zoneId = monitor.zoneId else { return nil }
        return (zoneId, ZoneState(
            layoutId: monitor.zoneLayoutId,
            availabilitySetId: monitor.zoneAvailabilitySetId,
            workspaceName: monitor.activeWorkspace.name,
            left: monitor.rect.topLeftX,
            width: monitor.rect.width,
            physicalId: monitor.physicalMonitor.monitorId_oneBased,
            styleId: monitor.zoneStyleId,
            styleColorHex: monitor.zoneStyleColorHex,
        ))
    })
}
