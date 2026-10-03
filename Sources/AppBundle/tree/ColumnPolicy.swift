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

    /// Windows whose `run` list is executing. Keyed by window, not by task: an unstructured
    /// `Task` inherits task-locals, so a task-local guard would leak into later refresh sessions.
    private static var runningWindows: Set<UInt32> = []

    static func call(_ path: String?, window: Window, workspace: Workspace, edge: Bool? = nil,
                     supervisor: NickelSupervisor = .shared, initialClass: WindowClass? = nil, columnsSnapshot: JSONValue? = nil) async -> JSONValue? {
        guard let path else { return nil }
        let started = ContinuousClock.now
        var argumentDuration: Duration?
        defer {
            if isDebug, ProcessInfo.processInfo.environment["WINMUX_DEBUG_POLICY_TIMING"] == "1", let argumentDuration {
                func milliseconds(_ duration: Duration) -> Double {
                    Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
                }
                debugFocusLog("policy-timing arguments-ms=\(milliseconds(argumentDuration)) total-ms=\(milliseconds(started.duration(to: .now)))")
            }
        }
        do {
            let argsWithoutEdge = try await withThrowingTaskGroup(of: (Int, JSONValue?).self) { group in
                group.addTask { @MainActor @Sendable in
                    guard var record = try await window.windowRecord(initialClass: initialClass) else { return (0, nil) }
                    record.workspace = workspace.name
                    record.project = workspace.projectId.rawValue
                    record.monitor = MonitorRecord(workspace.workspaceMonitor)
                    return (0, record.json)
                }
                group.addTask { @MainActor @Sendable in (1, try await filterContextRecord().json) }
                group.addTask { @MainActor @Sendable in
                    if let columnsSnapshot { return (2, columnsSnapshot) }
                    return (2, try await workspace.columnRecords(excluding: edge == nil ? window : nil))
                }
                var values = [JSONValue?](repeating: nil, count: 3)
                for try await (index, value) in group { values[index] = value }
                return values
            }
            guard argsWithoutEdge.allSatisfy({ $0 != nil }) else { return nil }
            var args = argsWithoutEdge.compactMap { $0 }
            try Task.checkCancellation()
            if let edge { args.append(.bool(edge)) }
            argumentDuration = started.duration(to: .now)
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
        } catch is CancellationError {
            return nil
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
                         supervisor: NickelSupervisor = .shared, columnsSnapshot: JSONValue? = nil) async -> PlacementDecision {
        var builtIn = PlacementDecision(slot: workspace.columnPlacementSlot(excluding: window), target: "nearest-empty", overflow: "tab-group", hook: nil)
        guard let columns = workspace.columns else { return builtIn }
        let path = hook("place", on: workspace)
        let result: JSONValue?
        if let answer { result = answer } else { result = await call(path, window: window, workspace: workspace, supervisor: supervisor, initialClass: .tiled, columnsSnapshot: columnsSnapshot) }
        builtIn = PlacementDecision(slot: workspace.columnPlacementSlot(excluding: window), target: "nearest-empty", overflow: "tab-group", hook: nil)
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
                case "last": slot = columns.count
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

    @discardableResult
    static func place(_ window: Window, on workspace: Workspace, answer: JSONValue? = nil,
                      supervisor: NickelSupervisor = .shared) async throws -> Bool {
        guard workspace.columns != nil else { return false }
        let location = Location(window)
        let columns = workspace.columns
        let decision = await decision(window: window, workspace: workspace, answer: answer, supervisor: supervisor)
        guard location.contains(window), workspace.columns === columns else { return false }
        if window.isBound { window.unbindFromParent() }
        workspace.bindToColumn(window, slot: decision.slot, overflow: decision.overflow)
        workspace.normalizeContainers()
        try await run(decision.run, window: window)
        return true
    }

    static func afterTransfer(_ window: Window, from previous: Workspace?, didMove: Bool) async throws -> Bool {
        if didMove, !window.isFloating, let workspace = window.nodeWorkspace, workspace !== previous,
           hook("place", on: workspace) != nil {
            try await place(window, on: workspace)
        }
        return didMove
    }

    static func arrive(_ window: Window, on detected: Workspace, floatingDefault: Bool,
                       supervisor: NickelSupervisor = .shared) async throws {
        let location = Location(window)
        let initialClass: WindowClass? = window.parent === macosPopupWindowsContainer ? nil : (floatingDefault ? .floating : .tiled)
        let result = await call(config.arrive, window: window, workspace: detected, supervisor: supervisor, initialClass: initialClass)
        guard location.contains(window) else { return }
        if window.parent === macosPopupWindowsContainer {
            try await run(commands(result), window: window)
            return
        }
        let destination = result?["workspace"]?.stringOrNil.map { Workspace.get(byName: $0) } ?? detected
        destination.seedMonitorIfNeeded(detected.workspaceMonitor)
        let floating: Bool
        if case .bool(let value) = result?["float"] { floating = value } else { floating = floatingDefault }
        if floating {
            if window.isBound { window.unbindFromParent() }
            window.bindAsFloatingWindow(to: destination)
        } else {
            let explicit = result?["column"] == nil ? nil : result
            var placement = explicit
            if case .object(var fields) = placement { fields.removeValue(forKey: "run"); placement = .object(fields) }
            if destination.columns != nil {
                if try await !place(window, on: destination, answer: placement, supervisor: supervisor) {
                    // Abandoned: the window moved, or the workspace's Columns were replaced, during
                    // the call. Only the second leaves it in the binding it was registered with.
                    guard location.contains(window) else { return }
                    window.bind(to: bindingDataForNewTilingWindow(destination, window: window))
                }
            } else {
                window.bind(to: bindingDataForNewTilingWindow(destination, window: window))
            }
        }
        try await run(commands(result), window: window)
    }

    static func commands(_ result: JSONValue?) -> [String] {
        result?["run"]?.arrayOrNil?.compactMap(\.stringOrNil) ?? []
    }

    static func run(_ commands: [String], window: Window) async throws {
        guard !commands.isEmpty, window.isBound else { return }
        guard runningWindows.insert(window.windowId).inserted else {
            NickelSupervisor.shared.recordHookFailure("Policy run: nested run list suppressed")
            return
        }
        defer { runningWindows.remove(window.windowId) }
        try await execute(commands, window: window)
    }

    private static func execute(_ commands: [String], window: Window) async throws {
        for raw in commands {
            guard window.isBound else { return }
            switch parseCommand(raw) {
                case .cmd(let command) where command.info.allowInConfig:
                    _ = try await [command].runCmdSeq(CmdEnv(windowWorkspaceFallback: window.nodeWorkspace?.name ?? focus.workspace.name, windowId: window.windowId), .emptyStdin)
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
