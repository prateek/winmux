@testable import AppBundle
import AppKit
import SwiftUI
import XCTest

@MainActor
final class TileTextTest: XCTestCase {
    private let screen = CGSize(width: 1920, height: 1080)
    private let longName = String(repeating: "W", count: 92)

    func testAppNameYieldsBeforeTitleWithoutWideningShortNames() {
        for (available, titleIdeal, appIdeal, title, app) in [
            (300.0, 100.0, 50.0, 250.0, 50.0),
            (300, 180, 200, 180, 120),
            (300, 500, 200, 200, 100),
            (300, 500, 50, 250, 50),
        ] {
            let widths = tileBarTextWidths(available: available, titleIdeal: titleIdeal, appIdeal: appIdeal)
            XCTAssertEqual(widths.title, title, accuracy: 0.001, "Title allocation for \(titleIdeal)/\(appIdeal)")
            XCTAssertEqual(widths.app, app, accuracy: 0.001, "App allocation for \(titleIdeal)/\(appIdeal)")
        }
    }

    func testLongAppNameStaysInsideListAndStripTextTiles() throws {
        XCTAssertEqual(longName.count, 92)
        let metrics = TileMetrics(visibleSize: screen)
        let list = ListLayout(count: 3, kind: .text, visibleSize: screen)
        for (presentation, size) in [
            ("list", CGSize(width: list.width - 40 * metrics.scale, height: list.rowHeight)),
            ("strip", CGSize(width: metrics.textWidth, height: metrics.textHeight)),
        ] {
            let image = try render(title: "A controlled window title", app: longName, kind: .text, presentation: presentation, size: size, metrics: metrics, margin: 800)
            let bitmap = NSBitmapImageRep(cgImage: image)
            var outsideInk = 0
            var insideInk = 0
            for y in 0..<image.height {
                for x in 0..<image.width {
                    if try XCTUnwrap(bitmap.colorAt(x: x, y: y)).alphaComponent > 0.01 {
                        if x < 800 || x >= 800 + Int(size.width) || y < 800 || y >= 800 + Int(size.height) { outsideInk += 1 }
                        else { insideInk += 1 }
                    }
                }
            }
            XCTAssertGreaterThan(insideInk, 100, "The renderer must draw visible text")
            XCTAssertEqual(outsideInk, 0, "\(presentation): app name ink must stay inside the Tile")
        }
    }

    func testFourteenWindowCardBarsDistinguishTitleSuffixes() throws {
        let input = Array(repeating: GridLayout.Entry(aspect: 520 / 382, realSize: CGSize(width: 520, height: 382), kind: .card), count: 14)
        let layout = GridLayout(entries: input, visibleSize: screen, tileSize: "real")
        let metrics = TileMetrics(scale: layout.tileScale)
        let size = try XCTUnwrap(layout.tiles.first).frame.size
        let titles = [
            "prateek/winmux pull request 201: a controlled long title for the tile comparison — alpha",
            "prateek/winmux pull request 203: a controlled long title for the tile comparison — omega",
        ]
        XCTAssertTrue(titles.allSatisfy { (80...95).contains($0.count) })
        var bars: [Data] = []
        for title in titles {
            let image = try render(title: title, app: "Demo", kind: .card, presentation: "grid", size: size, metrics: metrics)
            let bar = try XCTUnwrap(image.cropping(to: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: ceil(metrics.padding + metrics.barHeight))))
            bars.append(try XCTUnwrap(bar.dataProvider?.data) as Data)
        }
        XCTAssertNotEqual(bars[0], bars[1], "Card bars must retain the distinguishing title suffix")
    }

    private func render(title: String, app: String, kind: TileKind, presentation: String, size: CGSize, metrics: TileMetrics, margin: CGFloat = 0) throws -> CGImage {
        let tile = TileView(entry: TileEntry(title: title, appName: app), kind: kind, presentation: presentation, metrics: metrics, size: size, settings: LensConfig(), selected: false, marked: false, hint: nil)
        let renderer = ImageRenderer(content: tile.padding(margin))
        renderer.scale = 1
        return try XCTUnwrap(renderer.cgImage)
    }
}
