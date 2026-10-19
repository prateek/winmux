@MainActor
func updateDetachedTabFromTabStrip(_ windowId: UInt32) {
    guard let window = Window.get(byId: windowId) else {
        clearPendingWindowDragIntent()
        cancelManipulatedWithMouseState()
        return
    }
    startTabStripWindowMove(window: window, subject: .window, detachOrigin: .tabStrip)
}

@MainActor
func updateMoveFromTabStrip(_ windowId: UInt32, containerIdentity: UInt64) {
    guard let window = Window.get(byId: windowId) else {
        clearPendingWindowDragIntent()
        cancelManipulatedWithMouseState()
        return
    }
    if shouldDeferWindowTabStripGroupDragToDetachedTabDrag() {
        return
    }
    guard dragSubjectNode(for: window, subject: .group(containerIdentity)) != nil else {
        clearPendingWindowDragIntent()
        cancelManipulatedWithMouseState()
        return
    }
    startTabStripWindowMove(window: window, subject: .group(containerIdentity), detachOrigin: .tabStrip)
}

@MainActor
func finishMoveFromTabStrip() {
    guard shouldHandleWindowTabStripGroupDragEnd() else { return }
    Task { @MainActor in
        try? await resetManipulatedWithMouseIfPossible()
    }
}

@MainActor
private func startTabStripWindowMove(window: Window, subject: WindowDragSubject, detachOrigin: TabDetachOrigin) {
    beginWindowMoveWithMouseSessionIfNeeded(
        windowId: window.windowId,
        subject: subject,
        detachOrigin: detachOrigin,
        startedInSidebar: false,
        anchorRect: resolvedDraggedWindowAnchorRect(for: window, subject: subject),
        refreshActualRects: true,
    )
    WindowMouseInteractionDriver.shared.startMove(
        windowId: window.windowId,
        subject: subject,
        detachOrigin: detachOrigin,
        startedInSidebar: false,
    )
}
