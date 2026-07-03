import AppKit

/// Column id used for the single implicit column of a display that has no configured zones.
let implicitColumnDeckColumnId = "__implicit-column__"

/// A deck key names one column of one scene. Scenes are not a runtime concept yet, so every
/// display runs its implicit scene and the scene component keys by display identity: the
/// display name when the hardware reports one, physical geometry otherwise. Configured zone
/// columns key by their config-declared zone id, so the key survives display reorder and
/// resolution changes.
func columnDeckKey(sceneKey: String, columnId: String) -> String {
    "\(sceneKey)/column:\(columnId)"
}

func implicitSceneDeckKey(displayName: String, physicalTopLeftCorner: CGPoint) -> String {
    displayName.isEmpty
        ? "display-geometry:\(physicalTopLeftCorner.x),\(physicalTopLeftCorner.y)"
        : "display-name:\(displayName)"
}

@MainActor
func columnDeckKey(for monitor: Monitor) -> String {
    let physicalMonitor = monitor.physicalMonitor
    return columnDeckKey(
        sceneKey: implicitSceneDeckKey(
            displayName: physicalMonitor.name,
            physicalTopLeftCorner: physicalMonitor.rect.topLeftCorner,
        ),
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
            let deck = (decksByColumnKey[columnKey] ?? []).filter { cardId in
                guard liveCardIds.contains(cardId),
                      columnKeyByCardId[cardId] == columnKey,
                      reconciledReverseIndex[cardId] == nil
                else { return false }
                reconciledReverseIndex[cardId] = columnKey
                return true
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

/// The deck that adopts newly created workspaces: the focused column's deck. The hint is
/// recorded on focus changes instead of reading the focus state here because `Workspace.get`
/// runs inside the lazy initialization of the focus globals.
@MainActor
func columnDeckKeyForNewWorkspace() -> String {
    if let hint = winMuxWorkspaceState.focusedColumnDeckKeyHint,
       monitors.contains(where: { columnDeckKey(for: $0) == hint })
    {
        return hint
    }
    return columnDeckKey(for: mainMonitor.defaultWorkspaceViewport)
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
