import AppKit
import Common

/// Read-only reflections of the model's three declarative surfaces — columns, scenes, rules — for
/// the settings window. These builders mirror config plus live runtime state; editing stays in
/// `winmux.toml`, so nothing here writes config back.

let settingsImplicitSceneLabel = "Implicit scene"

struct SettingsColumnRowViewModel: Identifiable, Equatable {
    let id: String
    let monitorLabel: String
    let sceneLabel: String
    let columnId: String
    let name: String
    let widthText: String
    let colorHex: String?
    let isDefaultColumn: Bool
    let isEnabled: Bool
    let isImplicit: Bool
}

struct SettingsSceneRowViewModel: Identifiable, Equatable {
    let id: String
    let monitorLabel: String
    let sceneId: String
    let name: String
    let isActive: Bool
    let columnCount: Int
}

struct SettingsRuleRowViewModel: Identifiable, Equatable {
    let id: String
    let matchDescription: String
    let card: String
    let focus: Bool
}

/// One row per column of each display's active scene, in spatial order. A display running its
/// implicit scene (no `[scene.*]` config) contributes a single full-width implicit row, so the
/// laptop case reads as one column rather than an empty pane.
@MainActor
func buildSettingsColumnRows() -> [SettingsColumnRowViewModel] {
    let physicalMonitors = settingsDedupedPhysicalMonitors()
    let columnsByDisplay = Dictionary(
        grouping: getCurrentColumnTopologySnapshot().configuredZones(for: physicalMonitors),
        by: { $0.physicalMonitor.rect.topLeftCorner },
    )
    return physicalMonitors.enumerated().flatMap { index, physicalMonitor -> [SettingsColumnRowViewModel] in
        let monitorLabel = workspaceSidebarMonitorDisplayName(physicalMonitor, fallbackIndex: index + 1)
        let sceneLabel = activeSceneId(for: physicalMonitor) ?? settingsImplicitSceneLabel
        let columns = columnsByDisplay[physicalMonitor.rect.topLeftCorner] ?? []
        guard !columns.isEmpty else {
            return [SettingsColumnRowViewModel(
                id: "\(monitorLabel):\(implicitColumnDeckColumnId)",
                monitorLabel: monitorLabel,
                sceneLabel: sceneLabel,
                columnId: implicitColumnDeckColumnId,
                name: "Full width",
                widthText: settingsColumnWidthText(1.0),
                colorHex: nil,
                isDefaultColumn: true,
                isEnabled: true,
                isImplicit: true,
            )]
        }
        return columns.map { column in
            SettingsColumnRowViewModel(
                id: "\(monitorLabel):\(column.zoneId)",
                monitorLabel: monitorLabel,
                sceneLabel: sceneLabel,
                columnId: column.zoneId,
                name: column.displayName,
                widthText: settingsColumnWidthText(column.configuredWidth),
                colorHex: column.zoneStyleColorHex,
                isDefaultColumn: column.isDefaultZone,
                isEnabled: column.isEnabled,
                isImplicit: false,
            )
        }
    }
}

/// Every scene declared for each display, in declared order, tagged with which one is live. A
/// display with no declared scenes contributes none — its implicit scene has no name to show.
@MainActor
func buildSettingsSceneRows() -> [SettingsSceneRowViewModel] {
    settingsDedupedPhysicalMonitors().enumerated().flatMap { index, physicalMonitor -> [SettingsSceneRowViewModel] in
        let monitorLabel = workspaceSidebarMonitorDisplayName(physicalMonitor, fallbackIndex: index + 1)
        let activeId = activeSceneId(for: physicalMonitor)
        return scenes(on: physicalMonitor).map { scene in
            let layout = config.zoneLayouts.first { $0.id == scene.layoutId }
            return SettingsSceneRowViewModel(
                id: "\(monitorLabel):\(scene.id)",
                monitorLabel: monitorLabel,
                sceneId: scene.id,
                name: scene.id,
                isActive: scene.id == activeId,
                columnCount: layout?.columns.count ?? 0,
            )
        }
    }
}

/// The `[[rules]]` table in evaluation order: each entry's window match and the card it deals new
/// windows onto.
func buildSettingsRuleRows(rules: [RuleConfig]) -> [SettingsRuleRowViewModel] {
    rules.enumerated().map { index, rule in
        SettingsRuleRowViewModel(
            id: "rule-\(index)",
            matchDescription: settingsRuleMatchDescription(rule.matcher),
            card: rule.card ?? "",
            focus: rule.focus,
        )
    }
}

func settingsColumnWidthText(_ fraction: Double) -> String {
    "\(Int((fraction * 100).rounded()))%"
}

/// A human-readable summary of a rule's match conditions. Compiled `Regex` values do not retain
/// their source, so pattern fields describe their shape rather than echo the pattern.
func settingsRuleMatchDescription(_ matcher: WindowDetectedCallbackMatcher) -> String {
    var parts: [String] = []
    if let appId = matcher.appId {
        parts.append("app id is \(appId)")
    }
    if matcher.appNameRegexSubstring != nil {
        parts.append("app name matches a pattern")
    }
    if matcher.windowTitleRegexSubstring != nil {
        parts.append("window title matches a pattern")
    }
    if let workspace = matcher.workspace {
        parts.append("source card is \(workspace)")
    }
    if let duringStartup = matcher.duringWinMuxStartup {
        parts.append(duringStartup ? "during startup" : "after startup")
    }
    return parts.isEmpty ? "Any window" : parts.joined(separator: " and ")
}

@MainActor
private func settingsDedupedPhysicalMonitors() -> [Monitor] {
    var seenTopLeftCorners = Set<CGPoint>()
    return sortMonitorsBySpatialOrder(
        sortedMonitors.map(\.physicalMonitor).filter { seenTopLeftCorners.insert($0.rect.topLeftCorner).inserted },
    )
}
