@testable import AppBundle
import Common
import XCTest

@MainActor
final class SceneCardMoveTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testMoveCardToOffstageSceneTransfersDeckAndLeavesFocusBehind() {
        let main = configureScenesFromToml(twoSceneToml)
        assertSucc(setActiveScene("desk", for: main))

        let columns = sceneColumnMonitors()
        let work = occupyCard("Work", windowId: 1, on: columns["main"].orDie())
        let notes = occupyCard("Notes", windowId: 2, on: columns["main"].orDie())
        XCTAssertTrue(columns["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(work.focusWorkspace())
        Workspace.reconcileWorkspaceState()
        assertEquals(sceneDeckCardNames("scene:desk/column:main"), ["Work", "Notes"])

        assertSucc(moveCardToSceneColumn(work, sceneId: "focus", columnId: "main"))

        // The card follows its deck into the offstage scene and stops rendering.
        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: work.id), "scene:focus/column:main")
        XCTAssertFalse(work.isVisible)
        // Focus stays behind on the vacated column's next card (focus-follows-visibility).
        XCTAssertTrue(focus.workspace === notes)
        assertEquals(sceneActiveCards()["main"], "Notes")
    }

    func testMoveCardToVisibleColumnRepointsAndKeepsFocus() {
        let main = configureScenesFromToml(twoSceneToml)
        assertSucc(setActiveScene("desk", for: main))

        let work = occupyCard("Work", windowId: 1, on: sceneColumnMonitors()["main"].orDie())
        XCTAssertTrue(work.focusWorkspace())
        Workspace.reconcileWorkspaceState()

        assertSucc(moveCardToSceneColumn(work, sceneId: "desk", columnId: "comms"))

        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: work.id), "scene:desk/column:comms")
        XCTAssertTrue(work.isVisible)
        XCTAssertTrue(focus.workspace === work, "focus stays on the card because its destination is visible")
        assertEquals(sceneActiveCards()["comms"], "Work")
    }

    func testEmptyCardMovedBehindAnAnchorInOffstageSceneSurvives() {
        let main = configureScenesFromToml(twoSceneToml)
        assertSucc(setActiveScene("desk", for: main))

        // Anchor the offstage 'focus' scene's main column with a window-bearing card.
        let anchor = occupyCard("Anchor", windowId: 1, on: sceneColumnMonitors()["main"].orDie())
        assertSucc(moveCardToSceneColumn(anchor, sceneId: "focus", columnId: "main"))
        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: anchor.id), "scene:focus/column:main")

        // An empty card moved into that same offstage column lands second, behind the anchor, so
        // it is neither visible nor the deck's sole card: only the survival branch keeps it.
        let empty = Workspace.get(byName: "Empty")
        assertSucc(moveCardToSceneColumn(empty, sceneId: "focus", columnId: "main"))
        Workspace.reconcileWorkspaceState()

        XCTAssertNotNil(Workspace.existing(byName: "Empty"))
        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: empty.id), "scene:focus/column:main")
        assertEquals(sceneDeckCardNames("scene:focus/column:main"), ["Anchor", "Empty"])
    }

    func testMoveIntoVisibleColumnRehomesFocusOffADisplacedCard() {
        let main = configureScenesFromToml(twoSceneToml)
        assertSucc(setActiveScene("desk", for: main))

        let columns = sceneColumnMonitors()
        // 'Comms' shows in the comms column and holds focus.
        let comms = occupyCard("Comms", windowId: 1, on: columns["comms"].orDie())
        // 'Mover' parks offstage in the ref column's deck behind 'RefCard', so moving it takes the
        // plain reveal path and cleanly displaces whatever the target column was showing.
        let mover = occupyCard("Mover", windowId: 2, on: columns["ref"].orDie())
        _ = occupyCard("RefCard", windowId: 3, on: columns["ref"].orDie())
        XCTAssertTrue(comms.focusWorkspace())
        Workspace.reconcileWorkspaceState()
        XCTAssertFalse(mover.isVisible)

        // Moving 'Mover' into the visible comms column displaces the focused 'Comms' card.
        assertSucc(moveCardToSceneColumn(mover, sceneId: "desk", columnId: "comms"))

        XCTAssertFalse(comms.isVisible)
        XCTAssertTrue(mover.isVisible)
        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: mover.id), "scene:desk/column:comms")
        // Focus followed to a visible card instead of stranding on the now-hidden 'Comms'.
        XCTAssertTrue(focus.workspace === mover, "focus must follow visibility off the displaced card")
    }

    func testMoveMissingCardByNameCreatesItInSceneDefaultColumn() {
        let main = configureScenesFromToml(twoSceneToml)
        assertSucc(setActiveScene("desk", for: main))

        // 'comms' is named, but a missing card lands in desk's default-column ('main').
        assertSucc(moveCardToSceneColumnByName("Fresh", sceneId: "desk", columnId: "comms"))

        let fresh = Workspace.existing(byName: "Fresh").orDie()
        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: fresh.id), "scene:desk/column:main")
    }

    func testMoveToUnknownSceneOrColumnErrors() {
        let main = configureScenesFromToml(twoSceneToml)
        assertSucc(setActiveScene("desk", for: main))
        let work = occupyCard("Work", windowId: 1, on: sceneColumnMonitors()["main"].orDie())

        switch moveCardToSceneColumn(work, sceneId: "missing", columnId: "main") {
            case .success: XCTFail("Unknown scene must fail")
            case .failure(let message): assertTrue(message.contains("Unknown scene 'missing'"))
        }
        switch moveCardToSceneColumn(work, sceneId: "focus", columnId: "comms") {
            case .success: XCTFail("Unknown column must fail")
            case .failure(let message): assertTrue(message.contains("has no column 'comms'"))
        }
    }

    // `card move <column-id>` must reach the deck-transfer primitive, not the physical-monitor
    // matcher: the command was folded from move-workspace-to-monitor and initially misrouted a
    // bare column id through monitor-pattern resolution.
    func testCardMoveColumnIdRoutesToActiveSceneColumn() async throws {
        let main = configureScenesFromToml(twoSceneToml)
        assertSucc(setActiveScene("desk", for: main))
        let work = occupyCard("Work", windowId: 1, on: sceneColumnMonitors()["main"].orDie())
        XCTAssertTrue(work.focusWorkspace())
        Workspace.reconcileWorkspaceState()

        let result = try await parseCommand("card move comms").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: work.id), "scene:desk/column:comms")
        assertEquals(sceneActiveCards()["comms"], "Work")
    }

    // `card move <scene>:<column>` must transfer the focused card into another scene's deck.
    func testCardMoveSceneColumnRoutesCrossScene() async throws {
        let main = configureScenesFromToml(twoSceneToml)
        assertSucc(setActiveScene("desk", for: main))
        let work = occupyCard("Work", windowId: 1, on: sceneColumnMonitors()["main"].orDie())
        XCTAssertTrue(work.focusWorkspace())
        Workspace.reconcileWorkspaceState()

        let result = try await parseCommand("card move focus:main").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: work.id), "scene:focus/column:main")
    }
}
