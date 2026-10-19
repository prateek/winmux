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
    private(set) var generation = 0
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
        workspace.columns.map { columns in
            let children = workspace.rootTilingContainer.children
            return Context(windowId: window.windowId, workspace: ObjectIdentifier(workspace), columns: ObjectIdentifier(columns),
                           occupancy: (1...columns.slotCount).map { slot in
                               children.first { $0.columnSlot == slot }?.allLeafWindowsRecursive.map(\.windowId) ?? []
                           })
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
        if draggedWindowId != window.windowId {
            clear()
            draggedWindowId = window.windowId
        }
        let key = Self.context(window: window, workspace: workspace)
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
        return answer(window: window, workspace: workspace, slot: slot)
            ?? PlacementDecision(slot: slot, target: String(slot), overflow: .tabGroup, hook: nil)
    }

    /// The landed answer for the tree as it is now, if the preview already has one.
    func answer(window: Window, workspace: Workspace, slot: Int) -> PlacementDecision? {
        Self.context(window: window, workspace: workspace).flatMap { answers[Key(context: $0, slot: slot)] }
    }

    /// Ends the drag's previews: a drop takes its answer first, and only a later `clear` abandons it.
    func beginDrop() -> Int {
        clear()
        return generation
    }

    func decision(window: Window, workspace: Workspace, slot: Int, incoming: TreeNode) async -> PlacementDecision? {
        if context == nil { track(window: window, workspace: workspace) }
        let requestGeneration = generation
        let requestContext = context
        let columns = workspace.columns
        let answer = await request(window: window, workspace: workspace, slot: slot, incoming: incoming).value
        guard generation == requestGeneration, context == requestContext, workspace.columns === columns else { return nil }
        return answer
    }

    private func request(window: Window, workspace: Workspace, slot: Int, incoming: TreeNode) -> Task<PlacementDecision, Never> {
        guard let columns = workspace.columns, let context = Self.context(window: window, workspace: workspace) else {
            return Task { PlacementDecision(slot: slot, target: String(slot), overflow: .tabGroup, hook: nil) }
        }
        let key = Key(context: context, slot: slot)
        if let request = tasks[key], request.columns === columns { return request.task }
        let requestGeneration = generation
        let evaluate = evaluate
        let task = Task { @MainActor [weak self] in
            let answer = await evaluate(window, workspace, slot, incoming)
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
