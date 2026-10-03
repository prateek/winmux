import AppKit
import Common

final class ColumnState {
    let count: Int
    var focusedSlot: Int?
    let declaredWidths: [CGFloat]
    var widths: [CGFloat]
    weak var root: TilingContainer?

    init(count: Int, widths: [CGFloat]? = nil) {
        precondition(count > 0)
        let widths = widths ?? Array(repeating: 1 / CGFloat(count), count: count)
        precondition(widths.count == count && widths.allSatisfy { $0 > 0 && $0.isFinite })
        self.count = count
        let total = widths.reduce(0, +)
        self.declaredWidths = widths.map { $0 / total }
        self.widths = declaredWidths
    }
}

extension Workspace {
    @MainActor
    func enforceColumnInvariant() {
        guard let columns else { return }
        let root = rootTilingContainer
        if let oldRoot = columns.root, oldRoot !== root, oldRoot.nodeWorkspace === self {
            for child in oldRoot.children {
                let slot = child.columnSlot
                child.bind(to: root, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
                child.columnSlot = slot
            }
            oldRoot.unbindFromParent()
        }
        root.changeOrientation(.h)
        root.layout = .tiles
        columns.root = root
        var occupied: Set<Int> = []
        var extras: [TreeNode] = []
        for child in root.children {
            if let slot = child.columnSlot, (1...columns.count).contains(slot), occupied.insert(slot).inserted {
                continue
            }
            child.columnSlot = nil
            extras.append(child)
        }
        // Remove all extras before placement so unindexed arrivals cannot become MRU targets.
        for child in extras { child.unbindFromParent() }
        for child in extras {
            let slot = columnPlacementSlot()
            bindToColumn(child, slot: slot)
        }
        for child in root.children {
            if let slot = child.columnSlot {
                child.setWeight(.h, root.hWeight * columns.widths[slot - 1])
            }
        }
        let mostRecent = root.mostRecentChild
        for child in root.children.sorted(by: { $0.columnSlot.orDie() < $1.columnSlot.orDie() }) {
            let weight = child.hWeight
            child.bind(to: root, adaptiveWeight: weight, index: INDEX_BIND_LAST)
        }
        mostRecent?.markAsMostRecentChild()
    }

    @MainActor
    func moveAcrossColumnBoundary(_ node: TreeNode, direction: CardinalDirection) -> Bool {
        guard let columns, let slot = columnSlot(containing: node) else { return false }
        guard direction.orientation == .h else { return true }
        let destination = slot + direction.focusOffset
        guard (1...columns.count).contains(destination) else { return true }
        node.unbindFromParent()
        bindToColumn(node, slot: destination)
        return true
    }

    @MainActor
    func columnSlot(containing node: TreeNode?) -> Int? {
        guard let node, node.nodeWorkspace === self else { return nil }
        return node.parentsWithSelf.first { $0.parent === rootTilingContainer }?.columnSlot
    }

    @MainActor
    func columnPlacementSlot() -> Int {
        let columns = columns.orDie()
        let root = rootTilingContainer
        let anchor = columns.focusedSlot ?? columnSlot(containing: focus.windowOrNil) ??
            root.childrenByMostRecentUse.first?.columnSlot ?? 1
        let occupied = Set(root.children.compactMap(\.columnSlot))
        return (1...columns.count).filter { !occupied.contains($0) }.min {
            let left = abs($0 - anchor)
            let right = abs($1 - anchor)
            return left == right ? $0 < $1 : left < right
        } ?? anchor
    }

    @MainActor
    func columnBinding(slot: Int) -> BindingData {
        let root = rootTilingContainer
        if let existing = root.children.first(where: { $0.columnSlot == slot }) {
            if let group = existing as? TilingContainer, group.layout == .tabGroup {
                return BindingData(parent: group, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
            }
            let index = existing.ownIndex.orDie()
            let weight = existing.hWeight
            existing.unbindFromParent()
            let group = TilingContainer(parent: root, adaptiveWeight: weight, .v, .tabGroup, index: index)
            group.columnSlot = slot
            existing.columnSlot = nil
            existing.bind(to: group, adaptiveWeight: WEIGHT_AUTO, index: 0)
            return BindingData(parent: group, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        }
        // A short-lived wrapper carries the slot through BindingData until the window binds.
        let column = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: INDEX_BIND_LAST)
        column.columnSlot = slot
        return BindingData(parent: column, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }

    @MainActor
    func bindToColumn(_ node: TreeNode, slot: Int) {
        let binding = columnBinding(slot: slot)
        node.columnSlot = nil
        node.bind(to: binding.parent, adaptiveWeight: binding.adaptiveWeight, index: binding.index)
        if let column = binding.parent as? TilingContainer, column.children.count == 1 {
            column.unbindSingleColumnChild()
        }
    }
}

extension TilingContainer {
    @MainActor
    fileprivate func unbindSingleColumnChild() {
        guard let slot = columnSlot, let child = children.singleOrNil(), let parent else { return }
        let index = ownIndex.orDie()
        let weight = hWeight
        child.unbindFromParent()
        unbindFromParent()
        child.bind(to: parent, adaptiveWeight: weight, index: index)
        child.columnSlot = slot
    }
}
