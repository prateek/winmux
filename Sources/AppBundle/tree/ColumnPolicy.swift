import AppKit
import Common

struct PlacementDecision: Equatable {
    let slot: Int
    let target: String
    let overflow: String
    let hook: String?
    var run: [String] = []
    var failure: String?

    var json: JSONValue {
        .object(["column": .int(slot), "target": .string(target), "overflow": .string(overflow),
                 "hook": hook.map(JSONValue.string) ?? .null, "run": .array(run.map(JSONValue.string))])
    }
}

@MainActor
enum ColumnPolicy {
    static func call(_ path: String?, window: Window, workspace: Workspace, edge: Bool? = nil,
                     supervisor: NickelSupervisor = .shared, initialClass: WindowClass? = nil) async -> JSONValue? {
        guard let path else { return nil }
        do {
            guard var record = try await window.windowRecord() else { return nil }
            if let initialClass { record.windowClass = initialClass }
            record.workspace = workspace.name
            record.project = workspace.projectId.rawValue
            record.monitor = MonitorRecord(workspace.workspaceMonitor)
            var args = [record.json, try await filterContextRecord().json,
                        try await workspace.columnRecords(excluding: edge == nil ? window : nil)]
            if let edge { args.append(.bool(edge)) }
            switch await supervisor.hook(path, args: args) {
                case .success(let result):
                    guard accepts(result, hook: path.split(separator: ".").last.map(String.init) ?? path) else {
                        supervisor.recordHookFailure("\(path): helper returned an invalid hook result")
                        return nil
                    }
                    return result
                case .failure(let failure):
                    supervisor.recordHookFailure("\(path): \(failure.message)")
                    return nil
            }
        } catch {
            supervisor.recordHookFailure("\(path): \(error.localizedDescription)")
            return nil
        }
    }

    static func accepts(_ result: JSONValue, hook: String) -> Bool {
        guard case .object(let fields) = result else { return false }
        let allowed: Set<String>
        switch hook {
            case "arrive": allowed = ["workspace", "float", "column", "overflow", "run"]
            case "place": allowed = ["column", "overflow", "run"]
            case "move-boundary": allowed = ["action", "overflow", "run"]
            default: return false
        }
        guard Set(fields.keys).isSubset(of: allowed) else { return false }
        if let commands = fields["run"] {
            guard let commands = commands.arrayOrNil, commands.allSatisfy({ $0.stringOrNil != nil }) else { return false }
        }
        if let target = fields["column"] {
            switch target {
                case .int(let index) where index > 0: break
                case .string(let name) where ["focused", "mru", "nearest-empty", "last"].contains(name): break
                default: return false
            }
        } else if hook == "place" { return false }
        if let overflow = fields["overflow"] {
            guard let action = overflow.stringOrNil, ["tab-group", "split", "float", "squeeze"].contains(action) else { return false }
        } else if hook == "place" { return false }
        if hook == "arrive" {
            if let workspace = fields["workspace"], workspace.stringOrNil == nil { return false }
            if let floating = fields["float"] {
                guard case .bool = floating else { return false }
            }
        } else if hook == "move-boundary" {
            guard let action = fields["action"]?.stringOrNil,
                  ["join", "swap", "stop", "wrap", "next-workspace", "next-monitor"].contains(action) else { return false }
        }
        return true
    }

    static func decision(window: Window, workspace: Workspace, answer: JSONValue? = nil,
                         supervisor: NickelSupervisor = .shared) async -> PlacementDecision {
        var builtIn = PlacementDecision(slot: workspace.columnPlacementSlot(excluding: window), target: "nearest-empty", overflow: "tab-group", hook: nil)
        guard let columns = workspace.columns else { return builtIn }
        let path = config.columns.hook("place", workspace: workspace.name)
        let result: JSONValue?
        if let answer { result = answer } else { result = await call(path, window: window, workspace: workspace, supervisor: supervisor) }
        guard let result else {
            if path != nil { builtIn.failure = supervisor.status.lastError ?? "Hook unavailable" }
            return builtIn
        }
        let slot: Int
        let target: String
        if let value = result["column"]?.stringOrNil {
            target = value
            switch value {
                case "focused": slot = columns.focusedSlot ?? workspace.columnSlot(containing: focus.windowOrNil) ?? workspace.mruColumnSlot(excluding: window)
                case "mru": slot = workspace.mruColumnSlot(excluding: window)
                case "nearest-empty": slot = builtIn.slot
                case "last": slot = columns.slotCount
                default:
                    supervisor.recordHookFailure("\(path ?? "arrive"): invalid Column target")
                    builtIn.failure = supervisor.status.lastError
                    return builtIn
            }
        } else if case .int(let value) = result["column"] {
            guard (1...columns.count).contains(value) else {
                supervisor.recordHookFailure("\(path ?? "arrive"): Column index \(value) exceeds count \(columns.count)")
                builtIn.failure = supervisor.status.lastError
                return builtIn
            }
            slot = value
            target = String(value)
        } else {
            supervisor.recordHookFailure("\(path ?? "arrive"): missing Column target")
            builtIn.failure = supervisor.status.lastError
            return builtIn
        }
        guard (1...columns.slotCount).contains(slot) else {
            supervisor.recordHookFailure("\(path ?? "arrive"): Column index \(slot) exceeds count \(columns.slotCount)")
            builtIn.failure = supervisor.status.lastError
            return builtIn
        }
        return PlacementDecision(slot: slot, target: target, overflow: result["overflow"]?.stringOrNil ?? "tab-group",
                                 hook: answer == nil ? path : "arrive", run: commands(result))
    }

    static func place(_ window: Window, on workspace: Workspace, answer: JSONValue? = nil,
                      supervisor: NickelSupervisor = .shared) async throws {
        guard workspace.columns != nil else {
            let binding = bindingDataForNewTilingWindow(workspace, window: window)
            window.bind(to: binding.parent, adaptiveWeight: binding.adaptiveWeight, index: binding.index)
            return
        }
        let decision = await decision(window: window, workspace: workspace, answer: answer, supervisor: supervisor)
        guard window.isBound else { return }
        window.unbindFromParent()
        workspace.bindToColumn(window, slot: decision.slot, overflow: decision.overflow)
        workspace.normalizeContainers()
        try await run(decision.run, window: window)
    }

    static func afterTransfer(_ window: Window, from previous: Workspace?, didMove: Bool) async throws -> Bool {
        if didMove, !window.isFloating, let workspace = window.nodeWorkspace, workspace !== previous,
           config.columns.hook("place", workspace: workspace.name) != nil {
            try await place(window, on: workspace)
        }
        return didMove
    }

    static func arrive(_ window: Window, on detected: Workspace, floatingDefault: Bool,
                       supervisor: NickelSupervisor = .shared) async throws {
        let initialClass: WindowClass? = window.parent === macosPopupWindowsContainer ? nil : (floatingDefault ? .floating : .tiled)
        let result = await call(config.arrive, window: window, workspace: detected, supervisor: supervisor, initialClass: initialClass)
        if window.parent === macosPopupWindowsContainer,
           result?["workspace"] == nil, result?["float"] == nil, result?["column"] == nil {
            try await run(commands(result), window: window)
            return
        }
        let destination = result?["workspace"]?.stringOrNil.map { Workspace.get(byName: $0) } ?? detected
        destination.seedMonitorIfNeeded(detected.workspaceMonitor)
        let floating: Bool
        if case .bool(let value) = result?["float"] { floating = value } else { floating = floatingDefault }
        if floating {
            window.unbindFromParent()
            window.bindAsFloatingWindow(to: destination)
        } else {
            let explicit = result?["column"] == nil ? nil : result
            var placement = explicit
            if case .object(var fields) = placement { fields.removeValue(forKey: "run"); placement = .object(fields) }
            try await place(window, on: destination, answer: placement, supervisor: supervisor)
        }
        try await run(commands(result), window: window)
    }

    static func commands(_ result: JSONValue?) -> [String] {
        result?["run"]?.arrayOrNil?.compactMap(\.stringOrNil) ?? []
    }

    static func run(_ commands: [String], window: Window) async throws {
        for raw in commands {
            switch parseCommand(raw) {
                case .cmd(let command) where command.info.allowInConfig:
                    _ = try await [command].runCmdSeq(.defaultEnv.copy(\.windowId, window.windowId), .emptyStdin)
                case .failure(let error): NickelSupervisor.shared.recordHookFailure("Policy run: \(error)")
                default: NickelSupervisor.shared.recordHookFailure("Policy run: command is not allowed: \(raw)")
            }
        }
    }
}

extension Workspace {
    @MainActor func mruColumnSlot(excluding window: Window?) -> Int {
        rootTilingContainer.childrenByMostRecentUse.first { child in
            child.allLeafWindowsRecursive.contains { $0 !== window }
        }?.columnSlot ?? 1
    }

    @MainActor func columnRecords(excluding window: Window? = nil) async throws -> JSONValue {
        guard let columns else { return .array([]) }
        var records: [JSONValue] = []
        for slot in 1...columns.slotCount {
            let windows = rootTilingContainer.children.first { $0.columnSlot == slot }?.allLeafWindowsRecursive.filter { $0 !== window } ?? []
            var values: [JSONValue] = []
            for window in windows { if let record = try await window.windowRecord() { values.append(record.json) } }
            records.append(.object(["index": .int(slot), "width": .double(Double(columns.widths[slot - 1])),
                                    "empty": .bool(windows.isEmpty), "windows": .array(values)]))
        }
        return .array(records)
    }
}

extension JSONValue {
    var prettyPrinted: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? String(decoding: encoder.encode(self), as: UTF8.self)) ?? "null"
    }
}
