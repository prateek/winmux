@testable import AppBundle
import Common
import XCTest

/// A two-scene, single-display config parsed through the real `[scene.*]` pipeline (so backing
/// layouts and zones are synthesized as in production), then folded into the test config. `desk`
/// is a three-column scene; `focus` is one full-width column. Returns the display.
let twoSceneToml = """
[scene.desk]
display = 1
default-column = 'main'
columns = [
    { id = 'ref', name = 'Reference', width = 0.20 },
    { id = 'main', name = 'Work', width = 0.50 },
    { id = 'comms', name = 'Comms', width = 0.30 },
]

[scene.focus]
display = 1
columns = [ { id = 'main', name = 'Work', width = 1.0 } ]
"""

@MainActor
func configureScenesFromToml(_ toml: String, file: StaticString = #filePath, line: UInt = #line) -> Monitor {
    let main = TestMonitor(
        monitorAppKitNsScreenScreensId: 1,
        name: "Main",
        rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        isMain: true,
    )
    setMonitorsForTests([main])
    let (parsed, errors) = parseConfig(toml)
    XCTAssertTrue(errors.isEmpty, "\(errors.descriptions)", file: file, line: line)
    config.scenes = parsed.scenes
    config.zoneLayouts = parsed.zoneLayouts
    config.zones = parsed.zones
    refreshColumnTopologySnapshot()
    Workspace.reconcileWorkspaceState()
    return main
}

@MainActor
func sceneColumnMonitors() -> [String: Monitor] {
    Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.zoneId.map { ($0, monitor) }
    })
}

@MainActor
func sceneActiveCards() -> [String: String] {
    Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.zoneId.map { ($0, monitor.activeWorkspace.name) }
    })
}

@MainActor
func sceneDeckCardNames(_ columnKey: String) -> [String] {
    winMuxWorkspaceState.columnDecks.deck(forColumnKey: columnKey)
        .compactMap { winMuxWorkspaceState.workspaceById[$0]?.name }
}

@MainActor
func occupyCard(_ name: String, windowId: UInt32, on column: Monitor) -> Workspace {
    let workspace = Workspace.get(byName: name)
    _ = TestWindow.new(id: windowId, parent: workspace.rootTilingContainer)
    XCTAssertTrue(column.setActiveWorkspace(workspace))
    return workspace
}
