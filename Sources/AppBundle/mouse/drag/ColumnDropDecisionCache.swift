import Foundation

@MainActor
final class ColumnDropDecisionCache {
    static let shared = ColumnDropDecisionCache()

    private struct Context: Hashable {
        let windowId: UInt32
        let workspace: ObjectIdentifier
        let columns: ObjectIdentifier
        /// The leaf window ids in each slot: a window arriving or leaving mid-drag changes what the hook sees.
        let occupancy: [[UInt32]]
    }

    private struct Key: Hashable {
        let context: Context
        let slot: Int
    }

    private struct Request {
        /// Holds the state alive, so the `ObjectIdentifier` in a live key cannot be reused by a new one.
        let columns: ColumnState
        let task: Task<Void, Never>
    }

    private var draggedWindowId: UInt32?
    private var context: Context?
    private var generation = 0
    private var pointedSlot: Int?
    private var tasks: [Key: Request] = [:]
    private var answers: [Key: PlacementDecision] = [:]
    private var redraw: (() -> Void)?
    private let evaluate: @MainActor (Window, Workspace, Int, TreeNode) async -> PlacementDecision

    init(evaluate: @escaping @MainActor (Window, Workspace, Int, TreeNode) async -> PlacementDecision = {
        await ColumnPolicy.dropDecision(window: $0, workspace: $1, slot: $2, incoming: $3)
    }) {
        self.evaluate = evaluate
    }

    private static func context(window: Window, workspace: Workspace) -> Context? {
        workspace.columns.map {
            Context(windowId: window.windowId, workspace: ObjectIdentifier(workspace), columns: ObjectIdentifier($0),
                    occupancy: workspace.columnOccupancy)
        }
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
        track(window: window, context: Self.context(window: window, workspace: workspace))
    }

    private func track(window: Window, context key: Context?) {
        if draggedWindowId != window.windowId {
            clear()
            draggedWindowId = window.windowId
        }
        if context != key {
            context = key
            pointedSlot = nil
            redraw = nil
        }
    }

    func preview(window: Window, workspace: Workspace, slot: Int, incoming: TreeNode,
                 onReady: @escaping () -> Void) -> PlacementDecision {
        let context = Self.context(window: window, workspace: workspace)
        track(window: window, context: context)
        request(window: window, workspace: workspace, context: context, slot: slot, incoming: incoming)
        pointedSlot = slot
        redraw = onReady
        return context.flatMap { answers[Key(context: $0, slot: slot)] }
            ?? PlacementDecision(slot: slot, target: String(slot), overflow: .tabGroup, hook: nil)
    }

    private func request(window: Window, workspace: Workspace, context: Context?, slot: Int, incoming: TreeNode) {
        guard let columns = workspace.columns, let context else { return }
        let key = Key(context: context, slot: slot)
        if tasks[key] != nil { return }
        let requestGeneration = generation
        let evaluate = evaluate
        let task = Task { @MainActor [weak self] in
            let answer = await evaluate(window, workspace, slot, incoming)
            // Kept only for the tree it was asked about: the hook reads the records when it starts.
            if let self, self.generation == requestGeneration, workspace.columns === columns {
                if Self.context(window: window, workspace: workspace) == key.context {
                    self.answers[key] = answer
                }
                if self.context == key.context, self.pointedSlot == slot { self.redraw?() }
            }
        }
        tasks[key] = Request(columns: columns, task: task)
    }
}
