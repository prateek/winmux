import AppKit
import Common

func movedObs(_: AXObserver, ax: AXUIElement, notif: CFString, _: UnsafeMutableRawPointer?) {
    let windowId = ax.containingWindowId()
    let notif = notif as String
    Task { @MainActor in
        if shouldIgnoreMovedObsForCurrentDragSession(windowId: windowId) ||
            WindowMouseInteractionOpacityController.shared.shouldSuppressObserverEvent(windowId: windowId) ||
            shouldIgnoreAxObserverEventForPostDragSuppression(windowId: windowId, notif: notif)
        {
            return
        }
        guard let token: RunSessionGuard = .isServerEnabled else { return }
        guard let windowId, let window = Window.get(byId: windowId), try await isManipulatedWithMouse(window) else {
            scheduleRefreshSession(.ax(notif))
            return
        }
        Task {
            try checkCancellation()
            try await runLightSession(.ax(notif), token) {
                try await moveWithMouse(window)
            }
        }
    }
}

@MainActor
private func moveWithMouse(_ window: Window) async throws { // todo cover with tests
    syncClosedWindowsCacheToCurrentWorld()
    guard let parent = window.parent else { return }
    switch parent.cases {
        case .workspace:
            moveFloatingWindowWithMouse(window)
        case .tilingContainer:
            moveTilingWindow(window)
        case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
             .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer:
            return // Unconventional windows can't be moved with mouse
    }
}

@MainActor
func moveFloatingWindowWithMouse(_ window: Window) {
    let targetWorkspace = MousePointerTracker.shared.currentSample.point.monitorApproximation.activeWorkspace
    guard let parent = window.parent else { return }
    if targetWorkspace != parent {
        window.bindAsFloatingWindow(to: targetWorkspace)
    }
}

@MainActor
private func moveTilingWindow(_ window: Window) {
    let subject = resolvedMouseDragSubject(for: window)
    let anchorRect = resolvedDraggedWindowAnchorRect(for: window, subject: subject)
    let mouseLocation = MousePointerTracker.shared.currentSample.point
    let targetWorkspace = mouseLocation.monitorApproximation.activeWorkspace
    moveTilingWindowForMouseDrag(
        window: window,
        targetWorkspace: targetWorkspace,
        subject: subject,
        anchorRect: anchorRect,
        inputState: currentZoneSnapInputState(),
        beginSession: beginWindowMoveWithMouseSessionIfNeeded,
        startMove: WindowMouseInteractionDriver.shared.startMove,
    )
}

typealias BeginWindowMoveWithMouseSessionHandler = (
    _ windowId: UInt32,
    _ subject: WindowDragSubject,
    _ detachOrigin: TabDetachOrigin,
    _ startedInSidebar: Bool,
    _ anchorRect: Rect?,
    _ refreshActualRects: Bool
) -> Bool

typealias StartWindowMoveWithMouseHandler = (
    _ windowId: UInt32,
    _ subject: WindowDragSubject,
    _ detachOrigin: TabDetachOrigin,
    _ startedInSidebar: Bool
) -> Void

@MainActor
func moveTilingWindowForMouseDrag(
    window: Window,
    targetWorkspace: Workspace,
    subject: WindowDragSubject,
    anchorRect: Rect?,
    inputState: ZoneSnapInputState,
    beginSession: BeginWindowMoveWithMouseSessionHandler,
    startMove: StartWindowMoveWithMouseHandler,
) {
    if floatTilingWindowForMouseDragIfNeeded(
        window: window,
        targetWorkspace: targetWorkspace,
        subject: subject,
        inputState: inputState,
    ) {
        window.lastAppliedLayoutPhysicalRect = nil
        _ = beginSession(window.windowId, subject, .window, false, anchorRect, false)
        startMove(window.windowId, subject, .window, false)
        return
    }
    let didStartSession = beginSession(window.windowId, subject, .window, false, anchorRect, subject == .window)
    if didStartSession, subject == .window {
        window.lastAppliedLayoutPhysicalRect = nil
    }
    startMove(window.windowId, subject, .window, false)
}

@MainActor
@discardableResult
func floatTilingWindowForMouseDragIfNeeded(
    window: Window,
    targetWorkspace: Workspace,
    subject: WindowDragSubject,
    inputState: ZoneSnapInputState,
) -> Bool {
    guard subject == .window,
          window.parent is TilingContainer
    else { return false }

    let snapConfig = effectiveZoneSnapConfig(for: targetWorkspace.workspaceMonitor)
    guard snapConfig.policy == .floatUnlessSnap,
          snapConfig.target == .zone,
          targetWorkspace.workspaceMonitor.zoneId != nil,
          !zoneSnapActivationInputIsPressed(snapConfig, inputState: inputState)
    else { return false }

    window.bindAsFloatingWindow(to: targetWorkspace)
    return true
}

@MainActor
@discardableResult
func floatTilingWindowForMouseDragIfNeeded(
    window: Window,
    targetWorkspace: Workspace,
    subject: WindowDragSubject,
    modifierFlags: CGEventFlags,
    pressedMouseButtons: Int = 0,
) -> Bool {
    floatTilingWindowForMouseDragIfNeeded(
        window: window,
        targetWorkspace: targetWorkspace,
        subject: subject,
        inputState: ZoneSnapInputState(
            modifierFlags: modifierFlags,
            pressedMouseButtons: pressedMouseButtons,
        ),
    )
}

@MainActor
func moveTilingWindowForMouseDrag(
    window: Window,
    targetWorkspace: Workspace,
    subject: WindowDragSubject,
    anchorRect: Rect?,
    modifierFlags: CGEventFlags,
    pressedMouseButtons: Int = 0,
    beginSession: BeginWindowMoveWithMouseSessionHandler,
    startMove: StartWindowMoveWithMouseHandler,
) {
    moveTilingWindowForMouseDrag(
        window: window,
        targetWorkspace: targetWorkspace,
        subject: subject,
        anchorRect: anchorRect,
        inputState: ZoneSnapInputState(
            modifierFlags: modifierFlags,
            pressedMouseButtons: pressedMouseButtons,
        ),
        beginSession: beginSession,
        startMove: startMove,
    )
}

@MainActor
func swapWindows(_ window1: Window, _ window2: Window) {
    swapNodes(window1.moveNode, window2.moveNode)
}

@MainActor
func swapNodes(_ node1: TreeNode, _ node2: TreeNode) {
    if node1 == node2 { return }
    guard let index1 = node1.ownIndex else { return }
    guard let index2 = node2.ownIndex else { return }

    if index1 < index2 {
        let binding2 = node2.unbindFromParent()
        let binding1 = node1.unbindFromParent()

        node2.bind(to: binding1.parent, adaptiveWeight: binding1.adaptiveWeight, index: binding1.index)
        node1.bind(to: binding2.parent, adaptiveWeight: binding2.adaptiveWeight, index: binding2.index)
    } else {
        let binding1 = node1.unbindFromParent()
        let binding2 = node2.unbindFromParent()

        node1.bind(to: binding2.parent, adaptiveWeight: binding2.adaptiveWeight, index: binding2.index)
        node2.bind(to: binding1.parent, adaptiveWeight: binding1.adaptiveWeight, index: binding1.index)
    }
    node1.markAsMostRecentChild()
}

extension CGPoint {
    @MainActor
    func findIn(tree: TilingContainer, virtual: Bool) -> Window? {
        let point = self
        let target: TreeNode? = switch tree.layout {
            case .tiles:
                tree.children.first(where: {
                    (virtual ? $0.lastAppliedLayoutVirtualRect : $0.lastAppliedLayoutPhysicalRect)?.contains(point) == true
                })
            case .tabGroup:
                tree.mostRecentChild
        }
        guard let target else { return nil }
        return switch target.tilingTreeNodeCasesOrDie() {
            case .window(let window): window
            case .tilingContainer(let container): findIn(tree: container, virtual: virtual)
        }
    }
}
