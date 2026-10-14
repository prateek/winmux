@testable import AppBundle
import XCTest
import SwiftUI

@MainActor
final class LensSearchHighlightTest: XCTestCase {
    func testSessionHighlightsAppliedExplicitAndRecalledSearchButNeverInlineSearch() {
        let item = SwitcherPaletteItem(id: 1, title: "Quarterly report", appName: "Safari", icon: nil, workspaceName: "Work", isFocused: false,
                                      tile: TileEntry(title: "Quarterly report", appName: "Safari"))
        for presentation in ["list", "strip", "grid"] {
            var settings = LensConfig(); settings.presentation = presentation; settings.startsIn = "normal"
            let explicit = LensSession(name: "explicit", settings: settings, items: [item], search: "rep saf", searchIsExplicit: true)
            XCTAssertEqual(explicit.query, "rep saf")
            XCTAssertEqual(substrings(item.title, explicit.results[0].tile.titleRanges), ["rep"])
            XCTAssertEqual(substrings(item.appName, explicit.results[0].tile.appRanges), ["Saf"])
            explicit.send(.searchChanged("= true"))
            XCTAssertEqual(explicit.results[0].tile.titleRanges, [])
            XCTAssertEqual(explicit.results[0].tile.appRanges, [])
            let recalled = LensSession(name: "recall", settings: settings, items: [item], search: "rep saf")
            XCTAssertEqual(recalled.results[0].tile.titleRanges, [])
            recalled.enterSearch()
            XCTAssertEqual(substrings(item.title, recalled.results[0].tile.titleRanges), ["rep"])
        }
        let fallback = TileEntry(title: "", appName: "Safari", appRanges: [0..<3])
        XCTAssertEqual(substrings(fallback.displayTitle, fallback.displayTitleRanges), ["Saf"])
        let attributed = lensHighlightedText("Safari", ranges: [0..<3])
        XCTAssertEqual(attributed.runs.first?.foregroundColor, Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255))
        XCTAssertEqual(attributed.runs.first?.backgroundColor, Color(red: 1, green: 213 / 255, blue: 74 / 255))
    }

    func testLensReadsControlAvailabilityBesideFilterRecordsAndHidesMinimizedControl() async throws {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        let ordinary = TestWindow.new(id: 91, parent: workspace.rootTilingContainer)
        ordinary.testAxRecordAttributes = WindowAxRecordAttributes(title: "Demo", subrole: "AXStandardWindow", hasCloseButton: false, document: "",
                                                                  hasMinimizeButton: true, hasFullscreenButton: true)
        let minimized = TestWindow.new(id: 92, parent: macosMinimizedWindowsContainer)
        minimized.testAxRecordAttributes = WindowAxRecordAttributes(title: "Minimized", subrole: "AXStandardWindow", hasCloseButton: true, document: "",
                                                                   hasMinimizeButton: true, hasFullscreenButton: true)
        let fullscreen = TestWindow.new(id: 93, parent: workspace.macOsNativeFullscreenWindowsContainer)
        fullscreen.nativeIsMacosFullscreen = true
        fullscreen.testAxRecordAttributes = WindowAxRecordAttributes(title: "Fullscreen", subrole: "AXStandardWindow", hasCloseButton: true, document: "",
                                                                    hasMinimizeButton: true, hasFullscreenButton: true)
        var reads = 0
        ordinary.beforeAxRecord = { reads += 1 }
        let entries = try await lensWindows(popups: [])
        XCTAssertEqual(reads, 1)
        XCTAssertEqual(entries.first { $0.record.id == 93 }?.controls.fullscreen, true)
        XCTAssertEqual(entries.first { $0.record.id == 91 }?.controls, TileControlAvailability(close: false, minimize: true, fullscreen: true))
        XCTAssertEqual(entries.first { $0.record.id == 92 }?.controls, TileControlAvailability(close: true, minimize: false, fullscreen: true))
    }

    private func substrings(_ text: String, _ ranges: [Range<Int>]) -> [String] {
        let characters = Array(text)
        return ranges.map { String(characters[$0]) }
    }
}
