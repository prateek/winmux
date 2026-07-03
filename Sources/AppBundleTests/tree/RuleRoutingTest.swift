@testable import AppBundle
import Common
import XCTest

@MainActor
final class RuleRoutingTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    private func matchTestApp(card: String, focus: Bool = false, checkFurtherRules: Bool = false) -> RuleConfig {
        RuleConfig(
            matcher: WindowDetectedCallbackMatcher().copy(\.appId, TestApp.shared.rawAppBundleId),
            card: card,
            focus: focus,
            checkFurtherRules: checkFurtherRules,
        )
    }

    // A rule naming a card that does not exist yet creates it in the active scene's default
    // column, never the focused column, so rules stay independent of where focus happens to be.
    func testRuleCreatesMissingCardInActiveSceneDefaultColumnNotTheFocusedColumn() async throws {
        let main = configureScenesFromToml(twoSceneToml)
        guard case .success = setActiveScene("desk", for: main) else { return XCTFail("desk should activate") }

        let columns = sceneColumnMonitors()
        let comms = try XCTUnwrap(columns["comms"])
        // Put focus on comms, so the interactive `card new` default would create there.
        let seed = occupyCard("Seed", windowId: 1, on: comms)
        recordFocusedColumnDeckKeyHint(seed)
        assertEquals(columnDeckKeyForNewWorkspace(named: "Probe"), "scene:desk/column:comms")

        let window = TestWindow.new(id: 2, parent: seed.rootTilingContainer)
        config.rules = [matchTestApp(card: "Chat")]

        let handled = try await applyMatchingRule(to: window)

        assertTrue(handled)
        let chat = try XCTUnwrap(Workspace.existing(byName: "Chat"))
        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: chat.id), "scene:desk/column:main")
        assertEquals(window.nodeWorkspace?.name, "Chat")
    }

    // A window detached to the minimized-windows container has no nodeMonitor; the missing-card
    // fallback must still resolve deterministically (mainMonitor) rather than drifting to
    // Workspace.get(byName:)'s focused-column default.
    func testRuleCreatesMissingCardOnMainMonitorWhenTheWindowHasNoResolvedMonitor() async throws {
        let main = configureScenesFromToml(twoSceneToml)
        guard case .success = setActiveScene("desk", for: main) else { return XCTFail("desk should activate") }

        let columns = sceneColumnMonitors()
        let comms = try XCTUnwrap(columns["comms"])
        let seed = occupyCard("Seed", windowId: 1, on: comms)
        recordFocusedColumnDeckKeyHint(seed)

        let window = TestWindow.new(id: 2, parent: seed.rootTilingContainer)
        window.rememberMacOsLayoutOrigin(detachFromWorkspace: true)
        window.nativeIsMacosMinimized = true
        window.bind(to: macosMinimizedWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        XCTAssertNil(window.nodeMonitor)
        config.rules = [matchTestApp(card: "Chat")]

        let handled = try await applyMatchingRule(to: window)

        assertTrue(handled)
        let chat = try XCTUnwrap(Workspace.existing(byName: "Chat"))
        // desk's default column, resolved from mainMonitor (the physical display), not comms
        // where focus was left.
        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: chat.id), "scene:desk/column:main")
    }

    func testRuleRoutesWindowToAnExistingCardWithoutRecreatingIt() async throws {
        let main = configureScenesFromToml(twoSceneToml)
        guard case .success = setActiveScene("desk", for: main) else { return XCTFail("desk should activate") }

        let columns = sceneColumnMonitors()
        let work = occupyCard("Work", windowId: 1, on: try XCTUnwrap(columns["main"]))
        let seed = occupyCard("Seed", windowId: 2, on: try XCTUnwrap(columns["ref"]))
        let window = TestWindow.new(id: 3, parent: seed.rootTilingContainer)
        config.rules = [matchTestApp(card: "Work")]

        let handled = try await applyMatchingRule(to: window)

        assertTrue(handled)
        assertEquals(window.nodeWorkspace?.id, work.id)
        assertEquals(Workspace.all.filter { $0.name == "Work" }.count, 1)
    }

    func testNonMatchingRuleLeavesTheWindowOnItsCard() async throws {
        let main = configureScenesFromToml(twoSceneToml)
        guard case .success = setActiveScene("desk", for: main) else { return XCTFail("desk should activate") }

        let seed = occupyCard("Seed", windowId: 1, on: try XCTUnwrap(sceneColumnMonitors()["ref"]))
        let window = TestWindow.new(id: 2, parent: seed.rootTilingContainer)
        config.rules = [RuleConfig(matcher: WindowDetectedCallbackMatcher().copy(\.appId, "com.example.unrelated"), card: "Chat")]

        let handled = try await applyMatchingRule(to: window)

        assertTrue(!handled)
        assertNil(Workspace.existing(byName: "Chat"))
        assertEquals(window.nodeWorkspace?.name, "Seed")
    }

    func testFirstMatchingRuleWins() async throws {
        let main = configureScenesFromToml(twoSceneToml)
        guard case .success = setActiveScene("desk", for: main) else { return XCTFail("desk should activate") }

        let seed = occupyCard("Seed", windowId: 1, on: try XCTUnwrap(sceneColumnMonitors()["ref"]))
        let window = TestWindow.new(id: 2, parent: seed.rootTilingContainer)
        config.rules = [matchTestApp(card: "First"), matchTestApp(card: "Second")]

        let handled = try await applyMatchingRule(to: window)

        assertTrue(handled)
        assertEquals(window.nodeWorkspace?.name, "First")
        assertNil(Workspace.existing(byName: "Second"))
    }

    // check-further-rules keeps evaluating past a match, mirroring check-further-callbacks: the
    // window ends up on the last applicable rule's card, with every card it passed through created.
    func testCheckFurtherRulesChainsToTheNextMatchingRule() async throws {
        let main = configureScenesFromToml(twoSceneToml)
        guard case .success = setActiveScene("desk", for: main) else { return XCTFail("desk should activate") }

        let seed = occupyCard("Seed", windowId: 1, on: try XCTUnwrap(sceneColumnMonitors()["ref"]))
        let window = TestWindow.new(id: 2, parent: seed.rootTilingContainer)
        config.rules = [matchTestApp(card: "First", checkFurtherRules: true), matchTestApp(card: "Second")]

        let handled = try await applyMatchingRule(to: window)

        assertTrue(handled)
        assertEquals(window.nodeWorkspace?.name, "Second")
        assertNotNil(Workspace.existing(byName: "First"))
    }

    func testRuleFocusMovesFocusToTheRoutedWindow() async throws {
        let main = configureScenesFromToml(twoSceneToml)
        guard case .success = setActiveScene("desk", for: main) else { return XCTFail("desk should activate") }

        let seed = occupyCard("Seed", windowId: 1, on: try XCTUnwrap(sceneColumnMonitors()["ref"]))
        let previouslyFocused = TestWindow.new(id: 2, parent: seed.rootTilingContainer)
        XCTAssertTrue(previouslyFocused.focusWindow())
        let window = TestWindow.new(id: 3, parent: seed.rootTilingContainer)
        config.rules = [matchTestApp(card: "Chat", focus: true)]

        let handled = try await applyMatchingRule(to: window)

        assertTrue(handled)
        assertEquals(window.nodeWorkspace?.name, "Chat")
        assertTrue(focus.windowOrNil === window)
    }

    func testRuleFocusDefaultsToFalseAndLeavesFocusUnchanged() async throws {
        let main = configureScenesFromToml(twoSceneToml)
        guard case .success = setActiveScene("desk", for: main) else { return XCTFail("desk should activate") }

        let seed = occupyCard("Seed", windowId: 1, on: try XCTUnwrap(sceneColumnMonitors()["ref"]))
        let previouslyFocused = TestWindow.new(id: 2, parent: seed.rootTilingContainer)
        XCTAssertTrue(previouslyFocused.focusWindow())
        let window = TestWindow.new(id: 3, parent: seed.rootTilingContainer)
        config.rules = [matchTestApp(card: "Chat")]

        let handled = try await applyMatchingRule(to: window)

        assertTrue(handled)
        assertEquals(window.nodeWorkspace?.name, "Chat")
        assertTrue(focus.windowOrNil === previouslyFocused)
    }

    // Rules reuse the zone-affinity matcher engine (parseWindowDetectedMatcher) verbatim, so a
    // title-regex matcher behaves identically here.
    func testRuleTitleRegexMatcherParityWithZoneAffinityMatching() async throws {
        let main = configureScenesFromToml(twoSceneToml)
        guard case .success = setActiveScene("desk", for: main) else { return XCTFail("desk should activate") }
        let seed = occupyCard("Seed", windowId: 1, on: try XCTUnwrap(sceneColumnMonitors()["ref"]))
        var errors: [String] = []
        let regex = parseCaseInsensitiveRegex("Inbox|Mail").getOrNil(appendErrorTo: &errors).orDie()
        assertEquals(errors, [])
        config.rules = [RuleConfig(matcher: WindowDetectedCallbackMatcher(windowTitleRegexSubstring: regex), card: "Chat")]

        let matchingWindow = TestWindow.new(id: 2, parent: seed.rootTilingContainer, title: "mail-inbox.rtf")
        let matchingHandled = try await applyMatchingRule(to: matchingWindow)
        assertTrue(matchingHandled)
        assertEquals(matchingWindow.nodeWorkspace?.name, "Chat")

        let nonMatchingWindow = TestWindow.new(id: 3, parent: seed.rootTilingContainer, title: "notes.rtf")
        let nonMatchingHandled = try await applyMatchingRule(to: nonMatchingWindow)
        assertTrue(!nonMatchingHandled)
        assertEquals(nonMatchingWindow.nodeWorkspace?.name, "Seed")
    }

    func testRuleEvaluationReportsMatchAndExistingCardTarget() async throws {
        let main = configureScenesFromToml(twoSceneToml)
        guard case .success = setActiveScene("desk", for: main) else { return XCTFail("desk should activate") }
        let work = occupyCard("Work", windowId: 1, on: try XCTUnwrap(sceneColumnMonitors()["main"]))
        let seed = occupyCard("Seed", windowId: 2, on: try XCTUnwrap(sceneColumnMonitors()["ref"]))
        let window = TestWindow.new(id: 3, parent: seed.rootTilingContainer)
        let rule = matchTestApp(card: "Work", focus: true, checkFurtherRules: true)

        let evaluation = try await rule.evaluate(index: 0, window: window)

        assertTrue(evaluation.matched)
        assertEquals(evaluation.card, "Work")
        assertEquals(evaluation.target, .existing(columnKey: "scene:desk/column:main"))
        assertEquals(winMuxWorkspaceState.columnDecks.columnKey(of: work.id), "scene:desk/column:main")
        assertTrue(evaluation.focus)
        assertTrue(evaluation.checkFurtherRules)
    }

    func testRuleEvaluationExplainsWhereAMissingCardWouldBeCreated() async throws {
        let main = configureScenesFromToml(twoSceneToml)
        guard case .success = setActiveScene("desk", for: main) else { return XCTFail("desk should activate") }
        let seed = occupyCard("Seed", windowId: 1, on: try XCTUnwrap(sceneColumnMonitors()["ref"]))
        let window = TestWindow.new(id: 2, parent: seed.rootTilingContainer)
        let rule = matchTestApp(card: "Chat")

        let evaluation = try await rule.evaluate(index: 0, window: window)

        assertTrue(evaluation.matched)
        assertEquals(evaluation.target, .willCreate(columnKey: "scene:desk/column:main"))
        assertNil(Workspace.existing(byName: "Chat"))
    }

    func testRuleEvaluationExplainsNoMatchFields() async throws {
        let main = configureScenesFromToml(twoSceneToml)
        guard case .success = setActiveScene("desk", for: main) else { return XCTFail("desk should activate") }
        let seed = occupyCard("Seed", windowId: 1, on: try XCTUnwrap(sceneColumnMonitors()["ref"]))
        let window = TestWindow.new(id: 2, parent: seed.rootTilingContainer, title: "notes.rtf")
        let rule = RuleConfig(matcher: WindowDetectedCallbackMatcher(appId: "com.example.unrelated"), card: "Chat")

        let evaluation = try await rule.evaluate(index: 0, window: window)

        assertTrue(!evaluation.matched)
        assertTrue(evaluation.matcher.failedTerms.contains { $0.contains("app-id expected 'com.example.unrelated'") })
    }
}
