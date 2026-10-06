import Foundation

struct StripLayoutCache {
    let ids: [UInt32]
    let entries: [GridLayout.Entry]
    let visibleSize: CGSize
    let tileSize: String
    let snapshot: StripSnapshot
}

extension LensSession {
    var stripSnapshot: StripSnapshot {
        let items = results
        let entries = items.map {
            GridLayout.Entry(aspect: $0.tile.aspect, realSize: $0.tile.realSize, kind: tileKind,
                             accessory: $0.tile.accessory, monitorHeightFraction: $0.tile.monitorHeightFraction,
                             accessoryActualSize: settings.accessoryWindow == "actual-size")
        }
        let ids = items.map(\.id)
        if let cache = stripLayoutCache, cache.ids == ids, cache.entries == entries,
           cache.visibleSize == miniatureSize, cache.tileSize == settings.grid.tileSize {
            return cache.snapshot
        }
        let snapshot = StripSnapshot(items: items, size: miniatureSize, kind: tileKind, settings: settings)
        stripLayoutCache = StripLayoutCache(ids: ids, entries: entries, visibleSize: miniatureSize, tileSize: settings.grid.tileSize, snapshot: snapshot)
        return snapshot
    }

    func moveStripSelection(_ code: UInt16) {
        let layout = stripSnapshot.layout
        if code == 125 || code == 126, Set(layout.tiles.map { $0.frame.minY }).count > 1 {
            if let index = layout.nearest(from: selection, direction: code == 125 ? .down : .up) { send(.selectionChanged(index)) }
        } else { cycleStripSelection(code == 123 || code == 126 ? -1 : 1) }
    }
}

struct StripSnapshot {
    let items: [SwitcherPaletteItem]
    let layout: GridLayout
    let minimumWidth: CGFloat

    init(items: [SwitcherPaletteItem], size: CGSize, kind: TileKind, settings: LensConfig) {
        self.items = items
        let metrics = TileMetrics(visibleSize: size)
        minimumWidth = min(size.width * 0.9, metrics.textWidth + 88 * metrics.scale)
        layout = GridLayout(sections: [.init(label: nil, current: false, entries: items.map {
            .init(aspect: $0.tile.aspect, realSize: $0.tile.realSize, kind: kind, accessory: $0.tile.accessory,
                  monitorHeightFraction: $0.tile.monitorHeightFraction, accessoryActualSize: settings.accessoryWindow == "actual-size")
        })], visibleSize: size, tileSize: settings.grid.tileSize, minimumWidth: minimumWidth, sizing: .strip)
    }
}
