import AppKit
import Common
import SwiftUI

// Read-only reflections of the model surfaces. Editing lives in `winmux.toml`; these panes mirror
// the parsed config plus live runtime state and re-read on config reload.

struct SettingsColumnsView: View {
    @ObservedObject var model: ShortcutSettingsModel
    @State private var rows: [SettingsColumnRowViewModel] = []

    private var groups: [(header: String, rows: [SettingsColumnRowViewModel])] {
        var order: [String] = []
        var byHeader: [String: [SettingsColumnRowViewModel]] = [:]
        for row in rows {
            let header = row.monitorLabel == row.sceneLabel ? row.monitorLabel : "\(row.monitorLabel) · \(row.sceneLabel)"
            if byHeader[header] == nil { order.append(header) }
            byHeader[header, default: []].append(row)
        }
        return order.map { ($0, byHeader[$0] ?? []) }
    }

    var body: some View {
        SettingsReflectionScaffold(
            model: model,
            summary: "The columns of each display's active scene. A column behaves as its own small monitor: it holds an ordered deck of cards and shows one. Widths and colors are declared in [scene.*] config.",
            isEmpty: rows.isEmpty,
            emptyMessage: "No columns configured. Displays run a single implicit full-width column until you declare [scene.*] blocks.",
            reload: reload,
        ) {
            ForEach(groups, id: \.header) { group in
                GeneralSection(title: group.header) {
                    VStack(spacing: 0) {
                        ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                            SettingsColumnRow(row: row)
                            if index < group.rows.count - 1 {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                }
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() { rows = buildSettingsColumnRows() }
}

private struct SettingsColumnRow: View {
    let row: SettingsColumnRowViewModel

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(row.colorHex.flatMap(workspaceSidebarColor(hex:)) ?? Color.secondary.opacity(0.35))
                .frame(width: 4, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(.system(size: 13, weight: .medium))
                    if row.isDefaultColumn, !row.isImplicit {
                        SettingsBadge(text: "Default", tint: .accentColor)
                    }
                    if !row.isEnabled {
                        SettingsBadge(text: "Disabled", tint: .secondary)
                    }
                }
                if !row.isImplicit {
                    Text(row.columnId)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(row.widthText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

struct SettingsScenesView: View {
    @ObservedObject var model: ShortcutSettingsModel
    @State private var rows: [SettingsSceneRowViewModel] = []

    private var groups: [(header: String, rows: [SettingsSceneRowViewModel])] {
        var order: [String] = []
        var byHeader: [String: [SettingsSceneRowViewModel]] = [:]
        for row in rows {
            if byHeader[row.monitorLabel] == nil { order.append(row.monitorLabel) }
            byHeader[row.monitorLabel, default: []].append(row)
        }
        return order.map { ($0, byHeader[$0] ?? []) }
    }

    var body: some View {
        SettingsReflectionScaffold(
            model: model,
            summary: "A scene is a named arrangement a display switches to. Each display shows one at a time; switching back shows it exactly as you left it. The active scene is marked.",
            isEmpty: rows.isEmpty,
            emptyMessage: "No scenes declared. A display with no [scene.*] block runs its implicit one-column scene (the laptop case).",
            reload: reload,
        ) {
            ForEach(groups, id: \.header) { group in
                GeneralSection(title: group.header) {
                    VStack(spacing: 0) {
                        ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                            SettingsSceneRow(row: row)
                            if index < group.rows.count - 1 {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                }
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() { rows = buildSettingsSceneRows() }
}

private struct SettingsSceneRow: View {
    let row: SettingsSceneRowViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.isActive ? "largecircle.fill.circle" : "circle")
                .font(.system(size: 13))
                .foregroundStyle(row.isActive ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(.system(size: 13, weight: .medium))
                    if row.isActive {
                        SettingsBadge(text: "Active", tint: .accentColor)
                    }
                }
                Text(row.columnCount == 1 ? "1 column" : "\(row.columnCount) columns")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

struct SettingsRulesView: View {
    @ObservedObject var model: ShortcutSettingsModel
    @State private var rows: [SettingsRuleRowViewModel] = []

    var body: some View {
        SettingsReflectionScaffold(
            model: model,
            summary: "Rules deal new windows onto cards by name. A rule addresses content — the card — never a place; a rule naming a card that does not exist yet creates it in the active scene's default column. Rules evaluate top to bottom.",
            isEmpty: rows.isEmpty,
            emptyMessage: "No [[rules]] declared. Unmatched windows join the focused card.",
            reload: reload,
        ) {
            GeneralSection(title: "Rules") {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        SettingsRuleRow(row: row, index: index + 1)
                        if index < rows.count - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() { rows = buildSettingsRuleRows(rules: config.rules) }
}

private struct SettingsRuleRow: View {
    let row: SettingsRuleRowViewModel
    let index: Int

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
            Text(row.matchDescription)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "arrow.right")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text(row.card)
                    .font(.system(size: 13, weight: .medium))
                if row.focus {
                    SettingsBadge(text: "Focus", tint: .accentColor)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

// MARK: - Shared chrome

private struct SettingsBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(tint.opacity(0.16))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}

private struct SettingsReflectionScaffold<Content: View>: View {
    @ObservedObject var model: ShortcutSettingsModel
    let summary: String
    let isEmpty: Bool
    let emptyMessage: String
    let reload: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let error = model.errorMessage {
                    Text(error)
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                HStack(alignment: .top) {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 12)
                    Button("Reload Config", action: reloadConfigAction)
                }

                if isEmpty {
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                } else {
                    content
                }
            }
            .padding(24)
        }
    }

    private func reloadConfigAction() {
        Task {
            if let token: RunSessionGuard = .isServerEnabled {
                try await runLightSession(.menuBarButton, token) {
                    if try await reloadConfig() {
                        model.reload()
                        reload()
                    }
                }
            }
        }
    }
}
