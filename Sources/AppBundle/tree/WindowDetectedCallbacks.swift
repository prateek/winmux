import Common

@MainActor
func tryOnWindowDetected(_ window: Window) async throws {
    guard let parent = window.parent else { return }
    switch parent.cases {
        case .tilingContainer, .workspace, .macosMinimizedWindowsContainer,
             .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
            try await onWindowDetected(window)
        case .macosPopupWindowsContainer:
            break
    }
}

@MainActor
private func onWindowDetected(_ window: Window) async throws {
    broadcastEvent(.windowDetected(
        windowId: window.windowId,
        workspace: window.nodeWorkspace?.name,
        appBundleId: window.app.rawAppBundleId,
        appName: window.app.name,
    ))
    if try await applyMatchingRule(to: window) { return }
    for callback in config.onWindowDetected where try await callback.matches(window) {
        _ = try await callback.run.runCmdSeq(.defaultEnv.copy(\.windowId, window.windowId), .emptyStdin)
        if !callback.checkFurtherCallbacks {
            return
        }
    }
}

/// Deals a newly detected window onto every matching `[[rules]]` card in declaration order,
/// stopping at the first match unless it opts into `check-further-rules`, and reports whether any
/// rule handled it so the detection hook stops before the legacy affinity and callback passes.
/// Rules route by content (bind to a named card), never by place; an unmatched window is left on
/// the focused card it was already bound to when it was registered.
@MainActor
func applyMatchingRule(to window: Window) async throws -> Bool {
    var handled = false
    for rule in config.rules {
        guard let cardName = rule.card, try await rule.matcher.matches(window) else { continue }
        let card = resolveRuleCard(named: cardName, forWindow: window)
        _ = moveWindowToWorkspace(window, card, CmdIo(stdin: .emptyStdin), focusFollowsWindow: rule.focus, failIfNoop: false)
        handled = true
        if !rule.checkFurtherRules {
            return true
        }
    }
    return handled
}

@MainActor
private func resolveRuleCard(named cardName: String, forWindow window: Window) -> Workspace {
    if let existing = Workspace.existing(byName: cardName) {
        return existing
    }
    // nodeMonitor is nil for windows whose ancestry runs through the minimized-windows
    // container, which tryOnWindowDetected still routes here; mainMonitor keeps placement
    // deterministic instead of falling through to Workspace.get(byName:)'s focused-column
    // default, which would violate "rules must not depend on focus."
    let display = window.nodeMonitor ?? mainMonitor
    winMuxWorkspaceState.deckColumnKeyHintsByCardName[cardName] = ruleCardColumnDeckKey(onDisplay: display)
    return Workspace.get(byName: cardName)
}

/// The deck key of the active scene's default column on a display. Falls back to the display's
/// implicit column when no scene is active (the laptop case).
@MainActor
func ruleCardColumnDeckKey(onDisplay monitor: Monitor) -> String {
    if let sceneId = activeSceneId(for: monitor),
       let scene = config.scenes.first(where: { $0.id == sceneId }),
       let columnId = sceneDefaultColumnId(scene)
    {
        return columnDeckKey(sceneKey: sceneDeckKeyPrefix + sceneId, columnId: columnId)
    }
    return columnDeckKey(for: monitor.physicalMonitor.defaultWorkspaceViewport)
}

extension WindowDetectedCallback {
    @MainActor
    func matches(_ window: Window) async throws -> Bool {
        try await matcher.matches(window)
    }
}

extension WindowDetectedCallbackMatcher {
    @MainActor
    func matches(_ window: Window) async throws -> Bool {
        try await evaluate(window).matched
    }
}
