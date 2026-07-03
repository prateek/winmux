@testable import AppBundle
import Common
import XCTest

@MainActor
final class SceneRegistryTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSwitchingScenesWithDifferentColumnCountsRebuildsViewports() {
        let main = configureTwoScenes()

        activate("desk", on: main)
        XCTAssertEqual(sortedMonitors.compactMap(\.zoneId), ["ref", "main", "comms"])
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [240, 600, 360])

        activate("focus", on: main)
        XCTAssertEqual(sortedMonitors.compactMap(\.zoneId), ["main"])
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [1200])

        activate("desk", on: main)
        XCTAssertEqual(sortedMonitors.compactMap(\.zoneId), ["ref", "main", "comms"])
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [240, 600, 360])
    }

    // The signature live-context guarantee: mutate a scene, leave it, return, and find it
    // exactly as it was — same columns, widths, active cards, and deck order.
    func testSceneRoundTripRestoresColumnsCardsWidthsAndDecks() {
        let main = configureTwoScenes()

        activate("desk", on: main)
        var columns = sceneColumns()
        let ref = occupy("Ref", windowId: 1, on: columns["ref"].orDie())
        let work = occupy("Work", windowId: 2, on: columns["main"].orDie())
        let comms = occupy("Comms", windowId: 3, on: columns["comms"].orDie())

        // A second card joins the main deck but Work stays the one on screen.
        let notes = occupy("Notes", windowId: 4, on: columns["main"].orDie())
        XCTAssertTrue(columns["main"].orDie().setActiveWorkspace(work))
        Workspace.reconcileWorkspaceState()

        XCTAssertEqual(columnDeckKey(for: columns["main"].orDie()), "scene:desk/column:main")
        XCTAssertEqual(deckCardNames("scene:desk/column:main"), ["Work", "Notes"])
        XCTAssertEqual(activeCardsByColumn(), ["ref": "Ref", "main": "Work", "comms": "Comms"])

        activate("focus", on: main)
        // A card from the hidden scene keeps its column deck; it just stops rendering.
        XCTAssertFalse(work.isVisible)
        XCTAssertEqual(winMuxWorkspaceState.columnDecks.columnKey(of: work.id), "scene:desk/column:main")
        XCTAssertEqual(winMuxWorkspaceState.columnDecks.columnKey(of: comms.id), "scene:desk/column:comms")
        XCTAssertEqual(winMuxWorkspaceState.columnDecks.columnKey(of: ref.id), "scene:desk/column:ref")
        XCTAssertEqual(deckCardNames("scene:desk/column:main"), ["Work", "Notes"])

        let focusCard = occupy("FocusCard", windowId: 5, on: sortedMonitors.first.orDie())
        Workspace.reconcileWorkspaceState()
        XCTAssertEqual(winMuxWorkspaceState.columnDecks.columnKey(of: focusCard.id), "scene:focus/column:main")

        activate("desk", on: main)
        columns = sceneColumns()
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [240, 600, 360])
        XCTAssertEqual(activeCardsByColumn(), ["ref": "Ref", "main": "Work", "comms": "Comms"])
        XCTAssertEqual(deckCardNames("scene:desk/column:main"), ["Work", "Notes"])

        // The focus scene's card survived the round trip in its own deck.
        XCTAssertNotNil(Workspace.existing(byName: "FocusCard"))
        XCTAssertEqual(winMuxWorkspaceState.columnDecks.columnKey(of: focusCard.id), "scene:focus/column:main")
    }

    func testCardDeckMembershipSurvivesASceneItIsNotVisibleIn() {
        let main = configureTwoScenes()

        activate("desk", on: main)
        let work = occupy("Work", windowId: 1, on: sceneColumns()["main"].orDie())
        XCTAssertEqual(winMuxWorkspaceState.columnDecks.columnKey(of: work.id), "scene:desk/column:main")

        activate("focus", on: main)

        XCTAssertNotNil(Workspace.existing(byName: "Work"))
        XCTAssertFalse(work.isVisible)
        XCTAssertEqual(winMuxWorkspaceState.columnDecks.columnKey(of: work.id), "scene:desk/column:main")
    }

    func testReactivatingTheActiveSceneIsANoOp() {
        let main = configureTwoScenes()

        activate("desk", on: main)
        let work = occupy("Work", windowId: 1, on: sceneColumns()["main"].orDie())

        guard case .success = setActiveScene("desk", for: main) else {
            return XCTFail("Re-activating the active scene should succeed")
        }
        XCTAssertEqual(activeCardsByColumn()["main"], "Work")
        XCTAssertEqual(winMuxWorkspaceState.columnDecks.columnKey(of: work.id), "scene:desk/column:main")
    }

    func testUnknownSceneAndUnknownLayoutReturnErrors() {
        let main = configureTwoScenes()

        switch setActiveScene("missing", for: main) {
            case .success: XCTFail("Expected unknown scene to fail")
            case .failure(let message): XCTAssertTrue(message.contains("Unknown scene 'missing'"))
        }

        config.scenes.append(SceneConfig(id: "dangling", monitor: .sequenceNumber(1), layoutId: "no-such-layout"))
        switch setActiveScene("dangling", for: main) {
            case .success: XCTFail("Expected unknown layout to fail")
            case .failure(let message): XCTAssertTrue(message.contains("unknown layout preset 'no-such-layout'"))
        }
    }

    func testStructuralFailureRollsBackToPriorScene() {
        let main = configureTwoScenes()

        activate("desk", on: main)
        let work = occupy("Work", windowId: 1, on: sceneColumns()["main"].orDie())

        config.zoneLayouts.append(ZoneLayoutConfig(id: "broken-layout", layout: .columns, columns: []))
        config.scenes.append(SceneConfig(id: "broken", monitor: .sequenceNumber(1), layoutId: "broken-layout"))

        switch setActiveScene("broken", for: main) {
            case .success: XCTFail("Expected a scene with no columns to fail")
            case .failure(let message): XCTAssertTrue(message.contains("produced no columns"))
        }

        XCTAssertEqual(activeSceneId(for: main), "desk")
        XCTAssertEqual(sortedMonitors.compactMap(\.zoneId), ["ref", "main", "comms"])
        XCTAssertEqual(sortedMonitors.map(\.rect.width), [240, 600, 360])
        XCTAssertEqual(activeCardsByColumn()["main"], "Work")
        XCTAssertEqual(winMuxWorkspaceState.columnDecks.columnKey(of: work.id), "scene:desk/column:main")
    }
}

@MainActor
private func activate(_ sceneId: String, on physicalMonitor: Monitor, file: StaticString = #filePath, line: UInt = #line) {
    guard case .success = setActiveScene(sceneId, for: physicalMonitor) else {
        return XCTFail("Expected scene '\(sceneId)' to activate", file: file, line: line)
    }
}

@MainActor
private func occupy(_ name: String, windowId: UInt32, on column: Monitor) -> Workspace {
    let workspace = Workspace.get(byName: name)
    _ = TestWindow.new(id: windowId, parent: workspace.rootTilingContainer)
    XCTAssertTrue(column.setActiveWorkspace(workspace))
    return workspace
}

@MainActor
private func sceneColumns() -> [String: Monitor] {
    Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.zoneId.map { ($0, monitor) }
    })
}

@MainActor
private func activeCardsByColumn() -> [String: String] {
    Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.zoneId.map { ($0, monitor.activeWorkspace.name) }
    })
}

@MainActor
private func deckCardNames(_ columnKey: String) -> [String] {
    winMuxWorkspaceState.columnDecks.deck(forColumnKey: columnKey)
        .compactMap { winMuxWorkspaceState.workspaceById[$0]?.name }
}

@MainActor
private func configureTwoScenes() -> Monitor {
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
            id: "desk-layout",
            layout: .columns,
            defaultZone: "main",
            columns: [
                ZoneColumnConfig(id: "ref", name: "Reference", width: 0.20),
                ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
                ZoneColumnConfig(id: "comms", name: "Comms", width: 0.30),
            ],
        ),
        ZoneLayoutConfig(
            id: "focus-layout",
            layout: .columns,
            defaultZone: "main",
            columns: [
                ZoneColumnConfig(id: "main", name: "Work", width: 1.0),
            ],
        ),
    ]
    config.zones = [
        ZoneConfig(monitor: .sequenceNumber(1), layoutPreset: "desk-layout"),
    ]
    config.scenes = [
        SceneConfig(id: "desk", monitor: .sequenceNumber(1), layoutId: "desk-layout", defaultColumn: "main"),
        SceneConfig(id: "focus", monitor: .sequenceNumber(1), layoutId: "focus-layout"),
    ]
    refreshZoneTopologySnapshot()
    Workspace.reconcileWorkspaceState()
    return main
}
