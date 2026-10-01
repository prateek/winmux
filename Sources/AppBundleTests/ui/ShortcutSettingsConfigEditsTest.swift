@testable import AppBundle
import XCTest

final class ShortcutSettingsConfigEditsTest: XCTestCase {
    func testInferWorkspaceShortcutStatePrefersPatternAndExtractsOverrides() {
        let state = inferWorkspaceShortcutState(
            from: [
                "alt-1": "workspace 1",
                "alt-2": "workspace 2",
                "cmd-3": "workspace 3",
                "alt-shift-1": "move-node-to-workspace 1",
                "alt-shift-2": "move-node-to-workspace 2",
                "cmd-shift-3": "move-node-to-workspace 3",
            ],
            workspaceNumbers: ["1", "2", "3"]
        )

        XCTAssertEqual(state.switchModifiers, [.option])
        XCTAssertEqual(state.moveModifiers, [.option, .shift])
        XCTAssertEqual(state.switchOverrides, ["3": "cmd-3"])
        XCTAssertEqual(state.moveOverrides, ["3": "cmd-shift-3"])
    }
}
