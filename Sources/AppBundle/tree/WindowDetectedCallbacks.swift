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
