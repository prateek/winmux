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
