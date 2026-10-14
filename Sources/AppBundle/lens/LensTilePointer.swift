import AppKit

struct LensPointerMotion {
    let anchor: CGPoint
    private var latest: CGPoint
    private var armed = false

    init(anchor: CGPoint) { self.anchor = anchor; latest = anchor }

    mutating func moved(to point: CGPoint) -> Bool {
        guard point != latest else { return false }
        latest = point
        if !armed { armed = hypot(point.x - anchor.x, point.y - anchor.y) > 1 }
        return armed
    }
}

extension LensSession {
    func tileHitTest(at point: CGPoint) -> UInt32? {
        let layout: GridLayout
        switch settings.presentation {
            case "strip": layout = stripSnapshot.layout
            case "grid": layout = gridLayout
            default: return nil
        }
        let scale = tileMetrics.scale
        let footer = settings.presentation == "strip" ? (22 + GridLayout.Sizing.stripFooterHeight) * scale : 48 * scale
        guard CGRect(origin: .zero, size: layout.panelSize).contains(point),
              point.y < layout.panelSize.height - footer,
              settings.presentation != "grid" || point.y >= 36 * scale,
              !layout.headers.contains(where: { $0.frame.contains(point) }) else { return nil }
        let items = results
        if layout.tiles.indices.contains(selection), items.indices.contains(selection) {
            let frame = layout.tiles[selection].frame
            let scale = tileKind == .text ? 1 : TileMetrics(scale: layout.tileScale).selectionScale
            if frame.insetBy(dx: -frame.width * (scale - 1) / 2, dy: -frame.height * (scale - 1) / 2).contains(point) {
                return items[selection].id
            }
        }
        return layout.tiles.indices.reversed().first { layout.tiles[$0].frame.contains(point) }.map { items[$0].id }
    }

    func hoverTile(at point: CGPoint, pointerLocation: CGPoint) {
        hover(tileHitTest(at: point), at: pointerLocation)
    }

    func clickTile(at point: CGPoint, event: NSEvent?) {
        guard let id = tileHitTest(at: point) else { return }
        hover(id)
        if let event, let key = key(for: event, click: true) { onAction?(key) }
    }

    func scrollTiles(delta: CGFloat, sideways: CGFloat = 0, phase: NSEvent.Phase, momentum: NSEvent.Phase, time: TimeInterval,
                     precise: Bool, paging: inout MiniatureScrollPaging) {
        guard let step = paging.turn(delta: delta, sideways: sideways, phase: phase, momentum: momentum, time: time, precise: precise) else { return }
        if settings.presentation == "strip" { cycleStripSelection(step) }
        else if settings.presentation == "grid" { moveSelection(step) }
    }
}
