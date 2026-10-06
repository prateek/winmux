@testable import AppBundle
import AppKit
import Clocks
import XCTest

@MainActor
final class SectionSessionTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }
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
        model.send(.searchChanged("= true"))
        model.acceptInlineResult([2, 3])
        XCTAssertEqual(model.selectedId, 2)
        model.removeStripItems([2])
        XCTAssertEqual(model.selectedId, 3)
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
    func testHoldGIsLetterOnlyUntilPresentationDrawsSections() {
        func key(_ code: UInt16, _ text: String) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)!
        }
        for presentation in ["strip", "list", "grid", "miniatures"] {
            var settings = LensConfig(); settings.presentation = presentation
            let model = LensSession(name: "demo", settings: settings, items: items(), search: "")
            model.startHold(StripGesture(keyCode: 48, invoking: .command))
            if presentation == "strip" {
                for event in [key(5, "g"), key(4, "h")] { _ = model.perform(model.meaning(for: event)) }
                XCTAssertEqual(model.query, "gh")
                XCTAssertEqual(model.settings.presentation, "list")
            } else if presentation != "miniatures" {
                for event in [key(37, "l"), key(31, "o")] { _ = model.perform(model.meaning(for: event)) }
            }
            let query = model.query
            if presentation == "miniatures" { model.changeSections("next") }
            else { _ = model.perform(model.meaning(for: key(5, "g"))) }
            XCTAssertEqual(model.query, query)
            XCTAssertEqual(model.settings.sections, presentation == "miniatures" ? "workspace" : "app")
            model.endHold(flags: [])
            if presentation != "miniatures" {
                _ = model.perform(model.meaning(for: key(5, "g")))
                XCTAssertEqual(model.settings.sections, "none")
                XCTAssertEqual(model.query, query)
            }
        }
    }
}


extension SectionSessionTest {
    func testQueuedHoldLettersReResolveBindingsAfterStripConversion() {
        let clock = TestClock<Duration>()
        let owner = testLensLifecycle(clock: clock)
        var settings = LensConfig(); settings.presentation = "strip"
        let gesture = StripGesture(keyCode: 48, invoking: .command, clock: clock)
        let ticket = owner.begin("demo", toggle: false, strip: gesture, keys: [])!
        for (code, text): (UInt16, String) in [(5, "g"), (4, "h"), (5, "g")] {
            XCTAssertEqual(owner.openingStripKey(keyCode: code, flags: .command, characters: text), .consumed)
        }
        owner.openingFlagsChanged([])
        let model = LensSession(name: "demo", settings: settings, items: items(), search: "")
        owner.complete(model, ticket: ticket)
        defer { owner.dismiss() }
        XCTAssertEqual(model.query, "gh")
        XCTAssertEqual(model.settings.sections, "app")
        XCTAssertEqual(model.settings.presentation, "list")
        XCTAssertNil(model.hold)
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
        settings.keys["cmd-g"] = []
        settings.keys["alt-g"] = ["sections next"]
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
