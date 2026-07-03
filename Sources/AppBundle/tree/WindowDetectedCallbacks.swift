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
    for (index, affinity) in config.zoneAffinities.enumerated() {
        let evaluation = try await affinity.evaluate(index: index, window: window)
        guard evaluation.matched else { continue }
        let commandResult = try await MoveNodeToZoneCommand(args: affinity.commandArgs).run(.defaultEnv.copy(\.windowId, window.windowId), .emptyStdin)
        if commandResult.exitCode == 0 && !affinity.checkFurtherCallbacks {
            return
        }
    }
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
    if let display = window.nodeMonitor {
        winMuxWorkspaceState.deckColumnKeyHintsByCardName[cardName] = ruleCardColumnDeckKey(onDisplay: display)
    }
    return Workspace.get(byName: cardName)
}

/// The deck key of the active scene's default column on a display. Falls back to the display's
/// implicit column when no scene is active (the laptop case).
@MainActor
func ruleCardColumnDeckKey(onDisplay monitor: Monitor) -> String {
    if let sceneId = activeSceneId(for: monitor),
       let scene = config.scenes.first(where: { $0.id == sceneId }),
       let layout = config.zoneLayouts.first(where: { $0.id == scene.layoutId }),
       let columnId = scene.defaultColumn ?? layout.columns.first?.id
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

extension ZoneAffinityConfig {
    var commandArgs: MoveNodeToZoneCmdArgs {
        MoveNodeToZoneCmdArgs(zone: zone.orDie("Zone affinity should have a parsed zone target"))
            .copy(\.focusFollowsWindow, focusFollowsWindow)
            .copy(\.failIfNoop, failIfNoop)
    }

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
