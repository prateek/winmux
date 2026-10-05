import AppKit
import Common

final class ColumnState {
    let count: Int
    var slotCount: Int { widths.count }
    var focusedSlot: Int?
    var lastFocusedWindowSlot: Int?
    let declaredWidths: [CGFloat]
    var widths: [CGFloat]
    var widthsBeforeMouseResize: [CGFloat]?
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
    static func frame(slot: Int, widths: [CGFloat], in rect: CGRect, gap: CGFloat) -> CGRect {
        let offset = widths.prefix(slot - 1).reduce(0, +) * rect.width
        let left = slot == 1 ? 0 : gap / 2
        let right = slot == widths.count ? 0 : gap / 2
        return CGRect(x: rect.minX + offset + left, y: rect.minY,
                      width: widths[slot - 1] * rect.width - left - right, height: rect.height)
    }

    func proposedWidths(slot: Int, fraction: CGFloat, availableWidth: CGFloat, starting: [CGFloat]? = nil) -> [CGFloat] {
        let base = starting ?? widths
        guard base.indices.contains(slot - 1), fraction.isFinite, availableWidth > 0 else { return base }
        let count = base.count
        guard count > 1 else { return [1] }
        if availableWidth < minimumTiledResizeWeight * CGFloat(count) {
            return Array(repeating: 1 / CGFloat(count), count: count)
        }
        let floor = min(minimumTiledResizeWeight / availableWidth, 1 / CGFloat(count))
        let old = base[slot - 1]
        let others = base.enumerated().filter { $0.offset != slot - 1 }.map(\.element)
        let maximum = 1 - floor * (1 - old) / others.min().orDie()
        if maximum < floor { return Array(repeating: 1 / CGFloat(count), count: count) }
        let desired = max(floor, min(maximum, fraction))
        let scale = (1 - desired) / (1 - old)
        return base.enumerated().map { $0.offset == slot - 1 ? desired : $0.element * scale }
    }

    /// The fraction for `slot` that puts its right edge at `position`, a fraction of the workspace
    /// width, once the other Columns have absorbed the change in proportion. A Column's own change
    /// moves the Columns to its left too, so the edge does not move by the change in width alone.
    func fraction(slot: Int, rightEdgeAt position: CGFloat, starting base: [CGFloat]) -> CGFloat {
        let left = base.prefix(slot - 1).reduce(0, +)
        let own = base[slot - 1]
        let right = 1 - left - own
        return right > 0.000001 ? (position * (1 - own) - left) / right : position - left
    }

    /// As `fraction(slot:rightEdgeAt:starting:)`, for the left edge.
    func fraction(slot: Int, leftEdgeAt position: CGFloat, starting base: [CGFloat]) -> CGFloat {
        let left = base.prefix(slot - 1).reduce(0, +)
        let own = base[slot - 1]
        return left > 0.000001 ? 1 - position * (1 - own) / left : own
    }

    func setWidth(slot: Int, fraction: CGFloat, availableWidth: CGFloat) {
        widths = proposedWidths(slot: slot, fraction: fraction, availableWidth: availableWidth)
    }

    func stepWidth(slot: Int, forward: Bool, presets: [CGFloat], availableWidth: CGFloat) {
        guard widths.indices.contains(slot - 1), !presets.isEmpty else { return }
        let sorted = presets.sorted()
        let current = widths[slot - 1]
        let preset = forward
            ? sorted.first(where: { $0 > current + 0.000001 }) ?? sorted[0]
            : sorted.last(where: { $0 < current - 0.000001 }) ?? sorted.last.orDie()
        setWidth(slot: slot, fraction: preset, availableWidth: availableWidth)
    }

}

extension Workspace {
    @MainActor
    func enforceColumnInvariant() {
        guard let columns else { return }
        defer {
            if focus.workspace === self, let slot = columnSlot(containing: focus.windowOrNil),
               columns.lastFocusedWindowSlot != slot {
                columns.focusedSlot = slot
                columns.lastFocusedWindowSlot = slot
            }
        }
        let root = rootTilingContainer
        if columns.slotCount > columns.count,
           !root.children.contains(where: { $0.columnSlot == columns.slotCount && !$0.allLeafWindowsRecursive.isEmpty }) {
            columns.widths = columns.declaredWidths
            columns.focusedSlot = columns.focusedSlot.map { min($0, columns.count) }
        }
        let slots = root.children.compactMap(\.columnSlot)
        let recoversRoot = columns.root.map { $0 !== root && $0.nodeWorkspace === self } ?? false
        if !recoversRoot, slots.count == root.children.count,
           Set(slots).count == slots.count, slots.allSatisfy({ (1...columns.slotCount).contains($0) }) {
            root.changeOrientation(.h)
            root.layout = .tiles
            columns.root = root
            applyColumnWidthsAndOrder()
            return
        }
        func snapshot(_ node: TreeNode) -> [(TreeNode, [TreeNode])] {
            let order = node.childrenByMostRecentUse.flatMap { child in
                recoversRoot && node === root && child === columns.root ? child.childrenByMostRecentUse : [child]
            }
            return [(node, order)] + node.children.flatMap(snapshot)
        }
        let mru = snapshot(self)
        defer { for (node, order) in mru { node.restoreChildMru(order) } }
        if let oldRoot = columns.root, oldRoot !== root, oldRoot.nodeWorkspace === self {
            for child in oldRoot.children {
                let binding = child.unbindFromParent()
                child.bind(to: BindingData(parent: root, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST, columnSlot: binding.columnSlot))
            }
            oldRoot.unbindFromParent()
        }
        root.changeOrientation(.h)
        root.layout = .tiles
        columns.root = root
        var occupied: Set<Int> = []
        var extras: [TreeNode] = []
        for child in root.children {
            if let slot = child.columnSlot, (1...columns.slotCount).contains(slot), occupied.insert(slot).inserted {
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
        applyColumnWidthsAndOrder()
    }

    @MainActor
    private func applyColumnWidthsAndOrder() {
        guard let columns else { return }
        let root = rootTilingContainer
        for child in root.children {
            if let slot = child.columnSlot {
                child.setWeight(.h, root.hWeight * columns.widths[slot - 1])
            }
        }
        root.sortChildrenByColumnSlot()
    }

    @MainActor
    func moveAcrossColumnBoundary(_ node: TreeNode, window: Window, direction: CardinalDirection) -> Bool {
        guard let columns, let slot = columnSlot(containing: node) else { return false }
        guard direction.orientation == .h else { return true }
        let destination = slot + direction.focusOffset
        guard (1...columns.slotCount).contains(destination) else { return true }
        // A window in a tab group leaves the group alone; `node` is then the group, not the window.
        let moving = (node as? TilingContainer)?.layout == .tabGroup ? window : node
        moving.unbindFromParent()
        bindToColumn(moving, slot: destination)
        return true
    }

    @MainActor
    func columnSlot(containing node: TreeNode?) -> Int? {
        guard let node, node.nodeWorkspace === self else { return nil }
        return node.parentsWithSelf.first { $0.parent === rootTilingContainer }?.columnSlot
    }

    @MainActor
    func columnPlacementSlot(excluding window: Window? = nil) -> Int {
        guard let columns else { return 1 }
        let root = rootTilingContainer
        let anchor = max(1, min(columns.slotCount, columns.focusedSlot ?? columnSlot(containing: focus.windowOrNil) ??
            root.childrenByMostRecentUse.first?.columnSlot ?? 1))
        let occupied = Set(root.children.filter { $0.allLeafWindowsRecursive.contains { $0 !== window } }.compactMap(\.columnSlot))
        return (1...columns.slotCount).filter { !occupied.contains($0) }.min {
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
            let orientation = (existing as? TilingContainer)?.orientation.opposite ?? .v
            let group = TilingContainer(parent: root, adaptiveWeight: weight, orientation, .tabGroup, index: index)
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
    func bindToColumn(_ node: TreeNode, slot: Int, overflow: OverflowPolicy = .tabGroup) {
        let columns = columns.orDie()
        let placement = ColumnPlacement.resolve(slot: slot, overflow: overflow, columns: columns,
                                                children: rootTilingContainer.children, incoming: node)
        columns.widths = placement.widths
        let slot = placement.slot
        switch placement.effect {
            case .float:
                node.bind(to: self, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
                return
            case .split(let existing):
                let binding = existing.unbindFromParent()
                let wrapper = TilingContainer(parent: binding.parent, adaptiveWeight: binding.adaptiveWeight, .v, .tiles, index: binding.index)
                wrapper.columnSlot = slot
                existing.columnSlot = nil
                existing.bind(to: wrapper, adaptiveWeight: WEIGHT_AUTO, index: 0)
                node.columnSlot = nil
                node.bind(to: wrapper, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
                return
            case .attach: break
        }
        if let group = node as? TilingContainer,
           rootTilingContainer.children.contains(where: { $0.columnSlot == slot }) {
            let windows = group.allLeafWindowsRecursive
            for window in windows {
                window.unbindFromParent()
                bindToColumn(window, slot: slot)
            }
            if group.isBound { group.unbindFromParent() }
            return
        }
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
        child.bind(to: BindingData(parent: parent, adaptiveWeight: weight, index: index, columnSlot: slot))
    }
}
