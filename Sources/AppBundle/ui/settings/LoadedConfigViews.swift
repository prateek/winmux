import SwiftUI

struct LoadedOverviewView: View {
    let summary: LoadedConfigSummary
    @State private var helperError: String?
    var body: some View {
        SettingsPage(title: "Overview") {
            if let loaded = summary.load.loaded {
                Text(loaded.file.path).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                Text(loaded.shippedDefaults ? "Shipped defaults" : "Your config file").foregroundStyle(.secondary)
                Text("Loaded \(loaded.time.formatted(date: .abbreviated, time: .standard))").foregroundStyle(.secondary)
            } else {
                Text("WinMux's built-in defaults").font(.headline)
                if let file = summary.file { Text(file.path).font(.caption).textSelection(.enabled) }
                Text(summary.loadExplanation).foregroundStyle(.secondary)
            }
            Divider()
            SettingsValueRow("Lenses", "\(summary.lenses.filter { !$0.missing }.count)")
            SettingsValueRow("Triggers", "\(summary.lenses.reduce(0) { $0 + $1.triggers.count })")
            SettingsValueRow("Bindings in effect", "\(summary.bindings.count)")
            SettingsValueRow("Columns", "\(summary.columns.filter { $0.count != nil }.count) enabled workspace policies · \(summary.columns.count - 1) named workspaces")
            SettingsValueRow("Hooks", "\(summary.hooks.filter { $0.value != "None" }.count) configured")
            SettingsValueRow("Filters", "\(summary.lenses.filter { $0.filter != "None" }.count) Lenses with a Filter")
            if let helperError, helperError != summary.load.failure?.diagnostic {
                Divider()
                Text("Config helper's last error").font(.headline)
                Text(helperError).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            }
        }
        .task {
            while !Task.isCancelled {
                helperError = NickelSupervisor.shared.status.lastError
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

struct LoadedLensesView: View {
    let summary: LoadedConfigSummary
    var body: some View {
        SettingsPage(title: "Lenses") {
            ForEach(summary.lenses) { lens in
                VStack(alignment: .leading, spacing: 6) {
                    Text(lens.name).font(.headline)
                    Text(lens.missing ? "Missing Lens · a Trigger names a Lens that is not configured" : "\(lens.presentation) · \(lens.enabled ? "Enabled" : "Disabled") · Filter: \(lens.filter)")
                        .foregroundStyle(lens.missing ? .orange : .secondary)
                    if lens.triggers.isEmpty { Text("No Trigger").foregroundStyle(.secondary) }
                    ForEach(lens.triggers) { trigger in
                        Text("\(trigger.mode) · \(trigger.notation)  \(trigger.glyphs)\n\(trigger.command)")
                            .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    }
                }
                Divider()
            }
        }
    }
}

struct LoadedShortcutsView: View {
    let summary: LoadedConfigSummary
    @State private var search = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shortcuts").font(.title2.bold())
            TextField("Search notation, command or mode", text: $search)
                .textFieldStyle(.roundedBorder).accessibilityIdentifier("settings-shortcut-search")
            let matches = summary.search(search)
            Text("\(matches.count) bindings").font(.caption).foregroundStyle(.secondary)
                .accessibilityIdentifier("settings-shortcut-count")
            if matches.isEmpty { Text("No shortcuts match your search.").foregroundStyle(.secondary) }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(matches.enumerated()), id: \.element.id) { index, binding in
                        if index == 0 || matches[index - 1].mode != binding.mode {
                            Text("Mode: \(binding.mode)").font(.headline).padding(.top, 6)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(binding.notation)   \(binding.glyphs)").font(.system(.body, design: .monospaced))
                            Text(binding.command).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                        }.textSelection(.enabled)
                        Divider()
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(20)
    }
}

struct LoadedColumnsView: View {
    let summary: LoadedConfigSummary
    var body: some View {
        SettingsPage(title: "Columns") {
            Text("Resolved config for each workspace. Other workspaces use the first policy.").foregroundStyle(.secondary)
            ForEach(summary.columns) { row in
                SettingsValueRow(row.label, row.value)
                Divider()
            }
        }
    }
}

struct LoadedHooksView: View {
    let summary: LoadedConfigSummary
    var body: some View {
        SettingsPage(title: "Hooks and Filters") {
            Text("Filters").font(.headline)
            Text("Filter functions stay in the config helper; their source names are not available here. Lenses shows each Filter in use.")
                .foregroundStyle(.secondary)
            Text("Hooks").font(.headline)
            ForEach(summary.hooks) { hook in
                VStack(alignment: .leading, spacing: 4) {
                    Text(hook.name).font(.headline)
                    Text(hook.value).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Divider()
            }
        }
    }
}
