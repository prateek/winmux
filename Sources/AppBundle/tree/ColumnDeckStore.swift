import AppKit

/// Column id used for the single implicit column of a display that has no configured zones.
let implicitColumnDeckColumnId = "__implicit-column__"

/// A deck key names one column of one scene. A display running a named scene keys by the scene
/// id (`activeSceneDeckKeyComponent`), so each scene's columns own distinct decks and a card
/// stays in its scene's deck while other scenes render. A display with no active scene runs its
/// implicit scene, whose component is the display identity: the display name when the hardware
/// reports one, physical geometry otherwise. Configured columns key by their config-declared id,
/// so the key survives display reorder and resolution changes.
func columnDeckKey(sceneKey: String, columnId: String) -> String {
    "\(sceneKey)/column:\(columnId)"
}

func implicitSceneDeckKey(displayName: String, physicalTopLeftCorner: CGPoint) -> String {
    displayName.isEmpty
        ? "display-geometry:\(physicalTopLeftCorner.x),\(physicalTopLeftCorner.y)"
        : "display-name:\(displayName)"
}

private let columnDeckKeySeparator = "/column:"
private let geometrySceneKeyPrefix = "display-geometry:"

func splitColumnDeckKey(_ columnKey: String) -> (sceneKey: String, columnId: String)? {
    guard let separatorRange = columnKey.range(of: columnDeckKeySeparator, options: .backwards) else { return nil }
    return (
        String(columnKey[..<separatorRange.lowerBound]),
        String(columnKey[separatorRange.upperBound...]),
    )
}

func geometrySceneKeyPoint(_ sceneKey: String) -> CGPoint? {
    guard sceneKey.hasPrefix(geometrySceneKeyPrefix) else { return nil }
    let components = sceneKey.dropFirst(geometrySceneKeyPrefix.count).split(separator: ",")
    guard components.count == 2,
          let x = Double(components[0]),
          let y = Double(components[1])
    else { return nil }
    return CGPoint(x: x, y: y)
}

@MainActor
func columnDeckKey(for monitor: Monitor) -> String {
    columnDeckKey(
        sceneKey: activeSceneDeckKeyComponent(for: monitor),
        columnId: monitor.zoneId ?? implicitColumnDeckColumnId,
    )
}

/// The stable ordered decks of cards (runtime workspaces), one deck per column. Every live
/// card belongs to exactly one deck; `columnKeyByCardId` is the reverse index that enforces
/// the partition. All mutations keep both structures in sync.
struct ColumnDeckStore: Equatable, Sendable {
    private(set) var decksByColumnKey: [String: [WorkspaceId]] = [:]
    private(set) var columnKeyByCardId: [WorkspaceId: String] = [:]

    init() {}

    init(decksByColumnKey: [String: [WorkspaceId]], columnKeyByCardId: [WorkspaceId: String]) {
        self.decksByColumnKey = decksByColumnKey
        self.columnKeyByCardId = columnKeyByCardId
    }

    func deck(forColumnKey columnKey: String) -> [WorkspaceId] {
        decksByColumnKey[columnKey] ?? []
    }

    func columnKey(of cardId: WorkspaceId) -> String? {
        columnKeyByCardId[cardId]
    }

    mutating func adopt(_ cardId: WorkspaceId, into columnKey: String, at index: Int? = nil) {
        remove(cardId)
        var deck = decksByColumnKey[columnKey] ?? []
        deck.insert(cardId, at: min(max(index ?? deck.count, 0), deck.count))
        decksByColumnKey[columnKey] = deck
        columnKeyByCardId[cardId] = columnKey
    }

    mutating func transfer(_ cardId: WorkspaceId, to columnKey: String) {
        guard columnKeyByCardId[cardId] != columnKey else { return }
        adopt(cardId, into: columnKey)
    }

    mutating func reorder(_ cardId: WorkspaceId, to index: Int) {
        guard let columnKey = columnKeyByCardId[cardId],
              var deck = decksByColumnKey[columnKey],
              let currentIndex = deck.firstIndex(of: cardId)
        else { return }
        deck.remove(at: currentIndex)
        deck.insert(cardId, at: min(max(index, 0), deck.count))
        decksByColumnKey[columnKey] = deck
    }

    mutating func mergeDeck(from sourceColumnKey: String, into targetColumnKey: String) {
        guard sourceColumnKey != targetColumnKey else { return }
        for cardId in decksByColumnKey[sourceColumnKey] ?? [] {
            adopt(cardId, into: targetColumnKey)
        }
    }

    mutating func remove(_ cardId: WorkspaceId) {
        guard let columnKey = columnKeyByCardId.removeValue(forKey: cardId) else { return }
        var deck = decksByColumnKey[columnKey] ?? []
        deck.removeAll { $0 == cardId }
        if deck.isEmpty {
            decksByColumnKey.removeValue(forKey: columnKey)
        } else {
            decksByColumnKey[columnKey] = deck
        }
    }

    /// Same reconciliation semantics as the per-project workspace order: stale ids are
    /// filtered, duplicate memberships are removed (the reverse index wins across decks,
    /// the first occurrence wins within a deck), and live cards that are in no deck are
    /// appended, in the given order, to their fallback column's deck.
    mutating func reconcile(
        liveCardIdsInOrder: [WorkspaceId],
        fallbackColumnKeysByCardId: [WorkspaceId: String],
    ) {
        let liveCardIds = Set(liveCardIdsInOrder)
        var reconciledDecks: [String: [WorkspaceId]] = [:]
        var reconciledReverseIndex: [WorkspaceId: String] = [:]
        for columnKey in decksByColumnKey.keys.sorted() {
            var deck: [WorkspaceId] = []
            for cardId in decksByColumnKey[columnKey] ?? [] {
                guard liveCardIds.contains(cardId),
                      columnKeyByCardId[cardId] == columnKey,
                      reconciledReverseIndex[cardId] == nil
                else { continue }
                reconciledReverseIndex[cardId] = columnKey
                deck.append(cardId)
            }
            if !deck.isEmpty {
                reconciledDecks[columnKey] = deck
            }
        }
        decksByColumnKey = reconciledDecks
        columnKeyByCardId = reconciledReverseIndex
        for cardId in liveCardIdsInOrder where columnKeyByCardId[cardId] == nil {
            guard let fallbackColumnKey = fallbackColumnKeysByCardId[cardId] else { continue }
            adopt(cardId, into: fallbackColumnKey)
        }
    }
}

@MainActor
func reconcileColumnDecks() {
    let liveWorkspaces = Workspace.all.filter { !$0.isArchived }
    var fallbackColumnKeysByCardId: [WorkspaceId: String] = [:]
    for workspace in liveWorkspaces where winMuxWorkspaceState.columnDecks.columnKey(of: workspace.id) == nil {
        fallbackColumnKeysByCardId[workspace.id] = columnDeckKey(for: workspace.workspaceMonitor)
    }
    winMuxWorkspaceState.columnDecks.reconcile(
        liveCardIdsInOrder: liveWorkspaces.map(\.id),
        fallbackColumnKeysByCardId: fallbackColumnKeysByCardId,
    )
}

/// Moves every current viewport's active card into that viewport's column deck. Deck keys
/// follow display names while viewport identities follow geometry, so a display swap that
/// keeps geometry (no viewport re-activation happens then) can leave actives keyed under the
/// old display's decks until reconciliation runs.
@MainActor
func alignActiveCardsWithColumnDecks() {
    let transfers: [(cardId: WorkspaceId, columnKey: String)] = monitors.compactMap { monitor in
        let viewportId = MonitorViewportId(monitor)
        guard let activeWorkspaceId = winMuxWorkspaceState.monitorViewportsById[viewportId]?.activeWorkspaceId else { return nil }
        let columnKey = columnDeckKey(for: monitor)
        guard winMuxWorkspaceState.columnDecks.columnKey(of: activeWorkspaceId) != columnKey else { return nil }
        return (activeWorkspaceId, columnKey)
    }
    for transfer in transfers {
        winMuxWorkspaceState.columnDecks.transfer(transfer.cardId, to: transfer.columnKey)
    }
}

/// The deck that adopts newly created workspaces: the card's recorded column when the
/// persisted deck state knows the name, else the focused column's deck. The focus hint is
/// recorded on focus changes instead of reading the focus state here because `Workspace.get`
/// runs inside the lazy initialization of the focus globals.
@MainActor
func columnDeckKeyForNewWorkspace(named name: String) -> String {
    if let recordedColumnKey = winMuxWorkspaceState.deckColumnKeyHintsByCardName.removeValue(forKey: name) {
        return recordedColumnKey
    }
    if let hint = winMuxWorkspaceState.focusedColumnDeckKeyHint,
       monitors.contains(where: { columnDeckKey(for: $0) == hint })
    {
        return hint
    }
    return columnDeckKey(for: mainMonitor.defaultWorkspaceViewport)
}

/// Re-keys implicit-scene decks after a display topology change, the deck-key analog of the
/// viewport remap in `rearrangeWorkspacesOnMonitors`. Name-keyed scenes are stable across
/// hotplug and linger while their display is away, so only geometry-keyed scenes can be
/// orphaned (a resolution or arrangement change moves the corner they are keyed by). Each
/// orphaned deck follows its display to the nearest current geometry-keyed scene: the deck is
/// re-keyed when that display still has the column, and merges, order preserved, into the
/// display's default column's deck when it does not. Decks of columns that are merely absent
/// from a current scene (disabled zones, cards parked offstage) are left alone.
@MainActor
func remapColumnDecksOntoCurrentDisplays() {
    let store = winMuxWorkspaceState.columnDecks
    guard !store.decksByColumnKey.isEmpty else { return }

    struct CurrentScene {
        let sceneKey: String
        let geometryPoint: CGPoint?
        var columnIds: Set<String>
        let defaultColumnKey: String
    }
    var currentScenesByKey: [String: CurrentScene] = [:]
    let currentPhysicalMonitors = sortedPhysicalMonitors
    // Disabled zones keep their decks: a configured column exists even while it is hidden
    // from the viewport list.
    let configuredZonesByPhysicalTopLeft = Dictionary(
        grouping: getCurrentColumnTopologySnapshot().configuredZones(for: currentPhysicalMonitors),
        by: { $0.physicalMonitor.rect.topLeftCorner },
    )
    for physicalMonitor in currentPhysicalMonitors {
        let sceneKey = implicitSceneDeckKey(
            displayName: physicalMonitor.name,
            physicalTopLeftCorner: physicalMonitor.rect.topLeftCorner,
        )
        var columnIds: Set<String> = []
        for viewport in monitors where viewport.physicalMonitor.rect.topLeftCorner == physicalMonitor.rect.topLeftCorner {
            columnIds.insert(viewport.zoneId ?? implicitColumnDeckColumnId)
        }
        for zone in configuredZonesByPhysicalTopLeft[physicalMonitor.rect.topLeftCorner] ?? [] {
            columnIds.insert(zone.zoneId)
        }
        if var existing = currentScenesByKey[sceneKey] {
            existing.columnIds.formUnion(columnIds)
            currentScenesByKey[sceneKey] = existing
        } else {
            currentScenesByKey[sceneKey] = CurrentScene(
                sceneKey: sceneKey,
                geometryPoint: physicalMonitor.name.isEmpty ? physicalMonitor.rect.topLeftCorner : nil,
                columnIds: columnIds,
                defaultColumnKey: columnDeckKey(for: physicalMonitor.defaultWorkspaceViewport),
            )
        }
    }

    let geometryScenes = currentScenesByKey.values.filter { $0.geometryPoint != nil }
    for deckKey in store.decksByColumnKey.keys.sorted() {
        guard let (sceneKey, columnId) = splitColumnDeckKey(deckKey),
              currentScenesByKey[sceneKey] == nil,
              let orphanedPoint = geometrySceneKeyPoint(sceneKey),
              let targetScene = geometryScenes.minBy({ ($0.geometryPoint.orDie() - orphanedPoint).vectorLength })
        else { continue }
        let targetColumnKey = targetScene.columnIds.contains(columnId)
            ? columnDeckKey(sceneKey: targetScene.sceneKey, columnId: columnId)
            : targetScene.defaultColumnKey
        winMuxWorkspaceState.columnDecks.mergeDeck(from: deckKey, into: targetColumnKey)
    }
}

@MainActor
func recordFocusedColumnDeckKeyHint(_ workspace: Workspace) {
    guard let monitor = workspace.visibleMonitor else { return }
    let columnKey = columnDeckKey(for: monitor)
    winMuxWorkspaceState.focusedColumnDeckKeyHint = columnKey
}

@MainActor
func orderedDeckWorkspaces(inColumn columnKey: String) -> [Workspace] {
    winMuxWorkspaceState.columnDecks.deck(forColumnKey: columnKey)
        .compactMap { winMuxWorkspaceState.workspaceById[$0] }
        .filter { !$0.isArchived }
}
