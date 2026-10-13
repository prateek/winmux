@testable import AppBundle
import Common
import XCTest

@MainActor
final class WindowModeBindingTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        activeMode = mainModeId
    }

    func testExistingMainDispatchUnknownModeAndUnboundChord() async throws {
        let modes = defaultConfig.modes
        let main = try XCTUnwrap(activeHotkeyBinding("alt-l", mode: "main", modes: modes))
        XCTAssertTrue(main.commands.singleOrNil()!.equals(parseCommand("focus right").cmdOrDie))
        XCTAssertNil(activeHotkeyBinding("x", mode: "main", modes: modes))
        XCTAssertNil(activeHotkeyBinding("alt-l", mode: "absent", modes: modes))
        let result = try await parseCommand("mode absent").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(activeMode, "absent")
    }

    func testLoadedDefaultsSequenceStaysOnThroughMovementFailureAndWorkspaceChange() async throws {
        let supervisor = NickelSupervisor()
        let loaded = try await supervisor.load(nil).get()
        defer { supervisor.discard(loaded) }
        let parsed = parseConfig(loaded.settings)
        XCTAssertTrue(parsed.errors.isEmpty)
        let modes = parsed.config.modes
        // Dispatch uses loaded bindings; mode activation itself must not register desktop keys.
        config.modes = ["main": .zero, "window": .zero]
        TrayMenuModel.shared.isEnabled = true
        let ws = Workspace.get(byName: "1")
        ws.markAsAutomaticallyNamed()
        let root = ws.rootTilingContainer
        let first = TestWindow.new(id: 1, parent: root)
        TestWindow.new(id: 2, parent: root)
        let third = TestWindow.new(id: 3, parent: root)
        XCTAssertTrue(first.focusWindow())
        try await press("alt-semicolon", modes: modes)
        XCTAssertEqual(activeMode, "window")
        try await press("l", modes: modes)
        XCTAssertEqual(focus.windowOrNil?.windowId, 2)
        XCTAssertEqual(activeMode, "window")
        try await press("l", modes: modes)
        XCTAssertEqual(focus.windowOrNil?.windowId, 3)
        XCTAssertEqual(activeMode, "window")
        try await press("l", modes: modes)
        XCTAssertEqual(focus.windowOrNil?.windowId, 3, "the default edge action stops successfully")
        XCTAssertEqual(activeMode, "window")
        let before = root.layoutDescription
        try await press("shift-j", modes: modes)
        XCTAssertNotEqual(root.layoutDescription, before)
        XCTAssertTrue(focus.windowOrNil === third)
        XCTAssertEqual(activeMode, "window")
        for (name, id) in [("2", 4), ("3", 5)] {
            let workspace = Workspace.get(byName: name)
            workspace.markAsAutomaticallyNamed()
            TestWindow.new(id: UInt32(id), parent: workspace.rootTilingContainer)
        }
        Workspace.reconcileWorkspaceState()
        try await press("3", modes: modes)
        XCTAssertEqual(focus.workspace.name, "3")
        XCTAssertEqual(activeMode, "window")
        focus.windowOrNil!.bindAsFloatingWindow(to: focus.workspace)
        let failed = try await activeHotkeyBinding("shift-j", mode: activeMode, modes: modes)!.commands.runCmdSeq(.defaultEnv, .emptyStdin)
        XCTAssertEqual(failed.exitCode, 1, "moving a floating window is rejected")
        XCTAssertEqual(activeMode, "window")
        XCTAssertNil(activeHotkeyBinding("alt-slash", mode: activeMode, modes: modes))
        XCTAssertNil(activeHotkeyBinding("x", mode: activeMode, modes: modes))
        try await press("esc", modes: modes)
        XCTAssertEqual(activeMode, "main")
        try await press("alt-semicolon", modes: modes)
        try await press("alt-semicolon", modes: modes)
        XCTAssertEqual(activeMode, "main", "the same registered chord must resolve this mode's command")
        try await press("alt-semicolon", modes: modes)
        var disabled = LensConfig(); disabled.enabled = false
        config.lenses = ["overview": disabled]
        _ = try await activeHotkeyBinding("o", mode: activeMode, modes: modes)!.commands.runCmdSeq(.defaultEnv, .emptyStdin)
        XCTAssertEqual(activeMode, "main")
    }

    private func press(_ chord: String, modes: [String: Mode]) async throws {
        let binding = try XCTUnwrap(activeHotkeyBinding(chord, mode: activeMode, modes: modes))
        let result = try await binding.commands.runCmdSeq(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0, chord)
    }
}
