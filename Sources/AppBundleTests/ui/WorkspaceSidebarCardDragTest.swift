@testable import AppBundle
import Common
import XCTest

/// Card-row drag maps a drop target to a deck/scene primitive. These exercise the seam functions the
/// drag layer calls: within-deck reorder (deck store), cross-column transfer and cross-scene
/// transfer (the scene primitives, which carry focus-follows-visibility).
@MainActor
final class WorkspaceSidebarCardDragTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testCardDragPayloadRoundTripsCardName() {
        XCTAssertEqual(
            WorkspaceSidebarDragPayload(encodedValue: WorkspaceSidebarDragPayload.card("Work").encodedValue),
            .card("Work"),
        )
        // A card name may contain characters; the whole suffix round-trips.
        XCTAssertEqual(
            WorkspaceSidebarDragPayload(encodedValue: WorkspaceSidebarDragPayload.card("Work: Notes").encodedValue),
            .card("Work: Notes"),
        )
    }

    func testReorderedDeckInsertionIndexAdjustsForRemoval() {
        // Deck of 3. Dragging the head to the tail gap lands it last once it is removed first.
        XCTAssertEqual(reorderedDeckInsertionIndex(sourceIndex: 0, dropSlotIndex: 3, deckCount: 3), 2)
        // Dragging the tail to the head gap needs no adjustment.
        XCTAssertEqual(reorderedDeckInsertionIndex(sourceIndex: 2, dropSlotIndex: 0, deckCount: 3), 0)
        // Both gaps adjacent to the card are no-ops.
        XCTAssertEqual(reorderedDeckInsertionIndex(sourceIndex: 1, dropSlotIndex: 1, deckCount: 3), 1)
        XCTAssertEqual(reorderedDeckInsertionIndex(sourceIndex: 1, dropSlotIndex: 2, deckCount: 3), 1)
        // Out-of-range slots clamp to the deck bounds.
        XCTAssertEqual(reorderedDeckInsertionIndex(sourceIndex: 0, dropSlotIndex: 99, deckCount: 3), 2)
    }

    func testCardSlotDropReordersWithinTheSameDeck() {
        let main = configureScenesFromToml(twoSceneToml)
        assertSucc(setActiveScene("desk", for: main))
        let columns = sceneColumnMonitors()
        _ = occupyCard("Work", windowId: 1, on: columns["main"].orDie())
        _ = occupyCard("Notes", windowId: 2, on: columns["main"].orDie())
        _ = occupyCard("Extra", windowId: 3, on: columns["main"].orDie())
        Workspace.reconcileWorkspaceState()
        assertEquals(sceneDeckCardNames("scene:desk/column:main"), ["Work", "Notes", "Extra"])
        let scope = workspaceSidebarMonitorScopeId(for: main)

        // Drag "Work" to the tail gap.
        XCTAssertTrue(performCardSlotDropNow("Work", monitorScopeId: scope, columnId: "main", dropSlotIndex: 3))

        assertEquals(sceneDeckCardNames("scene:desk/column:main"), ["Notes", "Extra", "Work"])
        // A drop on the card's own gap changes nothing.
        XCTAssertFalse(performCardSlotDropNow("Notes", monitorScopeId: scope, columnId: "main", dropSlotIndex: 0))
        assertEquals(sceneDeckCardNames("scene:desk/column:main"), ["Notes", "Extra", "Work"])
    }

    func testCardSlotDropReordersWithinImplicitLaptopDeck() {
        // A display with no configured scene runs its implicit one-column deck. The sidebar routes
        // that laptop list through the same card-slot drop as a configured column, so its cards
        // reorder within the implicit column.
        let main = TestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
            isMain: true,
        )
        setMonitorsForTests([main])
        let implicitKey = columnDeckKey(for: main.defaultWorkspaceViewport)
        _ = occupyCard("Work", windowId: 1, on: main)
        _ = occupyCard("Notes", windowId: 2, on: main)
        _ = occupyCard("Extra", windowId: 3, on: main)
        Workspace.reconcileWorkspaceState()
        assertEquals(sceneDeckCardNames(implicitKey), ["Work", "Notes", "Extra"])
        let scope = workspaceSidebarMonitorScopeId(for: main)

        XCTAssertTrue(performCardSlotDropNow("Work", monitorScopeId: scope, columnId: implicitColumnDeckColumnId, dropSlotIndex: 3))

        assertEquals(sceneDeckCardNames(implicitKey), ["Notes", "Extra", "Work"])
        // A drop on the card's own gap changes nothing.
        XCTAssertFalse(performCardSlotDropNow("Notes", monitorScopeId: scope, columnId: implicitColumnDeckColumnId, dropSlotIndex: 0))
        assertEquals(sceneDeckCardNames(implicitKey), ["Notes", "Extra", "Work"])
    }

    func testCardSlotDropTransfersAcrossColumnsAndKeepsFocusOnVisibleColumn() {
        let main = configureScenesFromToml(twoSceneToml)
        assertSucc(setActiveScene("desk", for: main))
        let columns = sceneColumnMonitors()
        let work = occupyCard("Work", windowId: 1, on: columns["main"].orDie())
        XCTAssertTrue(work.focusWorkspace())
        Workspace.reconcileWorkspaceState()
        let scope = workspaceSidebarMonitorScopeId(for: main)

        // Dropping on a different column of the same scene transfers the card there.
        XCTAssertTrue(performCardSlotDropNow("Work", monitorScopeId: scope, columnId: "comms", dropSlotIndex: 0))

        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: work.id), "scene:desk/column:comms")
        XCTAssertTrue(work.isVisible)
        // Focus follows the card because the destination column is visible.
        XCTAssertTrue(focus.workspace === work)
        assertEquals(sceneActiveCards()["comms"], "Work")
    }

    func testSceneTargetTransfersToOffstageSceneAndLeavesFocusBehind() {
        let main = configureScenesFromToml(twoSceneToml)
        assertSucc(setActiveScene("desk", for: main))
        let columns = sceneColumnMonitors()
        let work = occupyCard("Work", windowId: 1, on: columns["main"].orDie())
        let notes = occupyCard("Notes", windowId: 2, on: columns["main"].orDie())
        XCTAssertTrue(columns["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(work.focusWorkspace())
        Workspace.reconcileWorkspaceState()
        let scope = workspaceSidebarMonitorScopeId(for: main)

        // The scene switcher exposes the non-active 'focus' scene; a card dropped there goes into
        // that scene's default column (its only column, 'main').
        XCTAssertTrue(performCardDropNow("Work", target: .scene(monitorScopeId: scope, sceneId: "focus")))

        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: work.id), "scene:focus/column:main")
        XCTAssertFalse(work.isVisible)
        // Focus stays behind on the vacated column's next card (focus-follows-visibility).
        XCTAssertTrue(focus.workspace === notes)
        assertEquals(sceneActiveCards()["main"], "Notes")
    }

    func testSceneSwitchTargetsListDisplayScenesTaggingActive() {
        let main = configureScenesFromToml(twoSceneToml)
        assertSucc(setActiveScene("desk", for: main))
        let scope = workspaceSidebarMonitorScopeId(for: main)

        let targets = buildWorkspaceSidebarSceneSwitchTargetViewModels(sortedMonitors: sortedMonitors)
            .filter { $0.monitorScopeId == scope }

        XCTAssertEqual(targets.map(\.sceneId), ["desk", "focus"])
        XCTAssertEqual(targets.singleOrNil { $0.sceneId == "desk" }?.isActive, true)
        XCTAssertEqual(targets.singleOrNil { $0.sceneId == "focus" }?.isActive, false)
    }

    func testActionableCardDropTargetRejectsNoopsAndForeignKinds() {
        let main = configureScenesFromToml(twoSceneToml)
        assertSucc(setActiveScene("desk", for: main))
        let columns = sceneColumnMonitors()
        _ = occupyCard("Work", windowId: 1, on: columns["main"].orDie())
        _ = occupyCard("Notes", windowId: 2, on: columns["main"].orDie())
        Workspace.reconcileWorkspaceState()
        let scope = workspaceSidebarMonitorScopeId(for: main)

        // A same-column drop that would not move "Work" (index 0) is not actionable.
        XCTAssertFalse(isActionableCardDropTarget(
            sourceCardName: "Work",
            targetKind: .cardSlot(monitorScopeId: scope, columnId: "main", index: 0),
        ))
        // A same-column drop past "Work" moves it, so it is actionable.
        XCTAssertTrue(isActionableCardDropTarget(
            sourceCardName: "Work",
            targetKind: .cardSlot(monitorScopeId: scope, columnId: "main", index: 2),
        ))
        // A drop into another column is always actionable.
        XCTAssertTrue(isActionableCardDropTarget(
            sourceCardName: "Work",
            targetKind: .cardSlot(monitorScopeId: scope, columnId: "comms", index: 0),
        ))
        // A non-active scene is a valid cross-scene target.
        XCTAssertTrue(isActionableCardDropTarget(
            sourceCardName: "Work",
            targetKind: .scene(monitorScopeId: scope, sceneId: "focus"),
        ))
        XCTAssertFalse(isActionableCardDropTarget(
            sourceCardName: "Work",
            targetKind: .scene(monitorScopeId: scope, sceneId: "no-such-scene"),
        ))
        // Window drop kinds are never card destinations.
        XCTAssertFalse(isActionableCardDropTarget(sourceCardName: "Work", targetKind: .workspace("Notes")))
        XCTAssertFalse(isActionableCardDropTarget(
            sourceCardName: "Work",
            targetKind: .zone(monitorScopeId: scope, zoneId: "comms"),
        ))
    }
}
