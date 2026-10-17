import Foundation

struct GridLayoutCache {
    let ids: [UInt32]
    let entries: [GridLayout.Entry]
    let visibleSize: CGSize
    let tileSize: String
    let grouping: String
    let arrangement: String
    let sectionKeys: [String]
    let layout: GridLayout
}

extension LensSession {
    /// Packing steps the row height down until everything fits, so it is redone only when its inputs change.
    var gridLayout: GridLayout { gridLayout(items: results) }

    func gridLayout(items results: [SwitcherPaletteItem]) -> GridLayout {
        let ids = results.map(\.id), kind = tileKind, scale = TileMetrics(visibleSize: miniatureSize).scale
        func entry(_ item: SwitcherPaletteItem) -> GridLayout.Entry {
            GridLayout.Entry(aspect: item.tile.aspect, realSize: item.tile.realSize, kind: kind,
                             barWidth: kind == .card ? item.tile.cardBarWidth(badges: settings.badges, scale: scale) : 0)
        }
        let entries = results.map(entry)
        if let cache = gridLayoutCache, cache.ids == ids, cache.entries == entries,
           cache.visibleSize == miniatureSize, cache.tileSize == settings.grid.tileSize, cache.grouping == settings.sections,
           cache.arrangement == settings.grid.sectionsArrangement, cache.sectionKeys == results.map { $0.sectionKey(settings.sections) } {
            return cache.layout
        }
        let layout = GridLayout(sections: sections(for: results).map { section in
            GridLayout.Section(label: section.label, current: section.current, entries: section.entries.map(entry))
        }, visibleSize: miniatureSize, tileSize: settings.grid.tileSize, arrangement: settings.grid.sectionsArrangement, minimumWidth: sectionControlMinimumWidth)
        gridLayoutCache = GridLayoutCache(ids: ids, entries: entries, visibleSize: miniatureSize, tileSize: settings.grid.tileSize, grouping: settings.sections, arrangement: settings.grid.sectionsArrangement, sectionKeys: results.map { $0.sectionKey(settings.sections) }, layout: layout)
        return layout
    }
    func moveGridSelection(_ direction: GridLayout.Direction) {
        if let index = gridLayout.nearest(from: selection, direction: direction) { send(.selectionChanged(index)) }
    }
    func refreshGridThumbnails(lens: Int, request: (Window, Int, CGSize) -> Void) {
        let items = results
        let layout = settings.presentation == "strip" ? stripSnapshot(items: items).layout : gridLayout(items: items)
        for (item, tile) in zip(items, layout.tiles) {
            if let entry = item.miniature, !entry.frozen, tile.pictureSize != .zero {
                request(entry.window, lens, thumbnailDemand(tile.pictureSize, lifted: true))
            }
        }
    }
}
