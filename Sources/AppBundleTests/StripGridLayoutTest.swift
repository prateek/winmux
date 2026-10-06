@testable import AppBundle
import Foundation
import XCTest

final class StripGridLayoutTest: XCTestCase {
    let monitor = CGSize(width: 1920, height: 1080)
    func entries(_ count: Int, kind: TileKind = .card) -> [GridLayout.Entry] {
        Array(repeating: .init(aspect: 4 / 3, realSize: CGSize(width: 1200, height: 900), kind: kind), count: count)
    }
    func layout(_ count: Int, size: CGSize? = nil, mode: String = "real", kind: TileKind = .card) -> GridLayout {
        GridLayout(sections: [.init(label: nil, current: false, entries: entries(count, kind: kind))], visibleSize: size ?? monitor,
                   tileSize: mode, sizing: .strip)
    }
    func rows(_ layout: GridLayout) -> Int { Set(layout.tiles.map { $0.frame.minY }).count }
    func check(_ layout: GridLayout, count: Int, size: CGSize) {
        XCTAssertEqual(layout.tiles.count, count)
        XCTAssertLessThanOrEqual(layout.panelSize.width, size.width * 0.9 + 0.001)
        XCTAssertLessThanOrEqual(layout.panelSize.height, size.height * 0.88 + 0.001)
        for (index, tile) in layout.tiles.enumerated() {
            XCTAssertTrue(CGRect(origin: .zero, size: layout.panelSize).contains(tile.frame))
            for previous in layout.tiles.prefix(index) { XCTAssertFalse(previous.frame.intersects(tile.frame)) }
        }
    }
    func testMeasuredOrdinaryWindows() {
        for size in [monitor, CGSize(width: 1280, height: 720)] {
            for mode in ["real", "same-height", "equal"] {
                for count in [3, 9, 11, 12, 14, 20, 40] {
                    let card = layout(count, size: size, mode: mode), picture = layout(count, size: size, mode: mode, kind: .picture)
                    print("STRIP-MEASURE | \(Int(size.width))×\(Int(size.height)) | \(mode) | \(count) | \(rows(card)) | \(String(format: "%.2f", Double(card.rowHeight))) | \(rows(picture)) | \(String(format: "%.2f", Double(picture.rowHeight))) |")
                    check(card, count: count, size: size); check(picture, count: count, size: size)
                }
            }
        }
    }
    func testFewWindowsGrowAndStopAtCapAndNineStayInOneRow() {
        for size in [monitor, CGSize(width: 1280, height: 720)] {
            let three = layout(3, size: size), nine = layout(9, size: size)
            XCTAssertEqual(rows(three), 1); XCTAssertEqual(rows(nine), 1)
            XCTAssertGreaterThan(three.rowHeight, nine.rowHeight)
            XCTAssertEqual(layout(2, size: size).rowHeight, 190 * TileMetrics(visibleSize: size).scale)
        }
    }
    func testFourteenAndTwelveWrapAtReadableHeightAndEveryTileFits() {
        for count in [12, 14] {
            let packed = layout(count)
            XCTAssertEqual(rows(packed), 2)
            XCTAssertGreaterThanOrEqual(packed.rowHeight, GridLayout.stripReadableHeight)
            XCTAssertLessThanOrEqual(packed.rowHeight, 190)
            check(packed, count: count, size: monitor)
        }
    }
    func testFloorBoundaryAndCardTitlesCauseEarlierWrapping() {
        let floor = GridLayout.stripReadableHeight
        let input = entries(9, kind: .picture)
        let width = CGFloat(9) * (1200 * floor / 1080 + 20) + 8 * 14 + 88
        for (delta, expected): (CGFloat, Int) in [(1, 1), (-1, 2)] {
            let sizing = GridLayout.Sizing(rowHeightCap: 190, readableHeight: floor, horizontalChrome: 1920 * 0.9 - width - delta + 88, top: 26, bottom: 66, minimumWidth: 418, emptyHeight: 92)
            let packed = GridLayout(sections: [.init(label: nil, current: false, entries: input)], visibleSize: monitor, tileSize: "real", sizing: sizing)
            XCTAssertEqual(rows(packed), expected)
        }
        XCTAssertEqual(rows(layout(11)), 1)
        XCTAssertEqual(rows(layout(12)), 2)
    }
    func testLargeCountsTerminateInEveryModeAndKindAtBothSizes() {
        for size in [monitor, CGSize(width: 1280, height: 720)] {
            for mode in ["real", "same-height", "equal"] {
                for kind in TileKind.allCases {
                    for count in [40, 100] { check(layout(count, size: size, mode: mode, kind: kind), count: count, size: size) }
                }
            }
        }
    }
    func testAccessoryPolicyOnlyChangesStripPicturesInEveryMode() {
        for mode in ["real", "same-height", "equal"] {
            let ordinary = GridLayout.Entry(aspect: 1.5, realSize: CGSize(width: 600, height: 400), kind: .picture)
            let enlarged = GridLayout.Entry(aspect: 1.5, realSize: ordinary.realSize, kind: .picture, accessory: true, monitorHeightFraction: 0.1)
            let actual = GridLayout.Entry(aspect: 1.5, realSize: ordinary.realSize, kind: .picture, accessory: true, monitorHeightFraction: 0.1, accessoryActualSize: true)
            func pack(_ entry: GridLayout.Entry, _ sizing: GridLayout.Sizing) -> GridLayout {
                GridLayout(sections: [.init(label: nil, current: false, entries: [entry])], visibleSize: monitor, tileSize: mode, sizing: sizing)
            }
            XCTAssertEqual(pack(enlarged, .strip).tiles[0].pictureSize.height, 190, accuracy: 0.001)
            XCTAssertEqual(pack(actual, .strip).tiles[0].pictureSize.height, 28, accuracy: 0.001)
            XCTAssertEqual(pack(actual, .grid).tiles[0].pictureSize, pack(ordinary, .grid).tiles[0].pictureSize)
        }
    }
    func testMixedExtremeAndOversizedWindowsRemainInsidePanel() {
        let input: [GridLayout.Entry] = [0.01, 10, 1.5, 0.6, 100, 1.2].map {
            .init(aspect: $0, realSize: CGSize(width: $0 * 2000, height: 2000), kind: .card)
        }
        for mode in ["real", "same-height", "equal"] {
            let packed = GridLayout(sections: [.init(label: nil, current: false, entries: input)], visibleSize: monitor, tileSize: mode, sizing: .strip)
            check(packed, count: input.count, size: monitor)
        }
    }
}
