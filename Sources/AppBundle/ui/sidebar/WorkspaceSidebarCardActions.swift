import AppKit
import Common

/// Maps a card-row drop onto the deck and scene primitives. The drag layer never moves a card
/// itself: it resolves the drop target to the right call. Reorder within a deck uses
/// `ColumnDeckStore.reorder`; a cross-column move uses `moveCardToSceneColumn` on the
/// display's active scene; a cross-scene move uses `moveCardToSceneColumnByName` on a non-active
/// scene. Focus-follows-visibility is a property of those primitives, not of this layer.

/// The deck key for a column identified by a sidebar `(monitorScopeId, columnId)` pair. Prefers
/// the live viewport (an active-scene column) and falls back to the display's active-scene deck
/// namespace for a collapsed column that has no viewport.
@MainActor
func workspaceSidebarColumnDeckKey(monitorScopeId: String, columnId: String) -> String? {
    if let resolved = workspaceSidebarResolvedColumnTarget(monitorScopeId: monitorScopeId, columnId: columnId) {
        return columnDeckKey(for: resolved.monitor)
    }
    guard let physical = workspaceSidebarMonitor(forScopeId: monitorScopeId)?.physicalMonitor else { return nil }
    return columnDeckKey(sceneKey: activeSceneDeckKeyComponent(for: physical), columnId: columnId)
}

/// Translates a rendered deck gap into the index the `reorder` primitive expects, which inserts
/// after removing the card. A gap past the card's current slot shifts left by one once the card
/// leaves; a gap at or before it does not. Both gaps adjacent to the card resolve to a no-op.
func reorderedDeckInsertionIndex(sourceIndex: Int, dropSlotIndex: Int, deckCount: Int) -> Int {
    let clampedSlot = min(max(dropSlotIndex, 0), deckCount)
    return clampedSlot > sourceIndex ? clampedSlot - 1 : clampedSlot
}

@MainActor
func moveCardWithinDeckNow(_ cardName: String, deckKey: String, dropSlotIndex: Int) -> Bool {
    guard let card = Workspace.existing(byName: cardName),
          winMuxWorkspaceState.columnDecks.columnKey(of: card.id) == deckKey
    else { return false }
    let deck = winMuxWorkspaceState.columnDecks.deck(forColumnKey: deckKey)
    guard let sourceIndex = deck.firstIndex(of: card.id) else { return false }
    let targetIndex = reorderedDeckInsertionIndex(sourceIndex: sourceIndex, dropSlotIndex: dropSlotIndex, deckCount: deck.count)
    guard targetIndex != sourceIndex else { return false }
    winMuxWorkspaceState.columnDecks.reorder(card.id, to: targetIndex)
    return true
}

@MainActor
func transferCardToColumnNow(_ cardName: String, monitorScopeId: String, columnId: String) -> Bool {
    guard let card = Workspace.existing(byName: cardName) else { return false }
    let physical: Monitor
    if let resolved = workspaceSidebarResolvedColumnTarget(monitorScopeId: monitorScopeId, columnId: columnId) {
        physical = resolved.monitor.physicalMonitor
    } else if let monitor = workspaceSidebarMonitor(forScopeId: monitorScopeId) {
        physical = monitor.physicalMonitor
    } else {
        return false
    }
    guard let sceneId = activeSceneId(for: physical) else { return false }
    switch moveCardToSceneColumn(card, sceneId: sceneId, columnId: columnId) {
        case .success: return true
        case .failure: return false
    }
}

/// Same column reorders; a different column transfers. The reorder index is ignored on a
/// cross-column transfer, which appends via the deck primitive.
@MainActor
func performCardSlotDropNow(_ cardName: String, monitorScopeId: String, columnId: String, dropSlotIndex: Int) -> Bool {
    guard let card = Workspace.existing(byName: cardName),
          let deckKey = workspaceSidebarColumnDeckKey(monitorScopeId: monitorScopeId, columnId: columnId)
    else { return false }
    if winMuxWorkspaceState.columnDecks.columnKey(of: card.id) == deckKey {
        return moveCardWithinDeckNow(cardName, deckKey: deckKey, dropSlotIndex: dropSlotIndex)
    }
    return transferCardToColumnNow(cardName, monitorScopeId: monitorScopeId, columnId: columnId)
}

@MainActor
func transferCardToSceneNow(_ cardName: String, sceneId: String) -> Bool {
    guard let scene = config.scenes.first(where: { $0.id == sceneId }),
          let column = sceneDefaultColumnId(scene)
    else { return false }
    switch moveCardToSceneColumnByName(cardName, sceneId: sceneId, columnId: column) {
        case .success: return true
        case .failure: return false
    }
}

/// True when the drop would change something: a cross-column or cross-scene move always would, a
/// same-column reorder only when it lands the card in a new slot.
@MainActor
func isActionableCardDropTarget(sourceCardName: String, targetKind: WorkspaceSidebarDropTargetKind) -> Bool {
    guard let card = Workspace.existing(byName: sourceCardName) else { return false }
    switch targetKind {
        case .cardSlot(let monitorScopeId, let columnId, let index):
            guard let deckKey = workspaceSidebarColumnDeckKey(monitorScopeId: monitorScopeId, columnId: columnId) else { return false }
            guard winMuxWorkspaceState.columnDecks.columnKey(of: card.id) == deckKey else { return true }
            let deck = winMuxWorkspaceState.columnDecks.deck(forColumnKey: deckKey)
            guard let sourceIndex = deck.firstIndex(of: card.id) else { return false }
            return reorderedDeckInsertionIndex(sourceIndex: sourceIndex, dropSlotIndex: index, deckCount: deck.count) != sourceIndex
        case .scene(_, let sceneId):
            return config.scenes.contains { $0.id == sceneId }
        case .workspace, .newWorkspace, .column, .monitor:
            return false
    }
}

@MainActor
func performCardDropNow(_ cardName: String, target: WorkspaceSidebarDropTargetKind) -> Bool {
    switch target {
        case .cardSlot(let monitorScopeId, let columnId, let index):
            return performCardSlotDropNow(cardName, monitorScopeId: monitorScopeId, columnId: columnId, dropSlotIndex: index)
        case .scene(_, let sceneId):
            return transferCardToSceneNow(cardName, sceneId: sceneId)
        case .workspace, .newWorkspace, .column, .monitor:
            return false
    }
}

@MainActor
func moveCardFromSidebar(_ cardName: String, to target: WorkspaceSidebarDropTargetKind) {
    runWorkspaceSidebarSession {
        guard performCardDropNow(cardName, target: target) else { return }
        await updateWorkspaceSidebarModel()
    }
}
