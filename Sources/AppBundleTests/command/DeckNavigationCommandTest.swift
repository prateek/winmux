@testable import AppBundle
import Common
import XCTest

@MainActor
final class DeckNavigationCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    // MARK: workspace next|prev

    func testWorkspaceNextPrevStayWithinFocusedColumnDeck() async throws {
        let zones = configureThreeZones()
        let mainZone = zones["main"].orDie()
        let rightZone = zones["right"].orDie()
        let alpha = Workspace.get(byName: "alpha")
        _ = TestWindow.new(id: 1, parent: alpha.rootTilingContainer)
        XCTAssertTrue(mainZone.setActiveWorkspace(alpha))
        XCTAssertTrue(alpha.focusWorkspace())
        let beta = Workspace.get(byName: "beta")
        _ = TestWindow.new(id: 2, parent: beta.rootTilingContainer)
        let comms = Workspace.get(byName: "comms")
        _ = TestWindow.new(id: 3, parent: comms.rootTilingContainer)
        XCTAssertTrue(rightZone.setActiveWorkspace(comms))

        let next = try await WorkspaceCommand(args: WorkspaceCmdArgs(target: .relative(.next)))
            .run(.defaultEnv, .emptyStdin)
        assertEquals(next.exitCode, 0)
        XCTAssertTrue(focus.workspace === beta)

        let wrapped = try await WorkspaceCommand(args: WorkspaceCmdArgs(target: .relative(.next), wrapAround: true))
            .run(.defaultEnv, .emptyStdin)
        assertEquals(wrapped.exitCode, 0)
        XCTAssertTrue(focus.workspace === alpha, "wrap-around cycles the focused column's deck, not other columns")

        let previous = try await WorkspaceCommand(args: WorkspaceCmdArgs(target: .relative(.prev), wrapAround: true))
            .run(.defaultEnv, .emptyStdin)
        assertEquals(previous.exitCode, 0)
        XCTAssertTrue(focus.workspace === beta)
        XCTAssertTrue(rightZone.activeWorkspace === comms, "the other column's deck is untouched")
    }

    // MARK: workspace <N>

    func testNumericWorkspaceAddressesDeckPosition() async throws {
        let (mainZone, alpha, beta, comms) = try await configureTwoDecks()

        let second = try await WorkspaceCommand(args: WorkspaceCmdArgs(target: .direct(.parse("2").getOrDie())))
            .run(.defaultEnv, .emptyStdin)
        assertEquals(second.exitCode, 0)
        XCTAssertTrue(focus.workspace === beta)
        XCTAssertTrue(mainZone.activeWorkspace === beta)

        let first = try await WorkspaceCommand(args: WorkspaceCmdArgs(target: .direct(.parse("1").getOrDie())))
            .run(.defaultEnv, .emptyStdin)
        assertEquals(first.exitCode, 0)
        XCTAssertTrue(focus.workspace === alpha, "card 1 is the focused column's first card, not another column's")
        XCTAssertFalse(focus.workspace === comms, "the other column's deck is untouched by positional addressing")
    }

    func testNumericWorkspaceAtDeckEdgeCreatesTransientBlankInFocusedColumn() async throws {
        let (mainZone, _, _, _) = try await configureTwoDecks()

        let result = try await WorkspaceCommand(args: WorkspaceCmdArgs(target: .direct(.parse("3").getOrDie())))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertTrue(focus.workspace.isEffectivelyEmpty)
        XCTAssertEqual(
            winMuxWorkspaceState.columnDecks.columnKey(of: focus.workspace.id),
            columnDeckKey(for: mainZone),
        )
        XCTAssertEqual(
            winMuxWorkspaceState.columnDecks.deck(forColumnKey: columnDeckKey(for: mainZone)).last,
            focus.workspace.id,
        )
    }

    func testNumericWorkspaceBeyondDeckEdgeFailsWithoutCreating() async throws {
        _ = try await configureTwoDecks() // focused deck: [alpha, beta] -> the edge is 3
        let workspaceCount = Workspace.all.count

        let result = try await WorkspaceCommand(args: WorkspaceCmdArgs(target: .direct(.parse("4").getOrDie())))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 1)
        XCTAssertEqual(Workspace.all.count, workspaceCount)
    }

    // MARK: summon-workspace

    func testSummonTransfersCardIntoFocusedColumnDeckAndFocuses() async throws {
        let zones = configureThreeZones()
        let mainZone = zones["main"].orDie()
        let rightZone = zones["right"].orDie()
        let alpha = Workspace.get(byName: "alpha")
        _ = TestWindow.new(id: 1, parent: alpha.rootTilingContainer)
        XCTAssertTrue(mainZone.setActiveWorkspace(alpha))
        XCTAssertTrue(alpha.focusWorkspace())
        let comms = Workspace.get(byName: "comms")
        _ = TestWindow.new(id: 2, parent: comms.rootTilingContainer)
        XCTAssertTrue(rightZone.setActiveWorkspace(comms))
        let commsExtra = Workspace.get(byName: "comms-extra")
        _ = TestWindow.new(id: 3, parent: commsExtra.rootTilingContainer)
        winMuxWorkspaceState.columnDecks.adopt(commsExtra.id, into: columnDeckKey(for: rightZone))

        let result = try await parseCommand("summon-workspace comms").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertTrue(focus.workspace === comms, "summon always ends focused")
        XCTAssertTrue(mainZone.activeWorkspace === comms)
        XCTAssertEqual(
            winMuxWorkspaceState.columnDecks.columnKey(of: comms.id),
            columnDeckKey(for: mainZone),
            "summoning is moving: the card changes deck membership",
        )
        XCTAssertTrue(rightZone.activeWorkspace === commsExtra, "the vacated column shows its deck's next card")
    }

    func testPagingAwayAndBackActivatesSummonedCardOnItsCurrentDeckColumn() async throws {
        let (mainZone, rightZone, alpha, comms, commsExtra) = try await summonCommsIntoMainDeck()

        let away = try await WorkspaceCommand(args: WorkspaceCmdArgs(target: .relative(.prev)))
            .run(.defaultEnv, .emptyStdin)
        assertEquals(away.exitCode, 0)
        XCTAssertTrue(focus.workspace === alpha)

        let back = try await WorkspaceCommand(args: WorkspaceCmdArgs(target: .relative(.next)))
            .run(.defaultEnv, .emptyStdin)
        assertEquals(back.exitCode, 0)

        XCTAssertTrue(focus.workspace === comms)
        XCTAssertTrue(mainZone.activeWorkspace === comms, "a hidden card activates on its deck's column, not its creation column")
        XCTAssertEqual(
            winMuxWorkspaceState.columnDecks.columnKey(of: comms.id),
            columnDeckKey(for: mainZone),
            "paging back must not move the card to another deck",
        )
        XCTAssertTrue(rightZone.activeWorkspace === commsExtra, "the creation column's visible card is untouched")
    }

    func testWorkspaceBackAndForthReturnsToSummonedCardOnItsCurrentDeckColumn() async throws {
        let (mainZone, rightZone, alpha, comms, commsExtra) = try await summonCommsIntoMainDeck()
        let away = try await WorkspaceCommand(args: WorkspaceCmdArgs(target: .relative(.prev)))
            .run(.defaultEnv, .emptyStdin)
        assertEquals(away.exitCode, 0)
        XCTAssertTrue(focus.workspace === alpha)

        let result = try await parseCommand("workspace-back-and-forth").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertTrue(focus.workspace === comms)
        XCTAssertTrue(mainZone.activeWorkspace === comms, "back-and-forth returns the card to its deck's column")
        XCTAssertEqual(winMuxWorkspaceState.columnDecks.columnKey(of: comms.id), columnDeckKey(for: mainZone))
        XCTAssertTrue(rightZone.activeWorkspace === commsExtra, "the creation column's visible card is untouched")
    }

    // MARK: move-node-to-workspace next|prev

    func testMoveNodeToWorkspaceNextAtDeckEdgeCreatesBlankInSubjectDeck() async throws {
        let zones = configureThreeZones()
        let mainZone = zones["main"].orDie()
        let rightZone = zones["right"].orDie()
        let alpha = Workspace.get(byName: "alpha")
        alpha.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 31, parent: alpha.rootTilingContainer)
        XCTAssertTrue(mainZone.setActiveWorkspace(alpha))
        XCTAssertTrue(alpha.focusWorkspace())
        let beta = Workspace.get(byName: "beta")
        beta.markAsAutomaticallyNamed()
        let betaWindow = TestWindow.new(id: 32, parent: beta.rootTilingContainer)
        // A blank showing at the tail of ANOTHER column: project-scoped edge creation would
        // see the project's automatic list end in an empty slot and refuse to create.
        let comms = Workspace.get(byName: "comms")
        comms.markAsAutomaticallyNamed()
        XCTAssertTrue(rightZone.setActiveWorkspace(comms))
        _ = betaWindow.focusWindow()

        let result = try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(target: .relative(.next)))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        let target = try XCTUnwrap(betaWindow.nodeWorkspace)
        XCTAssertFalse(target === beta)
        XCTAssertEqual(
            winMuxWorkspaceState.columnDecks.columnKey(of: target.id),
            columnDeckKey(for: mainZone),
            "the blank is created at the edge of the subject's deck",
        )
        XCTAssertEqual(
            winMuxWorkspaceState.columnDecks.deck(forColumnKey: columnDeckKey(for: mainZone)).last,
            target.id,
        )
        XCTAssertTrue(rightZone.activeWorkspace === comms, "the other column's deck is untouched")
    }

    // MARK: move-workspace-to-monitor

    func testMoveWorkspaceToMonitorTransfersDeckAndFocusFollowsToVisibleDestination() async throws {
        let zones = configureThreeZones()
        let mainZone = zones["main"].orDie()
        let rightZone = zones["right"].orDie()
        let alpha = Workspace.get(byName: "alpha")
        _ = TestWindow.new(id: 1, parent: alpha.rootTilingContainer)
        XCTAssertTrue(mainZone.setActiveWorkspace(alpha))
        XCTAssertTrue(alpha.focusWorkspace())
        let beta = Workspace.get(byName: "beta")
        _ = TestWindow.new(id: 2, parent: beta.rootTilingContainer)

        let result = try await parseCommand("move-workspace-to-monitor next").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertTrue(rightZone.activeWorkspace === alpha)
        XCTAssertEqual(
            winMuxWorkspaceState.columnDecks.columnKey(of: alpha.id),
            columnDeckKey(for: rightZone),
            "the moved card transfers to the destination column's deck",
        )
        XCTAssertTrue(focus.workspace === alpha, "focus follows the card to a visible destination")
        XCTAssertTrue(mainZone.activeWorkspace === beta, "the vacated column shows its deck's next card, even an occupied one")
    }

    func testMovingUnfocusedCardLeavesFocusBehindAndVacatedColumnPages() async throws {
        let zones = configureThreeZones()
        let mainZone = zones["main"].orDie()
        let leftZone = zones["left"].orDie()
        let rightZone = zones["right"].orDie()
        let alpha = Workspace.get(byName: "alpha")
        _ = TestWindow.new(id: 1, parent: alpha.rootTilingContainer)
        XCTAssertTrue(mainZone.setActiveWorkspace(alpha))
        XCTAssertTrue(alpha.focusWorkspace())
        let comms = Workspace.get(byName: "comms")
        _ = TestWindow.new(id: 2, parent: comms.rootTilingContainer)
        XCTAssertTrue(rightZone.setActiveWorkspace(comms))
        let commsExtra = Workspace.get(byName: "comms-extra")
        _ = TestWindow.new(id: 3, parent: commsExtra.rootTilingContainer)
        winMuxWorkspaceState.columnDecks.adopt(commsExtra.id, into: columnDeckKey(for: rightZone))

        XCTAssertTrue(activateWorkspaceOnMonitorPreservingSourceViewport(comms, targetMonitor: leftZone))

        XCTAssertTrue(leftZone.activeWorkspace === comms)
        XCTAssertEqual(winMuxWorkspaceState.columnDecks.columnKey(of: comms.id), columnDeckKey(for: leftZone))
        XCTAssertTrue(focus.workspace === alpha, "moving an unfocused card leaves focus where it is")
        XCTAssertTrue(rightZone.activeWorkspace === commsExtra, "the vacated column shows its deck's next card")
    }

    // MARK: fallback synthesis

    func testFallbackWorkspaceIsTheDeckNextCardAfterTheDepartingOne() throws {
        let zones = configureThreeZones()
        let mainZone = zones["main"].orDie()
        let alpha = Workspace.get(byName: "alpha")
        XCTAssertTrue(mainZone.setActiveWorkspace(alpha))
        XCTAssertTrue(alpha.focusWorkspace())
        let beta = Workspace.get(byName: "beta")
        _ = TestWindow.new(id: 1, parent: beta.rootTilingContainer)
        let gamma = Workspace.get(byName: "gamma")
        _ = TestWindow.new(id: 2, parent: gamma.rootTilingContainer)

        XCTAssertTrue(
            getOrCreateFallbackWorkspace(projectId: workspaceProjectDefaultId, monitor: mainZone, excluding: alpha)
                === beta,
        )
        XCTAssertTrue(
            getOrCreateFallbackWorkspace(projectId: workspaceProjectDefaultId, monitor: mainZone, excluding: beta)
                === gamma,
            "the rotation starts after the departing card, not at the deck's head",
        )
        XCTAssertTrue(
            getOrCreateFallbackWorkspace(projectId: workspaceProjectDefaultId, monitor: mainZone, excluding: gamma)
                === alpha,
            "the rotation wraps past the deck's end",
        )
        XCTAssertTrue(
            getOrCreateFallbackWorkspace(projectId: workspaceProjectDefaultId, monitor: mainZone, excluding: nil)
                === alpha,
            "when nothing departs the column keeps its active card",
        )
    }

    func testFallbackWorkspaceForEmptyDeckCreatesBlank() throws {
        let zones = configureThreeZones()
        let leftZone = zones["left"].orDie()

        let fallback = getOrCreateFallbackWorkspace(projectId: workspaceProjectDefaultId, monitor: leftZone, excluding: nil)

        XCTAssertTrue(fallback.isEffectivelyEmpty)
        XCTAssertEqual(fallback.projectId, workspaceProjectDefaultId)
    }

    // MARK: helpers

    /// Main column deck: [alpha (visible, focused), beta (hidden, occupied)].
    /// Right column deck: [comms (visible, occupied)].
    private func configureTwoDecks() async throws -> (mainZone: Monitor, alpha: Workspace, beta: Workspace, comms: Workspace) {
        let zones = configureThreeZones()
        let mainZone = zones["main"].orDie()
        let rightZone = zones["right"].orDie()
        let alpha = Workspace.get(byName: "alpha")
        _ = TestWindow.new(id: 11, parent: alpha.rootTilingContainer)
        XCTAssertTrue(mainZone.setActiveWorkspace(alpha))
        XCTAssertTrue(alpha.focusWorkspace())
        let beta = Workspace.get(byName: "beta")
        _ = TestWindow.new(id: 12, parent: beta.rootTilingContainer)
        let comms = Workspace.get(byName: "comms")
        _ = TestWindow.new(id: 13, parent: comms.rootTilingContainer)
        XCTAssertTrue(rightZone.setActiveWorkspace(comms))
        return (mainZone, alpha, beta, comms)
    }

    /// Creates comms in the right column with the production creation seed
    /// (`createBlankWorkspace` seeds `preferredMonitorPoint` at the birth column), then
    /// summons it into main's deck. The right column shows comms-extra afterwards.
    private func summonCommsIntoMainDeck() async throws -> (mainZone: Monitor, rightZone: Monitor, alpha: Workspace, comms: Workspace, commsExtra: Workspace) {
        let zones = configureThreeZones()
        let mainZone = zones["main"].orDie()
        let rightZone = zones["right"].orDie()
        let alpha = Workspace.get(byName: "alpha")
        _ = TestWindow.new(id: 21, parent: alpha.rootTilingContainer)
        XCTAssertTrue(mainZone.setActiveWorkspace(alpha))
        XCTAssertTrue(alpha.focusWorkspace())
        let comms = Workspace.get(byName: "comms")
        _ = TestWindow.new(id: 22, parent: comms.rootTilingContainer)
        comms.seedMonitorIfNeeded(rightZone)
        XCTAssertTrue(rightZone.setActiveWorkspace(comms))
        let commsExtra = Workspace.get(byName: "comms-extra")
        _ = TestWindow.new(id: 23, parent: commsExtra.rootTilingContainer)
        winMuxWorkspaceState.columnDecks.adopt(commsExtra.id, into: columnDeckKey(for: rightZone))
        let summon = try await parseCommand("summon-workspace comms").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(summon.exitCode, 0)
        XCTAssertTrue(focus.workspace === comms)
        return (mainZone, rightZone, alpha, comms, commsExtra)
    }
}

@MainActor
private func configureThreeZones() -> [String: Monitor] {
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
            defaultZone: "main",
            columns: [
                ZoneColumnConfig(id: "left", name: "Reference", width: 0.25),
                ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
                ZoneColumnConfig(id: "right", name: "Comms", width: 0.25),
            ],
        ),
    ]
    refreshColumnTopologySnapshot()
    return Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.zoneId.map { ($0, monitor) }
    })
}
