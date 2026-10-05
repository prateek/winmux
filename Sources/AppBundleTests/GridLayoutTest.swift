@testable import AppBundle
import Foundation
import XCTest

final class GridLayoutTest: XCTestCase {
    private let monitor = CGSize(width: 1920, height: 1080)
    private func entries(_ count: Int, kind: TileKind = .card) -> [GridLayout.Entry] {
        (0..<count).map { index in
            let size = [CGSize(width: 1200, height: 900), CGSize(width: 300, height: 200), CGSize(width: 450, height: 1000)][index % 3]
            return .init(aspect: size.width / size.height, realSize: size, kind: kind)
        }
    }
    private func check(_ count: Int, mode: String = "real", kind: TileKind = .card) -> GridLayout {
        let input = entries(count, kind: kind)
        let layout = GridLayout(entries: input, visibleSize: monitor, tileSize: mode)
        XCTAssertEqual(layout.tiles.count, count)
        XCTAssertLessThanOrEqual(layout.panelSize.width, monitor.width * 0.9 + 0.01)
        XCTAssertLessThanOrEqual(layout.panelSize.height, monitor.height * 0.88 + 0.01)
        for (index, tile) in layout.tiles.enumerated() {
            XCTAssertGreaterThanOrEqual(tile.frame.minX, 0)
            XCTAssertGreaterThanOrEqual(tile.frame.minY, 0)
            XCTAssertLessThanOrEqual(tile.frame.maxX, layout.panelSize.width)
            XCTAssertLessThanOrEqual(tile.frame.maxY, layout.panelSize.height)
            XCTAssertLessThanOrEqual(tile.pictureSize.width, input[index].realSize.width)
            XCTAssertLessThanOrEqual(tile.pictureSize.height, input[index].realSize.height)
            XCTAssertLessThanOrEqual(tile.pictureSize.width, tile.frame.width)
            XCTAssertLessThanOrEqual(tile.pictureSize.height, tile.frame.height)
            for previous in layout.tiles.prefix(index) { XCTAssertFalse(previous.frame.intersects(tile.frame)) }
        }
        for row in Set(layout.tiles.map { $0.frame.minY }) {
            let frames = layout.tiles.map(\.frame).filter { $0.minY == row }
            XCTAssertEqual((frames.map(\.minX).min()! + frames.map(\.maxX).max()!) / 2, layout.panelSize.width / 2, accuracy: 0.001)
        }
        return layout
    }
    func testOneFullRowWrapAndFortyAllFitInCentredRows() {
        XCTAssertEqual(check(1).rowHeight, 330)
        XCTAssertEqual(Set(check(3).tiles.map { $0.frame.minY }).count, 1)
        XCTAssertGreaterThan(Set(check(14).tiles.map { $0.frame.minY }).count, 1)
        _ = check(40)
        _ = check(80)
        _ = check(1000)
    }
    func testEveryModeAndKindFitsWithoutPaging() {
        for mode in ["real", "same-height", "equal"] {
            for kind in TileKind.allCases { for count in [1, 3, 14, 40, 80, 300] { _ = check(count, mode: mode, kind: kind) } }
        }
    }
    func testRealUsesOneMonitorFactorWithoutStretchingSmallPictures() {
        let layout = check(3)
        for (entry, tile) in zip(entries(3), layout.tiles) {
            XCTAssertEqual(tile.pictureSize.width, entry.realSize.width * layout.rowHeight / monitor.height, accuracy: 0.001)
            XCTAssertEqual(tile.pictureSize.height, entry.realSize.height * layout.rowHeight / monitor.height, accuracy: 0.001)
        }
        XCTAssertLessThan(layout.tiles[1].pictureSize.width, layout.tiles[1].frame.width)
    }
    func testDialogIsNeverUpscaledInAnyModeAndEqualKeepsEqualBoxes() {
        let input = Array(repeating: GridLayout.Entry(aspect: 1.5, realSize: CGSize(width: 300, height: 200), kind: .card), count: 3)
        for mode in ["real", "same-height", "equal"] {
            let layout = GridLayout(entries: input, visibleSize: monitor, tileSize: mode)
            XCTAssertLessThanOrEqual(layout.tiles[0].pictureSize.width, 300)
            XCTAssertLessThanOrEqual(layout.tiles[0].pictureSize.height, 200)
            if mode != "real" { XCTAssertEqual(layout.tiles[0].pictureSize, input[0].realSize) }
        }
        let equal = check(3, mode: "equal")
        XCTAssertEqual(equal.tiles[0].frame.size, equal.tiles[1].frame.size)
        let tall = GridLayout(entries: [.init(aspect: 0.1, realSize: CGSize(width: 100, height: 1000), kind: .picture)], visibleSize: monitor, tileSize: "same-height")
        XCTAssertEqual(tall.tiles[0].pictureSize.width / tall.tiles[0].pictureSize.height, 0.1, accuracy: 0.001)
    }
    func testEmptyPanelIsSmallAndNarrowingResizes() {
        let empty = GridLayout(entries: [], visibleSize: monitor, tileSize: "real")
        XCTAssertTrue(empty.tiles.isEmpty)
        XCTAssertLessThan(empty.panelSize.width, 500)
        XCTAssertLessThan(empty.panelSize.height, 200)
        XCTAssertGreaterThan(check(3).rowHeight, check(40).rowHeight)
        XCTAssertNotEqual(check(3).panelSize, check(40).panelSize)
    }
    func testOneTileLastRowRemainsCentredAndReachable() {
        let input = Array(repeating: GridLayout.Entry(aspect: 1.5, realSize: CGSize(width: 1500, height: 1000), kind: .card), count: 4)
        let layout = GridLayout(entries: input, visibleSize: monitor, tileSize: "equal")
        XCTAssertEqual(Set(layout.tiles.map { $0.frame.minY }).count, 2)
        XCTAssertEqual(layout.tiles[3].frame.midX, layout.panelSize.width / 2)
        XCTAssertEqual(layout.nearest(from: 1, direction: .down), 3)
        XCTAssertEqual(layout.nearest(from: 3, direction: .up), 1)
    }
    func testRealUsesUnclampedRealWidthForExtremeWindows() {
        let input = [GridLayout.Entry(aspect: 10, realSize: CGSize(width: 1800, height: 180), kind: .picture)]
        let layout = GridLayout(entries: input, visibleSize: monitor, tileSize: "real")
        XCTAssertEqual(layout.tiles[0].pictureSize.width, 1800 * layout.rowHeight / monitor.height, accuracy: 0.001)
        XCTAssertEqual(layout.tiles[0].pictureSize.height, 180 * layout.rowHeight / monitor.height, accuracy: 0.001)
    }
    func testFloorRelaxationThreshold() {
        let input = GridLayout.Entry(aspect: 4 / 3, realSize: CGSize(width: 1200, height: 900), kind: .card)
        let threshold = (1...300).first { GridLayout(entries: Array(repeating: input, count: $0), visibleSize: monitor, tileSize: "real").relaxedTitleFloor }!
        print("GRID title floor gives way at \(threshold) editor-sized Tiles on 1920x1080")
        XCTAssertGreaterThan(threshold, 80)
        XCTAssertFalse(GridLayout(entries: Array(repeating: input, count: threshold - 1), visibleSize: monitor, tileSize: "real").relaxedTitleFloor)
    }
    func testLeftAndRightStayInTheRowAndUpAndDownChangeRows() {
        for mode in ["real", "same-height", "equal"] {
            for count in [5, 7, 14, 40] {
                // Wide Tiles put the Tile below closer than the next one along.
                let input = (0..<count).map { GridLayout.Entry(aspect: 2.4, realSize: CGSize(width: [1920, 1500, 1700][$0 % 3], height: 760), kind: .card) }
                let layout = GridLayout(entries: input, visibleSize: monitor, tileSize: mode)
                let rows = layout.tiles.map { $0.frame.minY }
                XCTAssertGreaterThan(Set(rows).count, 1)
                for index in layout.tiles.indices {
                    let sameRowNext = index + 1 < count && rows[index + 1] == rows[index]
                    XCTAssertEqual(layout.nearest(from: index, direction: .right), sameRowNext ? index + 1 : nil, "\(mode) \(count) right of \(index)")
                    let sameRowPrevious = index > 0 && rows[index - 1] == rows[index]
                    XCTAssertEqual(layout.nearest(from: index, direction: .left), sameRowPrevious ? index - 1 : nil, "\(mode) \(count) left of \(index)")
                    if let down = layout.nearest(from: index, direction: .down) {
                        XCTAssertEqual(rows[down], rows.first { $0 > rows[index] })
                    } else { XCTAssertEqual(rows[index], rows.max()) }
                    if let up = layout.nearest(from: index, direction: .up) {
                        XCTAssertEqual(rows[up], rows.last { $0 < rows[index] })
                    } else { XCTAssertEqual(rows[index], rows.min()) }
                }
            }
        }
    }
    func testArrowsReachEveryTileFromEveryTileAndStopAtEdges() {
        for count in [3, 7, 14, 40, 80] {
            let layout = check(count, mode: "same-height")
            for start in 0..<count {
                var reached: Set<Int> = [start], pending = [start]
                while let index = pending.popLast() {
                    for direction in [GridLayout.Direction.left, .right, .up, .down] {
                        if let next = layout.nearest(from: index, direction: direction), reached.insert(next).inserted { pending.append(next) }
                    }
                }
                XCTAssertEqual(reached.count, count, "count=\(count), start=\(start)")
            }
            let top = layout.tiles.indices.min { layout.tiles[$0].frame.midY < layout.tiles[$1].frame.midY }!
            XCTAssertNil(layout.nearest(from: top, direction: .up))
        }
    }
}
