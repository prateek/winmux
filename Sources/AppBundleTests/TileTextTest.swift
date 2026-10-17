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
        let crowded = TileBadges(workspaceLabel: "2", onFocusedWorkspace: false, floating: true, minimized: true)
        for (presentation, size, badges, hint) in [
            ("list", CGSize(width: list.width - 40 * metrics.scale, height: list.rowHeight), TileBadges(workspaceLabel: nil, onFocusedWorkspace: true), nil),
            ("strip", CGSize(width: metrics.textWidth, height: metrics.textHeight), TileBadges(workspaceLabel: nil, onFocusedWorkspace: true), nil),
            ("crowded strip", CGSize(width: metrics.textWidth, height: metrics.textHeight), crowded, "⌥3"),
        ] as [(String, CGSize, TileBadges, String?)] {
            let entry = TileEntry(title: "A controlled window title", appName: longName, badges: badges)
            let image = try render(entry: entry, kind: .text, presentation: presentation == "list" ? "list" : "strip", size: size, metrics: metrics, hint: hint, margin: 40)
            let ink = try alphaMask(image)
            var outsideInk = 0
            var insideInk = 0
            for y in 0..<image.height {
                for x in 0..<image.width where ink[y * image.width + x] {
                    if x < 40 || x >= 40 + Int(size.width) || y < 40 || y >= 40 + Int(size.height) { outsideInk += 1 }
                    else { insideInk += 1 }
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
        // Identical up to their last word, so no wider bar can tell them apart by a prefix.
        let titles = [
            "prateek/winmux pull request 201: a controlled long title for the tile comparison — alpha",
            "prateek/winmux pull request 201: a controlled long title for the tile comparison — omega",
        ]
        XCTAssertTrue(titles.allSatisfy { (80...95).contains($0.count) })
        var bars: [[Bool]] = []
        for title in titles {
            let image = try render(entry: TileEntry(title: title, appName: "Demo"), kind: .card, presentation: "grid", size: size, metrics: metrics)
            let bar = try XCTUnwrap(image.cropping(to: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: ceil(metrics.padding + metrics.barHeight))))
            bars.append(try alphaMask(bar))
        }
        XCTAssertTrue(bars[0] != bars[1], "Card bars must retain the distinguishing title suffix")
    }

    func testSelectedPerAppCardTitleMatchesADoubleWidthCard() throws {
        let entry = TileEntry(title: "Calculator", appName: "Calculator", badges: TileBadges(workspaceLabel: "W3", onFocusedWorkspace: false), appCount: 1)
        let input = GridLayout.Entry(aspect: entry.aspect, realSize: entry.realSize, kind: .card, barWidth: entry.cardBarWidth(badges: true))
        let layout = GridLayout(sections: [.init(label: nil, current: false, entries: Array(repeating: input, count: 10))], visibleSize: screen, tileSize: "real", sizing: .strip)
        let size = try XCTUnwrap(layout.tiles.first).frame.size
        let metrics = TileMetrics(scale: layout.tileScale)
        let titleWidth = ceil((entry.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: metrics.titleFont, weight: .semibold)]).width)
        let region = CGRect(x: metrics.padding + metrics.icon + metrics.gap, y: metrics.padding, width: titleWidth, height: metrics.barHeight)
        var titles: [[UInt8]] = []
        for width in [size.width, 2 * size.width] {
            let tile = TileView(entry: entry, kind: .card, presentation: "strip", metrics: metrics, size: CGSize(width: width, height: size.height),
                                settings: LensConfig(), selected: true, marked: false, hint: nil, pictureSize: layout.tiles[0].pictureSize)
            // Undo selection enlargement so both renders use the same bar coordinates.
            let renderer = ImageRenderer(content: tile.scaleEffect(1 / metrics.selectionScale).environment(\.lensTheme, .light).background(Color.black))
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.cgImage)
            let crop = try XCTUnwrap(image.cropping(to: region))
            let context = try XCTUnwrap(CGContext(data: nil, width: crop.width, height: crop.height, bitsPerComponent: 8, bytesPerRow: 4 * crop.width,
                                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
            let bytes = try XCTUnwrap(context.data).bindMemory(to: UInt8.self, capacity: 4 * crop.width * crop.height)
            titles.append(Array(UnsafeBufferPointer(start: bytes, count: 4 * crop.width * crop.height)))
        }
        XCTAssertGreaterThan(stride(from: 0, to: titles[1].count, by: 4).filter { titles[1][$0] > 5 }.count, 100, "The reference must contain visible title ink")
        XCTAssertEqual(titles[0], titles[1], "The selected app name must draw whole at the strip's width")
    }

    /// Draws the image into a fresh RGBA buffer, so a cropped image is compared by its own pixels.
    private func alphaMask(_ image: CGImage) throws -> [Bool] {
        let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 4 * image.width,
                                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try XCTUnwrap(context.data).bindMemory(to: UInt8.self, capacity: 4 * image.width * image.height)
        return (0..<image.width * image.height).map { bytes[4 * $0 + 3] > 2 }
    }

    private func render(entry: TileEntry, kind: TileKind, presentation: String, size: CGSize, metrics: TileMetrics, hint: String? = nil, margin: CGFloat = 0) throws -> CGImage {
        let tile = TileView(entry: entry, kind: kind, presentation: presentation, metrics: metrics, size: size, settings: LensConfig(), selected: false, marked: hint != nil, hint: hint)
        let renderer = ImageRenderer(content: tile.padding(margin))
        renderer.scale = 1
        return try XCTUnwrap(renderer.cgImage)
    }
}
