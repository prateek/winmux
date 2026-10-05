import Foundation

struct GridLayout {
    enum Direction { case left, right, up, down }
    struct Entry {
        let aspect: CGFloat
        let realSize: CGSize
        let kind: TileKind
    }
    struct Tile {
        let frame: CGRect
        let pictureSize: CGSize
    }
    let rowHeight: CGFloat
    let panelSize: CGSize
    let tiles: [Tile]
    let tileScale: CGFloat
    let relaxedTitleFloor: Bool

    init(entries: [Entry], visibleSize: CGSize, tileSize: String) {
        let scale = TileMetrics(visibleSize: visibleSize).scale
        let maxWidth = max(1, visibleSize.width * 0.9 - 56 * scale)
        let maxHeight = max(1, visibleSize.height * 0.88 - 90 * scale)
        guard !entries.isEmpty else {
            rowHeight = 330 * scale
            panelSize = CGSize(width: min(386 * scale, visibleSize.width * 0.9), height: 136 * scale)
            tiles = []; tileScale = scale; relaxedTitleFloor = false
            return
        }
        struct Plan {
            var tiles: [Tile] = []
            var size = CGSize.zero
        }
        func plan(height: CGFloat, chrome: CGFloat, titleFloor: Bool) -> Plan {
            let metrics = TileMetrics(visibleSize: CGSize(width: 1920 * chrome, height: 1080 * chrome))
            let gap = 14 * chrome
            var rows: [[Tile]] = [[]]
            var rowWidths: [CGFloat] = [0]
            for entry in entries {
                let box: CGSize
                if tileSize == "real" {
                    let factor = min(1, height / max(1, visibleSize.height))
                    box = CGSize(width: max(70 * chrome, entry.realSize.width * factor), height: max(height, entry.realSize.height * factor))
                } else {
                    box = CGSize(width: height * (tileSize == "equal" ? 1.5 : min(2.1, max(0.6, entry.aspect))), height: height)
                }
                let picture: CGSize
                if tileSize == "real" {
                    let factor = min(1, height / max(1, visibleSize.height))
                    picture = CGSize(width: entry.realSize.width * factor, height: entry.realSize.height * factor)
                } else {
                    let fitted = metrics.fittedPicture(aspect: entry.aspect, in: box)
                    let factor = min(1, entry.realSize.width / max(1, fitted.width), entry.realSize.height / max(1, fitted.height))
                    picture = CGSize(width: fitted.width * factor, height: fitted.height * factor)
                }
                let floor = entry.kind == .card && titleFloor ? min(200 * chrome, max(1.2 * height, 110 * chrome)) : 0
                let width = entry.kind == .text ? metrics.textWidth : max(box.width, floor) + 2 * metrics.padding
                let tileHeight = metrics.height(kind: entry.kind, rowHeight: box.height)
                let last = rows.count - 1
                if !rows[last].isEmpty, rowWidths[last] + gap + width > maxWidth {
                    rows.append([]); rowWidths.append(0)
                }
                let row = rows.count - 1
                let x = rowWidths[row] + (rows[row].isEmpty ? 0 : gap)
                rows[row].append(Tile(frame: CGRect(x: x, y: 0, width: width, height: tileHeight), pictureSize: entry.kind == .text ? .zero : picture))
                rowWidths[row] = x + width
            }
            var result = Plan()
            result.size.width = rowWidths.max() ?? 0
            for (index, row) in rows.enumerated() {
                let y = result.size.height
                let dx = (result.size.width - rowWidths[index]) / 2
                result.tiles += row.map { Tile(frame: $0.frame.offsetBy(dx: dx, dy: y), pictureSize: $0.pictureSize) }
                result.size.height += (row.map { $0.frame.height }.max() ?? 0) + gap
            }
            result.size.height -= gap
            return result
        }
        var height = 330 * scale
        var chrome = scale
        var relaxed = false
        var best = plan(height: height, chrome: chrome, titleFloor: true)
        while best.size.width > maxWidth || best.size.height > maxHeight {
            if height > 36 * scale {
                height = max(36 * scale, height - 6 * scale)
            } else {
                height *= 0.94
                chrome = scale * height / (36 * scale)
                relaxed = true
            }
            best = plan(height: height, chrome: chrome, titleFloor: !relaxed)
        }
        rowHeight = height
        tileScale = chrome
        relaxedTitleFloor = relaxed
        panelSize = CGSize(width: max(best.size.width + 56 * scale, min(386 * scale, visibleSize.width * 0.9)), height: best.size.height + 90 * scale)
        let insetX = (panelSize.width - best.size.width) / 2
        tiles = best.tiles.map { Tile(frame: $0.frame.offsetBy(dx: insetX, dy: 40 * scale), pictureSize: $0.pictureSize) }
    }

    func nearest(from index: Int, direction: Direction) -> Int? {
        guard tiles.indices.contains(index) else { return nil }
        let source = tiles[index].frame
        return tiles.indices.filter { candidate in
            guard candidate != index else { return false }
            let rect = tiles[candidate].frame
            switch direction {
                case .left: return rect.midX < source.midX
                case .right: return rect.midX > source.midX
                case .up: return rect.midY < source.midY
                case .down: return rect.midY > source.midY
            }
        }.min { lhs, rhs in
            func distance(_ index: Int) -> CGFloat {
                let frame = tiles[index].frame
                return hypot(frame.midX - source.midX, frame.midY - source.midY)
            }
            let a = distance(lhs), b = distance(rhs)
            return a == b ? lhs < rhs : a < b
        }
    }
}
