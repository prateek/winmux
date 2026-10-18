import AppKit

@MainActor
final class MissionControlState {
    static let shared = MissionControlState()
    private(set) var isOpen = false

    private var observer: AXObserver?
    private var dockPid: pid_t?
    private var dockApplication: NSRunningApplication?
    private var finishedLaunchingObservation: NSKeyValueObservation?
    private var runningApplicationsObservation: NSKeyValueObservation?

    func receive(_ notification: String) {
        switch notification {
            case "AXExposeShowAllWindows", "AXExposeShowFrontWindows", "AXExposeShowDesktop": setOpen(true)
            case "AXExposeExit": setOpen(false)
            default: break
        }
    }

    private func setOpen(_ value: Bool) {
        guard isOpen != value else { return }
        isOpen = value
        WindowTabStripPanelController.shared.refresh()
        ColumnDividerPanelController.shared.refresh()
        FocusedEmptyColumnPanel.shared.refresh()
        WorkspaceSidebarPanel.refreshAll()
    }

    func dockDidExit() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        finishedLaunchingObservation = nil
        dockApplication = nil
        dockPid = nil
        setOpen(false)
    }

    func startObserving() {
        guard runningApplicationsObservation == nil else { return }
        runningApplicationsObservation = NSWorkspace.shared.observe(\.runningApplications, options: [.initial, .new]) { workspace, _ in
            let dock = workspace.runningApplications.first { $0.bundleIdentifier == "com.apple.dock" }
            Task { @MainActor in self.dockProcessChanged(to: dock) }
        }
    }

    private func dockProcessChanged(to dock: NSRunningApplication?) {
        guard dockPid != dock?.processIdentifier else { return }
        dockDidExit()
        guard let dock else { return }
        dockApplication = dock
        dockPid = dock.processIdentifier
        finishedLaunchingObservation = dock.observe(\.isFinishedLaunching, options: [.initial, .new]) { app, _ in
            let pid = app.processIdentifier
            let ready = app.isFinishedLaunching
            Task { @MainActor in
                guard self.dockPid == pid, ready, self.observer == nil else { return }
                self.attach(to: pid)
            }
        }
    }

    private func attach(to pid: pid_t) {
        guard let observer = AXObserver.new(pid, { observer, _, notification, _ in
            MainActor.assumeIsolated {
                let state = MissionControlState.shared
                guard state.observer == observer else { return }
                state.receive(notification as String)
            }
        }) else { return }
        let application = AXUIElementCreateApplication(pid)
        for name in ["AXExposeShowAllWindows", "AXExposeShowFrontWindows", "AXExposeShowDesktop", "AXExposeExit"] {
            guard AXObserverAddNotification(observer, application, name as CFString, nil) == .success else { return }
        }
        self.observer = observer
        dockPid = pid
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }
}
