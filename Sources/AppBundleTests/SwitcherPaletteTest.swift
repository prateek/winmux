@testable import AppBundle
import XCTest

final class SwitcherPaletteTest: XCTestCase {
    private func item(_ id: UInt32, app: String, title: String, workspace: String = "1") -> SwitcherPaletteItem {
        SwitcherPaletteItem(id: id, title: title, appName: app, icon: nil, workspaceName: workspace, isFocused: false)
    }

    func testSearchWordsCanMatchFieldsInAnyOrder() {
        let items = [item(1, app: "Visual Studio Code", title: "Release Notes", workspace: "docs")]
        XCTAssertEqual(filterSwitcherPaletteItems(items, query: "notes visual").map(\.id), [1])
        XCTAssertEqual(filterSwitcherPaletteItems(items, query: "vsc").map(\.id), [1])
        XCTAssertEqual(filterSwitcherPaletteItems(items, query: "visual absent").map(\.id), [])
    }

    func testTitleMatchesOutrankWorkspaceMatchesAndTiesKeepSort() {
        let items = [item(1, app: "Mail", title: "Inbox", workspace: "notes"),
                     item(2, app: "Editor", title: "notes"), item(3, app: "Editor", title: "notes")]
        XCTAssertEqual(filterSwitcherPaletteItems(items, query: "notes").map(\.id), [2, 3, 1])
    }

    func testEmptyQueryKeepsOriginalOrder() {
        let items = [item(1, app: "Safari", title: "Docs"), item(2, app: "Ghostty", title: "zsh")]
        XCTAssertEqual(filterSwitcherPaletteItems(items, query: "  ").map(\.id), [1, 2])
    }

    func testNonMatchingItemsAreDropped() {
        let items = [item(1, app: "Safari", title: "Docs"), item(2, app: "Ghostty", title: "zsh")]
        XCTAssertEqual(filterSwitcherPaletteItems(items, query: "ghos").map(\.id), [2])
    }

    func testWordStartAndConsecutiveMatchesRankAboveScattered() {
        let items = [
            item(1, app: "Calendar", title: "June"), // scattered "cal" not at word start? it is prefix
            item(2, app: "Books", title: "local archive"), // "cal" inside "local"
        ]
        XCTAssertEqual(filterSwitcherPaletteItems(items, query: "cal").first?.id, 1)
    }

    func testSubsequenceMatchesAcrossFields() {
        let items = [item(7, app: "Zed", title: "refresh.swift", workspace: "code")]
        XCTAssertEqual(filterSwitcherPaletteItems(items, query: "zed refresh").map(\.id), [7])
        XCTAssertEqual(filterSwitcherPaletteItems(items, query: "xyzzy").map(\.id), [])
    }

    func testFuzzyScoreRejectsNonSubsequence() {
        XCTAssertNil(lensSearchTier("ba", in: "ab"))
        XCTAssertNotNil(lensSearchTier("ab", in: "a-b"))
    }

    func testFinderFolderTitleIsSearchable() {
        let items = [item(8, app: "Finder", title: "Quarterly Planning")]
        XCTAssertEqual(filterSwitcherPaletteItems(items, query: "quarterly").map(\.id), [8])
    }

    @MainActor
    func testColdLensCandidateIncludesWindowTitleBeforeSearch() async throws {
        setUpWorkspacesForTests()
        resetCachedWindowTitles()
        let workspace = Workspace.get(byName: "finder-palette-test")
        let window = TestWindow.new(id: 88, parent: workspace.rootTilingContainer)

        window.testAxRecordAttributes = WindowAxRecordAttributes(title: "Quarterly Planning", subrole: "AXStandardWindow", hasCloseButton: true, document: "")
        let entries = try await lensWindows(popups: [])
        XCTAssertEqual(entries.first?.record.title, "Quarterly Planning")
        XCTAssertEqual(searchLensWindows(entries, search: "quarterly").map { $0.record.id }, [88])
    }
}

final class LensSearchTierTest: XCTestCase {
    func testEveryTier() {
        for (text, word, tier) in [("notes", "notes", 6), ("notes today", "notes", 5),
                                   ("release notes", "notes", 4), ("footnotes", "notes", 3),
                                   ("Visual Studio Code", "vsc", 2), ("abcdef", "ace", 1)] {
            XCTAssertEqual(lensSearchTier(word, in: text), tier)
        }
        XCTAssertNil(lensSearchTier("ba", in: "ab"))
    }

    func testProjectFieldAndWeights() {
        XCTAssertEqual(LensSearchFields(title: "", app: "", workspace: "", project: "Release").match("release")?.score, 6)
        XCTAssertEqual(LensSearchFields(title: "Release", app: "", workspace: "", project: "").match("release")?.score, 12)
    }
}
