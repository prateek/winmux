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
}
