@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor
final class BindingModeHudTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testVisibilityDecisionForMainDisabledAndUserModes() {
        for mode in [nil, "main", "window", "custom", "lens"] {
            XCTAssertNil(bindingModeHudText(mode: mode, enabled: false))
            XCTAssertEqual(bindingModeHudText(mode: mode, enabled: true), mode == "main" ? nil : mode)
        }
    }

    func testMainAndDisabledPathsDoNotShowAPanel() async throws {
        var shown: [String] = []
        var hides = 0
        BindingModeHud.shared = BindingModeHud(show: { text, _ in shown.append(text) }, hide: { hides += 1 })
        TrayMenuModel.shared.isEnabled = true
        try await activateMode("main")
        _ = try await parseCommand("enable off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertTrue(shown.isEmpty)
        XCTAssertEqual(hides, 0, "a HUD that was never shown has no panel to hide")
        XCTAssertNil(activeMode)
        TrayMenuModel.shared.isEnabled = true
    }

    func testCliReloadKeptAndDroppedModesAndDisableUpdateHud() async throws {
        var shown: [String] = []
        var hides = 0
        BindingModeHud.shared = BindingModeHud(show: { text, _ in shown.append(text) }, hide: { hides += 1 })
        TrayMenuModel.shared.isEnabled = true
        config.modes = ["main": .zero, "window": .zero, "custom": .zero]
        _ = try await parseCommand("mode window").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(shown.last, "window")
        try await activateMode(config.modeToKeep(activeMode))
        XCTAssertEqual(shown, ["window"], "a reload that keeps the mode leaves the HUD as it is")
        config.modes.removeValue(forKey: "window")
        try await activateMode(config.modeToKeep(activeMode))
        XCTAssertEqual(activeMode, "main")
        XCTAssertEqual(hides, 1)
        _ = try await parseCommand("mode custom").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(shown.last, "custom")
        _ = try await parseCommand("enable off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(hides, 2)
        TrayMenuModel.shared.isEnabled = true
    }

    func testUnchangedRefreshDoesNothingAndAHiddenHudNeverAsksForTheMonitor() {
        var shows = 0
        var hides = 0
        var frameReads = 0
        let hud = BindingModeHud(show: { _, _ in shows += 1 }, hide: { hides += 1 })
        let frame = NSRect(x: 0, y: 0, width: 1280, height: 720)
        for mode in ["main", nil] {
            hud.refresh(mode: mode, enabled: true) { frameReads += 1; return frame }
        }
        hud.refresh(mode: "window", enabled: false) { frameReads += 1; return frame }
        XCTAssertEqual([shows, hides, frameReads], [0, 0, 0])
        for _ in 1...3 { hud.refresh(mode: "window", enabled: true) { frame } }
        XCTAssertEqual(shows, 1, "a layout refresh that changes nothing must not order the panel front again")
        hud.refresh(mode: "custom", enabled: true) { frame }
        XCTAssertEqual(shows, 2)
        for _ in 1...2 { hud.refresh(mode: "main", enabled: true) { frame } }
        XCTAssertEqual(hides, 1)
    }

    func testHudFollowsFocusedMonitorAndIgnoresMouseAndKeyFocus() {
        var frames: [NSRect] = []
        let hud = BindingModeHud(show: { _, frame in frames.append(frame) }, hide: {})
        let first = NSRect(x: 0, y: 0, width: 1280, height: 720)
        let second = NSRect(x: 1280, y: 40, width: 1920, height: 1080)
        hud.refresh(mode: "window", enabled: true) { first }
        hud.refresh(mode: "window", enabled: true) { second }
        XCTAssertEqual(frames, [first, second])
        let panel = BindingModeHudPanel()
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertTrue(panel.ignoresMouseEvents)
        panel.show("window", visibleFrame: second)
        XCTAssertEqual(panel.frame.midX, second.midX, accuracy: 0.5)
        XCTAssertEqual(panel.frame.minY, second.minY + 20, accuracy: 0.5)
        panel.orderOut(nil)
    }
}
