@testable import AppBundle
import AppKit
import Clocks
import XCTest

@MainActor
final class SectionSessionTest: SerialClockTestCase {
    override func setUp() async throws { setUpWorkspacesForTests(); enterModeForTests("browse") }
    private func items() -> [SwitcherPaletteItem] {
        [SwitcherPaletteItem(id: 1, title: "Focused", appName: "Editor", icon: nil, workspaceName: "1", appIdentity: "editor", isFocused: true),
         SwitcherPaletteItem(id: 2, title: "needle", appName: "Mail", icon: nil, workspaceName: "2", appIdentity: "mail", isFocused: false),
         SwitcherPaletteItem(id: 3, title: "weak needle match", appName: "Editor", icon: nil, workspaceName: "1", appIdentity: "editor", isFocused: false)]
    }
    func testOpeningAndSearchSelectUngroupedBestRegardlessOfSection() {
        let model = LensSession(name: "recent", settings: LensConfig(), items: items(), search: "")
        XCTAssertEqual(model.results.map(\.id), [1, 3, 2])
        XCTAssertEqual(model.selectedId, 2)
        model.send(.searchChanged("needle"))
        XCTAssertEqual(model.results.map(\.id), [3, 2])
        XCTAssertEqual(model.selectedId, 2)
        XCTAssertEqual(model.targets(for: "enter"), [2])
    }
    func testAWindowClosingElsewhereLeavesTheSelectionOnItsWindowWhileSearching() {
        let model = LensSession(name: "recent", settings: LensConfig(), items: items(), search: "needle")
        model.hover(3)
        model.removeStripItems([1])
        XCTAssertEqual(model.selectedId, 3)
        model.removeStripItems([99])
        XCTAssertEqual(model.selectedId, 3)
        model.removeStripItems([3])
        XCTAssertEqual(model.selectedId, 2)
    }
    func testAnInlineResultKeepsTheSelectionOnItsWindow() {
        enterModeForTests("search")
        let model = LensSession(name: "recent", settings: LensConfig(), items: items(), search: "= true")
        XCTAssertEqual(model.selectedId, 2)
        model.acceptInlineResult([1, 2, 3])
        XCTAssertEqual(model.selectedId, 2)
        model.hover(3)
        model.acceptInlineResult([1, 3])
        XCTAssertEqual(model.selectedId, 3)
        model.acceptInlineResult([1])
        XCTAssertEqual(model.selectedId, 1)
    }
    func testAppSectionsJoinProcessesThatAppEntriesKeepApart() {
        var settings = LensConfig(); settings.entries = "app"; settings.sections = "app"
        let instances = (1...2).map {
            SwitcherPaletteItem(id: UInt32($0), title: "Profile \($0)", appName: "Browser", icon: nil, workspaceName: "1", appIdentity: String($0), appSection: "org.browser", isFocused: false)
        }
        let model = LensSession(name: "apps", settings: settings, items: instances, search: "")
        XCTAssertEqual(model.results.map(\.id), [1, 2])
        XCTAssertEqual(model.sections.map { $0.entries.map(\.id) }, [[1, 2]])
    }
    func testAListKeepsItsWidthWhenAGroupingOutsideTheCycleIsSet() {
        let model = LensSession(name: "recent", settings: LensConfig(), items: testProjectItems(), search: "")
        XCTAssertEqual(model.sectionCycle, ["none", "workspace", "app", "project"])
        let width = model.listLayout.width
        model.changeSections("monitor")
        XCTAssertEqual(model.visibleSectionValues.count, 5)
        XCTAssertEqual(model.listLayout.width, width)
        XCTAssertGreaterThanOrEqual(width, model.sectionControlMinimumWidth)
    }
    private func testProjectItems() -> [SwitcherPaletteItem] {
        [SwitcherPaletteItem(id: 1, title: "One", appName: "Editor", icon: nil, workspaceName: "1", projectName: "Work", projectIdentity: "work", monitorIdentity: "m", monitorName: "Main", isFocused: false),
         SwitcherPaletteItem(id: 2, title: "Two", appName: "Mail", icon: nil, workspaceName: "2", projectName: "Home", projectIdentity: "home", monitorIdentity: "m", monitorName: "Main", isFocused: true)]
    }
    func testGroupingKeepsWindowMarksAndLifecycleWithoutEventsAndChangesCache() async {
        let clock = TestClock<Duration>()
        var events: [String] = []
        let owner = testLensLifecycle(clock: clock, emit: { events.append($0.eventType.rawValue) })
        var settings = LensConfig(); settings.presentation = "grid"
        let model = LensSession(name: "demo", settings: settings, items: items(), search: "")
        owner.complete(model, ticket: owner.begin("demo", toggle: false)!)
        defer { owner.dismiss() }
        model.toggleMark()
        let prior = model.gridLayout
        let count = events.count
        model.changeSections("app")
        XCTAssertEqual(model.selectedId, 2)
        XCTAssertEqual(model.marks, [2])
        XCTAssertEqual(events.count, count)
        XCTAssertNotEqual(prior.headers.map(\.label), model.gridLayout.headers.map(\.label))
        model.changePresentation("list")
        XCTAssertEqual(model.selectedId, 2)
        XCTAssertEqual(model.settings.sections, "app")
    }
    func testHeldGroupingKeyOnlyChangesPresentationsWithSections() {
        for presentation in ["strip", "list", "grid", "miniatures"] {
            var settings = LensConfig(); settings.presentation = presentation
            let model = LensSession(name: "demo", settings: settings, items: items(), search: "")
            model.enterHeldModeForTests(ModeInvocation(keyCode: 48, invoking: .command))
            let before = model.settings.sections
            model.changeSections("next")
            XCTAssertEqual(model.settings.sections, ["list", "grid"].contains(presentation) ? "app" : before)
            XCTAssertTrue(model.isHeld)
            XCTAssertEqual(model.query, "")
        }
    }

}


extension SectionSessionTest {
    func testQueuedKeysResolveAfterPresentationConversionInArrivalOrder() async {
        enterModeForTests("browse")
        let owner = testLensLifecycle()
        var settings = LensConfig(); settings.presentation = "strip"
        let ticket = owner.begin("demo", toggle: false)!
        let model = LensSession(name: "demo", settings: settings, items: items(), search: "")
        for (code, text, flags): (UInt16, String, NSEvent.ModifierFlags) in [(44, "/", []), (5, "g", []), (4, "h", []), (5, "g", .command)] {
            let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)!
            ModeEngine.shared.whenLensReady { model.pressForTests(key) }
        }
        owner.complete(model, ticket: ticket)
        await ModeEngine.shared.waitForReadiness()
        defer { owner.dismiss() }
        XCTAssertEqual(model.query, "gh")
        XCTAssertEqual(model.settings.sections, "app")
        XCTAssertEqual(model.settings.presentation, "list")
        XCTAssertFalse(model.isHeld)
    }

    func testCycleSnapshotExplicitExtraAndEmptyResultsAndBindingChip() {
        var settings = LensConfig(); settings.sections = "monitor"
        let model = LensSession(name: "demo", settings: settings, items: items(), search: "")
        XCTAssertEqual(model.sectionCycle, ["none", "workspace", "app"])
        XCTAssertEqual(model.visibleSectionValues, ["none", "workspace", "app", "monitor"])
        model.changeSections("next")
        XCTAssertEqual(model.settings.sections, "none")
        model.send(.searchChanged("absent"))
        XCTAssertTrue(model.results.isEmpty)
        XCTAssertTrue(model.performSectionsAction("cmd-g"))
        XCTAssertEqual(model.settings.sections, "workspace")
        testModeBindings["cmd-g"] = []
        testModeBindings["alt-g"] = ["sections next"]
        let custom = LensSession(name: "custom", settings: settings, items: items(), search: "")
        XCTAssertEqual(custom.sectionsKey, "alt-g")
    }
}


extension SectionSessionTest {
    func testProjectAndMonitorCycleOrderingAndMarksUseOpeningSnapshot() {
        let entries = [
            SwitcherPaletteItem(id: 1, title: "One", appName: "Editor", icon: nil, workspaceName: "1", appIdentity: "editor", projectName: "Work", projectIdentity: "work", monitorIdentity: "right", monitorName: "Right", isFocused: false),
            SwitcherPaletteItem(id: 2, title: "Two", appName: "Mail", icon: nil, workspaceName: "2", appIdentity: "mail", projectName: "Home", projectIdentity: "home", monitorIdentity: "left", monitorName: "Left", isFocused: true),
        ]
        let identities = [
            "project": [LensSectionIdentity(key: "work", label: "Work", current: false), LensSectionIdentity(key: "home", label: "Home", current: true)],
            "monitor": [LensSectionIdentity(key: "right", label: "Right", current: false), LensSectionIdentity(key: "left", label: "Left", current: true)],
        ]
        let model = LensSession(name: "demo", settings: LensConfig(), items: entries, search: "", sectionIdentities: identities)
        XCTAssertEqual(model.sectionCycle, ["none", "workspace", "app", "project", "monitor"])
        for grouping in ["project", "monitor"] {
            model.changeSections(grouping)
            XCTAssertEqual(model.sections.map(\.entries).map { $0.map(\.id) }, [[2], [1]])
            XCTAssertEqual(model.sections.map(\.current), [true, false])
            model.send(.searchChanged("One"))
            XCTAssertEqual(model.sections.map(\.current), [false])
            XCTAssertEqual(model.sectionCycle.count, 5)
            model.send(.searchChanged(""))
        }
    }
    func testAppRepresentativesAreGroupedAndMarksAndListArrowsUseSectionOrder() {
        var settings = LensConfig(); settings.entries = "app"
        let model = LensSession(name: "demo", settings: settings, items: items(), search: "")
        XCTAssertEqual(model.results.count, 2)
        model.changeSections("app")
        XCTAssertEqual(model.sections.map(\.entries).map { $0.count }, [1, 1])
        settings.entries = "window"
        let list = LensSession(name: "demo", settings: settings, items: items(), search: "")
        list.send(.selectionChanged(1))
        list.moveSelection(1)
        XCTAssertEqual(list.selectedId, 2)
        list.toggleMark()
        list.changeSections("app")
        XCTAssertEqual(list.targets(for: "enter"), [2])
    }
}
