import Foundation

@MainActor
final class ColumnDropDecisionCache {
    static let shared = ColumnDropDecisionCache()

    private struct Context: Hashable {
        let windowId: UInt32
        let workspace: ObjectIdentifier
        let columns: ObjectIdentifier
    }

    private struct Key: Hashable {
        let context: Context
        let slot: Int
    }

    private var context: Context?
    private var generation = 0
    private var pointedSlot: Int?
    private var tasks: [Key: Task<PlacementDecision, Never>] = [:]
    private var answers: [Key: PlacementDecision] = [:]
    private var redraw: (() -> Void)?
    private let evaluate: @MainActor (Window, Workspace, Int, TreeNode, [Window]) async -> PlacementDecision

    init(evaluate: @escaping @MainActor (Window, Workspace, Int, TreeNode, [Window]) async -> PlacementDecision = {
        await ColumnPolicy.dropDecision(window: $0, workspace: $1, slot: $2, incoming: $3, excludingWindows: $4)
    }) {
        self.evaluate = evaluate
    }

    func clear() {
        generation += 1
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
        answers.removeAll()
        context = nil
        pointedSlot = nil
        redraw = nil
    }

    func track(window: Window, workspace: Workspace) {
        let key = workspace.columns.map {
            Context(windowId: window.windowId, workspace: ObjectIdentifier(workspace), columns: ObjectIdentifier($0))
        }
        if context != key { clear(); context = key }
    }

    func preview(window: Window, workspace: Workspace, slot: Int, incoming: TreeNode,
                 onReady: @escaping () -> Void) -> PlacementDecision {
        track(window: window, workspace: workspace)
        _ = request(window: window, workspace: workspace, slot: slot, incoming: incoming)
        pointedSlot = slot
        redraw = onReady
        return context.flatMap { answers[Key(context: $0, slot: slot)] }
            ?? PlacementDecision(slot: slot, target: String(slot), overflow: .tabGroup, hook: nil)
    }

    func decision(window: Window, workspace: Workspace, slot: Int, incoming: TreeNode, excludingWindows: [Window] = []) async -> PlacementDecision? {
        if context == nil { track(window: window, workspace: workspace) }
        let requestGeneration = generation
        let columns = workspace.columns
        let answer = await request(window: window, workspace: workspace, slot: slot, incoming: incoming, excludingWindows: excludingWindows).value
        guard generation == requestGeneration, workspace.columns === columns else { return nil }
        return answer
    }

    private func request(window: Window, workspace: Workspace, slot: Int, incoming: TreeNode, excludingWindows: [Window] = []) -> Task<PlacementDecision, Never> {
        guard let columns = workspace.columns else {
            return Task { PlacementDecision(slot: slot, target: String(slot), overflow: .tabGroup, hook: nil) }
        }
        let key = Key(context: Context(windowId: window.windowId, workspace: ObjectIdentifier(workspace),
                                       columns: ObjectIdentifier(columns)), slot: slot)
        if let task = tasks[key] { return task }
        let requestGeneration = generation
        let evaluate = evaluate
        let excluded = excludingWindows.isEmpty ? incoming.allLeafWindowsRecursive : excludingWindows
        let task = Task { @MainActor [weak self] in
            let answer = await evaluate(window, workspace, slot, incoming, excluded)
            if let self, self.generation == requestGeneration, self.context == key.context,
               workspace.columns === columns {
                self.answers[key] = answer
                if self.pointedSlot == slot { self.redraw?() }
            }
            return answer
        }
        tasks[key] = task
        return task
    }
}
