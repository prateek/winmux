@testable import AppBundle
import AppKit
import XCTest

@MainActor
final class PerAppCardTest: XCTestCase {
    private let screen = CGSize(width: 1920, height: 1080)

    override func setUp() async throws { setUpWorkspacesForTests() }

    private func items() -> [SwitcherPaletteItem] {
        (0..<10).map { index in
            let name = index.isMultiple(of: 2) ? "Calculator" : "Safari"
            let size = CGSize(width: 800, height: 600)
            return SwitcherPaletteItem(id: UInt32(index + 1), title: "Document", appName: name, icon: nil, workspaceName: "3", appIdentity: "app-\(index)", isFocused: false,
                                       tile: TileEntry(title: "Document", appName: name, aspect: size.width / size.height, realSize: size,
                                                       badges: TileBadges(workspaceLabel: "W3", onFocusedWorkspace: false)))
        }
    }

    func testWindowEntriesKeepLegacyFramesThroughStripAndGridSessions() {
        for kind in TileKind.allCases {
            var settings = LensConfig(); settings.tile = kind.rawValue; settings.sections = "none"
            let session = LensSession(name: "windows", settings: settings, items: items(), search: "")
            session.miniatureSize = screen
            let entries = session.results.map { GridLayout.Entry(aspect: $0.tile.aspect, realSize: $0.tile.realSize, kind: kind) }
            let section = GridLayout.Section(label: nil, current: false, entries: entries)
            let strip = GridLayout(sections: [section], visibleSize: screen, tileSize: settings.grid.tileSize,
                                   minimumWidth: TileMetrics(visibleSize: screen).textWidth + 88, sizing: .strip)
            let grid = GridLayout(sections: [section], visibleSize: screen, tileSize: settings.grid.tileSize)
            XCTAssertEqual(session.stripSnapshot.layout.tiles.map(\.frame), strip.tiles.map(\.frame))
            XCTAssertEqual(session.gridLayout.tiles.map(\.frame), grid.tiles.map(\.frame))
        }
    }

    func testStripReservesWholePerAppBarsAndZeroKeepsLegacyFrames() {
        let tiles = (0..<10).map { index in
            TileEntry(title: index.isMultiple(of: 2) ? "Calculator" : "Safari", appName: "App",
                      badges: TileBadges(workspaceLabel: "W3", onFocusedWorkspace: false), appCount: index.isMultiple(of: 2) ? 1 : 3)
        }
        let entries = tiles.map { GridLayout.Entry(aspect: $0.aspect, realSize: $0.realSize, kind: .card, barWidth: $0.cardBarWidth(badges: true)) }
        func pack(_ entries: [GridLayout.Entry]) -> GridLayout {
            GridLayout(sections: [.init(label: nil, current: false, entries: entries)], visibleSize: screen, tileSize: "real", sizing: .strip)
        }
        let layout = pack(entries)
        XCTAssertFalse(layout.relaxedTitleFloor)
        for (entry, tile) in zip(entries, layout.tiles) {
            XCTAssertGreaterThanOrEqual(tile.frame.width - 2 * TileMetrics(scale: layout.tileScale).padding + 0.001, entry.barWidth * layout.tileScale, "The whole app bar must fit")
        }
        let zero = entries.map { GridLayout.Entry(aspect: $0.aspect, realSize: $0.realSize, kind: $0.kind, barWidth: 0) }
        let omitted = entries.map { GridLayout.Entry(aspect: $0.aspect, realSize: $0.realSize, kind: $0.kind) }
        XCTAssertEqual(pack(zero).tiles.map(\.frame), pack(omitted).tiles.map(\.frame))
        // Base 239918e7, ten 800-by-600 window cards at 1920-by-1080.
        XCTAssertEqual(pack(zero).tiles[0].frame.width, 151.4, accuracy: 0.01)
        XCTAssertEqual(pack(zero).tiles[0].frame.height, 165.50, accuracy: 0.01)
    }

    func testAppBarsReachBothSessionLayoutsAndInvalidateTheirCaches() {
        var settings = LensConfig(); settings.entries = "app"; settings.tile = "card"; settings.sections = "none"
        let session = LensSession(name: "apps", settings: settings, items: items(), search: "")
        session.miniatureSize = screen
        let original = session.results
        var wider = original
        for index in wider.indices { wider[index].tile.title = "A much longer application name" }
        let strip = session.stripSnapshot(items: original).layout
        let grid = session.gridLayout(items: original)
        let widerStrip = session.stripSnapshot(items: wider).layout
        let widerGrid = session.gridLayout(items: wider)
        for (layout, input) in [(strip, original), (grid, original), (widerStrip, wider), (widerGrid, wider)] {
            for (tile, item) in zip(layout.tiles, input) {
                XCTAssertGreaterThanOrEqual(tile.frame.width - 2 * TileMetrics(scale: layout.tileScale).padding + 0.001,
                                            item.tile.cardBarWidth(badges: true) * layout.tileScale)
            }
        }
        XCTAssertNotEqual(strip.tiles.map(\.frame), widerStrip.tiles.map(\.frame), "Strip cache must include the bar width")
        XCTAssertNotEqual(grid.tiles.map(\.frame), widerGrid.tiles.map(\.frame), "Grid cache must include the bar width")
    }

    func testBarWidthCapsTheNameAndKeepsTheCountWhenBadgesAreOff() {
        var entry = TileEntry(title: String(repeating: "W", count: 80), appName: "App",
                              badges: TileBadges(workspaceLabel: "W3", onFocusedWorkspace: false), appCount: 1)
        let count = ceil(("1 window" as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold)]).width) + 14
        XCTAssertEqual(entry.cardBarWidth(badges: false), 26 + 8 + 240 + 8 + count)
        XCTAssertGreaterThan(entry.cardBarWidth(badges: true), entry.cardBarWidth(badges: false))
        entry.appCount = nil
        XCTAssertEqual(entry.cardBarWidth(badges: true), 0)
    }

    func testPicturesAndTextIgnoreBarsAndCrowdedCardsRelaxThemToFit() {
        for kind in TileKind.allCases {
            let plain = GridLayout.Entry(aspect: 4 / 3, realSize: CGSize(width: 800, height: 600), kind: kind)
            var wide = plain; wide.barWidth = 5000
            func pack(_ input: GridLayout.Entry) -> GridLayout {
                GridLayout(sections: [.init(label: nil, current: false, entries: Array(repeating: input, count: 100))],
                           visibleSize: screen, tileSize: "real", sizing: .strip)
            }
            let layout = pack(wide)
            XCTAssertLessThanOrEqual(layout.panelSize.width, screen.width * 0.9)
            XCTAssertLessThanOrEqual(layout.panelSize.height, screen.height * 0.88)
            if kind == .card { XCTAssertTrue(layout.relaxedTitleFloor) }
            else { XCTAssertEqual(layout.tiles.map(\.frame), pack(plain).tiles.map(\.frame)) }
        }
    }
}
