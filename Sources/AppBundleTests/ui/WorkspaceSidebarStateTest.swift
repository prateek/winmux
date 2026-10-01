@testable import AppBundle
import Common
import Foundation
import XCTest

@MainActor
final class WorkspaceSidebarStateTest: XCTestCase {
    private var stateUrl: URL!

    override func setUp() async throws {
        stateUrl = FileManager.default.temporaryDirectory
            .appending(path: "WinMuxTests-\(UUID().uuidString)")
            .appending(path: "winmux/sidebar.json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: stateUrl.deletingLastPathComponent().deletingLastPathComponent())
    }

    func testMissingOrUnreadableFileMeansNoOverrides() throws {
        assertEquals(readWorkspaceSidebarState(from: stateUrl), WorkspaceSidebarState())

        try FileManager.default.createDirectory(at: stateUrl.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "not json".write(to: stateUrl, atomically: true, encoding: .utf8)

        assertEquals(readWorkspaceSidebarState(from: stateUrl), WorkspaceSidebarState())
    }

    func testChangesSurviveAReadBack() throws {
        try updateWorkspaceSidebarState(at: stateUrl) {
            $0.workspaceLabels["1"] = "Mail"
            $0.projectLabels["default"] = "Home"
            $0.projectColors["default"] = "#112233"
        }
        try updateWorkspaceSidebarState(at: stateUrl) { $0.workspaceLabels["2"] = "Code" }

        var expected = WorkspaceSidebarState()
        expected.workspaceLabels = ["1": "Mail", "2": "Code"]
        expected.projectLabels = ["default": "Home"]
        expected.projectColors = ["default": "#112233"]
        assertEquals(readWorkspaceSidebarState(from: stateUrl), expected)
    }

    func testStateOverridesWhatTheConfigDeclaresAndRemovingItRestoresTheConfigsValue() throws {
        var declared = WorkspaceSidebarConfig()
        declared.workspaceLabels = ["1": "One", "2": "Two"]
        declared.projectLabels = ["default": "Default"]
        declared.projectColors = ["default": "#C4B5FD"]
        try updateWorkspaceSidebarState(at: stateUrl) {
            $0.workspaceLabels["1"] = "Mail"
            $0.projectColors["default"] = "#112233"
        }

        var overridden = declared
        overridden.apply(readWorkspaceSidebarState(from: stateUrl))
        try updateWorkspaceSidebarState(at: stateUrl) { $0.workspaceLabels["1"] = nil }
        var afterReset = declared
        afterReset.apply(readWorkspaceSidebarState(from: stateUrl))

        assertEquals(overridden.workspaceLabels, ["1": "Mail", "2": "Two"])
        assertEquals(overridden.projectLabels, ["default": "Default"])
        assertEquals(overridden.projectColors, ["default": "#112233"])
        assertEquals(afterReset.workspaceLabels, ["1": "One", "2": "Two"])
    }
}
