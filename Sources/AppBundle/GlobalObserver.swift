import AppKit
import Common
import HotKey

enum GlobalObserver {
    @MainActor private static var isInitialized = false
    @MainActor private static var notificationObserverTokens: [NSObjectProtocol] = []
    @MainActor private static var eventMonitorTokens: [Any] = []

    private static func onNotif(_ notification: Notification) {
        // Third line of defence against lock screen window. See: closedWindowsCache
        // Second and third lines of defence are technically needed only to avoid potential flickering
        if (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == lockScreenAppBundleId {
            return
        }
        let notifName = notification.name.rawValue
        Task { @MainActor in
            if !TrayMenuModel.shared.isEnabled { return }
            if notifName == NSWorkspace.didActivateApplicationNotification.rawValue {
                scheduleRefreshSession(.globalObserver(notifName), optimisticallyPreLayoutWorkspaces: true)
            } else {
                scheduleRefreshSession(.globalObserver(notifName))
            }
        }
    }

    private static func onHideApp(_ notification: Notification) {
        let notifName = notification.name.rawValue
        Task { @MainActor in
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            try await runLightSession(.globalObserver(notifName), token) {
                if config.automaticallyUnhideMacosHiddenApps {
                    if let w = prevFocus?.windowOrNil,
                       w.macAppUnsafe.nsApp.isHidden,
                       // "Hide others" (cmd-alt-h) -> don't force focus
                       // "Hide app" (cmd-h) -> force focus
                       MacApp.allAppsMap.values.count(where: { $0.nsApp.isHidden }) == 1
                    {
                        // Force focus
                        _ = w.focusWindow()
                        w.nativeFocus()
                    }
                    for app in MacApp.allAppsMap.values {
                        app.nsApp.unhide()
                    }
                }
            }
        }
    }

    // NSEvent monitor callbacks arrive on the main thread. Running their bodies synchronously
    // instead of spawning a Task avoids an allocation + run-loop hop per input event — pointer
    // events fire at 60-120Hz, so the Task-per-event pattern adds constant latency and churn.
    private static func runOnMainActor(_ body: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated(body)
        } else {
            Task { @MainActor in body() }
        }
    }

    private static func onKeyDown(_ event: NSEvent) {
        runOnMainActor {
            noteTapBindingKeyDown()
        }
    }

    private static func onFlagsChanged(_ event: NSEvent) {
        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags
        runOnMainActor {
            noteTapBindingFlagsChanged(keyCode: keyCode, modifierFlags: modifierFlags)
        }
    }

    @discardableResult
    private static func onPointerActivity(_ event: NSEvent) -> Bool {
        let isLeftMouseDownEvent = event.type == .leftMouseDown
        let isMouseMovedEvent = event.type == .mouseMoved
        let timestamp = event.timestamp
        let screenPoint = NSEvent.mouseLocation
        let point = normalizeAppKitScreenPoint(screenPoint)
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                onPointerActivityMain(
                    point: point,
                    timestamp: timestamp,
                    isLeftMouseDownEvent: isLeftMouseDownEvent,
                    isMouseMovedEvent: isMouseMovedEvent,
                )
            }
        }
        Task { @MainActor in
            _ = onPointerActivityMain(
                point: point,
                timestamp: timestamp,
                isLeftMouseDownEvent: isLeftMouseDownEvent,
                isMouseMovedEvent: isMouseMovedEvent,
            )
        }
        return false
    }

    @MainActor
    private static func onPointerActivityMain(
        point: CGPoint,
        timestamp: TimeInterval,
        isLeftMouseDownEvent: Bool,
        isMouseMovedEvent: Bool,
    ) -> Bool {
        MousePointerTracker.shared.note(point: point, timestamp: timestamp)
        WorkspaceSidebarPanel.trapCursorForVisiblePanelsIfNeeded()
        var consumed = false
        if isLeftMouseDownEvent {
            consumed = ZoneDividerDragController.shared.handleMouseDown(at: point)
            if !consumed {
                Task { @MainActor in
                    await WindowMouseInteractionDriver.shared.capturePendingResizeCandidate()
                }
            }
        } else if isMouseMovedEvent {
            ZoneDividerDragController.shared.updateHover(at: point)
        }
        noteTapBindingKeyDown()
        return consumed
    }

    @MainActor
    static func initObserver() {
        guard !isInitialized else { return }
        isInitialized = true

        let nc = NSWorkspace.shared.notificationCenter
        notificationObserverTokens.append(nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main, using: onNotif))
        notificationObserverTokens.append(nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main, using: onNotif))
        notificationObserverTokens.append(nc.addObserver(forName: NSWorkspace.didHideApplicationNotification, object: nil, queue: .main, using: onHideApp))
        notificationObserverTokens.append(nc.addObserver(forName: NSWorkspace.didUnhideApplicationNotification, object: nil, queue: .main, using: onNotif))
        notificationObserverTokens.append(nc.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main, using: onNotif))
        notificationObserverTokens.append(nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: onNotif))
        notificationObserverTokens.append(nc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main, using: onNotif))
        notificationObserverTokens.append(nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main, using: onNotif))

        retainEventMonitor(NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { _ in
            // todo reduce number of refreshSession in the callback
            //  resetManipulatedWithMouseIfPossible might call its own refreshSession
            //  The end of the callback calls refreshSession
            Task { @MainActor in
                let mouseLocation = mouseLocation
                if ZoneDividerDragController.shared.handleMouseUp(at: mouseLocation) {
                    return
                }
                finishWorkspaceSidebarDragAfterGlobalMouseUp()
                guard let token: RunSessionGuard = .isServerEnabled else { return }
                try await resetManipulatedWithMouseIfPossible()
                let clickedMonitor = mouseLocation.monitorApproximation
                // The barrier refresh exists to catch close-button clicks on unfocused windows
                // (kAXUIElementDestroyedNotification is unreliable) and delayed new-window
                // detection — both require the click to land on a window. A click over empty
                // desktop can skip the barrier; the cached-frame check costs no AX. A stale
                // cache can misclassify at worst one click, and the next real window event
                // schedules a barrier refresh anyway.
                let mouseUpEvent: RefreshSessionEvent = cachedWindowFrameCandidates(at: mouseLocation).isEmpty
                    ? .globalObserverLeftMouseUpOutsideWindows
                    : .globalObserverLeftMouseUp
                switch true {
                    // Detect clicks on desktop of different monitors
                    case clickedMonitor.activeWorkspace != focus.workspace:
                        _ = try await runLightSession(mouseUpEvent, token) {
                            clickedMonitor.activeWorkspace.focusWorkspace()
                        }
                    default:
                        scheduleRefreshSession(mouseUpEvent)
                }
            }
        })

        retainEventMonitor(NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { event in
            let timestamp = event.timestamp
            let point = normalizeAppKitScreenPoint(NSEvent.mouseLocation)
            runOnMainActor {
                MousePointerTracker.shared.note(point: point, timestamp: timestamp)
                WorkspaceSidebarPanel.trapCursorForVisiblePanelsIfNeeded()
                if ZoneDividerDragController.shared.handleMouseDragged(at: point) {
                    return
                }
                refreshPendingWindowDragIntentFromGlobalMouseDrag()
            }
        })

        let pointerActivityMask: NSEvent.EventTypeMask = [
            .mouseMoved,
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .scrollWheel,
        ]
        retainEventMonitor(NSEvent.addGlobalMonitorForEvents(matching: pointerActivityMask) { event in
            _ = onPointerActivity(event)
        })
        retainEventMonitor(NSEvent.addLocalMonitorForEvents(matching: pointerActivityMask) { event in
            if onPointerActivity(event) {
                return nil
            }
            return event
        })

        retainEventMonitor(NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: onFlagsChanged))
        retainEventMonitor(NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            onFlagsChanged(event)
            return event
        })

        retainEventMonitor(NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: onKeyDown))
        retainEventMonitor(NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            onKeyDown(event)
            // Check if this key matches a recently-pressed prefix (sequence binding)
            if handleSequenceKeyDown(event: event) {
                return nil // consume the event
            }
            // If this is a sequence prefix key (e.g. Escape), arm the sequence detector
            if let prefix = Key(carbonKeyCode: UInt32(event.keyCode)),
               sequenceBindingsPrefixKeys.contains(prefix) {
                noteSequencePrefixKeyPressed(prefix)
            }
            if event.modifierFlags.contains(.control), event.keyCode == 34 {
                return nil // consume the event
            }
            return event
        })
    }

    @MainActor private static func retainEventMonitor(_ monitor: Any?) {
        guard let monitor else { return }
        eventMonitorTokens.append(monitor)
    }
}
