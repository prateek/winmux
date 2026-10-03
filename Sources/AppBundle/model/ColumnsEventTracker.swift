import Foundation

@MainActor
struct ColumnsEventTracker {
    private struct Snapshot: Equatable {
        let identity: ObjectIdentifier
        let count: Int
        let widths: [Double]
        let occupied: [Int]
    }
    private var previous: Snapshot?

    mutating func event(for workspace: Workspace) -> ServerEvent? {
        let columns = workspace.columns
        let current = Snapshot(
            identity: ObjectIdentifier(workspace), count: columns?.slotCount ?? 0,
            widths: columns?.widths.map(Double.init) ?? [],
            occupied: columns == nil ? [] : workspace.rootTilingContainer.children
                .filter { !$0.allLeafWindowsRecursive.isEmpty }.compactMap(\.columnSlot).sorted()
        )
        defer { previous = current }
        guard let previous, previous.identity == current.identity, previous != current else { return nil }
        return .columnsChanged(workspace: workspace.name, count: current.count, widths: current.widths, occupied: current.occupied)
    }
}

@MainActor var columnsEventTracker = ColumnsEventTracker()
