import AppKit

private struct ZoneDividerDragSession {
    let handle: ZoneDividerHandle
    let startPoint: CGPoint
}

enum ZoneDividerMouseDownSource {
    case ambient
    case dividerChrome
}

@MainActor
final class ZoneDividerDragController {
    static let shared = ZoneDividerDragController()

    private let hitSlop: CGFloat = 16
    private var session: ZoneDividerDragSession?

    private init() {}

    var isDragging: Bool {
        session != nil
    }

    @discardableResult
    func updateHover(at point: CGPoint) -> Bool {
        guard session == nil, TrayMenuModel.shared.isEnabled else {
            if session == nil {
                ZoneDividerOverlayPanelController.shared.hide(after: 0.08)
            }
            return false
        }
        guard let handle = zoneDividerHandle(at: point, hitSlop: hitSlop) else {
            ZoneDividerOverlayPanelController.shared.hide(after: 0.08)
            return false
        }
        show(handle: handle, state: .hover, deltaPixels: 0)
        return true
    }

    @discardableResult
    func handleMouseDown(
        at point: CGPoint,
        source: ZoneDividerMouseDownSource = .ambient,
    ) -> Bool {
        guard TrayMenuModel.shared.isEnabled,
              session == nil,
              let handle = zoneDividerHandle(at: point, hitSlop: hitSlop)
        else { return false }
        guard source == .dividerChrome || !isPointInsideKnownWindowFrame(point) else {
            logWindowDragLive(
                "zoneDivider.start skipped reason=window-content point=\(point) boundary=\(handle.boundaryX)"
            )
            return false
        }

        clearPendingWindowDragIntent()
        WindowDropIntentOverlayPanelController.shared.hide()
        WindowResizePreviewPanel.shared.hide(reason: "zoneDivider.start")
        setCurrentMouseManipulationKind(.zoneDivider)
        session = ZoneDividerDragSession(handle: handle, startPoint: point)
        logWindowDragLive(
            "zoneDivider.start left=\(handle.leftZoneId) right=\(handle.rightZoneId) boundary=\(handle.boundaryX) point=\(point)"
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
            "zoneDivider.drag left=\(session.handle.leftZoneId) right=\(session.handle.rightZoneId) delta=\(point.x - session.startPoint.x) point=\(point)"
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
        switch moveZoneDivider(
            on: session.handle.physicalMonitor,
            leftZoneId: session.handle.leftZoneId,
            rightZoneId: session.handle.rightZoneId,
            deltaPixels: deltaPixels,
        ) {
            case .failure(let message):
                logWindowDragLive(
                    "zoneDivider.commit failed left=\(session.handle.leftZoneId) right=\(session.handle.rightZoneId) delta=\(deltaPixels) error=\(message)"
                )
                ZoneDividerOverlayPanelController.shared.hide(after: 0.2)
            case .success(let result):
                logWindowDragLive(
                    "zoneDivider.commit left=\(result.leftZoneId) right=\(result.rightZoneId) requestedDelta=\(result.requestedDeltaPixels) appliedDelta=\(result.appliedDeltaPixels) oldBoundary=\(result.oldBoundaryX) newBoundary=\(result.newBoundaryX)"
                )
                showCommitted(session: session, result: result)
                scheduleRefreshSession(.resetManipulatedWithMouse, optimisticallyPreLayoutWorkspaces: true)
        }
        return true
    }

    func cancel() {
        session = nil
        if getCurrentMouseManipulationKind() == .zoneDivider {
            setCurrentMouseManipulationKind(.none)
        }
        ZoneDividerOverlayPanelController.shared.hide()
    }

    private func show(
        handle: ZoneDividerHandle,
        state: ZoneDividerOverlayState,
        deltaPixels: CGFloat,
    ) {
        let preview = previewZoneDividerMove(
            on: handle.physicalMonitor,
            leftZoneId: handle.leftZoneId,
            rightZoneId: handle.rightZoneId,
            deltaPixels: deltaPixels,
        ).getOrNil()
        ZoneDividerOverlayPanelController.shared.show(ZoneDividerOverlayModel(
            workspaceRect: handle.workspaceRect,
            boundaryX: preview?.newBoundaryX ?? handle.boundaryX,
            leftName: handle.leftZoneName ?? handle.leftZoneId,
            rightName: handle.rightZoneName ?? handle.rightZoneId,
            leftShare: preview?.leftAfterShare,
            rightShare: preview?.rightAfterShare,
            state: state,
        ))
    }

    private func showCommitted(session: ZoneDividerDragSession, result: ZoneDividerChangeResult) {
        let enabledWidths = result.widths.filter(\.isEnabled)
        let enabledTotal = enabledWidths.reduce(0.0) { $0 + $1.effectiveWidth }
        let leftShare = enabledTotal > 0
            ? enabledWidths.first { $0.zoneId == result.leftZoneId }.map { $0.effectiveWidth / enabledTotal }
            : nil
        let rightShare = enabledTotal > 0
            ? enabledWidths.first { $0.zoneId == result.rightZoneId }.map { $0.effectiveWidth / enabledTotal }
            : nil

        ZoneDividerOverlayPanelController.shared.show(ZoneDividerOverlayModel(
            workspaceRect: session.handle.workspaceRect,
            boundaryX: result.newBoundaryX,
            leftName: result.leftZoneName ?? result.leftZoneId,
            rightName: result.rightZoneName ?? result.rightZoneId,
            leftShare: leftShare,
            rightShare: rightShare,
            state: .committed,
        ))
        ZoneDividerOverlayPanelController.shared.hide(after: 0.85)
    }
}

@MainActor
private func isPointInsideKnownWindowFrame(_ point: CGPoint) -> Bool {
    let candidates = Workspace.all
        .filter(\.isVisible)
        .flatMap(\.allLeafWindowsRecursive)
        .filter { window in
            guard !window.isHiddenInCorner else { return false }
            return [window.lastKnownActualRect, window.lastAppliedLayoutPhysicalRect]
                .compactMap { $0 }
                .contains { $0.contains(point) }
        }
    guard !candidates.isEmpty else { return false }
    let liveFrames = liveOnScreenWindowFramesById()
    return candidates.contains { window in
        if let frame = window.currentFrameForHitTesting() {
            return frame.contains(point)
        }
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
