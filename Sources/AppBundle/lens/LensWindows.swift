import Common
import Foundation

struct LensWindow {
    let record: WindowRecord
    let window: Window
    let spatialIndex: Int
    let workspaceIndex: Int
    var workspaceSearchName: String? = nil
    var projectSearchName: String? = nil
    var searchMatch: LensSearchMatch?

    var searchFields: LensSearchFields {
        LensSearchFields(title: record.title, app: record.app.name, workspace: workspaceSearchName ?? record.workspace, project: projectSearchName ?? record.project)
    }
}

@MainActor
func lensWindows(popups: [String]) async throws -> [LensWindow] {
    let ordered = orderedWorkspacesForPresentation()
    let workspaces = ordered + Workspace.all.filter { !ordered.contains($0) }.sorted { $0.name < $1.name }
    let indices = Dictionary(uniqueKeysWithValues: workspaces.enumerated().map { ($0.element.name, $0.offset) })
    let windows = workspaces.flatMap(\.allLeafWindowsRecursive)
        + macosMinimizedWindowsContainer.allLeafWindowsRecursive
        + macosPopupWindowsContainer.allLeafWindowsRecursive
    var records = [WindowRecord?](repeating: nil, count: windows.count)
    await withTaskGroup(of: (Int, WindowRecord?).self) { group in
        for (index, window) in windows.enumerated() {
            guard let windowClass = window.windowClass, lensIncludes(windowClass, popups: popups) else { continue }
            group.addTask { @MainActor @Sendable in
                (index, try? await window.windowRecord())
            }
        }
        for await (index, record) in group { records[index] = record }
    }
    let entries = windows.enumerated().compactMap { index, window -> LensWindow? in
        guard let record = records[index] else { return nil }
        return LensWindow(record: record, window: window, spatialIndex: index, workspaceIndex: indices[record.workspace] ?? Int.max,
                          workspaceSearchName: workspaceDisplayName(record.workspace),
                          projectSearchName: workspaceProjectDisplayName(WorkspaceProjectId(record.project), fallbackName: record.project))
    }
    return entries
}

func lensIncludes(_ windowClass: WindowClass, popups: [String]) -> Bool {
    ![WindowClass.appPopup, .accessoryPopup].contains(windowClass) || popups.contains(windowClass.rawValue)
}

func sortLensWindows(_ entries: [LensWindow], by keys: [String], previousId: UInt32?) -> [LensWindow] {
    entries.sorted { lhs, rhs in
        for key in keys {
            let comparison: ComparisonResult
            switch key {
                case "mru": comparison = compareLensValues(rhs.record.lastFocusedSeq, lhs.record.lastFocusedSeq)
                case "previous": comparison = compareLensValues(lhs.record.id == previousId.map(Int.init) ? 0 : 1, rhs.record.id == previousId.map(Int.init) ? 0 : 1)
                case "spatial": comparison = compareLensValues(lhs.spatialIndex, rhs.spatialIndex)
                case "workspace": comparison = compareLensValues(lhs.workspaceIndex, rhs.workspaceIndex)
                case "app": comparison = compareLensValues(lhs.record.app.name.lowercased(), rhs.record.app.name.lowercased())
                case "title": comparison = compareLensValues(lhs.record.title.lowercased(), rhs.record.title.lowercased())
                default: comparison = compareLensValues(lhs.record.id, rhs.record.id)
            }
            if comparison != .orderedSame { return comparison == .orderedAscending }
        }
        return lhs.record.id < rhs.record.id
    }
}

private func compareLensValues<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
    lhs == rhs ? .orderedSame : lhs < rhs ? .orderedAscending : .orderedDescending
}

func searchLensWindows(_ entries: [LensWindow], search: String) -> [LensWindow] {
    let ranked: [(Int, LensWindow)] = entries.enumerated().compactMap { index, entry in
        guard let match = entry.searchFields.match(search) else { return nil }
        var entry = entry
        entry.searchMatch = match
        return (index, entry)
    }
    return ranked.sorted { lhs, rhs in
        let a = lhs.1.searchMatch!.score, b = rhs.1.searchMatch!.score
        return a == b ? lhs.0 < rhs.0 : a > b
    }.map { $0.1 }
}
