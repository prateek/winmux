import AppKit

struct LensHintEntry: Equatable {
    let chords: [String]
    let bindingNames: [String]
    let phrase: String
}

private func workspaceDigit(_ key: LensKeyBinding, commands: [String]) -> Int? {
    guard commands.count == 1, commands[0].hasPrefix("move-node-to-workspace "),
          let last = key.name.split(separator: "-").last, last.count == 1,
          let digit = Int(last), (1...9).contains(digit) else { return nil }
    return digit
}

private func workspaceChords(_ keys: [LensKeyBinding], commands: [String: [String]]) -> [String] {
    var parts: [(name: String, chords: [String])] = []
    let digits = keys.compactMap { key -> (key: LensKeyBinding, number: Int)? in
        guard let number = workspaceDigit(key, commands: commands[key.name] ?? []) else { return nil }
        return (key, number)
    }
    for bindings in Dictionary(grouping: digits, by: { $0.key.modifiers.rawValue }).values {
        let sorted = bindings.sorted { ($0.number, $0.key.name) < ($1.number, $1.key.name) }
        let numbers = sorted.map(\.number)
        let consecutive = numbers.count > 1 && zip(numbers, numbers.dropFirst()).allSatisfy { $1 == $0 + 1 }
        let chords = consecutive ? [displayBindingNotation(sorted[0].key.name) + "–" + String(numbers.last!)] : sorted.map { displayBindingNotation($0.key.name) }
        parts.append((sorted[0].key.name, chords))
    }
    let digitNames = Set(digits.map { $0.key.name })
    for key in keys where !digitNames.contains(key.name) {
        parts.append((key.name, [displayBindingNotation(key.name)]))
    }
    return parts.sorted { $0.name < $1.name }.flatMap(\.chords)
}

func lensHintLegend(keys: [LensKeyBinding], commands: [String: [String]]) -> [LensHintEntry] {
    var groups: [[LensKeyBinding]] = []
    for key in keys.sorted(by: { $0.name < $1.name }) {
        let actions = commands[key.name] ?? []
        guard !actions.isEmpty else { continue }
        let matches = groups.indices.filter { index in
            groups[index].contains { other in
                let otherActions = commands[other.name] ?? []
                return actions == otherActions || (key.modifiers == other.modifiers &&
                    workspaceDigit(key, commands: actions) != nil && workspaceDigit(other, commands: otherActions) != nil)
            }
        }
        var merged = [key]
        for index in matches.reversed() { merged += groups.remove(at: index) }
        groups.append(merged)
    }
    let entries = groups.map { bindings -> (rank: Int, sort: String, entry: LensHintEntry) in
        let names = bindings.map(\.name).sorted()
        let actions = commands[names[0]]!
        let phrase: String
        let rank: Int
        let workspace = bindings.contains { workspaceDigit($0, commands: commands[$0.name]!) != nil }
        if workspace { phrase = "send to workspace"; rank = 2 }
        else {
            switch actions {
                case ["focus"]: phrase = "focus"; rank = 0
                case ["summon"]: phrase = "summon here"; rank = 1
                case ["close"]: phrase = "close"; rank = 3
                case ["peek"]: phrase = "peek"; rank = 4
                case ["sections next"]: phrase = "group"; rank = 5
                default: phrase = actions.joined(separator: "; "); rank = 6
            }
        }
        let chords = workspace ? workspaceChords(bindings, commands: commands) : (actions == ["peek"] ? names.sorted { $0 == "space" && $1 != "space" } : names).map(displayBindingNotation)
        return (rank, names[0], LensHintEntry(chords: chords, bindingNames: names, phrase: phrase))
    }
    return entries.sorted { ($0.rank, $0.sort) < ($1.rank, $1.sort) }.map(\.entry)
}

final class LensHintSnapshot {
    let legend: [LensHintEntry]
    let summonBindings: [LensKeyBinding]
    let workspaceChords: [String: String]

    init(keys: [LensKeyBinding], commands: [String: [String]]) {
        legend = lensHintLegend(keys: keys, commands: commands)
        let bindings = Dictionary(uniqueKeysWithValues: keys.map { ($0.name, $0) })
        summonBindings = legend.flatMap(\.bindingNames).compactMap { bindings[$0] }.filter { key in
            (commands[key.name] ?? []).contains { $0 == "summon" || $0.hasPrefix("summon ") }
        }
        var workspaces: [String: String] = [:]
        let prefix = "move-node-to-workspace "
        for key in keys {
            guard let actions = commands[key.name], actions.count == 1, actions[0].hasPrefix(prefix) else { continue }
            let workspace = String(actions[0].dropFirst(prefix.count))
            if workspaces[workspace] == nil { workspaces[workspace] = displayBindingNotation(key.name) }
        }
        workspaceChords = workspaces
    }
}

extension LensSession {
    var hintPanelBottom: CGFloat {
        settings.presentation == "list" ? listLayout.topOffset + min(max(listPanelHeight, listLayout.height), listLayout.panelHeight) : (miniatureSize.height + gridLayout.panelSize.height) / 2
    }
    var panelGlassOpacity: Double { hintsShown && settings.presentation != "miniatures" ? 0.55 : 1 }
    var hintSnapshot: LensHintSnapshot {
        if let snapshot = hintSnapshots[drawsSections] { return snapshot }
        let snapshot = LensHintSnapshot(keys: activeKeyBindings, commands: settings.keys)
        hintSnapshots[drawsSections] = snapshot
        return snapshot
    }
    var hintLegend: [LensHintEntry] { hintSnapshot.legend }
    var summonBindings: [LensKeyBinding] {
        let invoking = inputState == .hold ? hold?.invoking ?? [] : []
        return hintSnapshot.summonBindings.filter { $0.modifiers.intersection(invoking).isEmpty }
    }
    var summonHintsShown: Bool { hintsShown && !summonBindings.isEmpty }
    func summonHint(destination: String) -> String? {
        guard let key = summonBindings.first(where: { $0.modifiers == hintsModifier }) ?? summonBindings.first else { return nil }
        return "\(displayBindingNotation(key.name)) Summon to \(destination)"
    }
    func summonLabel(for id: UInt32, destination: String) -> String? {
        guard id == selectedId, summonHintsShown, settings.summonHints.contains("label"),
              settings.presentation == "miniatures" || stripSummonAvailable(items: results) else { return nil }
        return summonHint(destination: destination)
    }
    func workspaceHint(workspace: String) -> String? {
        hintSnapshot.workspaceChords[workspace]
    }
    func workspaceHint(for item: SwitcherPaletteItem) -> String? {
        guard hintsShown, settings.presentation == "strip" || settings.presentation == "grid", tileKind != .text else { return nil }
        let workspace = item.miniature?.workspace ?? item.workspaceIdentity ?? item.workspaceName
        guard !workspace.isEmpty else { return nil }
        return workspaceHint(workspace: workspace)
    }
}

struct LensHintGeometry {
    static func legendMaxWidth(screenWidth: CGFloat, scale: CGFloat, occupiedSideInset: CGFloat = 0) -> CGFloat { max(0, screenWidth - 2 * max(32 * scale, occupiedSideInset)) }
    /// Miniatures already start beside the sidebar; the other Presentations draw under it.
    static func sidebarClearance(presentation: String, monitorInset: CGFloat, scale: CGFloat) -> CGFloat {
        presentation == "miniatures" || monitorInset == 0 ? 0 : monitorInset + 8 * scale
    }
    static func workspaceChipBottomInset(badgeHeight: CGFloat, scale: CGFloat) -> CGFloat { 8 * scale + badgeHeight }

    static func legendTop(panelBottom: CGFloat, screenHeight: CGFloat, legendHeight: CGFloat, scale: CGFloat) -> CGFloat {
        min(panelBottom + 14 * scale, screenHeight - 52 * scale - legendHeight)
    }
}
