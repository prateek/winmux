import AppKit
import Common

/// Moves a card into another scene's column deck: the cross-scene form of a deck
/// transfer. When the target scene is live on a display the card re-points onto that column's
/// viewport and, if it was the focused card, keeps focus (destination visible). When the target
/// scene is offstage the card's deck membership moves and it stops rendering; a focused card
/// leaves focus behind on the vacated column's next card (focus-follows-visibility).
@MainActor
func moveCardToSceneColumn(_ card: Workspace, sceneId: String, columnId: String) -> Result<Void, String> {
    guard let scene = config.scenes.first(where: { $0.id == sceneId }) else {
        return .failure("Unknown scene '\(sceneId)'")
    }
    guard let layout = config.zoneLayouts.first(where: { $0.id == scene.layoutId }),
          layout.columns.contains(where: { $0.id == columnId })
    else {
        return .failure("Scene '\(sceneId)' has no column '\(columnId)'")
    }
    let targetDeckKey = columnDeckKey(sceneKey: sceneDeckKeyPrefix + sceneId, columnId: columnId)

    if let targetMonitor = liveColumnViewport(sceneId: sceneId, columnId: columnId) {
        let previouslyFocused = focus.workspace
        guard overrideWorkspaceOnMonitorBySwappingActiveViewports(card, targetMonitor: targetMonitor) else {
            return .failure("Can't move card '\(card.name)' into scene '\(sceneId)' column '\(columnId)'")
        }
        Workspace.reconcileWorkspaceState()
        // Focus follows visibility: re-home to the moved card whenever the previously focused card
        // is no longer visible, whether it was the moved card or one the move displaced offscreen.
        if !previouslyFocused.isVisible {
            _ = card.focusWorkspace()
        }
        return .success(())
    }

    return moveCardOffstage(card, toDeckKey: targetDeckKey)
}

/// Resolves a card by name for a cross-scene move, creating it when missing. A missing card is
/// created in the target scene's default column (the same placement rule scenes use for new
/// cards), so a name that names nothing still lands somewhere the scene owns.
@MainActor
func moveCardToSceneColumnByName(_ name: String, sceneId: String, columnId: String) -> Result<Void, String> {
    guard let scene = config.scenes.first(where: { $0.id == sceneId }) else {
        return .failure("Unknown scene '\(sceneId)'")
    }
    if let existing = Workspace.existing(byName: name) {
        return moveCardToSceneColumn(existing, sceneId: sceneId, columnId: columnId)
    }
    guard let defaultColumn = sceneDefaultColumnId(scene) else {
        return .failure("Scene '\(sceneId)' has no columns")
    }
    let created = Workspace.get(byName: name)
    return moveCardToSceneColumn(created, sceneId: sceneId, columnId: defaultColumn)
}

@MainActor
private func liveColumnViewport(sceneId: String, columnId: String) -> Monitor? {
    monitors.first { monitor in
        monitor.zoneId == columnId && activeSceneId(for: monitor.physicalMonitor) == sceneId
    }
}

@MainActor
private func moveCardOffstage(_ card: Workspace, toDeckKey targetDeckKey: String) -> Result<Void, String> {
    let sourceMonitor = card.isVisible ? card.workspaceMonitor : nil
    let wasFocused = focus.workspace == card

    winMuxWorkspaceState.columnDecks.transfer(card.id, to: targetDeckKey)
    // The moved card becomes the offstage column's active card. This both makes it the card the
    // scene reveals on return and satisfies the survival branch, so an empty card landing behind
    // an anchor is not pruned before its scene comes back on screen.
    winMuxWorkspaceState.hiddenActiveCardIdByColumnKey[targetDeckKey] = card.id

    var replacement: Workspace?
    if let sourceMonitor {
        let sourceViewportId = MonitorViewportId(sourceMonitor)
        let sourceColumnKey = columnDeckKey(for: sourceMonitor)
        let next = orderedDeckWorkspaces(inColumn: sourceColumnKey)
            .first { $0.id != card.id && !winMuxWorkspaceState.isWorkspaceActive($0.id, outside: sourceViewportId) }
            ?? createBlankWorkspace(projectId: card.projectId, monitor: sourceMonitor)
        _ = winMuxWorkspaceState.setActiveWorkspace(next, on: sourceViewportId, deckColumnKey: sourceColumnKey)
        replacement = next
    }

    Workspace.reconcileWorkspaceState()
    if wasFocused, let replacement {
        _ = replacement.focusWorkspace()
    }
    return .success(())
}
