import AppKit
import Common
import MASShortcut
import SwiftUI

/// Shows the config file as it is on disk. Editing happens in the user's own editor.
struct ShortcutAdvancedView: View {
    @ObservedObject var model: ShortcutSettingsModel
    @State private var configText = ""
    @State private var targetUrl: URL? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Config File")
                        .font(.headline)
                    if let targetUrl {
                        Text(targetUrl.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Spacer()

                Button("Reload From Disk") {
                    loadFromDisk()
                }
                .controlSize(.small)
            }

            ScrollView {
                Text(configText)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(Rectangle().stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
        }
        .padding(18)
        .task(id: model.settingsRevision) { loadFromDisk() }
    }

    private func loadFromDisk() {
        targetUrl = configUrl
        configText = (try? String(contentsOf: configUrl, encoding: .utf8)) ?? ""
    }
}

struct OpenShortcutSettingsButton: View {
    @Environment(\.openWindow) private var openWindow: OpenWindowAction

    var body: some View {
        Button("Settings…") {
            openShortcutSettingsWindow(openWindow)
        }
    }
}

@MainActor
func shortcutSettingsWindow() -> NSWindow? {
    NSApplication.shared.windows.first { $0.identifier?.rawValue == shortcutSettingsWindowId }
}

@MainActor
func presentShortcutSettingsWindow(_ window: NSWindow) {
    let fixedSize = NSSize(width: 760, height: 620)
    window.styleMask.remove(.resizable)
    window.minSize = fixedSize
    window.maxSize = fixedSize
    window.setContentSize(fixedSize)
    NSApp.activate(ignoringOtherApps: true)
    window.center()
    window.makeKeyAndOrderFront(nil)
    window.orderFrontRegardless()
}
