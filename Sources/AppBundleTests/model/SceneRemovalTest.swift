@testable import AppBundle
import Common
import XCTest

@MainActor
final class SceneRemovalTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testRemovingDefaultScenePromotesNextAndMergesDecks() {
        let main = configureScenesFromToml(twoSceneToml)
        assertSucc(setActiveScene("desk", for: main))

        let columns = sceneColumnMonitors()
        let work = occupyCard("Work", windowId: 1, on: columns["main"].orDie())
        let notes = occupyCard("Notes", windowId: 2, on: columns["main"].orDie())
        XCTAssertTrue(columns["main"].orDie().setActiveWorkspace(work))
        let ref = occupyCard("Ref", windowId: 3, on: columns["ref"].orDie())
        Workspace.reconcileWorkspaceState()
        assertEquals(sceneDeckCardNames("scene:desk/column:main"), ["Work", "Notes"])

        // Config reload drops [scene.desk]; only focus remains, so it becomes the default.
        removeScenesKeeping("""
            [scene.focus]
            display = 1
            columns = [ { id = 'main', name = 'Work', width = 1.0 } ]
            """)

        assertEquals(activeSceneId(for: main), "focus")
        // Every card from the removed scene merges, order preserved, into the new default column.
        let merged = sceneDeckCardNames("scene:focus/column:main")
        assertTrue(merged.contains("Work"))
        assertTrue(merged.contains("Notes"))
        assertTrue(merged.contains("Ref"))
        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: work.id), "scene:focus/column:main")
        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: notes.id), "scene:focus/column:main")
        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: ref.id), "scene:focus/column:main")
    }

    func testRemovingLastSceneRestoresImplicitScene() {
        let deskOnly = """
            [scene.desk]
            display = 1
            default-column = 'main'
            columns = [
                { id = 'ref', name = 'Reference', width = 0.30 },
                { id = 'main', name = 'Work', width = 0.70 },
            ]
            """
        let main = configureScenesFromToml(deskOnly)
        assertSucc(setActiveScene("desk", for: main))
        let work = occupyCard("Work", windowId: 1, on: sceneColumnMonitors()["main"].orDie())
        Workspace.reconcileWorkspaceState()
        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: work.id), "scene:desk/column:main")

        // Config reload drops every scene; the display returns to its implicit one-column scene.
        removeScenesKeeping("")

        assertNil(activeSceneId(for: main))
        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: work.id), "display-name:Main/column:__implicit-column__")
    }
}

@MainActor
private func removeScenesKeeping(_ toml: String) {
    let (parsed, errors) = parseConfig(toml)
    XCTAssertTrue(errors.isEmpty, "\(errors.descriptions)")
    config.scenes = parsed.scenes
    config.zoneLayouts = parsed.zoneLayouts
    config.zones = parsed.zones
    refreshZoneTopologySnapshot()
    remapColumnDecksOntoCurrentScenes()
    Workspace.reconcileWorkspaceState()
}
