import AppKit

@MainActor
final class MonitorConfigurationObserver {
    static let shared = MonitorConfigurationObserver()

    private var observer: NSObjectProtocol?
    private var screenChangeGeneration: UInt64 = 0
    private let refreshChrome: @MainActor () -> Void
    private let scheduleRefresh: @MainActor (String) -> Void

    init(refreshChrome: @escaping @MainActor () -> Void = {
        WorkspaceSidebarPanel.refreshAll()
        WindowTabStripPanelController.shared.refresh()
    }, scheduleRefresh: @escaping @MainActor (String) -> Void = { reason in
        if TrayMenuModel.shared.isEnabled { scheduleRefreshSession(.globalObserver(reason)) }
    }) {
        self.refreshChrome = refreshChrome
        self.scheduleRefresh = scheduleRefresh
    }

    func prepareForStartup() {
        refreshChrome()
    }

    func startObserving() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main,
        ) { _ in
            Task { @MainActor in
                MonitorConfigurationObserver.shared.handleScreenParametersChanged()
            }
        }
    }

    private func handleScreenParametersChanged() {
        refreshMonitorPolicy(refreshReason: NSApplication.didChangeScreenParametersNotification.rawValue)
        scheduleSettledRefresh()
    }

    func refreshMonitorPolicy(refreshReason: String) {
        refreshChrome()
        scheduleRefresh(refreshReason)
    }

    private func scheduleSettledRefresh() {
        screenChangeGeneration += 1
        let generation = screenChangeGeneration
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard generation == screenChangeGeneration else { return }
            refreshMonitorPolicy(refreshReason: "\(NSApplication.didChangeScreenParametersNotification.rawValue).settled")
        }
    }
}
