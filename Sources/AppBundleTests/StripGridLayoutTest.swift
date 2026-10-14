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
    // BASE's MRU frames in .scratch/winmux-fork/prototypes/31-lens-look/index.html.
    // The current live desk is measured separately.
    private let richDeskSizes: [CGSize] = [
        CGSize(width: 919, height: 1025), CGSize(width: 919, height: 509),
        CGSize(width: 798, height: 986), CGSize(width: 709, height: 1025),
        CGSize(width: 1221, height: 986), CGSize(width: 611, height: 1025),
        CGSize(width: 798, height: 986), CGSize(width: 440, height: 202),
        CGSize(width: 919, height: 509), CGSize(width: 513, height: 1025),
        CGSize(width: 798, height: 986), CGSize(width: 1221, height: 986),
        CGSize(width: 1846, height: 1025), CGSize(width: 230, height: 408),
    ]

    @MainActor
    func testPictureStripComparisonSizesAtPictureReadableFloor() {
        let controlledAspects: [CGFloat] = [0.3, 0.45, 0.7, 0.8, 0.9, 0.6, 2.6]
        let controlled = (0..<25).map { CGSize(width: 600 * controlledAspects[$0 % controlledAspects.count], height: 600) }
        let cases: [([CGSize], CGSize, Int)] = [
            (richDeskSizes, CGSize(width: 1728, height: 184.534), 1),
            ([CGSize(width: 300, height: 800), CGSize(width: 400, height: 1000), CGSize(width: 200, height: 600)], CGSize(width: 518, height: 300), 1),
            (controlled, CGSize(width: 1728, height: 368.504), 2),
            (Array((richDeskSizes + richDeskSizes).prefix(25)), CGSize(width: 1728, height: 310.408), 2),
        ]
        for (sizes, expected, expectedRows) in cases {
            let items = sizes.enumerated().map { index, size in
                var item = SwitcherPaletteItem(id: UInt32(index + 1), title: "Window \(index)", appName: "Fixture", icon: nil, workspaceName: "1", isFocused: false)
                item.tile = TileEntry(title: item.title, appName: item.appName, aspect: size.width / size.height, realSize: size)
                return item
            }
            var settings = LensConfig(); settings.grid.tileSize = "same-height"
            let packed = StripSnapshot(items: items, size: monitor, kind: .picture, settings: settings).layout
            XCTAssertEqual(packed.panelSize.width, expected.width, accuracy: 0.5)
            XCTAssertEqual(packed.panelSize.height, expected.height, accuracy: 0.5)
            XCTAssertEqual(rows(packed), expectedRows)
            check(packed, count: sizes.count, size: monitor)
            print("Picture strip comparison: \(sizes.count) windows, \(packed.panelSize), \(rows(packed)) rows")
        }
    }

    func testPicturesFirstWrapNearTwentyWindows() {
        for (sizes, firstWrap) in [(richDeskSizes, 19), ([CGSize(width: 1200, height: 900)], 17)] {
            for count in 1...firstWrap {
                let input = (0..<count).map { index in
                    let size = sizes[index % sizes.count]
                    return GridLayout.Entry(aspect: size.width / size.height, realSize: size, kind: .picture)
                }
                let packed = GridLayout(sections: [.init(label: nil, current: false, entries: input)], visibleSize: monitor, tileSize: "same-height", sizing: .strip)
                XCTAssertEqual(rows(packed), count == firstWrap ? 2 : 1, "count \(count), first wrap \(firstWrap)")
            }
        }
    }

    func testPictureFloorAppliesWherePicturesShareTheRowHeight() {
        for size in [monitor, CGSize(width: 1280, height: 720)] {
            for mode in ["real", "same-height", "equal"] {
                for kind in TileKind.allCases {
                    let expectedSizing = GridLayout.Sizing(rowHeightCap: 190, readableHeight: kind == .picture && mode != "real" ? 48 : 88, honoursAccessoryWindow: true, horizontalChrome: 88, top: 26, bottom: 64, minimumWidth: 418, emptyHeight: 90)
                    let input = entries(14, kind: kind)
                    let actual = GridLayout(sections: [.init(label: nil, current: false, entries: input)], visibleSize: size, tileSize: mode, sizing: .strip)
                    let expected = GridLayout(sections: [.init(label: nil, current: false, entries: input)], visibleSize: size, tileSize: mode, sizing: expectedSizing)
                    XCTAssertEqual(actual.rowHeight, expected.rowHeight, accuracy: 0.001)
                    XCTAssertEqual(actual.panelSize, expected.panelSize)
                }
            }
        }
    }

    func testMeasuredOrdinaryWindows() {
        for size in [monitor, CGSize(width: 1280, height: 720)] {
            for mode in ["real", "same-height", "equal"] {
                for count in [3, 9, 11, 12, 14, 20, 40] {
                    let card = layout(count, size: size, mode: mode), picture = layout(count, size: size, mode: mode, kind: .picture)
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
            let sizing = GridLayout.Sizing(rowHeightCap: 190, readableHeight: floor, honoursAccessoryWindow: true, horizontalChrome: 1920 * 0.9 - width - delta + 88, top: 26, bottom: 64, minimumWidth: 418, emptyHeight: 90)
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
    func testStripKeepsGridSizeModesFitLimitsAndTextDimensions() {
        let window = GridLayout.Entry(aspect: 10, realSize: CGSize(width: 9000, height: 900), kind: .picture)
        for mode in ["real", "same-height", "equal"] {
            let packed = GridLayout(sections: [.init(label: nil, current: false, entries: [window])], visibleSize: monitor, tileSize: mode, sizing: .strip)
            XCTAssertEqual(packed.rowHeight, 190)
            let width: CGFloat = mode == "real" ? 9000 * 190 / 1080 : (mode == "equal" ? 1.5 : 2.1) * 190
            XCTAssertEqual(packed.tiles[0].frame.width, width + 20, accuracy: 0.001)
            XCTAssertEqual(packed.tiles[0].pictureSize.width, width, accuracy: 0.001)
        }
        let portrait = GridLayout.Entry(aspect: 0.01, realSize: CGSize(width: 9, height: 900), kind: .picture)
        let fit = GridLayout(sections: [.init(label: nil, current: false, entries: [portrait])], visibleSize: monitor, tileSize: "same-height", sizing: .strip)
        XCTAssertEqual(fit.tiles[0].frame.width, 0.6 * 190 + 20, accuracy: 0.001)
        let text = layout(3, kind: .text)
        XCTAssertEqual(rows(text), 1)
        XCTAssertEqual(text.tiles[0].frame.size, CGSize(width: 330, height: 46))
        let cards = layout(11)
        let title = min(200, max(1.2 * cards.rowHeight, 110))
        for tile in cards.tiles { XCTAssertGreaterThanOrEqual(tile.frame.width, title + 20) }
    }
    func testStripChromeKeepsTheFooterGapAndEmptyHeight() {
        let packed = layout(3)
        let end = packed.tiles.map { $0.frame.maxY }.max()!
        XCTAssertEqual(packed.panelSize.height - end, 24 + 18 + 22)
        let empty = layout(0)
        XCTAssertEqual(empty.panelSize.height, 26 + 24 + 18 + 22)
        XCTAssertEqual(packed.tiles[0].frame.minY, 26)
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
    func testExtremeAccessoryNeitherShrinksTheRowNorBecomesASliver() {
        let ordinary = entries(2, kind: .picture)
        let bar = GridLayout.Entry(aspect: 20, realSize: CGSize(width: 400, height: 20), kind: .picture, accessory: true, monitorHeightFraction: 0.02)
        let sliver = GridLayout.Entry(aspect: 0.05, realSize: CGSize(width: 20, height: 400), kind: .picture, accessory: true, monitorHeightFraction: 0.4, accessoryActualSize: true)
        let packed = GridLayout(sections: [.init(label: nil, current: false, entries: ordinary + [bar, sliver])], visibleSize: monitor, tileSize: "real", sizing: .strip)
        XCTAssertEqual(packed.rowHeight, 190)
        XCTAssertEqual(rows(packed), 1)
        XCTAssertEqual(packed.tiles[2].frame.width, 3.6 * 190 + 20, accuracy: 0.001)
        XCTAssertEqual(packed.tiles[2].pictureSize.width / packed.tiles[2].pictureSize.height, 20, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(packed.tiles[3].frame.width, 70 + 20)
    }
}
