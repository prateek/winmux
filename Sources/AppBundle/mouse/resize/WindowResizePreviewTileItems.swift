import AppKit
import Common

@MainActor
func windowResizePreviewTileItems(
    container: TilingContainer,
    point: CGPoint,
    width: CGFloat,
    height: CGFloat,
    virtual: Rect,
    context: WindowResizePreviewLayoutContext,
    activeWindowId: UInt32?,
) -> [WindowResizePreviewItem] {
    guard !container.children.isEmpty else { return [] }

    if container.isRootContainer, let columns = context.workspace.columns {
        let widths = context.weightMap.columnWidths ?? columns.widths
        let gap = CGFloat(context.resolvedGaps.inner.horizontal)
        return container.children.flatMap { child -> [WindowResizePreviewItem] in
            guard let slot = child.columnSlot, widths.indices.contains(slot - 1) else { return [] }
            let offset = widths.prefix(slot - 1).reduce(0, +) * width
            let columnWidth = widths[slot - 1] * width
            let left = slot == 1 ? 0 : gap / 2
            let right = slot == columns.count ? 0 : gap / 2
            return windowResizePreviewItems(node: child, point: point.addingXOffset(offset + left),
                width: max(0, columnWidth - left - right), height: height,
                virtual: Rect(topLeftX: virtual.minX + offset, topLeftY: virtual.minY, width: columnWidth, height: virtual.height),
                context: context, activeWindowId: activeWindowId)
        }
    }
    var items: [WindowResizePreviewItem] = []
    var point = point
    var virtualPoint = virtual.topLeftCorner
    let orientation = container.orientation
    let availableDimension = orientation == .h ? width : height
    let totalWeight = container.children.reduce(CGFloat(0)) { partial, child in
        partial + context.weight(for: child, orientation: orientation)
    }
    guard let delta = (availableDimension - totalWeight).div(container.children.count) else { return [] }

    let rawGap = CGFloat(context.resolvedGaps.inner.get(orientation))
    let lastIndex = container.children.indices.last
    for (index, child) in container.children.enumerated() {
        let adjustedWeight = context.weight(for: child, orientation: orientation) + delta
        let gap = rawGap - (index == 0 ? rawGap / 2 : 0) - (index == lastIndex ? rawGap / 2 : 0)
        let childPoint = index == 0 ? point : point.addingOffset(orientation, rawGap / 2)
        let childWidth = orientation == .h ? max(adjustedWeight - gap, 0) : max(width, 0)
        let childHeight = orientation == .v ? max(adjustedWeight - gap, 0) : max(height, 0)
        let childVirtual = Rect(
            topLeftX: virtualPoint.x,
            topLeftY: virtualPoint.y,
            width: orientation == .h ? max(adjustedWeight, 0) : max(width, 0),
            height: orientation == .v ? max(adjustedWeight, 0) : max(height, 0),
        )
        items += windowResizePreviewItems(
            node: child,
            point: childPoint,
            width: childWidth,
            height: childHeight,
            virtual: childVirtual,
            context: context,
            activeWindowId: activeWindowId,
        )
        virtualPoint = orientation == .h
            ? virtualPoint.addingXOffset(adjustedWeight)
            : virtualPoint.addingYOffset(adjustedWeight)
        point = orientation == .h
            ? point.addingXOffset(adjustedWeight)
            : point.addingYOffset(adjustedWeight)
    }
    return items
}
