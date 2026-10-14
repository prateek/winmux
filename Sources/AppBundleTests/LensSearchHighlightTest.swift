@testable import AppBundle
import XCTest
import SwiftUI
import AppKit

private final class LensRecordAxElement: AxUiElementMock {
    var values: [String: Any] = [:]
    func get<Attr: ReadableAttr>(_ attr: Attr) -> Attr.T? { values[attr.key] as? Attr.T }
    func containingWindowId() -> CGWindowID? { 1 }
}

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
        ordinary.testAxRecordAttributes = WindowAxRecordAttributes(title: "Demo", subrole: "AXStandardWindow", hasCloseButton: true, document: "",
                                                                  buttons: TileControlAvailability(close: false, minimize: true, fullscreen: true))
        let minimized = TestWindow.new(id: 92, parent: macosMinimizedWindowsContainer)
        minimized.testAxRecordAttributes = WindowAxRecordAttributes(title: "Minimized", subrole: "AXStandardWindow", hasCloseButton: true, document: "", buttons: .all)
        let fullscreen = TestWindow.new(id: 93, parent: workspace.macOsNativeFullscreenWindowsContainer)
        fullscreen.nativeIsMacosFullscreen = true
        fullscreen.testAxRecordAttributes = WindowAxRecordAttributes(title: "Fullscreen", subrole: "AXStandardWindow", hasCloseButton: true, document: "", buttons: .all)
        var reads = 0
        ordinary.beforeAxRecord = { reads += 1 }
        let entries = try await lensWindows(popups: [])
        XCTAssertEqual(reads, 1)
        XCTAssertEqual(entries.first { $0.record.id == 91 }?.controls, TileControlAvailability(close: false, minimize: true, fullscreen: true))
        XCTAssertEqual(entries.first { $0.record.id == 92 }?.controls, TileControlAvailability(close: true, minimize: false, fullscreen: true))
        XCTAssertEqual(entries.first { $0.record.id == 93 }?.controls, TileControlAvailability(close: true, minimize: false, fullscreen: true))
        // Anything else that reads a record skips the button reads.
        let plain = try await ordinary.readAxRecordAttributes(buttons: false)
        XCTAssertNil(plain?.buttons)
    }

    func testControlsOnlyActOnTheirOwnWindowInEveryClass() {
        let expected: [WindowClass: TileControlAvailability] = [
            .tiled: .all, .floating: .all, .appPopup: .all, .accessoryPopup: .all,
            .fullscreen: TileControlAvailability(close: true, minimize: false, fullscreen: true),
            .minimized: TileControlAvailability(close: true, minimize: false, fullscreen: true),
            .hiddenApp: TileControlAvailability(close: true, minimize: false, fullscreen: false),
        ]
        for (windowClass, controls) in expected {
            XCTAssertEqual(TileControlAvailability(buttons: .all, windowClass: windowClass), controls, "\(windowClass)")
            XCTAssertEqual(TileControlAvailability(buttons: nil, windowClass: windowClass), TileControlAvailability())
        }
    }

    func testAXButtonReadNeedsAnEnabledButtonAndAFullScreenGreenButton() {
        func read(fullscreen: Bool? = nil, zoom: String? = nil, minimizeEnabled: Bool = true, closeEnabled: Bool = true, buttons: Bool = true) -> WindowAxRecordAttributes {
            let window = LensRecordAxElement()
            func button(_ enabled: Bool, subrole: String? = nil) -> LensRecordAxElement {
                let button = LensRecordAxElement()
                button.values[Ax.enabledAttr.key] = enabled
                if let subrole { button.values[Ax.subroleAttr.key] = subrole }
                return button
            }
            window.values[Ax.titleAttr.key] = "Title"
            window.values[Ax.closeButtonAttr.key] = button(closeEnabled)
            window.values[Ax.minimizeButtonAttr.key] = button(minimizeEnabled)
            if let fullscreen { window.values[Ax.fullscreenButtonAttr.key] = button(fullscreen) }
            if let zoom { window.values[Ax.zoomButtonAttr.key] = button(true, subrole: zoom) }
            return WindowAxRecordAttributes.read(from: window, buttons: buttons)
        }
        XCTAssertEqual(read(fullscreen: true).buttons, .all)
        XCTAssertEqual(read(zoom: "AXFullScreenButton").buttons, .all)
        XCTAssertEqual(read(zoom: "AXZoomButton").buttons?.fullscreen, false)
        XCTAssertEqual(read().buttons?.fullscreen, false)
        XCTAssertEqual(read(fullscreen: false, zoom: "AXFullScreenButton").buttons?.fullscreen, false)
        // A window in native fullscreen keeps a disabled minimize button.
        XCTAssertEqual(read(fullscreen: true, minimizeEnabled: false).buttons?.minimize, false)
        XCTAssertEqual(read(fullscreen: true, closeEnabled: false).buttons?.close, false)
        let plain = read(fullscreen: true, buttons: false)
        XCTAssertEqual(plain.title, "Title")
        XCTAssertTrue(plain.hasCloseButton)
        XCTAssertNil(plain.buttons)
    }

    private func substrings(_ text: String, _ ranges: [Range<Int>]) -> [String] {
        let characters = Array(text)
        return ranges.map { String(characters[$0]) }
    }
}
