@testable import AppBundle
import Common
import XCTest

@MainActor
final class SceneCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSceneSwitchesFocusedDisplay() async throws {
        _ = configureScenesFromToml(twoSceneToml)

        let result = try await SceneCommand(args: SceneCmdArgs(target: .switchTo("desk")))
            .run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        assertEquals(activeSceneId(for: mainMonitor.physicalMonitor), "desk")
        assertEquals(sortedMonitors.compactMap(\.zoneId), ["ref", "main", "comms"])
    }

    func testSceneNextCyclesDeclaredScenes() async throws {
        let main = configureScenesFromToml(twoSceneToml)

        assertSucc(setActiveScene("desk", for: main))

        let toFocus = try await SceneCommand(args: SceneCmdArgs(target: .next)).run(.defaultEnv, .emptyStdin)
        assertEquals(toFocus.exitCode, 0)
        assertEquals(activeSceneId(for: main), "focus")
        assertEquals(sortedMonitors.compactMap(\.zoneId), ["main"])

        // Cycling wraps back to the first declared scene.
        let backToDesk = try await SceneCommand(args: SceneCmdArgs(target: .next)).run(.defaultEnv, .emptyStdin)
        assertEquals(backToDesk.exitCode, 0)
        assertEquals(activeSceneId(for: main), "desk")
    }

    func testSceneNewPreflightRejectsReservedAndExistingNames() {
        let main = configureScenesFromToml(twoSceneToml)
        assertSucc(setActiveScene("desk", for: main))

        switch buildSceneBlock(named: "next", on: main) {
            case .success: XCTFail("Reserved name must be rejected")
            case .failure(let message): assertTrue(message.contains("reserved scene name"))
        }
        switch buildSceneBlock(named: "desk", on: main) {
            case .success: XCTFail("Existing scene name must be rejected")
            case .failure(let message): assertTrue(message.contains("already exists"))
        }
    }

    func testSceneNewCapturesLiveColumns() {
        let main = configureScenesFromToml(twoSceneToml)
        assertSucc(setActiveScene("desk", for: main))

        switch buildSceneBlock(named: "triage", on: main) {
            case .failure(let message): XCTFail("Expected a rendered block, got: \(message)")
            case .success(let block):
                assertTrue(block.contains("[scene.triage]"))
                assertTrue(block.contains("display = 1"))
                assertTrue(block.contains("id = \"ref\""))
                assertTrue(block.contains("id = \"main\""))
                assertTrue(block.contains("id = \"comms\""))
        }
    }

    func testSceneNewRefusesOnUserZonesDisplay() {
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
        config.scenes = []
        config.zoneLayouts = []
        config.zones = [
            ZoneConfig(
                monitor: .sequenceNumber(1),
                layout: .columns,
                defaultZone: "main",
                columns: [
                    ZoneColumnConfig(id: "side", name: "Side", width: 0.5),
                    ZoneColumnConfig(id: "main", name: "Main", width: 0.5),
                ],
            ),
        ]
        refreshZoneTopologySnapshot()
        Workspace.reconcileWorkspaceState()

        switch buildSceneBlock(named: "desk", on: main) {
            case .success: XCTFail("scene new on a [[zones]] display must be refused")
            case .failure(let message): assertTrue(message.contains("configured by [[zones]]"))
        }
    }

    func testRenderSceneConfigBlockNormalizesWidths() {
        let block = renderSceneConfigBlock(
            name: "desk",
            display: 2,
            defaultColumn: "main",
            columns: [
                SceneBlockColumn(id: "ref", name: "Reference", width: 0.2, color: "#3EA2FF"),
                SceneBlockColumn(id: "main", name: "Work", width: 0.5, color: nil),
            ],
        )
        assertEquals(block, """
            [scene.desk]
            display = 2
            default-column = "main"
            columns = [
                { id = "ref", name = "Reference", width = 0.2, color = "#3EA2FF" },
                { id = "main", name = "Work", width = 0.8 },
            ]
            """)
    }
}
