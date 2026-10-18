import Common
import Foundation

struct LoadedConfigSummary {
    struct Binding: Identifiable, Equatable {
        let id: String
        let mode: String
        let notation: String
        let command: String
        let lensNames: [String]
        let kind: String
        var glyphs: String {
            kind == "sequence" ? notation.components(separatedBy: "-").map(displayBindingNotation).joined(separator: " → ") : displayBindingNotation(notation)
        }
    }
    struct Lens: Identifiable {
        let name: String
        let presentation: String
        let enabled: Bool
        let filter: String
        let missing: Bool
        let triggers: [Binding]
        var id: String { name }
    }
    struct Columns: Identifiable {
        let workspace: String?
        let count: Int?
        let widths: [CGFloat]
        var id: String { workspace.map { "workspace:\($0)" } ?? "other" }
        var label: String { workspace ?? "Other workspaces" }
        var value: String {
            guard let count else { return "Off" }
            return "\(count) Columns · " + widths.map { String(format: "%.0f", $0 * 100) }.joined(separator: " / ") + " %"
        }
    }
    struct Hook: Identifiable {
        let id: String
        let name: String
        let value: String
        init(name: String, value: String, id: String? = nil) {
            self.id = id ?? name
            self.name = name
            self.value = value
        }
    }
    let load: ConfigLoadState
    let lenses: [Lens]
    let bindings: [Binding]
    let columns: [Columns]
    let hooks: [Hook]
    var file: URL? { load.loaded?.file ?? load.defaultsFile }

    var loadExplanation: String {
        if let loaded = load.loaded {
            if load.failure?.applying == true {
                return "Values below are from the config loaded at \(loaded.time.formatted(date: .abbreviated, time: .standard)); applying it did not finish."
            }
            return "Values below are from the last config that loaded at \(loaded.time.formatted(date: .abbreviated, time: .standard))."
        }
        return "Values below are WinMux's built-in defaults because no config has loaded since WinMux started."
    }

    func search(_ query: String) -> [Binding] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return bindings }
        return bindings.filter { binding in
            [binding.notation, binding.glyphs, binding.command, binding.mode].contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    static func build(_ config: Config, load: ConfigLoadState, workspaceNames: [String]) -> Self {
        var bindings: [Binding] = []
        for modeName in config.modes.keys.sorted(by: { lhs, rhs in
            if lhs == mainModeId { return rhs != mainModeId }
            if rhs == mainModeId { return false }
            return lhs < rhs
        }) {
            let mode = config.modes[modeName]!
            func binding(_ notation: String, _ commands: [any Command], kind: String) -> Binding {
                Binding(id: "\(modeName):\(kind):\(notation)", mode: modeName, notation: notation,
                        command: commands.prettyDescription, lensNames: commands.compactMap { ($0 as? LensCommand)?.args.name }, kind: kind)
            }
            let chords = mode.bindings.values.map { binding($0.descriptionWithKeyNotation, $0.commands, kind: "chord") }
            let taps = mode.tapBindings.values.map { binding($0.descriptionWithKeyNotation, $0.commands, kind: "tap") }
            let sequences = mode.sequenceBindings.values.map { binding($0.descriptionWithKeyNotation, $0.commands, kind: "sequence") }
            bindings += (chords + taps + sequences).sorted { $0.notation == $1.notation ? $0.id < $1.id : $0.notation < $1.notation }
        }
        let names = Set(config.lenses.keys).union(bindings.flatMap(\.lensNames)).sorted()
        let lenses = names.map { name in
            let settings = config.lenses[name]
            return Lens(name: name, presentation: settings?.presentation ?? "—", enabled: settings?.enabled ?? false,
                        filter: settings?.filter.map { $0.hasPrefix("lenses.") ? "function" : $0 } ?? "None",
                        missing: settings == nil, triggers: bindings.filter { $0.lensNames.contains(name) })
        }
        let workspaceNames = Set(workspaceNames).union(config.persistentWorkspaces)
            .union(config.workspaceToMonitorForceAssignment.keys).union(config.columns.workspaceNames)
            .sorted { $0.toLogicalSegments() < $1.toLogicalSegments() }
        var unnamed = ""
        while config.columns.workspaceNames.contains(unnamed) { unnamed += " " }
        let columns = ([String?](arrayLiteral: nil) + workspaceNames.map(Optional.some)).map { name in
            let state = config.columns.resolved(workspace: name ?? unnamed)
            return Columns(workspace: name, count: state?.count, widths: state?.widths ?? [])
        }
        func commands(_ list: [any Command]) -> String { list.isEmpty ? "None" : list.prettyDescription }
        func function(_ path: String?) -> String { path.map { "Nickel function · \($0)" } ?? "None" }
        var hooks = [Hook(name: "arrive", value: function(config.arrive)),
                     Hook(name: "after-startup-command", value: commands(config.afterStartupCommand)),
                     Hook(name: "after-login-command", value: commands(config.afterLoginCommand)),
                     Hook(name: "exec-on-workspace-change", value: config.execOnWorkspaceChange.isEmpty ? "None" : config.execOnWorkspaceChange.joined(separator: "\n")),
                     Hook(name: "on-focus-changed", value: commands(config.onFocusChanged)),
                     Hook(name: "on-focused-monitor-changed", value: commands(config.onFocusedMonitorChanged)),
                     Hook(name: "on-mode-changed", value: commands(config.onModeChanged))]
        for row in columns {
            for name in ["place", "move-boundary"] {
                let path = config.columns.hook(name, workspace: row.workspace ?? unnamed)
                let value = function(path) + (row.count == nil && path != nil ? " (inactive: Columns Off)" : "")
                hooks.append(Hook(name: "\(name) · \(row.label)", value: value, id: "\(row.id):\(name)"))
            }
        }
        return Self(load: load, lenses: lenses, bindings: bindings, columns: columns, hooks: hooks)
    }
}
