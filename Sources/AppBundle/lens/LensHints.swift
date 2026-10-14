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
                case ["sections next"]: phrase = "group"; rank = 4
                default: phrase = actions.joined(separator: "; "); rank = 5
            }
        }
        let chords = workspace ? workspaceChords(bindings, commands: commands) : names.map(displayBindingNotation)
        return (rank, names[0], LensHintEntry(chords: chords, bindingNames: names, phrase: phrase))
    }
    return entries.sorted { ($0.rank, $0.sort) < ($1.rank, $1.sort) }.map(\.entry)
}

extension LensSession {
    var panelGlassOpacity: Double { hintsShown && settings.presentation != "miniatures" ? 0.55 : 1 }
    var hintLegend: [LensHintEntry] { lensHintLegend(keys: activeKeyBindings, commands: settings.keys) }
    var summonBindings: [LensKeyBinding] {
        let bindings = Dictionary(uniqueKeysWithValues: activeKeyBindings.map { ($0.name, $0) })
        return hintLegend.flatMap(\.bindingNames).compactMap { bindings[$0] }.filter { key in
            commands(for: key.name).contains { $0 == "summon" || $0.hasPrefix("summon ") }
        }
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
        activeKeyBindings.first { commands(for: $0.name) == ["move-node-to-workspace \(workspace)"] }.map { displayBindingNotation($0.name) }
    }
    func workspaceHint(for item: SwitcherPaletteItem) -> String? {
        guard hintsShown, settings.presentation == "strip" || settings.presentation == "grid", tileKind != .text else { return nil }
        let window = settings.entries == "app" ? items.first { $0.appIdentity == item.appIdentity } : item
        guard let workspace = window?.miniature?.workspace ?? window?.workspaceIdentity ?? window?.workspaceName, !workspace.isEmpty else { return nil }
        return workspaceHint(workspace: workspace)
    }
}

struct LensHintGeometry {
    static func legendTop(panelBottom: CGFloat, screenHeight: CGFloat, legendHeight: CGFloat, scale: CGFloat) -> CGFloat {
        min(panelBottom + 14 * scale, screenHeight - 52 * scale - legendHeight)
    }
}
