@testable import AppBundle
import AppKit
import SwiftUI
import XCTest

@MainActor
final class LensThemeTest: XCTestCase {
    func testAutoSnapshotsSystemAtOpeningAndExplicitAppearanceDoesNotReadIt() {
        var dark = false
        var reads = 0
        let read = { reads += 1; return dark }
        let light = LensSession(name: "theme", settings: LensConfig(), items: [], search: "", systemIsDark: read)
        XCTAssertEqual(light.theme, .light)
        dark = true
        XCTAssertEqual(light.theme, .light)
        let next = LensSession(name: "theme", settings: LensConfig(), items: [], search: "", systemIsDark: read)
        XCTAssertEqual(next.theme, .dark)
        XCTAssertEqual(reads, 2)
        for appearance in ["dark", "light"] {
            var settings = LensConfig(); settings.appearance = appearance
            let session = LensSession(name: "theme", settings: settings, items: [], search: "", systemIsDark: read)
            XCTAssertEqual(session.theme.isDark, appearance == "dark")
        }
        XCTAssertEqual(reads, 2)
    }

    func testLightTokensMatchPrototypeAndPanelAppearance() {
        let theme = LensTheme.light
        XCTAssertEqual(theme.text.chromeHex, "#16181D")
        XCTAssertEqual(theme.searchText.chromeHex, "#16181D")
        XCTAssertEqual(theme.selectionRing, .accentColor)
        XCTAssertEqual(LensTheme.dark.selectionRing, .accentColor)
        XCTAssertEqual(theme.miniatureScrim.chromeHex, "#E8EAF0")
        XCTAssertEqual(theme.nsAppearance.name, .aqua)
        XCTAssertEqual(LensTheme.dark.nsAppearance.name, .darkAqua)
        XCTAssertEqual(theme.panelFill.chromeHex, "#ECEEF3")
        XCTAssertEqual(NSColor(theme.panelFill).alphaComponent, 0.74, accuracy: 0.001)
        XCTAssertEqual(NSColor(theme.panelLine).alphaComponent, 0.12, accuracy: 0.001)
        XCTAssertEqual(NSColor(theme.secondaryText).alphaComponent, 0.55, accuracy: 0.001)
        XCTAssertEqual(NSColor(theme.selectionPlate).alphaComponent, 0.2, accuracy: 0.001)
        XCTAssertEqual(NSColor(theme.chip).alphaComponent, 0.1, accuracy: 0.001)
        XCTAssertEqual(NSColor(LensTheme.dark.secondaryText).alphaComponent, 0.62, accuracy: 0.001)
        XCTAssertEqual(NSColor(LensTheme.dark.chip).alphaComponent, 0.16, accuracy: 0.001)
        XCTAssertEqual(theme.colorScheme, .light)
        XCTAssertEqual(LensTheme.dark.colorScheme, .dark)
    }
    func testLightKeepsDarkEmphasisSteps() {
        let light = LensTheme.light
        XCTAssertEqual(NSColor(light.ink(0.62)).alphaComponent, 0.55, accuracy: 0.001)
        XCTAssertLessThan(NSColor(light.ink(0.45)).alphaComponent, NSColor(light.ink(0.62)).alphaComponent)
        XCTAssertEqual(NSColor(light.fill(0.16)).alphaComponent, 0.1, accuracy: 0.001)
        XCTAssertLessThan(NSColor(light.fill(0.035)).alphaComponent, NSColor(light.fill(0.16)).alphaComponent)
        XCTAssertEqual(NSColor(light.line(0.3)).alphaComponent, 0.12, accuracy: 0.001)
        XCTAssertLessThan(NSColor(light.line(0.07)).alphaComponent, NSColor(light.line(0.3)).alphaComponent)
    }

    func testPanelSetsNativeAppearanceForEachOpening() async {
        let panel = SwitcherPalettePanel.shared
        defer { panel.dismiss() }
        for appearance in ["light", "dark", "light"] {
            var settings = LensConfig(); settings.appearance = appearance
            let ticket = panel.beginLens("theme", toggle: false)!
            await panel.openLens(name: "theme", settings: settings, entries: [], search: "", banner: nil, context: .null, ticket: ticket)
            XCTAssertEqual(panel.appearance?.name, appearance == "dark" ? .darkAqua : .aqua)
            XCTAssertEqual(panel.session?.theme.isDark, appearance == "dark")
            panel.dismiss()
        }
    }

}
