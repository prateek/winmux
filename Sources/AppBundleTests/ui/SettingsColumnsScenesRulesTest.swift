import AppKit
@testable import AppBundle
import Common
import XCTest

@MainActor
final class SettingsColumnsScenesRulesTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    // MARK: - Pane enum

    func testSettingsSidebarExposesColumnsScenesRulesPanes() {
        XCTAssertEqual(SettingsSidebarItem.columns.label, "Columns")
        XCTAssertEqual(SettingsSidebarItem.scenes.label, "Scenes")
        XCTAssertEqual(SettingsSidebarItem.rules.label, "Rules")
        // Each pane carries a distinct sidebar icon.
        let icons = [SettingsSidebarItem.columns, .scenes, .rules].map(\.icon)
        XCTAssertEqual(Set(icons).count, 3)
    }

    // MARK: - Columns pane

    func testColumnRowsReflectActiveSceneColumnsWithIdNameWidth() {
        let main = configureScenesFromToml(twoSceneToml)
        guard case .success = setActiveScene("desk", for: main) else {
            return XCTFail("Expected scene 'desk' to activate")
        }

        let rows = buildSettingsColumnRows()

        XCTAssertEqual(rows.map(\.columnId), ["ref", "main", "comms"])
        XCTAssertEqual(rows.map(\.name), ["Reference", "Work", "Comms"])
        XCTAssertEqual(rows.map(\.widthText), ["20%", "50%", "30%"])
        XCTAssertEqual(rows.map(\.sceneLabel), ["desk", "desk", "desk"])
        XCTAssertEqual(rows.map(\.isImplicit), [false, false, false])
        XCTAssertEqual(rows.singleOrNil { $0.columnId == "main" }?.isDefaultColumn, true)
        XCTAssertEqual(rows.singleOrNil { $0.columnId == "ref" }?.isDefaultColumn, false)
    }

    func testImplicitDisplayYieldsSingleFullWidthColumnRow() {
        let main = TestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
            isMain: true,
        )
        setMonitorsForTests([main])
        refreshColumnTopologySnapshot()

        let rows = buildSettingsColumnRows()

        XCTAssertEqual(rows.count, 1, "a display with no [scene.*] runs one implicit column")
        let row = rows.first.orDie()
        XCTAssertTrue(row.isImplicit)
        XCTAssertEqual(row.widthText, "100%")
        XCTAssertEqual(row.sceneLabel, settingsImplicitSceneLabel)
    }

    // MARK: - Scenes pane

    func testSceneRowsListDeclaredScenesAndMarkTheActiveOne() {
        let main = configureScenesFromToml(twoSceneToml)
        guard case .success = setActiveScene("desk", for: main) else {
            return XCTFail("Expected scene 'desk' to activate")
        }

        let rows = buildSettingsSceneRows()

        XCTAssertEqual(rows.map(\.sceneId), ["desk", "focus"])
        XCTAssertEqual(rows.singleOrNil { $0.sceneId == "desk" }?.isActive, true)
        XCTAssertEqual(rows.singleOrNil { $0.sceneId == "focus" }?.isActive, false)
        XCTAssertEqual(rows.singleOrNil { $0.sceneId == "desk" }?.columnCount, 3)
        XCTAssertEqual(rows.singleOrNil { $0.sceneId == "focus" }?.columnCount, 1)
    }

    func testImplicitDisplayContributesNoSceneRows() {
        let main = TestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
            isMain: true,
        )
        setMonitorsForTests([main])
        refreshColumnTopologySnapshot()

        XCTAssertTrue(buildSettingsSceneRows().isEmpty, "an implicit scene has no name to list")
    }

    // MARK: - Rules pane

    func testRuleRowsDescribeAppIdMatchAndTargetCard() {
        let rule = RuleConfig(
            matcher: WindowDetectedCallbackMatcher().copy(\.appId, "com.tinyspeck.slackmacgap"),
            card: "Chat",
            focus: true,
        )

        let rows = buildSettingsRuleRows(rules: [rule])

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.matchDescription, "app id is com.tinyspeck.slackmacgap")
        XCTAssertEqual(rows.first?.card, "Chat")
        XCTAssertEqual(rows.first?.focus, true)
    }

    func testRuleMatchDescriptionSummarizesRegexAndEmptyMatchers() throws {
        let regexMatcher = try WindowDetectedCallbackMatcher()
            .copy(\.windowTitleRegexSubstring, Regex("Inbox|Mail"))
        XCTAssertEqual(settingsRuleMatchDescription(regexMatcher), "window title matches a pattern")
        XCTAssertEqual(settingsRuleMatchDescription(WindowDetectedCallbackMatcher()), "Any window")
    }

    func testColumnWidthTextFormatsFractionAsPercent() {
        XCTAssertEqual(settingsColumnWidthText(0.55), "55%")
        XCTAssertEqual(settingsColumnWidthText(1.0), "100%")
        XCTAssertEqual(settingsColumnWidthText(0.2), "20%")
    }

    // MARK: - Expose overview vocabulary

    func testExposeOverviewTitleSpeaksColumnsAndWindows() {
        XCTAssertEqual(exposeOverviewTitle(for: .display), "Columns")
        XCTAssertEqual(exposeOverviewTitle(for: .card), "Windows")
    }
}
