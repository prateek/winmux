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
    /// A drop owns its answer from `beginDrop` to `endDrop`; drag lookups find no destination meanwhile.
    private(set) var isDropping = false
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
        _ = request(window: window, workspace: workspace, context: context, slot: slot, incoming: incoming)
        pointedSlot = slot
        redraw = onReady
        return context.flatMap { answers[Key(context: $0, slot: slot)] }
            ?? PlacementDecision(slot: slot, target: String(slot), overflow: .tabGroup, hook: nil)
    }

    /// The landed answer for the tree as it is now, if the preview already has one.
    func answer(window: Window, workspace: Workspace, slot: Int) -> PlacementDecision? {
        Self.context(window: window, workspace: workspace).flatMap { answers[Key(context: $0, slot: slot)] }
    }

    /// Ends the previews and hands the drop the request for this key, landed or still running.
    func beginDrop(window: Window, workspace: Workspace, slot: Int) -> Task<PlacementDecision, Never>? {
        let key = Self.context(window: window, workspace: workspace).map { Key(context: $0, slot: slot) }
        let answer = key.flatMap { answers[$0] }
        var request = key.flatMap { tasks.removeValue(forKey: $0) }
        if request?.columns !== workspace.columns { request = nil }
        clear()
        isDropping = true
        if let answer { return Task { answer } }
        return request?.task
    }

    func endDrop() {
        isDropping = false
    }

    func decision(window: Window, workspace: Workspace, slot: Int, incoming: TreeNode) async -> PlacementDecision? {
        let context = Self.context(window: window, workspace: workspace)
        if self.context == nil { track(window: window, context: context) }
        let requestGeneration = generation
        let requestContext = self.context
        let columns = workspace.columns
        let answer = await request(window: window, workspace: workspace, context: context, slot: slot, incoming: incoming).value
        guard generation == requestGeneration, self.context == requestContext, workspace.columns === columns else { return nil }
        return answer
    }

    private func request(window: Window, workspace: Workspace, context: Context?, slot: Int, incoming: TreeNode) -> Task<PlacementDecision, Never> {
        guard let columns = workspace.columns, let context else {
            return Task { PlacementDecision(slot: slot, target: String(slot), overflow: .tabGroup, hook: nil) }
        }
        let key = Key(context: context, slot: slot)
        if let request = tasks[key], request.columns === columns { return request.task }
        let requestGeneration = generation
        let evaluate = evaluate
        let task = Task { @MainActor [weak self] in
            let answer = await evaluate(window, workspace, slot, incoming)
            // Kept only for the tree it was asked about: the hook reads the records when it starts.
            if let self, self.generation == requestGeneration, workspace.columns === columns,
               Self.context(window: window, workspace: workspace) == key.context {
                self.answers[key] = answer
                if self.context == key.context, self.pointedSlot == slot { self.redraw?() }
            }
            return answer
        }
        tasks[key] = Request(columns: columns, task: task)
        return task
    }
}
