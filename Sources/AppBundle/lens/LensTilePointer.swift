import AppKit

func pointerMovedBeyondThreshold(from anchor: CGPoint, to point: CGPoint) -> Bool {
    hypot(point.x - anchor.x, point.y - anchor.y) > 1
}

/// The SwiftUI coordinate space at the root of a Lens panel, which is the panel's window.
let lensWindowCoordinateSpace = "lensWindow"

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

struct LensTileHit {
    let index: Int
    let windowId: UInt32
    let control: TileWindowControl?
}

extension LensSession {
    func tileHitTest(at point: CGPoint) -> LensTileHit? {
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
                return tileHit(index: selection, point: point, layout: layout, item: items[selection])
            }
        }
        return layout.tiles.indices.reversed().first { layout.tiles[$0].frame.contains(point) }
            .map { tileHit(index: $0, point: point, layout: layout, item: items[$0]) }
    }

    private func tileHit(index: Int, point: CGPoint, layout: GridLayout, item: SwitcherPaletteItem) -> LensTileHit {
        let control = hoveredTileId == item.id ? controlRects(index: index, layout: layout, entry: item.tile)
            .first { $0.1.contains(point) }?.0 : nil
        return LensTileHit(index: index, windowId: item.id, control: control)
    }

    func controlRects(index: Int, layout: GridLayout) -> [(TileWindowControl, CGRect)] {
        let items = results
        guard items.indices.contains(index) else { return [] }
        return controlRects(index: index, layout: layout, entry: items[index].tile)
    }

    private func controlRects(index: Int, layout: GridLayout, entry: TileEntry) -> [(TileWindowControl, CGRect)] {
        guard tileKind != .text, layout.tiles.indices.contains(index) else { return [] }
        let tile = layout.tiles[index]
        let metrics = TileMetrics(scale: layout.tileScale)
        let picture = tilePictureRect(entry: entry, kind: tileKind, size: tile.frame.size, pictureSize: tile.pictureSize,
                                      metrics: metrics, presentation: settings.presentation, selected: index == selection)
            .offsetBy(dx: tile.frame.minX, dy: tile.frame.minY)
        return tileControlRects(in: picture, scale: metrics.scale).filter { entry.controls.allows($0.0) }.map { control, rect in
            (control, scaledTileRect(rect, about: tile.frame, by: index == selection ? metrics.selectionScale : 1))
        }
    }

    func hoverTile(at point: CGPoint?, pointerLocation: CGPoint) {
        let armed = pointerMoved(to: pointerLocation)
        let hit = point.flatMap { tileHitTest(at: $0) }
        // Assigning a published value redraws the panel even when it is unchanged.
        let hovered = armed ? hit?.windowId : hit == nil ? nil : hoveredTileId
        if hovered != hoveredTileId { hoveredTileId = hovered }
        hoverIndex(armed: armed) { hit?.index }
    }

    func clickTile(at point: CGPoint, event: NSEvent?) {
        guard let hit = tileHitTest(at: point) else { return }
        if let control = hit.control {
            let id = hit.windowId
            hoveredTileId = nil
            reanchorPointer()
            onControl?(control, id)
            return
        }
        send(.selectionChanged(hit.index))
        if let event, let key = key(for: event, click: true) { onAction?(key) }
    }

    func scrollTiles(delta: CGFloat, sideways: CGFloat = 0, phase: NSEvent.Phase, momentum: NSEvent.Phase, time: TimeInterval,
                     precise: Bool, paging: inout LensScrollStepper) {
        guard let step = paging.turn(delta: delta, sideways: sideways, phase: phase, momentum: momentum, time: time, precise: precise) else { return }
        if settings.presentation == "strip" { cycleStripSelection(step) }
        else if settings.presentation == "grid" { moveSelection(step) }
    }
}
