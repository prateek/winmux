import Common
import Foundation

@MainActor
struct PolicyHookCompletion {
    enum Outcome {
        case completed(Bool)
        case fallback(Bool)
    }
    private struct Abandoned: Error {}
    private let window: Window
    private let workspace: Workspace
    private let location: ColumnPolicy.Location
    private let columns: ColumnState?
    private let checksColumns: Bool

    private init(window: Window, workspace: Workspace, checksColumns: Bool) {
        self.window = window
        self.workspace = workspace
        location = ColumnPolicy.Location(window)
        columns = workspace.columns
        self.checksColumns = checksColumns
    }

    private var isCurrent: Bool {
        location.contains(window) && (!checksColumns || workspace.columns === columns)
    }

    func arrivalFallback(to destination: Workspace) -> Bool {
        guard location.contains(window) else { return false }
        window.bind(to: bindingDataForNewTilingWindow(destination, window: window))
        return true
    }

    private struct RunningHook: Hashable {
        let windowId: UInt32
        let path: String
    }

    /// Hook definitions whose `run` list is executing for a window. Keyed by window and path,
    /// not by task: an unstructured `Task` inherits task-locals, so a task-local guard would
    /// leak into later refresh sessions.
    private static var runningWindows: Set<RunningHook> = []

    static func call(_ path: String?, window: Window, workspace: Workspace, edge: Bool? = nil,
                     supervisor: any PolicyHookHelper = PolicyHooks.current, initialClass: WindowClass? = nil, columnsSnapshot: JSONValue? = nil) async -> JSONValue? {
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
                    guard ColumnPolicy.accepts(result, hook: path.split(separator: ".").last.map(String.init) ?? path) else {
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

    static func commands(_ result: JSONValue?) -> [String] {
        result?["run"]?.arrayOrNil?.compactMap(\.stringOrNil) ?? []
    }

    static func run(_ commands: [String], window: Window, path: String) async throws {
        guard !commands.isEmpty, window.isBound else { return }
        let key = RunningHook(windowId: window.windowId, path: path)
        guard runningWindows.insert(key).inserted else {
            PolicyHooks.current.recordHookFailure("Policy run: \(path) is already running for this window; its run list is suppressed")
            return
        }
        defer { runningWindows.remove(key) }
        try await execute(commands, window: window)
    }

    private static func execute(_ commands: [String], window: Window) async throws {
        for raw in commands {
            guard window.isBound else { return }
            switch parseCommand(raw) {
                case .cmd(let command) where command.info.allowInConfig:
                    _ = try await [command].runCmdSeq(CmdEnv(windowWorkspaceFallback: window.nodeWorkspace?.name ?? focus.workspace.name, windowId: window.windowId), .emptyStdin)
                case .failure(let error): PolicyHooks.current.recordHookFailure("Policy run: \(error)")
                default: PolicyHooks.current.recordHookFailure("Policy run: command is not allowed: \(raw)")
            }
        }
    }

    static func runList(_ result: JSONValue?, path: String?) -> (String?, [String]) {
        (path, commands(result))
    }

    func overflow() async throws -> OverflowPolicy {
        let decision = await ColumnPolicy.decision(window: window, workspace: workspace)
        guard isCurrent else { throw Abandoned() }
        return decision.overflow
    }

    static func perform<Value>(
        window: Window, workspace: Workspace, checksColumns: Bool = true,
        normalize: Workspace? = nil, helper: any PolicyHookHelper = PolicyHooks.current,
        evaluate: @MainActor () async -> Value,
        runList: @MainActor (Value) -> (String?, [String]),
        abandoned: @MainActor () -> Bool,
        mutate: @MainActor (Value, PolicyHookCompletion) async throws -> Outcome
    ) async throws -> Bool {
        let attempt = PolicyHookCompletion(window: window, workspace: workspace, checksColumns: checksColumns)
        return try await PolicyHooks.$scoped.withValue(helper) { @MainActor in
            let value = await evaluate()
            guard attempt.isCurrent else { return abandoned() }
            let outcome: Outcome
            do { outcome = try await mutate(value, attempt) }
            catch is Abandoned { return abandoned() }
            switch outcome {
                case .fallback(let result): return result
                case .completed(let result):
                    normalize?.normalizeContainers()
                    let (path, commands) = runList(value)
                    if result, let path { try await run(commands, window: window, path: path) }
                    return result
            }
        }
    }
}
