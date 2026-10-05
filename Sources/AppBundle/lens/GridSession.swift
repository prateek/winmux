import Foundation

extension LensSession {
    var gridLayout: GridLayout {
        GridLayout(entries: results.map { GridLayout.Entry(aspect: $0.tile.aspect, realSize: $0.tile.realSize, kind: tileKind) },
                   visibleSize: miniatureSize, tileSize: settings.grid.tileSize)
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
