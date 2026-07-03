import AppBundle
import Sparkle
import SwiftUI

// This file is shared between SPM and xcode project

@main
struct WinMuxApp: App {
    @StateObject var viewModel = TrayMenuModel.shared
    @StateObject var messageModel = MessageModel.shared
    @StateObject var shortcutSettingsModel = ShortcutSettingsModel.shared
    @Environment(\.openWindow) var openWindow: OpenWindowAction

    private static let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil,
    )

    init() {
        initAppBundle()
        // Raw-executable runs (swift build output, debug harness) have no bundle for Sparkle
        // to update; leaving the bridge unset hides the menu item and skips updater startup.
        if Bundle.main.bundleIdentifier != nil {
            let updater = Self.updaterController
            UpdaterBridge.shared.checkForUpdates = { updater.checkForUpdates(nil) }
            UpdaterBridge.shared.setAutomaticChecksEnabled = { updater.updater.automaticallyChecksForUpdates = $0 }
            UpdaterBridge.shared.applyConfig()
        }
    }

    var body: some Scene {
        menuBar(viewModel: viewModel)
        getShortcutSettingsWindow(model: shortcutSettingsModel)
            .onChange(of: shortcutSettingsModel.openRequestId) { _ in
                openShortcutSettingsWindow(openWindow)
            }
        getMessageWindow(messageModel: messageModel)
            .onChange(of: messageModel.message) { message in
                if message != nil {
                    openWindow(id: messageWindowId)
                }
            }
    }
}
