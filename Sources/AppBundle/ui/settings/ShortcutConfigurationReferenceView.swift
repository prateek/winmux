import SwiftUI

struct ShortcutConfigurationReferenceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Configuration Reference")
                    .font(.headline)
                Text("Every setting lives in the config file, winmux.ncl. Settings shows the loaded Lenses, Triggers, bindings, Columns, hooks and appearance without editing them. Use Open Config to make changes; this reference describes the config sections.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ReferenceSection("Keyboard") {
                    ReferenceRow("[key-mapping]", "Keyboard layout preset and custom key notation mappings.")
                    ReferenceRow("[mode.<name>.binding]", "Chord and sequence shortcuts for any mode.")
                    ReferenceRow("[mode.<name>.binding-tap]", "Tap-only shortcut bindings.")
                }
                ReferenceSection("Rules and integrations") {
                    ReferenceRow("[exec]", "Inherited environment and explicit environment variables for commands.")
                    ReferenceRow("[workspace-to-monitor-force-assignment]", "Workspace-to-display assignments.")
                    ReferenceRow("arrive", "Policy hook for newly detected windows and commands to run after placement.")
                    ReferenceRow("on-focus-changed", "Commands that run after the focused window changes.")
                    ReferenceRow("on-focused-monitor-changed", "Commands that run after the active display changes.")
                    ReferenceRow("on-mode-changed", "Commands that run after switching modes.")
                }
                ReferenceSection("Named sidebar items") {
                    ReferenceRow("workspace-labels", "Override visible workspace names.")
                    ReferenceRow("project-labels", "Override visible project names.")
                    ReferenceRow("project-colors", "Assign project colors using #RRGGBB values.")
                }
                Text("Config File displays the text on disk. Edit it with Open Config; invalid loads keep the running values and show an error banner.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }
}

private struct ReferenceSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            content
        }
    }
}

private struct ReferenceRow: View {
    let key: String
    let description: String

    init(_ key: String, _ description: String) {
        self.key = key
        self.description = description
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(key)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 255, alignment: .leading)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
