@testable import AppBundle
import XCTest

@MainActor
final class LensWindowsTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testCandidatesIncludeMinimizedAndExcludeUnlistedPopups() async throws {
        let ws = Workspace.get(byName: "1")
        _ = TestWindow.new(id: 3, parent: ws.rootTilingContainer)
        _ = TestWindow.new(id: 2, parent: macosMinimizedWindowsContainer)
        _ = TestWindow.new(id: 1, parent: macosPopupWindowsContainer)
        let entries = try await lensWindows(popups: [])
        XCTAssertEqual(Set(entries.map { $0.record.id }), [2, 3])
        let withPopups = try await lensWindows(popups: ["app-popup"])
        XCTAssertEqual(Set(withPopups.map { $0.record.id }), [1, 2, 3])
        let accessoryOnly = try await lensWindows(popups: ["accessory-popup"])
        XCTAssertEqual(Set(accessoryOnly.map { $0.record.id }), [2, 3])
    }

    func testCreatedSortAndTitleTieBreakAndSearchClearing() async throws {
        let ws = Workspace.get(byName: "1")
        _ = TestWindow.new(id: 3, parent: ws.rootTilingContainer)
        _ = TestWindow.new(id: 1, parent: ws.rootTilingContainer)
        _ = TestWindow.new(id: 2, parent: ws.rootTilingContainer)
        let entries = try await lensWindows(popups: [])
        XCTAssertEqual(sortLensWindows(entries, by: ["created"], previousId: nil).map { $0.record.id }, [1, 2, 3])
        XCTAssertEqual(sortLensWindows(entries, by: ["previous", "created"], previousId: 3).map { $0.record.id }, [3, 1, 2])
    }
}

@MainActor
final class LensSortAndNamesTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSortKeysApplyInOrderWithCreationOrderAsFinalTieBreak() async throws {
        let ws = Workspace.get(byName: "1")
        let window = TestWindow.new(id: 1, parent: ws.rootTilingContainer)
        let record = try await window.windowRecord()
        let base = try XCTUnwrap(record)
        let entries = [(1, "Zulu", "Alpha", 2, 2, 1), (2, "Alpha", "Zulu", 5, 0, 0), (3, "Alpha", "Alpha", 5, 1, 0)].map { id, title, app, seq, spatial, workspace in
            var record = base
            record.id = id; record.title = title; record.app.name = app; record.lastFocusedSeq = seq
            return LensWindow(record: record, window: window, spatialIndex: spatial, workspaceIndex: workspace)
        }
        for (keys, expected) in [(["mru"], [2, 3, 1]), (["spatial"], [2, 3, 1]), (["workspace", "title"], [2, 3, 1]),
                                 (["app", "title"], [3, 1, 2]), (["title", "created"], [2, 3, 1])] {
            XCTAssertEqual(sortLensWindows(entries, by: keys, previousId: nil).map { $0.record.id }, expected)
        }
        XCTAssertTrue(lensIncludes(.accessoryPopup, popups: ["accessory-popup"]))
        XCTAssertFalse(lensIncludes(.appPopup, popups: ["accessory-popup"]))
    }

    func testSearchUsesWorkspaceAndProjectNamesShownToTheUser() async throws {
        let ws = Workspace.get(byName: "1")
        _ = TestWindow.new(id: 1, parent: ws.rootTilingContainer)
        try renameWorkspaceForSidebar(workspaceName: "1", displayName: "Release")
        try renameWorkspaceProject(ws.projectId, displayName: "Research")
        let entries = try await lensWindows(popups: [])
        XCTAssertEqual(searchLensWindows(entries, search: "release research").map { $0.record.id }, [1])
    }
}
