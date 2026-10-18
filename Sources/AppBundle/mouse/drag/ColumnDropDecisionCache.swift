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

    private struct Request {
        let columns: ColumnState
        let task: Task<PlacementDecision, Never>
    }

    private var draggedWindowId: UInt32?
    private var context: Context?
    private var generation = 0
    private var pointedSlot: Int?
    private var tasks: [Key: Request] = [:]
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
        for request in tasks.values { request.task.cancel() }
        tasks.removeAll()
        answers.removeAll()
        draggedWindowId = nil
        context = nil
        pointedSlot = nil
        redraw = nil
    }

    func track(window: Window, workspace: Workspace) {
        if draggedWindowId != window.windowId {
            clear()
            draggedWindowId = window.windowId
        }
        let key = workspace.columns.map {
            Context(windowId: window.windowId, workspace: ObjectIdentifier(workspace), columns: ObjectIdentifier($0))
        }
        if context != key {
            context = key
            pointedSlot = nil
            redraw = nil
        }
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
        let requestContext = context
        let columns = workspace.columns
        let answer = await request(window: window, workspace: workspace, slot: slot, incoming: incoming, excludingWindows: excludingWindows).value
        guard generation == requestGeneration, context == requestContext, workspace.columns === columns else { return nil }
        return answer
    }

    private func request(window: Window, workspace: Workspace, slot: Int, incoming: TreeNode, excludingWindows: [Window] = []) -> Task<PlacementDecision, Never> {
        guard let columns = workspace.columns else {
            return Task { PlacementDecision(slot: slot, target: String(slot), overflow: .tabGroup, hook: nil) }
        }
        let key = Key(context: Context(windowId: window.windowId, workspace: ObjectIdentifier(workspace),
                                       columns: ObjectIdentifier(columns)), slot: slot)
        if let request = tasks[key], request.columns === columns { return request.task }
        let requestGeneration = generation
        let evaluate = evaluate
        let excluded = excludingWindows.isEmpty ? incoming.allLeafWindowsRecursive : excludingWindows
        let task = Task { @MainActor [weak self] in
            let answer = await evaluate(window, workspace, slot, incoming, excluded)
            if let self, self.generation == requestGeneration,
               workspace.columns === columns {
                self.answers[key] = answer
                if self.context == key.context, self.pointedSlot == slot { self.redraw?() }
            }
            return answer
        }
        tasks[key] = Request(columns: columns, task: task)
        return task
    }
}
