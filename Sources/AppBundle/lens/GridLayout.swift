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
    struct Section {
        let label: String?
        let current: Bool
        let entries: [Entry]
    }
    struct Header {
        let frame: CGRect
        let label: String
        let current: Bool
    }
    let headers: [Header]
    let arrangement: String
    let rowHeight: CGFloat
    let panelSize: CGSize
    let tiles: [Tile]
    let tileScale: CGFloat
    let relaxedTitleFloor: Bool

    init(entries: [Entry], visibleSize: CGSize, tileSize: String) {
        self.init(sections: [Section(label: nil, current: false, entries: entries)], visibleSize: visibleSize, tileSize: tileSize)
    }

    init(sections: [Section], visibleSize: CGSize, tileSize: String, arrangement: String = "flow", minimumWidth: CGFloat = 0) {
        let sections = sections.filter { !$0.entries.isEmpty }
        let entries = sections.flatMap(\.entries)
        let labelled = sections.contains { $0.label != nil }
        self.arrangement = labelled ? arrangement : "flow"
        let scale = TileMetrics(visibleSize: visibleSize).scale
        let maxWidth = max(1, visibleSize.width * 0.9 - 56 * scale)
        let maxHeight = max(1, visibleSize.height * 0.88 - 90 * scale)
        guard !entries.isEmpty else {
            rowHeight = 330 * scale
            panelSize = CGSize(width: min(max(386 * scale, minimumWidth), visibleSize.width * 0.9), height: 136 * scale)
            headers = []
            tiles = []; tileScale = scale; relaxedTitleFloor = false
            return
        }
        struct Plan {
            var tiles: [Tile] = []
            var headers: [Header] = []
            var size = CGSize.zero
        }
        func plan(height: CGFloat, chrome: CGFloat, titleFloor: Bool) -> Plan {
            let metrics = TileMetrics(scale: chrome)
            let gap = 14 * chrome
            var sizes: [Tile] = []
            var rows: [[Tile]] = [[]]
            var rowWidths: [CGFloat] = [0]
            for entry in entries {
                let box: CGSize
                let picture: CGSize
                if tileSize == "real" {
                    let factor = min(1, height / max(1, visibleSize.height))
                    picture = CGSize(width: entry.realSize.width * factor, height: entry.realSize.height * factor)
                    box = CGSize(width: max(70 * chrome, picture.width), height: max(height, picture.height))
                } else {
                    box = CGSize(width: height * (tileSize == "equal" ? 1.5 : min(2.1, max(0.6, entry.aspect))), height: height)
                    let fitted = metrics.fittedPicture(aspect: entry.aspect, in: box)
                    let factor = min(1, entry.realSize.width / max(1, fitted.width), entry.realSize.height / max(1, fitted.height))
                    picture = CGSize(width: fitted.width * factor, height: fitted.height * factor)
                }
                let floor = entry.kind == .card && titleFloor ? min(200 * chrome, max(1.2 * height, 110 * chrome)) : 0
                let width = entry.kind == .text ? metrics.textWidth : max(box.width, floor) + 2 * metrics.padding
                let tileHeight = metrics.height(kind: entry.kind, rowHeight: box.height)
                sizes.append(Tile(frame: CGRect(x: 0, y: 0, width: width, height: tileHeight), pictureSize: entry.kind == .text ? .zero : picture))
                let last = rows.count - 1
                if !rows[last].isEmpty, rowWidths[last] + gap + width > maxWidth {
                    rows.append([]); rowWidths.append(0)
                }
                let row = rows.count - 1
                let x = rowWidths[row] + (rows[row].isEmpty ? 0 : gap)
                rows[row].append(Tile(frame: CGRect(x: x, y: 0, width: width, height: tileHeight), pictureSize: entry.kind == .text ? .zero : picture))
                rowWidths[row] = x + width
            }
            if labelled {
                // Labelled columns share row tops, including windows taller than this monitor.
                let slotHeight = sizes.map(\.frame.height).max() ?? 0
                sizes = sizes.map { Tile(frame: CGRect(x: 0, y: 0, width: $0.frame.width, height: slotHeight), pictureSize: $0.pictureSize) }
                let hd = 34 * chrome
                var result = Plan()
                let counts = sections.map { $0.entries.count }
                func appendTile(_ tile: Tile, x: CGFloat, y: CGFloat) {
                    result.tiles.append(Tile(frame: tile.frame.offsetBy(dx: x, dy: y), pictureSize: tile.pictureSize))
                }
                if arrangement == "columns" && sections.count > 1 {
                    let columnWidth = max(1, (maxWidth - 30 * chrome * CGFloat(sections.count - 1)) / CGFloat(sections.count))
                    var offset = 0, x0: CGFloat = 0
                    for (section, count) in zip(sections, counts) {
                        var x: CGFloat = 0, y = hd, rowHeight: CGFloat = 0, width: CGFloat = 0
                        for tile in sizes[offset..<offset + count] {
                            if x > 0 && x + tile.frame.width > columnWidth { y += rowHeight + gap; x = 0; rowHeight = 0 }
                            appendTile(tile, x: x0 + x, y: y)
                            width = max(width, x + tile.frame.width)
                            rowHeight = max(rowHeight, tile.frame.height)
                            x += tile.frame.width + gap
                        }
                        width = max(width, 170 * chrome)
                        result.headers.append(Header(frame: CGRect(x: x0 + metrics.padding, y: 4 * chrome, width: max(0, width - 2 * metrics.padding), height: 22 * chrome), label: section.label ?? "", current: section.current))
                        result.size.height = max(result.size.height, y + rowHeight)
                        x0 += width + 30 * chrome
                        offset += count
                    }
                    result.size.width = x0 - 30 * chrome
                } else if arrangement == "flow" {
                    struct Row { var tiles: [Tile] = []; var heads: [Header] = []; var width: CGFloat = 0; var height: CGFloat = 0 }
                    var packed = [Row()]
                    var offset = 0
                    for (section, count) in zip(sections, counts) {
                        for index in 0..<count {
                            let tile = sizes[offset + index]
                            var row = packed.count - 1
                            let extra = index == 0 && packed[row].width > 0 ? 30 * chrome : 0
                            var x = packed[row].width + (packed[row].tiles.isEmpty ? 0 : gap) + extra
                            if !packed[row].tiles.isEmpty && x + tile.frame.width > maxWidth {
                                packed.append(Row()); row += 1; x = 0
                            }
                            if index == 0 {
                                packed[row].heads.append(Header(frame: CGRect(x: x + metrics.padding, y: 4 * chrome, width: 0, height: 22 * chrome), label: section.label ?? "", current: section.current))
                            }
                            packed[row].tiles.append(Tile(frame: tile.frame.offsetBy(dx: x, dy: hd), pictureSize: tile.pictureSize))
                            packed[row].width = x + tile.frame.width
                            packed[row].height = max(packed[row].height, tile.frame.height)
                        }
                        offset += count
                    }
                    result.size.width = packed.map(\.width).max() ?? 0
                    var y: CGFloat = 0
                    for row in packed {
                        let dx = (result.size.width - row.width) / 2
                        result.tiles += row.tiles.map { Tile(frame: $0.frame.offsetBy(dx: dx, dy: y), pictureSize: $0.pictureSize) }
                        for (index, head) in row.heads.enumerated() {
                            let end = index + 1 < row.heads.count ? row.heads[index + 1].frame.minX - gap : row.width
                            let frame = CGRect(x: head.frame.minX + dx, y: head.frame.minY + y, width: max(0, end - head.frame.minX), height: head.frame.height)
                            result.headers.append(Header(frame: frame, label: head.label, current: head.current))
                        }
                        y += hd + row.height + gap
                    }
                    result.size.height = y - gap
                } else {
                    var offset = 0, y: CGFloat = 0
                    for (section, count) in zip(sections, counts) {
                        result.headers.append(Header(frame: CGRect(x: metrics.padding, y: y + 4 * chrome, width: 0, height: 22 * chrome), label: section.label ?? "", current: section.current))
                        y += hd
                        var x: CGFloat = 0, rowHeight: CGFloat = 0
                        for tile in sizes[offset..<offset + count] {
                            if x > 0 && x + tile.frame.width > maxWidth { y += rowHeight + gap; x = 0; rowHeight = 0 }
                            appendTile(tile, x: x, y: y)
                            result.size.width = max(result.size.width, x + tile.frame.width)
                            rowHeight = max(rowHeight, tile.frame.height)
                            x += tile.frame.width + gap
                        }
                        y += rowHeight + gap + 6 * chrome
                        offset += count
                    }
                    result.size.height = y - gap - 6 * chrome
                    result.headers = result.headers.map { Header(frame: CGRect(x: $0.frame.minX, y: $0.frame.minY, width: max(0, result.size.width - 2 * metrics.padding), height: $0.frame.height), label: $0.label, current: $0.current) }
                }
                return result
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
        panelSize = CGSize(width: max(best.size.width + 56 * scale, min(max(386 * scale, minimumWidth), visibleSize.width * 0.9)), height: best.size.height + 90 * scale)
        let insetX = (panelSize.width - best.size.width) / 2
        headers = best.headers.map { Header(frame: $0.frame.offsetBy(dx: insetX, dy: 40 * scale), label: $0.label, current: $0.current) }
        tiles = best.tiles.map { Tile(frame: $0.frame.offsetBy(dx: insetX, dy: 40 * scale), pictureSize: $0.pictureSize) }
    }

    func nearest(from index: Int, direction: Direction) -> Int? {
        guard tiles.indices.contains(index) else { return nil }
        let source = tiles[index].frame
        let candidates = tiles.indices.filter { $0 != index }
        func overlapsX(_ frame: CGRect) -> Bool { frame.minX < source.maxX && frame.maxX > source.minX }
        func overlapsY(_ frame: CGRect) -> Bool { frame.minY < source.maxY && frame.maxY > source.minY }
        switch direction {
            case .left, .right:
                let directional = candidates.filter { direction == .left ? tiles[$0].frame.maxX <= source.minX : tiles[$0].frame.minX >= source.maxX }
                let sameRow = directional.filter { abs(tiles[$0].frame.minY - source.minY) < 0.001 }
                let pool = sameRow.isEmpty ? directional.filter { overlapsY(tiles[$0].frame) } : sameRow
                return pool.min { abs(tiles[$0].frame.midX - source.midX) < abs(tiles[$1].frame.midX - source.midX) }
            case .up, .down:
                let directional = candidates.filter { direction == .up ? tiles[$0].frame.minY < source.minY - 0.001 : tiles[$0].frame.minY > source.minY + 0.001 }
                let overlapping = directional.filter { overlapsX(tiles[$0].frame) }
                let pool = arrangement == "columns" && !overlapping.isEmpty ? overlapping : directional
                guard let row = (direction == .up ? pool.map { tiles[$0].frame.minY }.max() : pool.map { tiles[$0].frame.minY }.min()) else { return nil }
                return pool.filter { abs(tiles[$0].frame.minY - row) < 0.001 }.min {
                    abs(tiles[$0].frame.midX - source.midX) < abs(tiles[$1].frame.midX - source.midX)
                }
        }
    }
}
