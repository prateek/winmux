import AppKit
import Common

final class MacWindow: Window {
    let macApp: MacApp
    private var prevUnhiddenProportionalPositionInsideWorkspaceRect: CGPoint?
    /// The corner the window is parked in, together with the monitor rect it was parked
    /// against: when the monitor's geometry changes (or the workspace moves to another
    /// monitor), the old corner position is wrong and the window must be re-parked even
    /// though the corner still matches. One value so the two can't desync.
    private var hiddenInCorner: (corner: OptimalHideCorner, monitorVisibleRect: Rect)?
    var hiddenOnMonitorVisibleRect: Rect? { hiddenInCorner?.monitorVisibleRect }

    @MainActor
    private init(_ id: UInt32, _ actor: MacApp, lastFloatingSize: CGSize?, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) {
        self.macApp = actor
        super.init(id: id, actor, lastFloatingSize: lastFloatingSize, parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @MainActor static var allWindowsMap: [UInt32: MacWindow] = [:]
    @MainActor static var allWindows: [MacWindow] { Array(allWindowsMap.values) }

    @MainActor
    @discardableResult
    static func getOrRegister(windowId: UInt32, macApp: MacApp) async throws -> MacWindow? {
        if let existing = allWindowsMap[windowId] {
            // No AX round-trip for known windows: this runs for every window on every refresh
            // barrier, and lastKnownActualRect stays correct without polling because moved /
            // resized AX events invalidate it and consumers re-fetch on demand.
            return existing
        }
        let rect = try await macApp.getAxRect(windowId)
        let detectedWorkspace = isStartup
            ? (rect?.center.monitorApproximation ?? mainMonitor).activeWorkspace
            : focus.workspace
        let windowType = try await macApp.getAxUiElementWindowType(windowId, getWindowLevel(for: windowId))
        let data = BindingData(parent: windowType == .popup ? macosPopupWindowsContainer : detectedWorkspace,
                               adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)

        // atomic synchronous section
        if let existing = allWindowsMap[windowId] { return existing }
        recordStartupWindowFrame(windowId, rect: rect, atStartup: isRecordingStartupWindowFrames,
            isPopup: data.parent === macosPopupWindowsContainer)
        let window = MacWindow(windowId, macApp, lastFloatingSize: rect?.size, parent: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
        window.recordAuthoritativeActualRect(rect)
        allWindowsMap[windowId] = window
        WindowScreenshot.invalidateWindowList()
        // A window that is gone can come back only while the closed-windows cache remembers it.
        forgetWindowsExcept(closedWindowsCacheWindowIds.union(allWindowsMap.keys))

        try await debugWindowsIfRecording(window)
        let didRestorePersistedFrozenWorld = try await restorePersistedFrozenWorldIfNeeded(newlyDetectedWindow: window)
        let didRestoreClosedWindowsCache = try await restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: window)
        if !didRestorePersistedFrozenWorld && !didRestoreClosedWindowsCache {
            try await ColumnPolicy.arrive(window, on: detectedWorkspace,
                floatingDefault: windowType == .dialog || !config.automaticallyTileNewWindows)
            // A popup is announced when it is promoted to a window, as upstream announced it.
            if windowType != .popup {
                broadcastEvent(.windowDetected(windowId: window.windowId, workspace: window.nodeWorkspace?.name,
                    appBundleId: window.app.rawAppBundleId, appName: window.app.name))
            }
        }

        return window
    }

    // var description: String {
    //     let description = [
    //         ("title", title),
    //         ("role", axWindow.get(Ax.roleAttr)),
    //         ("subrole", axWindow.get(Ax.subroleAttr)),
    //         ("identifier", axWindow.get(Ax.identifierAttr)),
    //         ("modal", axWindow.get(Ax.modalAttr).map { String($0) } ?? ""),
    //         ("windowId", String(windowId)),
    //     ].map { "\($0.0): '\(String(describing: $0.1))'" }.joined(separator: ", ")
    //     return "Window(\(description))"
    // }

    @MainActor override var nativeWindowType: AxUiElementWindowType {
        get async throws { try await macApp.getAxUiElementWindowType(windowId, getWindowLevel(for: windowId)) }
    }

    func isWindowHeuristic(_ windowLevel: MacOsWindowLevel?) async throws -> Bool { // todo cache
        try await macApp.isWindowHeuristic(windowId, windowLevel)
    }

    func isDialogHeuristic(_ windowLevel: MacOsWindowLevel?) async throws -> Bool { // todo cache
        try await macApp.isDialogHeuristic(windowId, windowLevel)
    }

    func dumpAxInfo() async throws -> [String: Json] {
        try await macApp.dumpWindowAxInfo(windowId: windowId)
    }

    override func setNativeFullscreen(_ value: Bool) {
        macApp.setNativeFullscreen(windowId, value)
    }

    func setNativeMinimized(_ value: Bool) {
        macApp.setNativeMinimized(windowId, value)
    }

    // skipClosedWindowsCache is an optimization when it's definitely not necessary to cache closed window.
    //                        If you are unsure, it's better to pass `false`
    @MainActor
    func garbageCollect(skipClosedWindowsCache: Bool) {
        if MacWindow.allWindowsMap.removeValue(forKey: windowId) == nil {
            return
        }
        SwitcherPalettePanel.shared.stripWindowClosed(windowId)
        ThumbnailCache.shared.closeWindow(self)
        WindowScreenshot.invalidateWindowList()
        if !skipClosedWindowsCache { cacheClosedWindowIfNeeded() }
        unbindAndFocusAfterClosure()
    }

    @MainActor override var title: String { get async throws { try await macApp.getAxTitle(windowId) ?? "" } }
    @MainActor override var cgWindowLevel: Int { getWindowLevel(for: windowId)?.cgWindowLevel ?? 0 }
    @MainActor override func readAxRecordAttributes(buttons: Bool) async throws -> WindowAxRecordAttributes? {
        try await macApp.getAxRecordAttributes(windowId, buttons: buttons)
    }
    @MainActor override var isMacosFullscreen: Bool { get async throws { try await macApp.isMacosNativeFullscreen(windowId) == true } }
    @MainActor override var isMacosMinimized: Bool { get async throws { try await macApp.isMacosNativeMinimized(windowId) == true } }

    @MainActor
    override func nativeFocus() {
        macApp.nativeFocus(windowId)
    }

    @MainActor
    override func requestClose(timeout: TimeInterval, tabStripSession: RunSessionGuard? = nil) async -> WindowCloseConfirmation {
        guard await windowCloseSession(tabStripSession, body: {
            await self.macApp.pressCloseButton(self.windowId)
        }) == .closed else { return .refused }
        return await confirmWindowClose(
            timeout: timeout,
            isPresent: { try? await self.macApp.containsAxWindow(self.windowId) },
            hasSheet: {
                guard tabStripSession != nil else { return false }
                return (try? await self.macApp.windowHasSheet(self.windowId)) == true
            },
            collect: {
                await windowCloseSession(tabStripSession) {
                    self.garbageCollect(skipClosedWindowsCache: true)
                }
            },
        )
    }

    @MainActor
    func requestCloseForProjectDeletion(timeout: TimeInterval = 1.5) async -> Bool {
        await requestClose(timeout: timeout) == .gone
    }

    @MainActor
    override func closeAxWindow() async -> WindowCloseResult {
        let result = await macApp.pressCloseButton(windowId, unregisterOnSuccess: true)
        if result == .closed { garbageCollect(skipClosedWindowsCache: true) }
        return result
    }

    // todo it's part of the window layout and should be moved to layoutRecursive.swift
    @MainActor
    func hideInCorner(_ corner: OptimalHideCorner, force: Bool = false) async throws {
        guard let nodeMonitor else { return }
        if !force, isHiddenInCorner, hiddenInCorner?.corner == corner,
           hiddenInCorner?.monitorVisibleRect == nodeMonitor.visibleRect
        {
            return
        }
        // Don't accidentally override prevUnhiddenEmulationPosition in case of subsequent `hideInCorner` calls
        if !isHiddenInCorner {
            guard let windowRect = try await getAxRect() else { return }
            // Check for isHiddenInCorner for the second time because of the suspension point above
            if !isHiddenInCorner {
                miniatureFrame = windowRect.cgRect
                ThumbnailCache.shared.request(self)
                let topLeftCorner = windowRect.topLeftCorner
                let monitorRect = windowRect.center.monitorApproximation.rect // Similar to layoutFloatingWindow. Non idempotent
                let absolutePoint = topLeftCorner - monitorRect.topLeftCorner
                prevUnhiddenProportionalPositionInsideWorkspaceRect =
                    CGPoint(x: absolutePoint.x / monitorRect.width, y: absolutePoint.y / monitorRect.height)
            }
        }
        let p: CGPoint
        switch corner {
            case .bottomLeftCorner:
                guard let s = try await getAxSize() else { fallthrough }
                // Zoom will jump off if you do one pixel offset https://github.com/nikitabobko/WinMux/issues/527
                // todo this ad hoc won't be necessary once I implement optimization suggested by Zalim
                let onePixelOffset = macApp.appId == .zoom ? .zero : CGPoint(x: 1, y: -1)
                p = nodeMonitor.visibleRect.bottomLeftCorner + onePixelOffset + CGPoint(x: -s.width, y: 0)
            case .bottomRightCorner:
                // Zoom will jump off if you do one pixel offset https://github.com/nikitabobko/WinMux/issues/527
                // todo this ad hoc won't be necessary once I implement optimization suggested by Zalim
                let onePixelOffset = macApp.appId == .zoom ? .zero : CGPoint(x: 1, y: 1)
                p = nodeMonitor.visibleRect.bottomRightCorner - onePixelOffset
        }
        setAxFrame(p, nil)
        hiddenInCorner = (corner, nodeMonitor.visibleRect)
    }

    @MainActor
    func unhideFromCorner() {
        guard let prevUnhiddenProportionalPositionInsideWorkspaceRect else { return }
        guard let nodeWorkspace else { return } // hiding only makes sense for workspace windows
        guard let parent else { return }

        func restoreToSavedWorkspacePosition() {
            let frame = restoredFloatingWindowFrame(proportion: prevUnhiddenProportionalPositionInsideWorkspaceRect,
                size: lastKnownActualRect?.size ?? lastFloatingSize ?? .zero, in: nodeWorkspace.workspaceMonitor.rect.cgRect)
            setAxFrame(frame.origin, nil)
        }

        switch getChildParentRelation(child: self, parent: parent) {
            // Just a small optimization to avoid unnecessary AX calls for non floating windows
            // Tiling windows should be unhidden with layoutRecursive anyway
            case .floatingWindow:
                restoreToSavedWorkspacePosition()
            case .macosNativeFullscreenWindow, .macosNativeHiddenAppWindow, .macosNativeMinimizedWindow,
                 .macosPopupWindow, .tiling, .rootTilingContainer, .shimContainerRelation: break
        }

        self.prevUnhiddenProportionalPositionInsideWorkspaceRect = nil
        self.hiddenInCorner = nil
    }

    override var savedProportionalPosition: CGPoint? { prevUnhiddenProportionalPositionInsideWorkspaceRect }

    override var isHiddenInCorner: Bool {
        prevUnhiddenProportionalPositionInsideWorkspaceRect != nil
    }

    override func getAxSize() async throws -> CGSize? {
        try await macApp.getAxSize(windowId)
    }

    override func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?) {
        macApp.setAxFrame(windowId, topLeft, size)
    }

    func setAxFrameBlocking(_ topLeft: CGPoint?, _ size: CGSize?) async throws {
        try await macApp.setAxFrameBlocking(windowId, topLeft, size)
    }

    @MainActor
    override func getAxRect() async throws -> Rect? {
        let observationToken = await nativeStateObservationToken()
        let rect = try await macApp.getAxRect(windowId)
        let windowId = self.windowId
        await MainActor.run {
            Window.get(byId: windowId)?.recordObservedActualRect(rect, token: observationToken)
        }
        return rect
    }
}
