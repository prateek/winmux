import Common
import Foundation

private let persistedDeckStateVersion = 1
private let persistedDeckStateFilename = "deck-state.json"
private let persistedDeckStateSaveDebounceSeconds = 1.0
@MainActor private var persistedDeckStateSavesEnabled = false
@MainActor private var persistedDeckStateSaveGeneration = 0
@MainActor var persistedDeckStateDirectoryOverrideForTests: URL?

/// One column's persisted deck. Cards persist by name (not by session workspace id) so a
/// restart can rebuild deck membership for workspaces that get fresh ids.
struct PersistedColumnDeck: Codable, Equatable, Sendable {
    let columnKey: String
    let cardNames: [String]
    let activeCardName: String?
}

struct PersistedDeckState: Codable, Equatable, Sendable {
    let version: Int
    let columns: [PersistedColumnDeck]
}

@MainActor
private func persistedDeckStateUrl() throws -> URL {
    if let directory = persistedDeckStateDirectoryOverrideForTests {
        return directory.appendingPathComponent(persistedDeckStateFilename, isDirectory: false)
    }
    let appSupport = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true,
    )
    let directory = appSupport.appendingPathComponent(winMuxAppName, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent(persistedDeckStateFilename, isDirectory: false)
}

@MainActor
func snapshotCurrentDeckState() -> PersistedDeckState {
    let state = winMuxWorkspaceState
    var activeCardIdByColumnKey: [String: WorkspaceId] = [:]
    for monitor in monitors {
        guard let activeWorkspaceId = state.monitorViewportsById[MonitorViewportId(monitor)]?.activeWorkspaceId else { continue }
        activeCardIdByColumnKey[columnDeckKey(for: monitor)] = activeWorkspaceId
    }
    let columns = state.columnDecks.decksByColumnKey.keys.sorted().compactMap { columnKey -> PersistedColumnDeck? in
        let deck = state.columnDecks.deck(forColumnKey: columnKey)
        let cardNames = deck.compactMap { state.workspaceById[$0]?.name }
        guard !cardNames.isEmpty else { return nil }
        let activeCardName = activeCardIdByColumnKey[columnKey]
            .flatMap { activeId in deck.contains(activeId) ? state.workspaceById[activeId]?.name : nil }
        return PersistedColumnDeck(columnKey: columnKey, cardNames: cardNames, activeCardName: activeCardName)
    }
    return PersistedDeckState(version: persistedDeckStateVersion, columns: columns)
}

/// Saves are disarmed until startup has loaded the persisted state, so an early mutation can
/// never clobber the file with pre-load state. Tests never arm saves.
@MainActor
func enablePersistedDeckStateSaves() {
    persistedDeckStateSavesEnabled = true
}

@MainActor
func disablePersistedDeckStateSavesForTests() {
    persistedDeckStateSavesEnabled = false
    persistedDeckStateSaveGeneration += 1
}

@MainActor
func schedulePersistedDeckStateSave() {
    guard persistedDeckStateSavesEnabled else { return }
    persistedDeckStateSaveGeneration += 1
    let generation = persistedDeckStateSaveGeneration
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(persistedDeckStateSaveDebounceSeconds))
        guard generation == persistedDeckStateSaveGeneration else { return }
        persistDeckStateIfPossible()
    }
}

@MainActor
func persistDeckStateIfPossible() {
    guard persistedDeckStateSavesEnabled else { return }
    do {
        let url = try persistedDeckStateUrl()
        let data = try JSONEncoder.winMuxDefault.encode(snapshotCurrentDeckState())
        try data.write(to: url, options: .atomic)
    } catch {
        // Best effort. Deck state is a convenience; failure to save must not block anything.
    }
}

/// The version is probed before the full decode so a future-version file (whose shape may not
/// decode at all) can still be recognized and moved aside.
private struct PersistedDeckStateVersionProbe: Codable {
    let version: Int
}

@discardableResult
@MainActor
func loadPersistedDeckStateForStartupIfPresent() -> Bool {
    do {
        let url = try persistedDeckStateUrl()
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let data = try Data(contentsOf: url)
        let probedVersion = try JSONDecoder().decode(PersistedDeckStateVersionProbe.self, from: data).version
        guard probedVersion == persistedDeckStateVersion else {
            // A downgraded build must not let its armed saves clobber newer data.
            let backupUrl = url.appendingPathExtension("v\(probedVersion).bak")
            try? FileManager.default.removeItem(at: backupUrl)
            try FileManager.default.moveItem(at: url, to: backupUrl)
            return false
        }
        let state = try JSONDecoder().decode(PersistedDeckState.self, from: data)
        adoptPersistedDeckState(state)
        return true
    } catch {
        return false
    }
}

/// Placement hints stick around after adoption because reconciliation may prune a restored
/// empty card before its windows are detected (the frozen-world restore recreates it by name
/// later); the hint sends the recreated card back to its recorded column. Their lifetime is
/// tied to the pending frozen world, their only consumer. No hint is seeded for a card that
/// was already live before adoption (it needs no recreation) or for an automatic integer name
/// (those are minted freely for fresh viewports, which would teleport an unrelated card).
@MainActor
func adoptPersistedDeckState(_ state: PersistedDeckState) {
    var seenCardNames: Set<String> = []
    for column in state.columns {
        for cardName in column.cardNames {
            guard !cardName.isEmpty, seenCardNames.insert(cardName).inserted else { continue }
            let cardWasAlreadyLive = Workspace.existing(byName: cardName) != nil
            let workspace = Workspace.get(byName: cardName)
            winMuxWorkspaceState.columnDecks.adopt(workspace.id, into: column.columnKey)
            if cardWasAlreadyLive || parsePositiveWorkspaceDisplayIndex(cardName) != nil {
                winMuxWorkspaceState.deckColumnKeyHintsByCardName.removeValue(forKey: cardName)
            } else {
                winMuxWorkspaceState.deckColumnKeyHintsByCardName[cardName] = column.columnKey
            }
        }
    }
    for column in state.columns {
        guard let activeCardName = column.activeCardName,
              column.cardNames.contains(activeCardName),
              let workspace = Workspace.existing(byName: activeCardName),
              winMuxWorkspaceState.columnDecks.columnKey(of: workspace.id) == column.columnKey,
              let monitor = monitors.first(where: { columnDeckKey(for: $0) == column.columnKey })
        else { continue }
        _ = monitor.setActiveWorkspace(workspace)
    }
}
