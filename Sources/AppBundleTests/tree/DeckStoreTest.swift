@testable import AppBundle
import Common
import XCTest

@MainActor
final class DeckStoreTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    // MARK: Deck keys

    func testImplicitSceneDeckKeyPrefersDisplayNameOverGeometry() {
        XCTAssertEqual(
            implicitSceneDeckKey(displayName: "LG-Ultrawide", physicalTopLeftCorner: CGPoint(x: 0, y: 0)),
            "display-name:LG-Ultrawide",
        )
        XCTAssertEqual(
            implicitSceneDeckKey(displayName: "", physicalTopLeftCorner: CGPoint(x: 1920.0, y: 0.0)),
            "display-geometry:1920.0,0.0",
        )
        XCTAssertEqual(
            columnDeckKey(sceneKey: "display-name:LG-Ultrawide", columnId: "comms"),
            "display-name:LG-Ultrawide/column:comms",
        )
    }

    func testColumnDeckKeyForMonitorUsesZoneIdOrImplicitColumn() {
        let zones = configureThreeColumns()
        let mainZone = zones["main"].orDie()
        XCTAssertEqual(columnDeckKey(for: mainZone), "display-name:Main/column:main")

        configureNoColumns()
        XCTAssertEqual(columnDeckKey(for: mainMonitor), "display-name:Main/column:\(implicitColumnDeckColumnId)")
    }

    // MARK: Deck mutations (pure store)

    func testAdoptAppendsByDefaultAndInsertsAtClampedIndex() {
        var store = ColumnDeckStore()
        store.adopt(WorkspaceId("a"), into: "deck-1")
        store.adopt(WorkspaceId("b"), into: "deck-1")
        store.adopt(WorkspaceId("c"), into: "deck-1", at: 0)
        store.adopt(WorkspaceId("d"), into: "deck-1", at: 99)
        XCTAssertEqual(store.deck(forColumnKey: "deck-1"), ["c", "a", "b", "d"].map { WorkspaceId($0) })
        XCTAssertEqual(store.columnKey(of: WorkspaceId("c")), "deck-1")
        assertDeckPartitionInvariant(store)
    }

    func testAdoptMovesCardOutOfItsPreviousDeck() {
        var store = ColumnDeckStore()
        store.adopt(WorkspaceId("a"), into: "deck-1")
        store.adopt(WorkspaceId("b"), into: "deck-1")
        store.adopt(WorkspaceId("a"), into: "deck-2", at: 0)
        XCTAssertEqual(store.deck(forColumnKey: "deck-1"), [WorkspaceId("b")])
        XCTAssertEqual(store.deck(forColumnKey: "deck-2"), [WorkspaceId("a")])
        XCTAssertEqual(store.columnKey(of: WorkspaceId("a")), "deck-2")
        assertDeckPartitionInvariant(store)
    }

    func testTransferAppendsToTargetDeckAndKeepsOrderWhenAlreadyThere() {
        var store = ColumnDeckStore()
        store.adopt(WorkspaceId("a"), into: "deck-1")
        store.adopt(WorkspaceId("b"), into: "deck-1")
        store.adopt(WorkspaceId("c"), into: "deck-2")

        store.transfer(WorkspaceId("a"), to: "deck-2")
        XCTAssertEqual(store.deck(forColumnKey: "deck-2"), ["c", "a"].map { WorkspaceId($0) })

        store.transfer(WorkspaceId("c"), to: "deck-2")
        XCTAssertEqual(store.deck(forColumnKey: "deck-2"), ["c", "a"].map { WorkspaceId($0) })
        assertDeckPartitionInvariant(store)
    }

    func testReorderMovesCardWithinItsDeckAndClamps() {
        var store = ColumnDeckStore()
        store.adopt(WorkspaceId("a"), into: "deck-1")
        store.adopt(WorkspaceId("b"), into: "deck-1")
        store.adopt(WorkspaceId("c"), into: "deck-1")

        store.reorder(WorkspaceId("c"), to: 0)
        XCTAssertEqual(store.deck(forColumnKey: "deck-1"), ["c", "a", "b"].map { WorkspaceId($0) })

        store.reorder(WorkspaceId("c"), to: 99)
        XCTAssertEqual(store.deck(forColumnKey: "deck-1"), ["a", "b", "c"].map { WorkspaceId($0) })
        assertDeckPartitionInvariant(store)
    }

    func testRemoveDropsCardAndEmptyDeckKey() {
        var store = ColumnDeckStore()
        store.adopt(WorkspaceId("a"), into: "deck-1")
        store.remove(WorkspaceId("a"))
        XCTAssertNil(store.columnKey(of: WorkspaceId("a")))
        XCTAssertNil(store.decksByColumnKey["deck-1"])
        store.remove(WorkspaceId("a")) // idempotent
        assertDeckPartitionInvariant(store)
    }

    // MARK: Deck reconciliation (pure store)

    func testReconcileFiltersStaleCardIds() {
        var store = ColumnDeckStore()
        store.adopt(WorkspaceId("live"), into: "deck-1")
        store.adopt(WorkspaceId("stale"), into: "deck-1")
        store.reconcile(liveCardIdsInOrder: [WorkspaceId("live")], fallbackColumnKeysByCardId: [:])
        XCTAssertEqual(store.deck(forColumnKey: "deck-1"), [WorkspaceId("live")])
        XCTAssertNil(store.columnKey(of: WorkspaceId("stale")))
        assertDeckPartitionInvariant(store)
    }

    func testReconcileRemovesDuplicateMemberships() {
        let store = ColumnDeckStore(
            decksByColumnKey: [
                "deck-1": ["a", "a", "b"].map { WorkspaceId($0) },
                "deck-2": ["b", "c"].map { WorkspaceId($0) },
            ],
            columnKeyByCardId: [
                WorkspaceId("a"): "deck-1",
                WorkspaceId("b"): "deck-2",
                WorkspaceId("c"): "deck-2",
            ],
        )
        var reconciled = store
        reconciled.reconcile(
            liveCardIdsInOrder: ["a", "b", "c"].map { WorkspaceId($0) },
            fallbackColumnKeysByCardId: [:],
        )
        XCTAssertEqual(reconciled.deck(forColumnKey: "deck-1"), [WorkspaceId("a")])
        XCTAssertEqual(reconciled.deck(forColumnKey: "deck-2"), ["b", "c"].map { WorkspaceId($0) })
        assertDeckPartitionInvariant(reconciled)
    }

    func testReconcileAppendsUnseenCardsInGivenOrderToFallbackDecks() {
        var store = ColumnDeckStore()
        store.adopt(WorkspaceId("existing"), into: "deck-1")
        store.reconcile(
            liveCardIdsInOrder: ["existing", "a-new", "b-new"].map { WorkspaceId($0) },
            fallbackColumnKeysByCardId: [
                WorkspaceId("a-new"): "deck-1",
                WorkspaceId("b-new"): "deck-2",
            ],
        )
        XCTAssertEqual(store.deck(forColumnKey: "deck-1"), ["existing", "a-new"].map { WorkspaceId($0) })
        XCTAssertEqual(store.deck(forColumnKey: "deck-2"), [WorkspaceId("b-new")])
        assertDeckPartitionInvariant(store)
    }

    // MARK: Registry integration

    func testWorkspaceGetAdoptsNewWorkspaceIntoFocusedColumnDeck() {
        let zones = configureThreeColumns()
        let rightZone = zones["right"].orDie()
        let anchor = Workspace.get(byName: "anchor")
        XCTAssertTrue(rightZone.setActiveWorkspace(anchor))
        XCTAssertTrue(anchor.focusWorkspace())

        let fresh = Workspace.get(byName: "fresh")

        let rightKey = columnDeckKey(for: rightZone)
        XCTAssertEqual(winMuxWorkspaceState.columnDecks.columnKey(of: fresh.id), rightKey)
        XCTAssertEqual(
            Array(winMuxWorkspaceState.columnDecks.deck(forColumnKey: rightKey).suffix(1)),
            [fresh.id],
        )
    }

    func testActivatingWorkspaceOnAnotherColumnTransfersDeckMembership() {
        let zones = configureThreeColumns()
        let mainZone = zones["main"].orDie()
        let rightZone = zones["right"].orDie()

        let card = Workspace.get(byName: "card")
        XCTAssertTrue(mainZone.setActiveWorkspace(card))
        XCTAssertEqual(winMuxWorkspaceState.columnDecks.columnKey(of: card.id), columnDeckKey(for: mainZone))

        let replacement = Workspace.get(byName: "replacement")
        XCTAssertTrue(mainZone.setActiveWorkspace(replacement))
        XCTAssertTrue(rightZone.setActiveWorkspace(card))
        XCTAssertEqual(winMuxWorkspaceState.columnDecks.columnKey(of: card.id), columnDeckKey(for: rightZone))
    }

    func testRemovingWorkspaceFromRegistryRemovesDeckMembership() {
        let workspace = Workspace.get(byName: "doomed")
        XCTAssertNotNil(winMuxWorkspaceState.columnDecks.columnKey(of: workspace.id))
        removeWorkspaceFromRegistry(workspace)
        XCTAssertNil(winMuxWorkspaceState.columnDecks.columnKey(of: workspace.id))
    }

    func testEveryLiveWorkspaceBelongsToExactlyOneDeck() {
        let zones = configureThreeColumns()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        _ = TestWindow.new(id: 1, parent: work.rootTilingContainer)
        Workspace.reconcileWorkspaceState()

        var seen: Set<WorkspaceId> = []
        for (_, deck) in winMuxWorkspaceState.columnDecks.decksByColumnKey {
            for cardId in deck {
                XCTAssertTrue(seen.insert(cardId).inserted, "card \(cardId) is in more than one deck")
            }
        }
        for workspace in Workspace.all where !workspace.isArchived {
            XCTAssertTrue(seen.contains(workspace.id), "workspace \(workspace.name) is in no deck")
        }
    }

    func testReconcileColumnDecksAdoptsUnseenWorkspacesInSortedOrder() {
        let later = Workspace.get(byName: "b-unseen")
        let earlier = Workspace.get(byName: "a-unseen")
        winMuxWorkspaceState.columnDecks = ColumnDeckStore()

        reconcileColumnDecks()

        let key = columnDeckKey(for: mainMonitor.defaultWorkspaceViewport)
        XCTAssertEqual(
            winMuxWorkspaceState.columnDecks.deck(forColumnKey: key),
            [earlier.id, later.id, focus.workspace.id],
        )
    }

    // MARK: Survival matrix

    // Each row is arranged so exactly one predicate branch carries it: deleting or inverting
    // that branch must flip the row. In particular the visible and sole-card rows are kept out
    // of the retained-slot rule's reach so it cannot shadow them.
    func testSurvivalMatrix() {
        let zones = configureThreeColumns()
        let mainZone = zones["main"].orDie()
        let rightZone = zones["right"].orDie()
        let mainKey = columnDeckKey(for: mainZone)
        let rightKey = columnDeckKey(for: rightZone)

        // visible empty card; its deck has an anchor, but not adjacent, so the retained-slot
        // rule (visible empties qualify only next to an anchor) cannot select it
        let visibleEmpty = Workspace.get(byName: "visible-empty")
        XCTAssertTrue(mainZone.setActiveWorkspace(visibleEmpty))
        let mainAnchor = Workspace.get(byName: "main-anchor")
        _ = TestWindow.new(id: 1, parent: mainAnchor.rootTilingContainer)
        let mainSpacer = Workspace.get(byName: "main-spacer")
        winMuxWorkspaceState.columnDecks.adopt(mainAnchor.id, into: mainKey, at: 0)
        winMuxWorkspaceState.columnDecks.adopt(mainSpacer.id, into: mainKey, at: 1)

        // hidden card with a window, a hidden empty card next to it, and a hidden
        // configured-persistent card, all sharing one deck
        let anchored = Workspace.get(byName: "anchored-occupied")
        _ = TestWindow.new(id: 2, parent: anchored.rootTilingContainer)
        let anchoredEmpty = Workspace.get(byName: "anchored-empty")
        config.persistentWorkspaces = ["hidden-persistent"]
        let hiddenPersistent = Workspace.get(byName: "hidden-persistent")
        winMuxWorkspaceState.columnDecks.adopt(anchored.id, into: rightKey)
        winMuxWorkspaceState.columnDecks.adopt(anchoredEmpty.id, into: rightKey)
        winMuxWorkspaceState.columnDecks.adopt(hiddenPersistent.id, into: rightKey)

        // hidden sole card in a deck; survives even as an auto-created blank
        let soleBlank = Workspace.get(byName: "sole-blank")
        soleBlank.markAsTransientBlank()
        winMuxWorkspaceState.columnDecks.adopt(soleBlank.id, into: "display-name:Main/column:offstage")

        // hidden retained deck slot: an anchorless deck retains one empty card, chosen by
        // durable-first name order
        let retainedEmpty = Workspace.get(byName: "empty-slot-a")
        let plainEmpty = Workspace.get(byName: "empty-slot-b")
        winMuxWorkspaceState.columnDecks.adopt(retainedEmpty.id, into: "display-name:Main/column:offstage-2")
        winMuxWorkspaceState.columnDecks.adopt(plainEmpty.id, into: "display-name:Main/column:offstage-2")

        // hidden active card of a disabled zone: empty, non-sole, next to an anchor
        let hiddenActive = Workspace.get(byName: "hidden-active")
        let hiddenActiveAnchor = Workspace.get(byName: "hidden-active-anchor")
        _ = TestWindow.new(id: 3, parent: hiddenActiveAnchor.rootTilingContainer)
        let disabledZoneKey = "display-name:Main/column:offstage-3"
        winMuxWorkspaceState.columnDecks.adopt(hiddenActive.id, into: disabledZoneKey)
        winMuxWorkspaceState.columnDecks.adopt(hiddenActiveAnchor.id, into: disabledZoneKey)
        winMuxWorkspaceState.hiddenActiveCardIdByColumnKey[disabledZoneKey] = hiddenActive.id

        let retainedIds = retainedEmptyWorkspaceIdsByColumn()
        let matrix: [(workspace: Workspace, retainedIds: [String: WorkspaceId], shouldSurvive: Bool, row: String)] = [
            (visibleEmpty, retainedIds, true, "visible empty card survives"),
            (anchored, retainedIds, true, "hidden card with windows survives"),
            (hiddenPersistent, retainedIds, true, "configured-persistent card survives"),
            // an empty retained map proves the sole-card branch alone carries this row
            (soleBlank, [:], true, "sole card in deck survives even as auto-created blank"),
            (hiddenActive, retainedIds, true, "hidden active card of a disabled zone survives"),
            (retainedEmpty, retainedIds, true, "retained deck slot survives"),
            (plainEmpty, retainedIds, false, "plain empty non-sole card is pruned"),
            (mainSpacer, retainedIds, false, "hidden empty card not adjacent to an anchor is pruned"),
            (anchoredEmpty, retainedIds, false, "hidden empty card next to an occupied card is pruned"),
        ]
        for row in matrix {
            XCTAssertEqual(
                workspaceShouldSurviveReconciliation(row.workspace, retainedEmptyWorkspaceIds: row.retainedIds),
                row.shouldSurvive,
                row.row,
            )
        }
    }

    func testReconcileNeverLeavesADeckEmpty() {
        let zones = configureThreeColumns()
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        XCTAssertTrue(work.focusWorkspace())
        _ = TestWindow.new(id: 1, parent: work.rootTilingContainer)

        let first = Workspace.get(byName: "offstage-1")
        let second = Workspace.get(byName: "offstage-2")
        let offstageKey = "display-name:Main/column:offstage"
        winMuxWorkspaceState.columnDecks.adopt(first.id, into: offstageKey)
        winMuxWorkspaceState.columnDecks.adopt(second.id, into: offstageKey)

        Workspace.reconcileWorkspaceState()

        XCTAssertEqual(
            winMuxWorkspaceState.columnDecks.deck(forColumnKey: offstageKey),
            [first.id],
            "a deck is never emptied by reconciliation: one empty card is retained",
        )
        XCTAssertNil(Workspace.existing(byName: second.name))
    }

    func testReconcilePrunesEmptyNonSoleCardsButKeepsDeckAnchors() {
        let zones = configureThreeColumns()
        let rightZone = zones["right"].orDie()
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(rightZone.setActiveWorkspace(comms))
        XCTAssertTrue(work.focusWorkspace())
        _ = TestWindow.new(id: 1, parent: work.rootTilingContainer)
        _ = TestWindow.new(id: 2, parent: comms.rootTilingContainer)

        let commsExtra = Workspace.get(byName: "comms-extra")
        winMuxWorkspaceState.columnDecks.adopt(commsExtra.id, into: columnDeckKey(for: rightZone))

        Workspace.reconcileWorkspaceState()

        XCTAssertNotNil(Workspace.existing(byName: "comms"))
        XCTAssertNil(Workspace.existing(byName: "comms-extra"))
    }
}

@MainActor
private func assertDeckPartitionInvariant(_ store: ColumnDeckStore) {
    var seen: Set<WorkspaceId> = []
    for (columnKey, deck) in store.decksByColumnKey {
        XCTAssertFalse(deck.isEmpty, "deck '\(columnKey)' should have been dropped when emptied")
        for cardId in deck {
            XCTAssertTrue(seen.insert(cardId).inserted, "card \(cardId) is in more than one deck")
            XCTAssertEqual(store.columnKey(of: cardId), columnKey, "reverse index disagrees for card \(cardId)")
        }
    }
    XCTAssertEqual(seen, Set(store.columnKeyByCardId.keys))
}

@MainActor
private func configureThreeColumns() -> [String: Monitor] {
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

@MainActor
private func configureNoColumns() {
    let main = TestMonitor(
        monitorAppKitNsScreenScreensId: 1,
        name: "Main",
        rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        isMain: true,
    )
    setMonitorsForTests([main])
    config.zones = []
    refreshColumnTopologySnapshot()
}
