import AppKit

// Raw values are the Policy hook contract and CLI representation.
enum OverflowPolicy: String, CaseIterable {
    case tabGroup = "tab-group"
    case split
    case float
    case squeeze
}

@MainActor
struct ResolvedColumnPlacement {
    enum Effect {
        case attach
        case tabGroup
        case split(TreeNode)
        case float
    }

    let slot: Int
    let effect: Effect
    let widths: [CGFloat]
    /// The incoming tile's vertical share, before gaps; nil denotes a floating placement.
    let verticalRange: ClosedRange<CGFloat>?
}

@MainActor
enum ColumnPlacement {
    static func resolve(_ decision: PlacementDecision, columns: ColumnState, children: [TreeNode], incoming: TreeNode) -> ResolvedColumnPlacement {
        resolve(slot: decision.slot, overflow: decision.overflow, columns: columns, children: children, incoming: incoming)
    }

    static func resolve(slot: Int, overflow: OverflowPolicy, columns: ColumnState, children: [TreeNode], incoming: TreeNode) -> ResolvedColumnPlacement {
        var widths = columns.widths
        var slot = slot
        let existing = children.first { $0.columnSlot == slot && $0 !== incoming }
        if let existing {
            switch overflow {
                case .float:
                    return ResolvedColumnPlacement(slot: slot, effect: .float, widths: widths, verticalRange: nil)
                case .split:
                    let incomingWindows = Set(incoming.allLeafWindowsRecursive.map(ObjectIdentifier.init))
                    let keepsExistingTile = existing.allLeafWindowsRecursive.contains { !incomingWindows.contains(ObjectIdentifier($0)) }
                    return ResolvedColumnPlacement(slot: slot, effect: .split(existing), widths: widths,
                                                   verticalRange: keepsExistingTile ? 0.5...1 : 0...1)
                case .squeeze:
                    if widths.count == columns.count {
                        let width = 1 / CGFloat(columns.count + 1)
                        widths = widths.map { $0 * (1 - width) } + [width]
                    }
                    slot = widths.count
                case .tabGroup: break
            }
        }
        let occupied = children.contains { $0.columnSlot == slot && $0 !== incoming }
        return ResolvedColumnPlacement(slot: slot, effect: occupied ? .tabGroup : .attach, widths: widths, verticalRange: 0...1)
    }
}
