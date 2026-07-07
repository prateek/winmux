import AppKit
import Common

private struct ColumnDividerDragSession {
    let handle: ColumnDividerHandle
    let startPoint: CGPoint
}

enum ColumnDividerMouseDownSource {
    case ambient
    case dividerChrome
}

@MainActor
final class ColumnDividerDragController {
    static let shared = ColumnDividerDragController()

    private let hitSlop: CGFloat = 16
    private var session: ColumnDividerDragSession?

    // Live window frames may only be captured off the input path (see the plan's input-path
    // rule). Hovering a divider always precedes an ambient click on it, so the snapshot taken
    // on hover is fresh by mouse-down time.
    private static let liveFramesSnapshotLifetime: TimeInterval = 1.0
    private var liveFramesSnapshot: (frames: [UInt32: Rect], capturedAt: TimeInterval)?
    private var liveFramesRefreshInFlight = false

    private var liveFramesSnapshotIfFresh: [UInt32: Rect]? {
        guard let snapshot = liveFramesSnapshot,
              ProcessInfo.processInfo.systemUptime - snapshot.capturedAt < Self.liveFramesSnapshotLifetime
        else { return nil }
        return snapshot.frames
    }

    private func refreshLiveFramesSnapshotIfStale() {
        guard !liveFramesRefreshInFlight, liveFramesSnapshotIfFresh == nil else { return }
        liveFramesRefreshInFlight = true
        Task.detached(priority: .userInitiated) {
            let frames = liveOnScreenWindowFramesById()
            let capturedAt = ProcessInfo.processInfo.systemUptime
            await MainActor.run {
                ColumnDividerDragController.shared.liveFramesSnapshot = (frames, capturedAt)
                ColumnDividerDragController.shared.liveFramesRefreshInFlight = false
            }
        }
    }

    private init() {}

    var isDragging: Bool {
        session != nil
    }

    @discardableResult
    func updateHover(at point: CGPoint) -> Bool {
        guard session == nil, TrayMenuModel.shared.isEnabled, isDragAllowed else {
            if session == nil {
                ColumnDividerOverlayPanelController.shared.hide(after: 0.08)
            }
            return false
        }
        guard let handle = columnDividerHandle(at: point, hitSlop: hitSlop) else {
            ColumnDividerOverlayPanelController.shared.hide(after: 0.08)
            return false
        }
        refreshLiveFramesSnapshotIfStale()
        show(handle: handle, state: .hover, deltaPixels: 0)
        return true
    }

    /// Hide any lingering hover chrome when a mode change revokes divider interactivity.
    func noteModeChanged() {
        if !isDragAllowed {
            cancel()
        }
    }

    private var isDragAllowed: Bool {
        isColumnDividerDragAllowed(policy: config.mouse.columnDividerDrag, activeMode: activeMode)
    }

    @discardableResult
    func handleMouseDown(
        at point: CGPoint,
        source: ColumnDividerMouseDownSource = .ambient,
    ) -> Bool {
        guard TrayMenuModel.shared.isEnabled,
              isDragAllowed,
              session == nil,
              let handle = columnDividerHandle(at: point, hitSlop: hitSlop)
        else { return false }
        guard source == .dividerChrome || !isPointInsideKnownWindowFrame(point, liveFrames: liveFramesSnapshotIfFresh) else {
            logWindowDragLive(
                "zoneDivider.start skipped reason=window-content point=\(point) boundary=\(handle.boundaryX)"
            )
            return false
        }

        clearPendingWindowDragIntent()
        WindowDropIntentOverlayPanelController.shared.hide()
        WindowResizePreviewPanel.shared.hide(reason: "zoneDivider.start")
        setCurrentMouseManipulationKind(.columnDivider)
        session = ColumnDividerDragSession(handle: handle, startPoint: point)
        logWindowDragLive(
            "zoneDivider.start left=\(handle.leftColumnId) right=\(handle.rightColumnId) boundary=\(handle.boundaryX) point=\(point)"
        )
        show(handle: handle, state: .dragging, deltaPixels: 0)
        return true
    }

    @discardableResult
    func handleMouseDragged(at point: CGPoint) -> Bool {
        guard let session else { return false }
        show(
            handle: session.handle,
            state: .dragging,
            deltaPixels: point.x - session.startPoint.x,
        )
        logWindowDragLive(
            "zoneDivider.drag left=\(session.handle.leftColumnId) right=\(session.handle.rightColumnId) delta=\(point.x - session.startPoint.x) point=\(point)"
        )
        return true
    }

    @discardableResult
    func handleMouseUp(at point: CGPoint) -> Bool {
        guard let session else {
            updateHover(at: point)
            return false
        }

        defer {
            self.session = nil
            setCurrentMouseManipulationKind(.none)
        }

        let deltaPixels = point.x - session.startPoint.x
        switch moveColumnDivider(
            on: session.handle.physicalMonitor,
            leftColumnId: session.handle.leftColumnId,
            rightColumnId: session.handle.rightColumnId,
            deltaPixels: deltaPixels,
        ) {
            case .failure(let message):
                logWindowDragLive(
                    "zoneDivider.commit failed left=\(session.handle.leftColumnId) right=\(session.handle.rightColumnId) delta=\(deltaPixels) error=\(message)"
                )
                ColumnDividerOverlayPanelController.shared.hide(after: 0.2)
            case .success(let result):
                logWindowDragLive(
                    "zoneDivider.commit left=\(result.leftColumnId) right=\(result.rightColumnId) requestedDelta=\(result.requestedDeltaPixels) appliedDelta=\(result.appliedDeltaPixels) oldBoundary=\(result.oldBoundaryX) newBoundary=\(result.newBoundaryX)"
                )
                showCommitted(session: session, result: result)
                scheduleRefreshSession(.resetManipulatedWithMouse, optimisticallyPreLayoutWorkspaces: true)
        }
        return true
    }

    func cancel() {
        session = nil
        if getCurrentMouseManipulationKind() == .columnDivider {
            setCurrentMouseManipulationKind(.none)
        }
        ColumnDividerOverlayPanelController.shared.hide()
    }

    func setLiveFramesSnapshotForTests(_ frames: [UInt32: Rect]?) {
        liveFramesSnapshot = frames.map { ($0, ProcessInfo.processInfo.systemUptime) }
    }

    private func show(
        handle: ColumnDividerHandle,
        state: ColumnDividerOverlayState,
        deltaPixels: CGFloat,
    ) {
        let preview = previewColumnDividerMove(
            on: handle.physicalMonitor,
            leftColumnId: handle.leftColumnId,
            rightColumnId: handle.rightColumnId,
            deltaPixels: deltaPixels,
        ).getOrNil()
        ColumnDividerOverlayPanelController.shared.show(ColumnDividerOverlayModel(
            workspaceRect: handle.workspaceRect,
            boundaryX: preview?.newBoundaryX ?? handle.boundaryX,
            leftName: handle.leftColumnName ?? handle.leftColumnId,
            rightName: handle.rightColumnName ?? handle.rightColumnId,
            leftShare: preview?.leftAfterShare,
            rightShare: preview?.rightAfterShare,
            state: state,
        ))
    }

    private func showCommitted(session: ColumnDividerDragSession, result: ColumnDividerChangeResult) {
        let enabledWidths = result.widths.filter(\.isEnabled)
        let enabledTotal = enabledWidths.reduce(0.0) { $0 + $1.effectiveWidth }
        let leftShare = enabledTotal > 0
            ? enabledWidths.first { $0.columnId == result.leftColumnId }.map { $0.effectiveWidth / enabledTotal }
            : nil
        let rightShare = enabledTotal > 0
            ? enabledWidths.first { $0.columnId == result.rightColumnId }.map { $0.effectiveWidth / enabledTotal }
            : nil

        ColumnDividerOverlayPanelController.shared.show(ColumnDividerOverlayModel(
            workspaceRect: session.handle.workspaceRect,
            boundaryX: result.newBoundaryX,
            leftName: result.leftColumnName ?? result.leftColumnId,
            rightName: result.rightColumnName ?? result.rightColumnId,
            leftShare: leftShare,
            rightShare: rightShare,
            state: .committed,
        ))
        ColumnDividerOverlayPanelController.shared.hide(after: 0.85)
    }
}

func isColumnDividerDragAllowed(policy: ColumnDividerDragPolicy, activeMode: String?) -> Bool {
    switch policy {
        case .always: true
        case .off: false
        case .columnMode: activeMode == zoneModeId
    }
}

/// Chooses the refresh event for a global left mouse up. The barrier exists for clicks that land
/// on windows (close-button presses AX never reports, delayed new-window pickup), so a click the
/// cache can prove missed every window may skip it. The proof must fail SAFE: a window with no
/// cached rect at all (floating/fullscreen windows lose them on AX timeouts) makes the click
/// unclassifiable and keeps the barrier.
@MainActor
func mouseUpRefreshEvent(at point: CGPoint) -> RefreshSessionEvent {
    let provablyOutsideAllWindows = Workspace.all
        .filter(\.isVisible)
        .flatMap(\.allLeafWindowsRecursive)
        .allSatisfy { window in
            guard !window.isHiddenInCorner else { return true }
            let rects = [
                window.lastKnownActualRect,
                window.lastAppliedLayoutPhysicalRect,
                window.lastAppliedLayoutVirtualRect,
            ].compactMap { $0 }
            return !rects.isEmpty && !rects.contains { $0.contains(point) }
        }
    return provablyOutsideAllWindows ? .globalObserverLeftMouseUpOutsideWindows : .globalObserverLeftMouseUp
}

@MainActor
func cachedWindowFrameCandidates(at point: CGPoint) -> [Window] {
    Workspace.all
        .filter(\.isVisible)
        .flatMap(\.allLeafWindowsRecursive)
        .filter { window in
            guard !window.isHiddenInCorner else { return false }
            return [window.lastKnownActualRect, window.lastAppliedLayoutPhysicalRect]
                .compactMap { $0 }
                .contains { $0.contains(point) }
        }
}

@MainActor
private func isPointInsideKnownWindowFrame(_ point: CGPoint, liveFrames: [UInt32: Rect]?) -> Bool {
    let candidates = cachedWindowFrameCandidates(at: point)
    guard !candidates.isEmpty else { return false }
    return candidates.contains { window in
        if let frame = window.currentFrameForHitTesting() {
            return frame.contains(point)
        }
        // Without a fresh snapshot, trust the cached candidate: a spurious veto only delays a
        // divider drag by one hover cycle, while a spurious pass would start a drag through a
        // window the user meant to click.
        guard let liveFrames else { return true }
        return liveFrames[window.windowId]?.contains(point) == true
    }
}

private func liveOnScreenWindowFramesById() -> [UInt32: Rect] {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windowInfos = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] else {
        return [:]
    }
    return windowInfos.reduce(into: [:]) { result, info in
        guard let windowId = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
              let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue,
              layer == 0,
              let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue,
              alpha > 0.01,
              let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
              bounds.width > 8,
              bounds.height > 8
        else {
            return
        }
        result[windowId] = Rect(
            topLeftX: bounds.minX,
            topLeftY: bounds.minY,
            width: bounds.width,
            height: bounds.height,
        )
    }
}
