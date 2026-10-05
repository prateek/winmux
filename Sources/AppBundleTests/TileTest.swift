@testable import AppBundle
import AppKit
import XCTest

final class TileTest: XCTestCase {
    func testKindResolutionUsesOverrideThenConfigThenPresentation() {
        for (presentation, expected): (String, TileKind) in [("strip", .card), ("grid", .card), ("list", .text), ("miniatures", .picture)] {
            XCTAssertEqual(TileKind.resolve(configured: nil, override: nil, presentation: presentation), expected)
            for kind in TileKind.allCases {
                XCTAssertEqual(TileKind.resolve(configured: kind.rawValue, override: nil, presentation: presentation), presentation == "miniatures" ? .picture : kind)
                XCTAssertEqual(TileKind.resolve(configured: "text", override: kind.rawValue, presentation: presentation), presentation == "miniatures" ? .picture : kind)
            }
        }
    }

    func testBadgesAreOrderedAndCanBeDisabledWithoutChangingEntryFlags() {
        let flags = TileBadges(workspaceNumber: 3, onFocusedWorkspace: false, floating: true, minimized: true, hidden: true)
        XCTAssertEqual(flags.chips(enabled: true), ["3", "floating", "minimized", "hidden"])
        XCTAssertEqual(flags.chips(enabled: false), [])
        XCTAssertEqual(TileBadges(workspaceNumber: 1, onFocusedWorkspace: true).chips(enabled: true), [])
        XCTAssertEqual(TileBadges(workspaceNumber: nil, onFocusedWorkspace: false, hidden: true).chips(enabled: true), ["hidden"])
    }

    func testMetricsScaleEveryPrototypeDimension() {
        let full = TileMetrics(visibleHeight: 1080), half = TileMetrics(visibleHeight: 540)
        XCTAssertEqual(full.padding, 10)
        XCTAssertEqual(full.gap, 8)
        XCTAssertEqual(full.radius, 14)
        XCTAssertEqual(full.barHeight, 28)
        XCTAssertEqual(full.icon, 26)
        XCTAssertEqual(full.titleFont, 17)
        XCTAssertEqual(full.appFont, 14)
        XCTAssertEqual(full.chipFont, 12)
        XCTAssertEqual(full.textHeight, 46)
        XCTAssertEqual(full.listPictureHeight, 74)
        XCTAssertEqual(full.listPictureWidth, 96)
        XCTAssertEqual(full.selectionScale, 1.045)
        XCTAssertEqual(full.selectionRing, 2.5)
        XCTAssertEqual(full.miniatureRing, 4)
        XCTAssertEqual(half.padding, 5)
        XCTAssertEqual(half.titleFont, 8.5)
        XCTAssertEqual(half.textHeight, 23)
        XCTAssertEqual(half.miniatureIcon, 11)
        XCTAssertEqual(half.selectionScale, full.selectionScale)
    }

    func testWidthsKeepRealShapeWithPictureFloorAndCardTitleFloor() {
        let metrics = TileMetrics(visibleHeight: 1080)
        XCTAssertEqual(metrics.width(kind: .picture, aspect: 0.2, rowHeight: 190), 90)
        XCTAssertEqual(metrics.width(kind: .picture, aspect: 2, rowHeight: 190), 400)
        XCTAssertEqual(metrics.width(kind: .card, aspect: 0.2, rowHeight: 190), 220)
        XCTAssertEqual(metrics.width(kind: .card, aspect: 0.2, rowHeight: 100), 140)
        XCTAssertEqual(metrics.width(kind: .text, aspect: 2, rowHeight: 190), 330)
        XCTAssertEqual(metrics.fittedPicture(aspect: 0.5, in: CGSize(width: 96, height: 62)), CGSize(width: 31, height: 62))
        XCTAssertEqual(metrics.fittedPicture(aspect: 3, in: CGSize(width: 96, height: 62)), CGSize(width: 96, height: 32))
    }
}
