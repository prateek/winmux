import AppKit
import Common

struct PlacementDecision: Equatable {
    let slot: Int
    let target: String
    let overflow: OverflowPolicy
    let hook: String?
    var run: [String] = []
    var failure: String?

    var json: JSONValue {
        .object(["column": .int(slot), "target": .string(target), "overflow": .string(overflow.rawValue),
                 "hook": hook.map(JSONValue.string) ?? .null, "run": .array(run.map(JSONValue.string)), "failure": failure.map(JSONValue.string) ?? .null])
    }
}

@MainActor
enum ColumnPolicy {
    static func hook(_ name: String, on workspace: Workspace) -> String? {
        guard workspace.columns != nil else { return nil }
        return config.columns.hook(name, workspace: workspace.name)
    }

    @MainActor struct Location {
        let ancestors: [(TreeNode, UInt64)]
        let workspace: Workspace?
        let slot: Int?
        init(_ window: Window) {
            ancestors = window.parentsWithSelf.map { ($0, $0.bindingRevision) }
            workspace = window.nodeWorkspace
            slot = workspace?.columnSlot(containing: window)
        }
        func contains(_ window: Window) -> Bool {
            let current = window.parentsWithSelf
            return current.count == ancestors.count && zip(current, ancestors).allSatisfy { $0 === $1.0 && $0.bindingRevision == $1.1 }
                && window.nodeWorkspace === workspace && workspace?.columnSlot(containing: window) == slot
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
            guard let action = overflow.stringOrNil, OverflowPolicy(rawValue: action) != nil else { return false }
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
                         supervisor: any PolicyHookHelper = PolicyHooks.current, columnsSnapshot: JSONValue? = nil) async -> PlacementDecision {
        var builtIn = PlacementDecision(slot: workspace.columnPlacementSlot(excluding: window), target: "nearest-empty", overflow: .tabGroup, hook: nil)
        guard let columns = workspace.columns else { return builtIn }
        let path = hook("place", on: workspace)
        // An Arrive answer is Arrive's result: name Arrive in its failures and as its source.
        let source = answer == nil ? path : config.arrive
        let result: JSONValue?
        if let answer { result = answer } else { result = await PolicyHookCompletion.call(path, window: window, workspace: workspace, supervisor: supervisor, initialClass: .tiled, columnsSnapshot: columnsSnapshot) }
        builtIn = PlacementDecision(slot: workspace.columnPlacementSlot(excluding: window), target: "nearest-empty", overflow: .tabGroup, hook: nil)
        guard let result else {
            if path != nil { builtIn.failure = supervisor.lastHookError ?? "Hook unavailable" }
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
                case "last": slot = columns.count
                default:
                    supervisor.recordHookFailure("\(source ?? "arrive"): invalid Column target")
                    builtIn.failure = supervisor.lastHookError
                    return builtIn
            }
        } else if case .int(let value) = result["column"] {
            guard (1...columns.count).contains(value) else {
                supervisor.recordHookFailure("\(source ?? "arrive"): Column index \(value) exceeds count \(columns.count)")
                builtIn.failure = supervisor.lastHookError
                return builtIn
            }
            slot = value
            target = String(value)
        } else {
            supervisor.recordHookFailure("\(source ?? "arrive"): missing Column target")
            builtIn.failure = supervisor.lastHookError
            return builtIn
        }
        guard (1...columns.slotCount).contains(slot) else {
            supervisor.recordHookFailure("\(source ?? "arrive"): Column index \(slot) exceeds count \(columns.slotCount)")
            builtIn.failure = supervisor.lastHookError
            return builtIn
        }
        return PlacementDecision(slot: slot, target: target, overflow: result["overflow"]?.stringOrNil.flatMap(OverflowPolicy.init(rawValue:)) ?? .tabGroup,
                                 hook: source, run: PolicyHookCompletion.commands(result))
    }

    @discardableResult
    static func place(_ window: Window, on workspace: Workspace, answer: JSONValue? = nil,
                      supervisor: any PolicyHookHelper = PolicyHooks.current) async throws -> Bool {
        guard workspace.columns != nil else { return false }
        return try await PolicyHookCompletion.perform(window: window, workspace: workspace, normalizes: true, helper: supervisor,
            evaluate: { await decision(window: window, workspace: workspace, answer: answer, supervisor: supervisor) },
            runList: { ($0.hook, $0.run) }, abandoned: { false }) { decision, _ in
                if window.isBound { window.unbindFromParent() }
                workspace.bindToColumn(window, slot: decision.slot, overflow: decision.overflow)
                return .completed(true)
            }
    }

    static func afterTransfer(_ window: Window, from previous: Workspace?, didMove: Bool) async throws -> Bool {
        if didMove, !window.isFloating, let workspace = window.nodeWorkspace, workspace !== previous,
           hook("place", on: workspace) != nil {
            try await place(window, on: workspace)
        }
        return didMove
    }

    static func arrive(_ window: Window, on detected: Workspace, floatingDefault: Bool,
                       supervisor: any PolicyHookHelper = PolicyHooks.current) async throws {
        // With no hook to wait on, arrival binds without suspending, so nothing sees the window unplaced.
        guard config.arrive != nil || hook("place", on: detected) != nil else {
            return try await applyArrival(window, on: detected, floatingDefault: floatingDefault, supervisor: supervisor)
        }
        // Keep refresh task-locals while letting arrival outlive the detecting session.
        let task = Task { @MainActor in
            try await applyArrival(window, on: detected, floatingDefault: floatingDefault, supervisor: supervisor)
        }
        // The cancelled session stops before its layout, so lay out what arrival changed.
        defer { if Task.isCancelled { scheduleRefreshSession(.ax(kAXWindowCreatedNotification as String)) } }
        try await task.value
    }

    private static func applyArrival(_ window: Window, on detected: Workspace, floatingDefault: Bool,
                                     supervisor: any PolicyHookHelper) async throws {
        let initialClass: WindowClass? = window.parent === macosPopupWindowsContainer ? nil : (floatingDefault ? .floating : .tiled)
        let path = config.arrive
        _ = try await PolicyHookCompletion.perform(window: window, workspace: detected, checksColumns: false, normalizes: false, helper: supervisor,
            evaluate: { await PolicyHookCompletion.call(path, window: window, workspace: detected, supervisor: supervisor, initialClass: initialClass) },
            runList: { (path, PolicyHookCompletion.commands($0)) }, abandoned: { false }) { result, completion in
                if window.parent === macosPopupWindowsContainer { return .completed(true) }
                let destination = result?["workspace"]?.stringOrNil.map { Workspace.get(byName: $0) } ?? detected
                destination.seedMonitorIfNeeded(detected.workspaceMonitor)
                let floating: Bool
                if case .bool(let value) = result?["float"] { floating = value } else { floating = floatingDefault }
                if floating {
                    if window.isBound { window.unbindFromParent() }
                    window.bindAsFloatingWindow(to: destination)
                } else {
                    var placement = result?["column"] == nil ? nil : result
                    if case .object(var fields) = placement { fields.removeValue(forKey: "run"); placement = .object(fields) }
                    if destination.columns != nil {
                        if try await !place(window, on: destination, answer: placement, supervisor: supervisor) {
                            // Abandoned: the window moved, or the workspace's Columns were replaced, during
                            // the call. Only the second leaves it in the binding it was registered with.
                            guard completion.isAtOrigin else { return .fallback(false) }
                            window.bind(to: bindingDataForNewTilingWindow(destination, window: window))
                        }
                    } else {
                        window.bind(to: bindingDataForNewTilingWindow(destination, window: window))
                    }
                }
                return .completed(true)
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
        let slots = (1...columns.slotCount).map { slot in
            rootTilingContainer.children.first { $0.columnSlot == slot }?.allLeafWindowsRecursive.filter { $0 !== window } ?? []
        }
        let widths = columns.widths
        let windows = slots.flatMap { $0 }
        var values: [UInt32: JSONValue] = [:]
        try await withThrowingTaskGroup(of: (UInt32, WindowRecord?).self) { group in
            for window in windows {
                group.addTask { @MainActor @Sendable in (window.windowId, try await window.windowRecord()) }
            }
            for try await (id, record) in group { if let record { values[id] = record.json } }
        }
        let records = slots.enumerated().map { index, windows in
            JSONValue.object(["index": .int(index + 1), "width": .double(Double(widths[index])),
                              "empty": .bool(windows.isEmpty), "windows": .array(windows.compactMap { values[$0.windowId] })])
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
