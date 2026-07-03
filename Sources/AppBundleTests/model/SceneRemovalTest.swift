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

    func testRemovingNeverActivatedSceneMergesIntoItsOwnDisplayNotMain() {
        let left = TestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Left",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
            isMain: true,
        )
        let right = TestMonitor(
            monitorAppKitNsScreenScreensId: 2,
            name: "Right",
            rect: Rect(topLeftX: 1200, topLeftY: 0, width: 1200, height: 800),
            visibleRect: Rect(topLeftX: 1200, topLeftY: 0, width: 1200, height: 800),
            isMain: false,
        )
        setMonitorsForTests([left, right])
        config.gaps = .zero
        config.workspaceSidebar.enabled = false

        // 'extraB' is a secondary scene on display 2 (the non-main display) that is never switched to.
        applyTwoDisplayScenes("""
            [scene.deskA]
            display = 1
            columns = [ { id = 'main', name = 'Work', width = 1.0 } ]

            [scene.deskB]
            display = 2
            default-column = 'mainB'
            columns = [ { id = 'mainB', name = 'WorkB', width = 1.0 } ]

            [scene.extraB]
            display = 2
            columns = [ { id = 'sideB', name = 'SideB', width = 1.0 } ]
            """)
        Workspace.reconcileWorkspaceState()
        assertSucc(setActiveScene("deskA", for: left))
        assertSucc(setActiveScene("deskB", for: right))

        // Park a window-bearing card in display 2's never-activated 'extraB' scene deck.
        let parked = occupyCard("Parked", windowId: 1, on: sceneColumnMonitors()["mainB"].orDie())
        assertSucc(moveCardToSceneColumn(parked, sceneId: "extraB", columnId: "sideB"))
        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: parked.id), "scene:extraB/column:sideB")

        // Reload drops [scene.extraB]; deskA (display 1) and deskB (display 2) remain.
        let previousScenes = config.scenes
        applyTwoDisplayScenes("""
            [scene.deskA]
            display = 1
            columns = [ { id = 'main', name = 'Work', width = 1.0 } ]

            [scene.deskB]
            display = 2
            default-column = 'mainB'
            columns = [ { id = 'mainB', name = 'WorkB', width = 1.0 } ]
            """)
        remapColumnDecksOntoCurrentScenes(previousScenes: previousScenes)
        Workspace.reconcileWorkspaceState()

        // The orphaned deck merges into display 2's default scene, not display 1 / main.
        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: parked.id), "scene:deskB/column:mainB")
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
private func applyTwoDisplayScenes(_ toml: String) {
    let (parsed, errors) = parseConfig(toml)
    XCTAssertTrue(errors.isEmpty, "\(errors.descriptions)")
    config.scenes = parsed.scenes
    config.zoneLayouts = parsed.zoneLayouts
    config.zones = parsed.zones
    refreshColumnTopologySnapshot()
}

@MainActor
private func removeScenesKeeping(_ toml: String) {
    let (parsed, errors) = parseConfig(toml)
    XCTAssertTrue(errors.isEmpty, "\(errors.descriptions)")
    let previousScenes = config.scenes
    config.scenes = parsed.scenes
    config.zoneLayouts = parsed.zoneLayouts
    config.zones = parsed.zones
    refreshColumnTopologySnapshot()
    remapColumnDecksOntoCurrentScenes(previousScenes: previousScenes)
    Workspace.reconcileWorkspaceState()
}
