import Foundation

@MainActor
struct ColumnsEventTracker {
    private struct Snapshot: Equatable {
        let count: Int
        let widths: [Double]
        let occupied: [Int]

        var emptied: Snapshot { Snapshot(count: count, widths: widths, occupied: []) }

        init(count: Int, widths: [Double], occupied: [Int]) {
            self.count = count
            self.widths = widths
            self.occupied = occupied
        }

        init(_ workspace: Workspace) {
            let columns = workspace.columns
            count = columns?.slotCount ?? 0
            widths = columns?.widths.map(Double.init) ?? []
            occupied = columns == nil ? [] : workspace.existingRootTilingContainer?.children
                .filter(\.containsLeafWindow).compactMap(\.columnSlot).sorted() ?? []
        }
    }
    private var previous: [String: Snapshot]?

    mutating func event(for focused: Workspace, workspaces: [Workspace]? = nil) -> ServerEvent? {
        let workspaces = workspaces ?? Workspace.all
        let current = Dictionary(workspaces.map { ($0.name, Snapshot($0)) }, uniquingKeysWith: { first, _ in first })
        defer { previous = current }
        guard let previous, let after = current[focused.name] else { return nil }
        // A workspace created since the last refresh starts from its Columns with nothing in them,
        // so a window that arrives with the workspace still counts as filling a Column.
        let before = previous[focused.name] ?? after.emptied
        guard before != after else { return nil }
        return .columnsChanged(workspace: focused.name, count: after.count, widths: after.widths, occupied: after.occupied)
    }
}

@MainActor var columnsEventTracker = ColumnsEventTracker()
