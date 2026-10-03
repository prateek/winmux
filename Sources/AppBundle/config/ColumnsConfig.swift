import AppKit
import Common

struct ColumnsConfig: Sendable {
    private var global: JSONValue = .object([:])
    private var workspaces: JSONValue = .object([:])
    var widthPresets: [CGFloat] {
        global["width-presets"]?.arrayOrNil?.compactMap(columnNumber) ?? [1/3, 1/2, 2/3]
    }

    init() {}
    init(_ global: JSONValue?, workspaces: JSONValue?) {
        self.global = global ?? .object([:])
        self.workspaces = workspaces ?? .object([:])
    }

    func resolved(workspace: String) -> ColumnState? {
        let local = workspaces[workspace]?["columns"]
        var count: Int?
        var widths: [CGFloat]?
        for record in [Optional(global), global["when"]?["default"], local, local?["when"]?["default"]] {
            if let value = record?["count"] {
                count = value.stringOrNil == "off" ? nil : columnNumber(value).map(Int.init)
            }
            if let values = record?["widths"]?.arrayOrNil { widths = values.compactMap(columnNumber) }
        }
        guard let count, count > 0 else { return nil }
        guard widths == nil || (widths!.count == count && widths!.allSatisfy { $0 > 0 && $0.isFinite }) else { return nil }
        return ColumnState(count: count, widths: widths)
    }
}

private func columnNumber(_ value: JSONValue) -> CGFloat? {
    switch value {
        case .int(let number): CGFloat(number)
        case .double(let number): CGFloat(number)
        default: nil
    }
}

extension Workspace {
    @MainActor func applyColumns(_ settings: ColumnsConfig) {
        columns = settings.resolved(workspace: name)
        if columns == nil {
            // `rootTilingContainer` creates the root, and its orientation, when there is none yet.
            for root in children.filterIsInstance(of: TilingContainer.self) {
                for child in root.children { child.columnSlot = nil }
            }
        } else if !children.isEmpty {
            enforceColumnInvariant()
        }
    }
}
