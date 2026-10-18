import AppKit
import Common
import SwiftUI

public let shortcutSettingsWindowId = "\(winMuxAppName).shortcutSettings"

@MainActor
public func getShortcutSettingsWindow(model: ShortcutSettingsModel) -> some Scene {
    SwiftUI.Window("WinMux Settings", id: shortcutSettingsWindowId) {
        ShortcutSettingsView(model: model)
            .frame(width: 900, height: 620)
            .onAppear { NSApp.setActivationPolicy(.accessory) }
    }
}

@MainActor
public func openShortcutSettingsWindow(_ openWindow: OpenWindowAction) {
    let existing = shortcutSettingsWindow()
    let shown = existing.map { $0.isVisible || $0.isMiniaturized } ?? false
    ShortcutSettingsModel.shared.prepareForPresentation(alreadyShown: shown)
    if let window = existing { presentShortcutSettingsWindow(window, center: !shown) }
    else {
        openWindow(id: shortcutSettingsWindowId)
        DispatchQueue.main.async {
            if let window = shortcutSettingsWindow() { presentShortcutSettingsWindow(window) }
        }
    }
}

enum SettingsSidebarItem: String, CaseIterable, Identifiable {
    case overview = "Overview", lenses = "Lenses", shortcuts = "Shortcuts", columns = "Columns"
    case hooks = "Hooks and Filters", behavior = "Behavior", appearance = "Appearance"
    case configuration = "Config File", reference = "Configuration Reference"
    var id: Self { self }
    var icon: String {
        switch self {
            case .overview: "info.circle"
            case .lenses: "rectangle.stack"
            case .shortcuts: "keyboard"
            case .columns: "rectangle.split.3x1"
            case .hooks: "arrow.triangle.branch"
            case .behavior: "arrow.triangle.2.circlepath"
            case .appearance: "sidebar.left"
            case .configuration: "doc.text"
            case .reference: "book"
        }
    }
}

struct ShortcutSettingsView: View {
    @ObservedObject var model: ShortcutSettingsModel
    @State private var selectedItem: SettingsSidebarItem? = .overview

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                ForEach(SettingsSidebarItem.allCases) { item in
                    NavigationLink(value: item) { Label(item.rawValue, systemImage: item.icon) }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(235)
        } detail: {
            VStack(spacing: 0) {
                if let failure = model.summary.load.failure {
                    ConfigLoadFailureBanner(summary: model.summary, failure: failure)
                    Divider()
                }
                Group {
                    switch selectedItem {
                        case .overview: LoadedOverviewView(summary: model.summary)
                        case .lenses: LoadedLensesView(summary: model.summary)
                        case .shortcuts: LoadedShortcutsView(summary: model.summary)
                        case .columns: LoadedColumnsView(summary: model.summary)
                        case .hooks: LoadedHooksView(summary: model.summary)
                        case .behavior: ShortcutBehaviorSettingsView(model: model).id(model.settingsRevision)
                        case .appearance: ShortcutAppearanceSettingsView(model: model).id(model.settingsRevision)
                        case .configuration: ShortcutAdvancedView(model: model)
                        case .reference: ShortcutConfigurationReferenceView()
                        case nil: Text("Select an item")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Divider()
                HStack {
                    Text("Settings shows the loaded configuration. Edit the file to make changes.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Config") { openConfigFile() }
                }.padding(12)
            }
            .navigationTitle(selectedItem?.rawValue ?? "Settings")
        }
        .onChange(of: model.presentationRevision) { selectedItem = .overview }
    }
}

struct SettingsPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title).font(.title2.bold())
                content
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
        }
    }
}

struct SettingsValueRow: View {
    let label: String
    let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(label).frame(maxWidth: .infinity, alignment: .leading)
            Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
    }
}

private struct ConfigLoadFailureBanner: View {
    let summary: LoadedConfigSummary
    let failure: ConfigLoadState.Failure
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Config failed to \(failure.applying ? "apply" : "load") · \(failure.time.formatted(date: .omitted, time: .standard))").font(.headline)
            ScrollView {
                Text(failure.diagnostic).font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 100)
            Text(summary.loadExplanation).font(.caption)
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.orange.opacity(0.12))
    }
}
