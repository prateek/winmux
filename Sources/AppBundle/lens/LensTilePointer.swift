import AppKit

func pointerMovedBeyondThreshold(from anchor: CGPoint, to point: CGPoint) -> Bool {
    hypot(point.x - anchor.x, point.y - anchor.y) > 1
}

func lensTilePoint(_ contentPoint: CGPoint, in frame: CGRect) -> CGPoint? {
    guard frame.contains(contentPoint) else { return nil }
    return CGPoint(x: contentPoint.x - frame.minX, y: contentPoint.y - frame.minY)
}

struct LensPointerMotion {
    let anchor: CGPoint
    private var latest: CGPoint
    private var armed = false

    init(anchor: CGPoint) { self.anchor = anchor; latest = anchor }

    mutating func moved(to point: CGPoint) -> Bool {
        guard point != latest else { return false }
        latest = point
        if !armed { armed = pointerMovedBeyondThreshold(from: anchor, to: point) }
        return armed
    }
}

extension LensSession {
    func tileHitTest(at point: CGPoint) -> Int? {
        let items = results
        let layout: GridLayout
        switch settings.presentation {
            case "strip": layout = stripSnapshot(items: items).layout
            case "grid": layout = gridLayout(items: items)
            default: return nil
        }
        let scale = tileMetrics.scale
        let sizing = settings.presentation == "strip" ? GridLayout.Sizing.strip : .grid
        let footer = sizing.pointerBottomInset * scale
        guard CGRect(origin: .zero, size: layout.panelSize).contains(point),
              point.y < layout.panelSize.height - footer,
              point.y >= sizing.pointerTopInset * scale,
              !layout.headers.contains(where: { $0.frame.contains(point) }) else { return nil }
        if layout.tiles.indices.contains(selection), items.indices.contains(selection) {
            let frame = layout.tiles[selection].frame
            let scale = tileKind == .text ? 1 : TileMetrics(scale: layout.tileScale).selectionScale
            if frame.insetBy(dx: -frame.width * (scale - 1) / 2, dy: -frame.height * (scale - 1) / 2).contains(point) {
                return selection
            }
        }
        return layout.tiles.indices.reversed().first { layout.tiles[$0].frame.contains(point) }
    }

    func hoverTile(at point: CGPoint, pointerLocation: CGPoint) {
        hoverTileIndex(tileHitTest(at: point), at: pointerLocation)
    }

    func clickTile(at point: CGPoint, event: NSEvent?) {
        guard let index = tileHitTest(at: point) else { return }
        send(.selectionChanged(index))
        if let event, let key = key(for: event, click: true) { onAction?(key) }
    }

    func scrollTiles(delta: CGFloat, sideways: CGFloat = 0, phase: NSEvent.Phase, momentum: NSEvent.Phase, time: TimeInterval,
                     precise: Bool, paging: inout LensScrollStepper) {
        guard let step = paging.turn(delta: delta, sideways: sideways, phase: phase, momentum: momentum, time: time, precise: precise) else { return }
        if settings.presentation == "strip" { cycleStripSelection(step) }
        else if settings.presentation == "grid" { moveSelection(step) }
    }
}
