import Foundation

struct GridLayoutCache {
    let ids: [UInt32]
    let realSizes: [CGSize]
    let kind: TileKind
    let visibleSize: CGSize
    let tileSize: String
    let layout: GridLayout
}

extension LensSession {
    /// Packing steps the row height down until everything fits, so it is redone only when its inputs change.
    var gridLayout: GridLayout {
        let results = results
        let ids = results.map(\.id), realSizes = results.map(\.tile.realSize), kind = tileKind
        if let cache = gridLayoutCache, cache.ids == ids, cache.realSizes == realSizes, cache.kind == kind,
           cache.visibleSize == miniatureSize, cache.tileSize == settings.grid.tileSize {
            return cache.layout
        }
        let layout = GridLayout(entries: results.map { GridLayout.Entry(aspect: $0.tile.aspect, realSize: $0.tile.realSize, kind: kind) },
                                visibleSize: miniatureSize, tileSize: settings.grid.tileSize)
        gridLayoutCache = GridLayoutCache(ids: ids, realSizes: realSizes, kind: kind, visibleSize: miniatureSize, tileSize: settings.grid.tileSize, layout: layout)
        return layout
    }
    func moveGridSelection(_ direction: GridLayout.Direction) {
        if let index = gridLayout.nearest(from: selection, direction: direction) { send(.selectionChanged(index)) }
    }
    func refreshGridThumbnails(lens: Int, request: (Window, Int) -> Void) {
        for item in results {
            if let entry = item.miniature, !entry.frozen { request(entry.window, lens) }
        }
    }
}
