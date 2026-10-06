@testable import AppBundle
import XCTest

final class LensSectionsTest: XCTestCase {
    func testOrderedGroupsFocusedFirstStableEntriesAndMissingLast() {
        let entries = ["2", "", "1", "2", "3"]
        let order = [LensSectionIdentity(key: "1", label: "One", current: false),
                     LensSectionIdentity(key: "2", label: "Two", current: true),
                     LensSectionIdentity(key: "3", label: "Three", current: false)]
        let sections = lensSections(entries, grouping: "workspace", identities: order, key: { $0 }, label: { $0 })
        XCTAssertEqual(sections.map(\.key), ["2", "1", "3", ""])
        XCTAssertEqual(sections.map(\.label), ["Two", "One", "Three", "No workspace"])
        XCTAssertEqual(sections.map(\.current), [true, false, false, false])
        XCTAssertEqual(sections[0].entries, ["2", "2"])
        let apps = lensSections(entries, grouping: "app", identities: order, key: { $0 }, label: { $0 })
        XCTAssertEqual(apps.map(\.key), ["2", "", "1", "3"])
        XCTAssertFalse(apps.contains(where: \.current))
        XCTAssertEqual(lensSections(entries, grouping: "none", identities: order, key: { $0 }, label: { $0 }).first?.entries, entries)
        XCTAssertTrue(lensSections([String](), grouping: "workspace", identities: order, key: { $0 }, label: { $0 }).isEmpty)
    }

    func testAllArrangementsFitAndFramesDoNotIntersectEvenWithTwentyColumns() {
        for size in [CGSize(width: 1920, height: 1080), CGSize(width: 1280, height: 720)] {
            for arrangement in ["flow", "rows", "columns"] {
                for count in [10, 20] {
                    let sections = (0..<count).map { index in
                        GridLayout.Section(label: "Long section label \(index)", current: index == 0, entries: (0..<(40 / count)).map { entry in
                            GridLayout.Entry(aspect: entry == 0 ? 3 : 0.6, realSize: CGSize(width: entry == 0 ? 1800 : 450, height: 900), kind: .card)
                        })
                    }
                    let layout = GridLayout(sections: sections, visibleSize: size, tileSize: "real", arrangement: arrangement)
                    XCTAssertEqual(layout.tiles.count, 40)
                    XCTAssertEqual(layout.headers.count, count)
                    XCTAssertLessThanOrEqual(layout.panelSize.width, size.width * 0.9 + 0.01)
                    XCTAssertLessThanOrEqual(layout.panelSize.height, size.height * 0.88 + 0.01)
                    let frames = layout.tiles.map(\.frame) + layout.headers.map(\.frame)
                    for (index, frame) in frames.enumerated() {
                        XCTAssertTrue(CGRect(origin: .zero, size: layout.panelSize).contains(frame))
                        for prior in frames.prefix(index) { XCTAssertFalse(frame.intersects(prior)) }
                    }
                }
            }
        }
    }
}

extension LensSectionsTest {
    func testGeometricArrowsReachEveryTileAndRespectRowsAndColumns() {
        for arrangement in ["flow", "rows", "columns"] {
            for counts in [[4, 1, 5, 2], [2, 3, 1], [1, 1, 1, 1, 1], [8, 5, 6]] {
                let sections = counts.enumerated().map { section, count in
                    GridLayout.Section(label: "Section \(section)", current: section == 0, entries: (0..<count).map { index in
                        .init(aspect: [2.4, 0.6, 1.3][index % 3], realSize: CGSize(width: [1800, 450, 1000][index % 3], height: 900), kind: .card)
                    })
                }
                let layout = GridLayout(sections: sections, visibleSize: CGSize(width: 1920, height: 1080), tileSize: "real", arrangement: arrangement)
                for start in layout.tiles.indices {
                    var reached: Set<Int> = [start], pending = [start]
                    while let index = pending.popLast() {
                        for direction: GridLayout.Direction in [.left, .right, .up, .down] {
                            if let next = layout.nearest(from: index, direction: direction), reached.insert(next).inserted { pending.append(next) }
                        }
                    }
                    XCTAssertEqual(reached.count, layout.tiles.count, "\(arrangement) \(counts) from \(start)")
                    if let right = layout.nearest(from: start, direction: .right) {
                        XCTAssertEqual(layout.nearest(from: right, direction: .left), start, "\(arrangement) from \(start)")
                    }
                    if let down = layout.nearest(from: start, direction: .down), let up = layout.nearest(from: down, direction: .up) {
                        XCTAssertEqual(layout.tiles[up].frame.minY, layout.tiles[start].frame.minY, accuracy: 0.001)
                    }
                    if arrangement == "columns" {
                        let bounds = counts.reduce(into: [0]) { $0.append($0.last! + $1) }
                        let section = bounds.indices.dropLast().first { start >= bounds[$0] && start < bounds[$0 + 1] }!
                        let lower = (bounds[section]..<bounds[section + 1]).filter { layout.tiles[$0].frame.minY > layout.tiles[start].frame.minY }
                        if !lower.isEmpty, let down = layout.nearest(from: start, direction: .down) {
                            XCTAssertTrue((bounds[section]..<bounds[section + 1]).contains(down))
                        }
                    }
                }
            }
        }
    }
    func testListHeadersConsumeScrollHeightAndSelectionRemainsVisible() {
        let size = CGSize(width: 1920, height: 1080)
        let plain = ListLayout(count: 8, kind: .text, visibleSize: size)
        let grouped = ListLayout(count: 8, kind: .text, visibleSize: size, sectionStarts: [0, 2, 4, 6])
        XCTAssertGreaterThan(grouped.rowsHeight, plain.rowsHeight)
        XCTAssertEqual(grouped.rowOffsets[0], 32)
        XCTAssertEqual(grouped.rowOffsets[2] - grouped.rowOffsets[1], grouped.rowHeight + grouped.gap + 38)
        let long = ListLayout(count: 40, kind: .card, visibleSize: size, sectionStarts: Array(stride(from: 0, to: 40, by: 4)))
        for selection in 0..<40 { XCTAssertTrue(long.visibleRange(selection: selection, count: 40).contains(selection)) }
    }
}

extension LensSectionsTest {
    func testNoneIgnoresArrangementAndKeepsLegacyGeometryAndArrows() {
        let entries = (0..<14).map { _ in GridLayout.Entry(aspect: 2.4, realSize: CGSize(width: 1700, height: 760), kind: .card) }
        let size = CGSize(width: 1920, height: 1080)
        let plain = GridLayout(entries: entries, visibleSize: size, tileSize: "real")
        for arrangement in ["flow", "rows", "columns"] {
            let layout = GridLayout(sections: [.init(label: nil, current: false, entries: entries)], visibleSize: size, tileSize: "real", arrangement: arrangement)
            XCTAssertEqual(layout.tiles.map(\.frame), plain.tiles.map(\.frame))
            XCTAssertEqual(layout.panelSize, plain.panelSize)
            XCTAssertTrue(layout.headers.isEmpty)
            for index in entries.indices {
                for direction: GridLayout.Direction in [.left, .right, .up, .down] {
                    XCTAssertEqual(layout.nearest(from: index, direction: direction), plain.nearest(from: index, direction: direction))
                }
            }
        }
    }
    func testColumnReadabilityMeasurements() {
        for count in [8, 9, 10, 11, 12, 20] {
            let sections = (0..<count).map { GridLayout.Section(label: "Workspace \($0 + 1)", current: $0 == 0, entries: Array(repeating: .init(aspect: 4 / 3, realSize: CGSize(width: 1200, height: 900), kind: .card), count: 2)) }
            let layout = GridLayout(sections: sections, visibleSize: CGSize(width: 1920, height: 1080), tileSize: "real", arrangement: "columns")
            print("SECTION_COLUMNS count=\(count) height=\(layout.rowHeight) titleFont=\(17 * layout.tileScale) headerFont=\(15 * layout.tileScale) headerWidth=\(layout.headers[0].frame.width)")
            XCTAssertEqual(layout.tiles.count, count * 2)
        }
    }
}

extension LensSectionsTest {
    func testAppIdentityGroupsMultipleProcessesOfOneBundleButKeepsAnonymousAppsDistinct() {
        XCTAssertEqual(lensAppIdentity(bundleId: "org.ghostty", pid: 1), lensAppIdentity(bundleId: "org.ghostty", pid: 2))
        XCTAssertNotEqual(lensAppIdentity(bundleId: "", pid: 1), lensAppIdentity(bundleId: "", pid: 2))
    }
}
