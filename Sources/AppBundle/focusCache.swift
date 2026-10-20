import Common
import Foundation

@MainActor private var lastKnownNativeFocusedWindowId: UInt32? = nil

@MainActor private struct WorkspaceProjectFocusHold {
    let projectId: WorkspaceProjectId
    let expiresAt: Date
}

@MainActor private var workspaceProjectFocusHold: WorkspaceProjectFocusHold? = nil

/// A window in macOS native fullscreen that a refresh read as macOS's focused window. `focus` never
/// points at one, so this stands in for it until the next refresh or until `setFocus` moves focus.
@MainActor private var nativeFullscreenInFrontId: UInt32? = nil

/// The window the person is in: a window in macOS native fullscreen that macOS has focused, and
/// otherwise `focus`'s window.
@MainActor var windowInFront: Window? {
    nativeFullscreenInFrontId.flatMap { Window.get(byId: $0) } ?? focus.windowOrNil
}

@MainActor func forgetNativeFullscreenInFront() {
    nativeFullscreenInFrontId = nil
}

@MainActor
func resetFocusCacheForTests() {
    lastKnownNativeFocusedWindowId = nil
    nativeFullscreenInFrontId = nil
    workspaceProjectFocusHold = nil
}

@MainActor
func holdFocusOnWorkspaceProject(_ projectId: WorkspaceProjectId, for duration: TimeInterval) {
    workspaceProjectFocusHold = WorkspaceProjectFocusHold(
        projectId: projectId,
        expiresAt: Date().addingTimeInterval(duration),
    )
}

@MainActor
func clearFocusOnWorkspaceProjectHold(_ projectId: WorkspaceProjectId? = nil) {
    guard projectId == nil || workspaceProjectFocusHold?.projectId == projectId else { return }
    workspaceProjectFocusHold = nil
}

@MainActor
private func activeWorkspaceProjectFocusHold(now: Date = .now) -> WorkspaceProjectFocusHold? {
    guard let hold = workspaceProjectFocusHold else { return nil }
    if hold.expiresAt <= now {
        workspaceProjectFocusHold = nil
        return nil
    }
    return hold
}

@MainActor
private func shouldIgnoreNativeFocusDuringProjectHold(_ nativeFocused: Window?) -> Bool {
    guard let hold = activeWorkspaceProjectFocusHold(),
          let nativeFocused
    else {
        return false
    }
    return nativeFocused.visualWorkspace?.projectId != hold.projectId
}

/// The data should flow (from nativeFocused to focused) and
///                      (from nativeFocused to lastKnownNativeFocusedWindowId)
/// Alternative names: takeFocusFromMacOs, syncFocusFromMacOs
@MainActor func updateFocusCache(_ nativeFocused: Window?) {
    ThumbnailCache.shared.recordNativeFocus(nativeFocused)
    if nativeFocused?.parent is MacosPopupWindowsContainer {
        return
    }
    let lastKnownNativeFocusedWindowIdBefore = lastKnownNativeFocusedWindowId
    if shouldIgnoreNativeFocusDuringProjectHold(nativeFocused) {
        lastKnownNativeFocusedWindowId = nil
        debugFocusLog(
            "updateFocusCache ignoredProjectHold event=\(refreshSessionEvent.prettyDescription) nativeFocused=\(nativeFocused?.windowId.description ?? "nil") lastKnownNative=\(lastKnownNativeFocusedWindowIdBefore?.description ?? "nil") heldProject=\(activeWorkspaceProjectFocusHold()?.projectId.rawValue ?? "nil") logicalFocus=\(debugDescribe(focus))"
        )
        return
    }
    if nativeFocused?.windowId != lastKnownNativeFocusedWindowId {
        _ = nativeFocused?.focusWindow()
        lastKnownNativeFocusedWindowId = nativeFocused?.windowId
    }
    nativeFullscreenInFrontId = nativeFocused?.parent is MacosFullscreenWindowsContainer ? nativeFocused?.windowId : nil
    nativeFocused?.recordConfirmedFocus()
    (nativeFocused?.app as? MacApp)?.lastNativeFocusedWindowId = nativeFocused?.windowId
    debugFocusLog(
        "updateFocusCache event=\(refreshSessionEvent.prettyDescription) nativeFocused=\(nativeFocused?.windowId.description ?? "nil") lastKnownNative=\(lastKnownNativeFocusedWindowIdBefore?.description ?? "nil") -> \(lastKnownNativeFocusedWindowId?.description ?? "nil") logicalFocus=\(debugDescribe(focus))"
    )
}
