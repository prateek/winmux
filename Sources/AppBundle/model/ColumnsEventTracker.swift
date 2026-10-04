import Foundation

@MainActor
struct ColumnsEventTracker {
    private struct Snapshot: Equatable {
        let count: Int
        let widths: [Double]
        let occupied: [Int]

        init(_ workspace: Workspace) {
            let columns = workspace.columns
            count = columns?.slotCount ?? 0
            widths = columns?.widths.map(Double.init) ?? []
            occupied = columns == nil ? [] : workspace.existingRootTilingContainer?.children
                .filter(\.containsLeafWindow).compactMap(\.columnSlot).sorted() ?? []
        }
    }
    private var previous: [String: Snapshot] = [:]

    mutating func event(for focused: Workspace, workspaces: [Workspace]? = nil) -> ServerEvent? {
        let workspaces = workspaces ?? Workspace.all
        let current = Dictionary(uniqueKeysWithValues: workspaces.map { ($0.name, Snapshot($0)) })
        defer { previous = current }
        guard let before = previous[focused.name], let after = current[focused.name], before != after else { return nil }
        return .columnsChanged(workspace: focused.name, count: after.count, widths: after.widths, occupied: after.occupied)
    }
}

@MainActor var columnsEventTracker = ColumnsEventTracker()
