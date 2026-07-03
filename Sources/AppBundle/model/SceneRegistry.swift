import AppKit
import Common

/// A named arrangement a display can switch to: a set of columns with widths, plus the column
/// where rule-created cards land. Scenes are the fork's live-context selector. Switching to a
/// scene rebuilds the display's columns and reveals each column's deck; the outgoing scene keeps
/// its column membership and simply stops rendering. Nothing is a snapshot: leaving and
/// returning shows the scene exactly as it was.
///
/// Config-v3 `[scene.*]` parsing populates `config.scenes` (Builder 2's surface); each scene
/// references a zone-layout preset that supplies its columns and widths, and a `config.zones`
/// entry must target the display so the layout can activate. This phase keeps config-version 2,
/// so the field is additive and empty by default.
struct SceneConfig: ConvenienceCopyable, Equatable, Sendable {
    var id: String = ""
    var monitor: MonitorDescription?
    var layoutId: String = ""
    var defaultColumn: String?
}

/// The prefix that marks a deck key's scene component as a named scene rather than an implicit
/// display identity, so the two namespaces never collide and geometry remapping skips scenes.
let sceneDeckKeyPrefix = "scene:"

struct SceneActivationResult {
    let sceneId: String
    let layoutId: String
    let physicalMonitor: Monitor
    let columnIds: [String]
    let restoredCards: [(column: String, card: String)]
}

/// The scenes declared for a display, in declared order. The first is the display's default.
@MainActor
func scenes(on physicalMonitor: Monitor) -> [SceneConfig] {
    let targetTopLeft = physicalMonitor.physicalMonitor.rect.topLeftCorner
    let sortedPhysicals = sortedPhysicalMonitors
    return config.scenes.filter { scene in
        guard let description = scene.monitor,
              let resolved = description.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicals)
        else { return false }
        return resolved.rect.topLeftCorner == targetTopLeft
    }
}

/// The deck-key scene component for a display: the active named scene, else the implicit display
/// identity. Each named scene owns distinct column decks, so a card stays in its scene's deck
/// while other scenes render on the same display.
@MainActor
func activeSceneDeckKeyComponent(for monitor: Monitor) -> String {
    let physical = monitor.physicalMonitor
    if let sceneId = activeSceneId(for: physical) {
        return sceneDeckKeyPrefix + sceneId
    }
    return implicitSceneDeckKey(
        displayName: physical.name,
        physicalTopLeftCorner: physical.rect.topLeftCorner,
    )
}

/// Cycles the display to the next scene in its declared order, wrapping. With no scene active
/// (the implicit scene, or a stale selector) it activates the display's default (first) scene.
@MainActor
func cycleScene(for physicalMonitor: Monitor) -> Result<SceneActivationResult, String> {
    let targetPhysical = physicalMonitor.physicalMonitor
    let declared = scenes(on: targetPhysical)
    guard !declared.isEmpty else {
        return .failure("No scenes are declared for monitor \(targetPhysical.monitorId_oneBased ?? 0)")
    }
    let nextIndex: Int
    if let currentId = activeSceneId(for: targetPhysical),
       let currentIndex = declared.firstIndex(where: { $0.id == currentId })
    {
        nextIndex = (currentIndex + 1) % declared.count
    } else {
        nextIndex = 0
    }
    return setActiveScene(declared[nextIndex].id, for: targetPhysical)
}

/// Switches a display to a named scene by rebuilding its columns through the zone-layout path
/// and revealing each column's deck. A scene switch changes which columns exist (scenes differ
/// in count and widths), so it is not a workspace-pointer swap: the incoming layout activates,
/// then every surviving or created column shows the card its deck records as active. The whole
/// operation is an edit transaction, so a structural failure leaves the prior scene intact.
@MainActor
func setActiveScene(_ sceneId: String, for physicalMonitor: Monitor) -> Result<SceneActivationResult, String> {
    let targetPhysical = physicalMonitor.physicalMonitor
    let monitorLabel = targetPhysical.monitorId_oneBased ?? 0

    guard let scene = scenes(on: targetPhysical).first(where: { $0.id == sceneId }) else {
        return .failure("Unknown scene '\(sceneId)' on monitor \(monitorLabel)")
    }
    guard config.zoneLayouts.contains(where: { $0.id == scene.layoutId }) else {
        return .failure("Scene '\(sceneId)' references unknown layout preset '\(scene.layoutId)'")
    }
    // Layout activation is a no-op unless a zone config targets the display, so a scene with no
    // backing zone config would silently produce zero columns.
    let sortedPhysicals = sortMonitorsBySpatialOrder(physicalMonitors)
    let hasZoneConfig = config.zones.contains { zone in
        guard let description = zone.monitor,
              let resolved = description.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicals)
        else { return false }
        return resolved.rect.topLeftCorner == targetPhysical.rect.topLeftCorner
    }
    guard hasZoneConfig else {
        return .failure("No column config targets monitor \(monitorLabel)")
    }

    if activeSceneId(for: targetPhysical) == sceneId {
        let columnIds = sceneColumnViewports(on: targetPhysical).map { $0.zoneId.orDie() }
        return .success(SceneActivationResult(
            sceneId: sceneId,
            layoutId: scene.layoutId,
            physicalMonitor: targetPhysical,
            columnIds: columnIds,
            restoredCards: [],
        ))
    }

    let workspaceStateBefore = winMuxWorkspaceState
    let overlaysBefore = zoneRuntimeOverlaysSnapshot()
    func rollback(_ message: String) -> Result<SceneActivationResult, String> {
        winMuxWorkspaceState = workspaceStateBefore
        restoreZoneRuntimeOverlaysAfterRollback(overlaysBefore)
        checkWorkspaceHierarchyInvariants()
        return .failure(message)
    }

    // The outgoing scene's per-column active cards become that scene's hidden-active memory:
    // switching back reveals the exact cards, and the memory keeps a hidden active card alive
    // through reconciliation while its whole scene is offstage.
    rememberActiveCardsForActiveScene(on: targetPhysical)

    // Rebuild the columns and switch the deck-key namespace in one step, so the restore below
    // reads the incoming scene's decks.
    applySceneRuntimeOverlay(sceneId: sceneId, layoutId: scene.layoutId, for: targetPhysical)

    let sceneViewports = sceneColumnViewports(on: targetPhysical)
    guard !sceneViewports.isEmpty else {
        return rollback("Scene '\(sceneId)' produced no columns on monitor \(monitorLabel)")
    }

    var restoredCards: [(column: String, card: String)] = []
    for viewport in sceneViewports {
        guard let card = restoreSceneColumnActiveCard(for: viewport) else {
            return rollback("Can't reveal a card for column '\(viewport.zoneId ?? "")' in scene '\(sceneId)'")
        }
        restoredCards.append((column: viewport.zoneId.orDie(), card: card.name))
    }

    Workspace.reconcileWorkspaceState()
    return .success(SceneActivationResult(
        sceneId: sceneId,
        layoutId: scene.layoutId,
        physicalMonitor: targetPhysical,
        columnIds: sceneViewports.map { $0.zoneId.orDie() },
        restoredCards: restoredCards,
    ))
}

/// Reconciles decks after a config reload changes which scenes exist. A display whose active
/// scene was removed promotes to the new default (first declared) scene, or drops to its implicit
/// scene when its last scene is gone. Every deck keyed by a removed scene merges, order preserved,
/// into its owning display's default-scene default column — the same orphan-merge rule hotplug
/// uses. A removed scene that was never activated still belongs to its declared display, recovered
/// from `previousScenes` (the pre-reload config), so its decks follow that display instead of
/// dropping to main. Run before the reload's reconcile so the promoted scene's columns read the
/// merged decks.
@MainActor
func remapColumnDecksOntoCurrentScenes(previousScenes: [SceneConfig]) {
    guard !winMuxWorkspaceState.columnDecks.decksByColumnKey.isEmpty else { return }
    let validSceneIds = Set(config.scenes.map(\.id))
    let sortedPhysicals = sortedPhysicalMonitors

    // Only a display whose *active* scene was removed promotes; key by the removed scene id so
    // its decks route back to the same display below.
    var displayForRemovedScene: [String: Monitor] = [:]
    var displaysToPromote: [Monitor] = []
    for physicalMonitor in sortedPhysicals {
        guard let activeId = activeSceneId(for: physicalMonitor), !validSceneIds.contains(activeId) else { continue }
        displayForRemovedScene[activeId] = physicalMonitor
        displaysToPromote.append(physicalMonitor)
    }
    for physicalMonitor in displaysToPromote {
        if let promoted = scenes(on: physicalMonitor).first {
            applySceneRuntimeOverlay(sceneId: promoted.id, layoutId: promoted.layoutId, for: physicalMonitor)
        } else {
            clearActiveSceneOverlay(for: physicalMonitor)
        }
    }

    // Never-activated removed scenes have no runtime overlay to read their display from; recover
    // it from the pre-reload config so their orphaned decks still find their own display.
    for scene in previousScenes where !validSceneIds.contains(scene.id) && displayForRemovedScene[scene.id] == nil {
        guard let description = scene.monitor,
              let resolved = description.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicals)
        else { continue }
        displayForRemovedScene[scene.id] = resolved
    }

    for deckKey in winMuxWorkspaceState.columnDecks.decksByColumnKey.keys.sorted() {
        guard let (sceneKey, _) = splitColumnDeckKey(deckKey), sceneKey.hasPrefix(sceneDeckKeyPrefix) else { continue }
        let sceneId = String(sceneKey.dropFirst(sceneDeckKeyPrefix.count))
        guard !validSceneIds.contains(sceneId) else { continue }
        let display = displayForRemovedScene[sceneId] ?? mainMonitor.physicalMonitor
        let targetColumnKey = defaultSceneDefaultColumnDeckKey(forDisplay: display)
            ?? columnDeckKey(for: display.defaultWorkspaceViewport)
        winMuxWorkspaceState.columnDecks.mergeDeck(from: deckKey, into: targetColumnKey)
    }
}

/// Computed from config, not the active viewport, so it stays correct even before that scene is
/// activated; `nil` when the display has no scenes (it runs its implicit scene).
@MainActor
private func defaultSceneDefaultColumnDeckKey(forDisplay physicalMonitor: Monitor) -> String? {
    guard let defaultScene = scenes(on: physicalMonitor.physicalMonitor).first,
          let layout = config.zoneLayouts.first(where: { $0.id == defaultScene.layoutId }),
          let columnId = defaultScene.defaultColumn ?? layout.columns.first?.id
    else { return nil }
    return columnDeckKey(sceneKey: sceneDeckKeyPrefix + defaultScene.id, columnId: columnId)
}

/// Activates each configured display's default (first-declared) scene when none is active, so a
/// configured display keys its columns by scene from the first card instead of stranding early
/// cards in implicit decks that never match the persisted `scene:*` keys. Runs during config
/// application, before the persisted-deck load and first reconcile. Idempotent: a display already
/// running a scene is left untouched, so a runtime reload never overrides a live non-default scene.
@MainActor
func activateDefaultScenesForConfiguredDisplays() {
    for physicalMonitor in sortedPhysicalMonitors {
        guard activeSceneId(for: physicalMonitor) == nil,
              let defaultScene = scenes(on: physicalMonitor).first
        else { continue }
        applySceneRuntimeOverlay(sceneId: defaultScene.id, layoutId: defaultScene.layoutId, for: physicalMonitor)
    }
}

@MainActor
private func sceneColumnViewports(on physicalMonitor: Monitor) -> [Monitor] {
    let targetTopLeft = physicalMonitor.physicalMonitor.rect.topLeftCorner
    return sortMonitorsBySpatialOrder(monitors.filter {
        $0.zoneId != nil && $0.physicalMonitor.rect.topLeftCorner == targetTopLeft
    })
}

@MainActor
private func rememberActiveCardsForActiveScene(on physicalMonitor: Monitor) {
    let targetTopLeft = physicalMonitor.physicalMonitor.rect.topLeftCorner
    for viewport in monitors where viewport.zoneId != nil && viewport.physicalMonitor.rect.topLeftCorner == targetTopLeft {
        guard let activeId = winMuxWorkspaceState.monitorViewportsById[MonitorViewportId(viewport)]?.activeWorkspaceId else { continue }
        winMuxWorkspaceState.hiddenActiveCardIdByColumnKey[columnDeckKey(for: viewport)] = activeId
    }
}

/// Reveals a column's incoming card, always displacing the outgoing scene's card. A scene's
/// first visit has an empty deck, so a fresh blank is created rather than leaving the outgoing
/// card on screen.
@MainActor
private func restoreSceneColumnActiveCard(for viewport: Monitor) -> Workspace? {
    let viewportId = MonitorViewportId(viewport)
    let columnKey = columnDeckKey(for: viewport)

    if let activeId = winMuxWorkspaceState.monitorViewportsById[viewportId]?.activeWorkspaceId,
       winMuxWorkspaceState.columnDecks.columnKey(of: activeId) == columnKey,
       let active = winMuxWorkspaceState.workspaceById[activeId]
    {
        return active
    }

    if let hiddenId = winMuxWorkspaceState.hiddenActiveCardIdByColumnKey[columnKey],
       let hidden = winMuxWorkspaceState.workspaceById[hiddenId],
       winMuxWorkspaceState.columnDecks.columnKey(of: hiddenId) == columnKey,
       !winMuxWorkspaceState.isWorkspaceActive(hiddenId, outside: viewportId),
       viewport.setActiveWorkspace(hidden)
    {
        winMuxWorkspaceState.hiddenActiveCardIdByColumnKey.removeValue(forKey: columnKey)
        return hidden
    }

    if let card = orderedDeckWorkspaces(inColumn: columnKey).first(where: {
        !winMuxWorkspaceState.isWorkspaceActive($0.id, outside: viewportId)
    }), viewport.setActiveWorkspace(card) {
        winMuxWorkspaceState.hiddenActiveCardIdByColumnKey.removeValue(forKey: columnKey)
        return card
    }

    let projectId = winMuxWorkspaceState.monitorViewportsById[viewportId]?.activeWorkspaceId
        .flatMap { winMuxWorkspaceState.workspaceById[$0]?.projectId } ?? workspaceProjectDefaultId
    let blank = createBlankWorkspace(projectId: projectId, monitor: viewport)
    guard viewport.setActiveWorkspace(blank) else { return nil }
    return blank
}
