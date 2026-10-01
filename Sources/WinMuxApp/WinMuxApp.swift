import AppBundle
import SparkleSupport
import SwiftUI

// This file is shared between SPM and xcode project

@main
struct WinMuxApp: App {
    @StateObject var viewModel = TrayMenuModel.shared
    @StateObject var messageModel = MessageModel.shared
    @StateObject var shortcutSettingsModel = ShortcutSettingsModel.shared
    @Environment(\.openWindow) var openWindow: OpenWindowAction

    init() {
        #if !DEBUG
            AutomaticUpdates.start()
        #endif
        initAppBundle()
    }

    var body: some Scene {
        #if DEBUG
        menuBar(viewModel: viewModel)
        #else
        menuBar(
            viewModel: viewModel,
            checkForUpdates: { AutomaticUpdates.checkForUpdates() },
        )
        #endif
        getShortcutSettingsWindow(model: shortcutSettingsModel)
            .onChange(of: shortcutSettingsModel.openRequestId) {
                openShortcutSettingsWindow(openWindow)
            }
        getMessageWindow(messageModel: messageModel)
            .onChange(of: messageModel.message) { _, message in
                if message != nil {
                    openWindow(id: messageWindowId)
                }
            }
    }
}
