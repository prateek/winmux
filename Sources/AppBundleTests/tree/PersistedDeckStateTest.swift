@testable import AppBundle
import Common
import XCTest

@MainActor
final class PersistedDeckStateTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testPersistedDeckStateCodableRoundTrip() throws {
        let state = PersistedDeckState(
            version: 1,
            columns: [
                PersistedColumnDeck(
                    columnKey: "display-name:Main/column:main",
                    cardNames: ["work", "scratch"],
                    activeCardName: "work",
                ),
                PersistedColumnDeck(
                    columnKey: "display-geometry:1920.0,0.0/column:__implicit-column__",
                    cardNames: ["chat"],
                    activeCardName: nil,
                ),
            ],
        )

        let data = try JSONEncoder.winMuxDefault.encode(state)
        let decoded = try JSONDecoder().decode(PersistedDeckState.self, from: data)

        XCTAssertEqual(decoded, state)
    }

    // An offstage scene's per-column showing card lives in hiddenActiveCardIdByColumnKey, not on a
    // live viewport. Save must record it and adopt must seed it back, or "shows it exactly as you
    // left it" fails across a relaunch for any non-active scene.
    func testOffstageColumnActiveCardSurvivesSnapshotAndAdopt() {
        _ = configureThreeColumns()
        let offstageKey = columnDeckKey(sceneKey: sceneDeckKeyPrefix + "offstage", columnId: "main")
        XCTAssertNil(monitors.first { columnDeckKey(for: $0) == offstageKey }, "offstage column has no live viewport")

        let parked = Workspace.get(byName: "parked")
        winMuxWorkspaceState.columnDecks.adopt(parked.id, into: offstageKey)
        winMuxWorkspaceState.hiddenActiveCardIdByColumnKey[offstageKey] = parked.id

        let offstageColumn = snapshotCurrentDeckState().columns.first { $0.columnKey == offstageKey }.orDie()
        XCTAssertEqual(offstageColumn.activeCardName, "parked")

        winMuxWorkspaceState.hiddenActiveCardIdByColumnKey.removeAll()
        adoptPersistedDeckState(PersistedDeckState(version: 1, columns: [
            PersistedColumnDeck(columnKey: offstageKey, cardNames: ["parked"], activeCardName: "parked"),
        ]))
        let reparked = Workspace.existing(byName: "parked").orDie()
        XCTAssertEqual(winMuxWorkspaceState.hiddenActiveCardIdByColumnKey[offstageKey], reparked.id)
    }

    func testSnapshotCurrentDeckStateRecordsCardNamesInOrderAndActiveCards() {
        let zones = configureThreeColumns()
        let mainZone = zones["main"].orDie()
        let rightZone = zones["right"].orDie()

        let work = Workspace.get(byName: "work")
        let chat = Workspace.get(byName: "chat")
        XCTAssertTrue(mainZone.setActiveWorkspace(work))
        XCTAssertTrue(rightZone.setActiveWorkspace(chat))
        let spare = Workspace.get(byName: "spare")
        winMuxWorkspaceState.columnDecks.adopt(spare.id, into: columnDeckKey(for: rightZone))

        let snapshot = snapshotCurrentDeckState()

        let mainColumn = snapshot.columns.first { $0.columnKey == columnDeckKey(for: mainZone) }.orDie()
        XCTAssertEqual(mainColumn.cardNames, ["work"])
        XCTAssertEqual(mainColumn.activeCardName, "work")
        let rightColumn = snapshot.columns.first { $0.columnKey == columnDeckKey(for: rightZone) }.orDie()
        XCTAssertEqual(rightColumn.cardNames, ["chat", "spare"])
        XCTAssertEqual(rightColumn.activeCardName, "chat")
        XCTAssertEqual(snapshot.columns.map(\.columnKey), snapshot.columns.map(\.columnKey).sorted())
    }

    func testAdoptPersistedDeckStateMaterializesDecksByNameAndRestoresActiveCards() {
        let zones = configureThreeColumns()
        let mainZone = zones["main"].orDie()
        let rightZone = zones["right"].orDie()
        let mainKey = columnDeckKey(for: mainZone)
        let rightKey = columnDeckKey(for: rightZone)

        let existing = Workspace.get(byName: "work")
        adoptPersistedDeckState(PersistedDeckState(
            version: 1,
            columns: [
                PersistedColumnDeck(columnKey: mainKey, cardNames: ["work", "scratch"], activeCardName: "work"),
                // "work" is already a member of the main deck: the duplicate is ignored.
                PersistedColumnDeck(columnKey: rightKey, cardNames: ["chat", "work"], activeCardName: "chat"),
            ],
        ))

        XCTAssertEqual(
            winMuxWorkspaceState.columnDecks.deck(forColumnKey: mainKey),
            [existing.id, Workspace.existing(byName: "scratch").orDie().id],
        )
        XCTAssertEqual(
            winMuxWorkspaceState.columnDecks.deck(forColumnKey: rightKey),
            [Workspace.existing(byName: "chat").orDie().id],
        )
        XCTAssertTrue(mainZone.activeWorkspace === existing)
        XCTAssertTrue(rightZone.activeWorkspace === Workspace.existing(byName: "chat").orDie())
        XCTAssertTrue(Workspace.existing(byName: "scratch").orDie().isEffectivelyEmpty)
    }

    func testSnapshotAdoptRoundTripRestoresDecksIntoAFreshRegistry() throws {
        let zones = configureThreeColumns()
        let mainZone = zones["main"].orDie()
        let rightZone = zones["right"].orDie()
        let mainKey = columnDeckKey(for: mainZone)
        let rightKey = columnDeckKey(for: rightZone)

        XCTAssertTrue(mainZone.setActiveWorkspace(Workspace.get(byName: "work")))
        XCTAssertTrue(rightZone.setActiveWorkspace(Workspace.get(byName: "chat")))
        winMuxWorkspaceState.columnDecks.adopt(Workspace.get(byName: "spare").id, into: rightKey)

        let data = try JSONEncoder.winMuxDefault.encode(snapshotCurrentDeckState())

        // Simulate a restart: fresh registry, same monitors, decks rebuilt from card names.
        resetWinMuxWorkspaceStateForTests()
        let decoded = try JSONDecoder().decode(PersistedDeckState.self, from: data)
        adoptPersistedDeckState(decoded)

        XCTAssertEqual(
            winMuxWorkspaceState.columnDecks.deck(forColumnKey: mainKey).compactMap { winMuxWorkspaceState.workspaceById[$0]?.name },
            ["work"],
        )
        XCTAssertEqual(
            winMuxWorkspaceState.columnDecks.deck(forColumnKey: rightKey).compactMap { winMuxWorkspaceState.workspaceById[$0]?.name },
            ["chat", "spare"],
        )
        XCTAssertEqual(mainZone.activeWorkspace.name, "work")
        XCTAssertEqual(rightZone.activeWorkspace.name, "chat")
    }

    func testAdoptSeedsHintsOnlyForRecreatableExplicitNames() {
        let zones = configureThreeColumns()
        let rightKey = columnDeckKey(for: zones["right"].orDie())

        let alreadyLive = Workspace.get(byName: "already-live")
        adoptPersistedDeckState(PersistedDeckState(
            version: 1,
            columns: [
                PersistedColumnDeck(columnKey: rightKey, cardNames: ["already-live", "3", "roaming"], activeCardName: nil),
            ],
        ))

        XCTAssertEqual(winMuxWorkspaceState.deckColumnKeyHintsByCardName, ["roaming": rightKey])
        XCTAssertEqual(winMuxWorkspaceState.columnDecks.columnKey(of: alreadyLive.id), rightKey)
    }

    func testLoadMovesFutureVersionFileAsideInsteadOfLeavingItToBeClobbered() throws {
        let tempDir = try makeTempDeckStateDirectory()
        defer { cleanUpDeckStateOverrides(tempDir) }
        let fileUrl = tempDir.appendingPathComponent("deck-state.json")
        let futureData = Data(#"{"version":2,"decks":[{"unknown":"shape"}]}"#.utf8)
        try futureData.write(to: fileUrl)

        XCTAssertFalse(loadPersistedDeckStateForStartupIfPresent())

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileUrl.path))
        let backupUrl = tempDir.appendingPathComponent("deck-state.json.v2.bak")
        XCTAssertEqual(try Data(contentsOf: backupUrl), futureData)
    }

    func testSaveTriggersWriteNothingUntilArmedAndDebouncedSaveWritesDeckState() async throws {
        let zones = configureThreeColumns()
        let mainZone = zones["main"].orDie()
        let tempDir = try makeTempDeckStateDirectory()
        defer { cleanUpDeckStateOverrides(tempDir) }
        let fileUrl = tempDir.appendingPathComponent("deck-state.json")

        XCTAssertTrue(mainZone.setActiveWorkspace(Workspace.get(byName: "work")))
        persistDeckStateIfPossible()
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileUrl.path))

        enablePersistedDeckStateSaves()
        XCTAssertTrue(mainZone.setActiveWorkspace(Workspace.get(byName: "chat")))
        try await Task.sleep(for: .seconds(1.5))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileUrl.path))
        let saved = try JSONDecoder().decode(PersistedDeckState.self, from: Data(contentsOf: fileUrl))
        let mainColumn = saved.columns.first { $0.columnKey == columnDeckKey(for: mainZone) }.orDie()
        XCTAssertEqual(mainColumn.cardNames, ["work", "chat"])
        XCTAssertEqual(mainColumn.activeCardName, "chat")

        // The termination hook saves directly, without waiting out the debounce.
        try FileManager.default.removeItem(at: fileUrl)
        persistDeckStateIfPossible()
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileUrl.path))
    }

    func testRecordedColumnHintSendsRecreatedCardBackToItsColumn() {
        let zones = configureThreeColumns()
        let mainZone = zones["main"].orDie()
        let rightZone = zones["right"].orDie()
        let rightKey = columnDeckKey(for: rightZone)

        adoptPersistedDeckState(PersistedDeckState(
            version: 1,
            columns: [
                PersistedColumnDeck(columnKey: rightKey, cardNames: ["roaming"], activeCardName: nil),
            ],
        ))
        // The card gets pruned (or closed) before its windows come back...
        removeWorkspaceFromRegistry(Workspace.existing(byName: "roaming").orDie())
        XCTAssertTrue(mainZone.setActiveWorkspace(Workspace.get(byName: "focus-holder")))
        XCTAssertTrue(Workspace.get(byName: "focus-holder").focusWorkspace())

        // ...and its by-name recreation still lands in the recorded column, not the focused one.
        let recreated = Workspace.get(byName: "roaming")
        XCTAssertEqual(winMuxWorkspaceState.columnDecks.columnKey(of: recreated.id), rightKey)

        // The hint is consumed: deleting and recreating again follows the focused column.
        removeWorkspaceFromRegistry(recreated)
        let recreatedAgain = Workspace.get(byName: "roaming")
        XCTAssertEqual(
            winMuxWorkspaceState.columnDecks.columnKey(of: recreatedAgain.id),
            columnDeckKey(for: mainZone),
        )
    }
}

@MainActor
private func makeTempDeckStateDirectory() throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("winmux-deck-state-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    persistedDeckStateDirectoryOverrideForTests = tempDir
    return tempDir
}

@MainActor
private func cleanUpDeckStateOverrides(_ tempDir: URL) {
    disablePersistedDeckStateSavesForTests()
    persistedDeckStateDirectoryOverrideForTests = nil
    try? FileManager.default.removeItem(at: tempDir)
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
