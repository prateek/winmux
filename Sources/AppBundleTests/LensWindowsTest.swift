@testable import AppBundle
import XCTest
import Foundation

@MainActor
final class LensWindowsTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testAxReadsOverlapAndKeepCandidateOrderDespiteReverseCompletion() async throws {
        let ws = Workspace.get(byName: "1")
        let started = expectation(description: "all AX calls started before any completed")
        started.expectedFulfillmentCount = 3
        var pending: [UInt32: CheckedContinuation<Void, Never>] = [:]
        var released = false
        for id: UInt32 in [3, 1, 2] {
            let window = TestWindow.new(id: id, parent: ws.rootTilingContainer)
            window.beforeAxRecord = {
                started.fulfill()
                if !released {
                    await withCheckedContinuation { pending[id] = $0 }
                }
            }
        }
        let task = Task { try await lensWindows(popups: []).map { $0.record.id } }
        await fulfillment(of: [started], timeout: 1)
        released = true
        for id: UInt32 in [2, 1, 3] {
            pending.removeValue(forKey: id)?.resume()
            await Task.yield()
        }
        let entries = try await task.value
        XCTAssertEqual(entries, [3, 1, 2])
    }

    func testOneFailedAxRecordDoesNotLoseOtherCandidates() async throws {
        let ws = Workspace.get(byName: "1")
        _ = TestWindow.new(id: 1, parent: ws.rootTilingContainer)
        let broken = TestWindow.new(id: 2, parent: ws.rootTilingContainer)
        broken.testAxRecordError = NSError(domain: "AX", code: 1)
        _ = broken.focusWindow()
        _ = TestWindow.new(id: 3, parent: ws.rootTilingContainer)
        let entries = try await lensWindows(popups: [])
        XCTAssertEqual(entries.map { $0.record.id }, [1, 3])
        let command = try XCTUnwrap(parseCommand("list-windows --search TestWindow --count").cmdOrNil)
        let result = try await command.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, ["2"])
    }

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
