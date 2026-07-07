import AppKit
@testable import AppBundle
import Common
import XCTest

@MainActor
final class WorkspaceSidebarColumnSectionTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testColumnSectionsMapToActiveSceneColumnsInDeckOrder() {
        let zones = configureThreeColumnScene()
        let left = zones["left"].orDie()
        let mainColumn = zones["main"].orDie()
        let right = zones["right"].orDie()
        let ref = Workspace.get(byName: "ref")
        let work = Workspace.get(byName: "work")
        let work2 = Workspace.get(byName: "work2")
        let comms = Workspace.get(byName: "comms")
        winMuxWorkspaceState.columnDecks.adopt(ref.id, into: columnDeckKey(for: left))
        winMuxWorkspaceState.columnDecks.adopt(work.id, into: columnDeckKey(for: mainColumn))
        winMuxWorkspaceState.columnDecks.adopt(work2.id, into: columnDeckKey(for: mainColumn))
        winMuxWorkspaceState.columnDecks.adopt(comms.id, into: columnDeckKey(for: right))
        XCTAssertTrue(left.setActiveWorkspace(ref))
        XCTAssertTrue(mainColumn.setActiveWorkspace(work))
        XCTAssertTrue(right.setActiveWorkspace(comms))

        let sections = buildWorkspaceSidebarColumnSectionViewModels(sortedMonitors: sortedMonitors, currentFocus: focus)

        XCTAssertEqual(sections.map(\.columnId), ["left", "main", "right"])
        XCTAssertEqual(sections.map(\.title), ["Reference", "Work", "Comms"])
        XCTAssertEqual(sections.map(\.isImplicit), [false, false, false])
        XCTAssertEqual(Set(sections.map(\.monitorScopeId)).count, 1)
        XCTAssertEqual(sections.singleOrNil { $0.columnId == "left" }?.cardNames, ["ref"])
        XCTAssertEqual(sections.singleOrNil { $0.columnId == "main" }?.cardNames, ["work", "work2"])
        XCTAssertEqual(sections.singleOrNil { $0.columnId == "right" }?.cardNames, ["comms"])
    }

    func testColumnSectionMarksShowingAndFocusedCard() {
        let zones = configureThreeColumnScene()
        let ref = Workspace.get(byName: "ref")
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        winMuxWorkspaceState.columnDecks.adopt(ref.id, into: columnDeckKey(for: zones["left"].orDie()))
        winMuxWorkspaceState.columnDecks.adopt(work.id, into: columnDeckKey(for: zones["main"].orDie()))
        winMuxWorkspaceState.columnDecks.adopt(comms.id, into: columnDeckKey(for: zones["right"].orDie()))
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(ref))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        XCTAssertTrue(work.focusWorkspace())

        let sections = buildWorkspaceSidebarColumnSectionViewModels(sortedMonitors: sortedMonitors, currentFocus: focus)

        XCTAssertEqual(sections.map(\.showingCardName), ["ref", "work", "comms"].map(Optional.some))
        XCTAssertEqual(sections.singleOrNil { $0.columnId == "main" }?.isFocusedColumn, true)
        XCTAssertEqual(sections.singleOrNil { $0.columnId == "left" }?.isFocusedColumn, false)
        XCTAssertEqual(sections.singleOrNil { $0.columnId == "right" }?.isFocusedColumn, false)
    }

    func testColumnSectionColorTintsSectionFromColumnConfig() {
        let zones = configureThreeColumnScene(colors: ["left": "#3EA2FF"])
        let ref = Workspace.get(byName: "ref")
        winMuxWorkspaceState.columnDecks.adopt(ref.id, into: columnDeckKey(for: zones["left"].orDie()))
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(ref))

        let sections = buildWorkspaceSidebarColumnSectionViewModels(sortedMonitors: sortedMonitors, currentFocus: focus)

        XCTAssertEqual(sections.singleOrNil { $0.columnId == "left" }?.colorHex, "#3EA2FF")
        XCTAssertNil(sections.singleOrNil { $0.columnId == "main" }?.colorHex)
    }

    func testImplicitDisplayYieldsSingleHeaderlessSection() {
        let main = TestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
            isMain: true,
        )
        setMonitorsForTests([main])
        let alpha = Workspace.get(byName: "alpha")
        _ = TestWindow.new(id: 1, parent: alpha.rootTilingContainer)
        let beta = Workspace.get(byName: "beta")
        _ = TestWindow.new(id: 2, parent: beta.rootTilingContainer)
        XCTAssertTrue(main.setActiveWorkspace(alpha))
        XCTAssertTrue(alpha.focusWorkspace())

        let sections = buildWorkspaceSidebarColumnSectionViewModels(sortedMonitors: sortedMonitors, currentFocus: focus)

        XCTAssertEqual(sections.count, 1, "the implicit one-column scene is a single section")
        let section = sections.first.orDie()
        XCTAssertNil(section.title, "the implicit column is headerless, so the laptop's flat list is unchanged")
        XCTAssertTrue(section.isImplicit)
        XCTAssertEqual(section.showingCardName, "alpha")
        XCTAssertTrue(section.cardNames.contains("alpha"))
        XCTAssertTrue(section.cardNames.contains("beta"), "the headerless section holds all the display's cards in deck order")
    }
}

@MainActor
private func configureThreeColumnScene(colors: [String: String] = [:]) -> [String: Monitor] {
    let main = TestMonitor(
        monitorAppKitNsScreenScreensId: 1,
        name: "Main",
        rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        isMain: true,
    )
    setMonitorsForTests([main])
    config.gaps = .zero
    config.workspaceSidebar.enabled = true
    config.workspaceSidebar.enableFocus = false
    config.zones = [
        testDisplayLayoutConfig(
            monitor: .sequenceNumber(1),
            defaultZone: "main",
            columns: [
                ColumnConfig(id: "left", name: "Reference", width: 0.25, color: colors["left"]),
                ColumnConfig(id: "main", name: "Work", width: 0.50, color: colors["main"]),
                ColumnConfig(id: "right", name: "Comms", width: 0.25, color: colors["right"]),
            ],
        ),
    ]
    refreshColumnTopologySnapshot()
    return Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.columnId.map { ($0, monitor) }
    })
}
