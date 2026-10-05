@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor
final class LensLifecycleTest: XCTestCase {
    private func session(_ name: String, search: String = "") -> LensSession {
        LensSession(name: name, settings: LensConfig(), items: [], search: search)
    }

    func testOpeningStripAccumulatesForwardAndReverseTriggerSteps() {
        for (flags, expected): (NSEvent.ModifierFlags, UInt32) in [(.command, 3), ([.command, .shift], 1)] {
            let store = testLensLifecycle()
            let gesture = StripGesture(keyCode: 48, invoking: .command)
            let ticket = store.begin("recent", toggle: true, strip: gesture)!
            XCTAssertFalse(store.cycleStrip(name: "other", keyCode: 48, flags: .command))
            XCTAssertFalse(store.cycleStrip(name: "recent", keyCode: 50, flags: .command))
            XCTAssertTrue(store.cycleStrip(name: "recent", keyCode: 48, flags: flags))
            var settings = LensConfig(); settings.presentation = "strip"
            let items = (1...3).map { SwitcherPaletteItem(id: UInt32($0), title: "Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: $0 == 1) }
            let model = LensSession(name: "recent", settings: settings, items: items, search: "")
            XCTAssertTrue(store.complete(model, ticket: ticket))
            XCTAssertEqual(model.selectedId, expected)
            XCTAssertTrue(store.cycleStrip(name: "recent", keyCode: 48, flags: .command))
            XCTAssertNotNil(store.session)
        }
    }

    private func stripSession() -> LensSession {
        var settings = LensConfig(); settings.presentation = "strip"
        let items = (1...3).map { SwitcherPaletteItem(id: UInt32($0), title: "Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: $0 == 1) }
        return LensSession(name: "recent", settings: settings, items: items, search: "")
    }

    func testOpeningStripSortsKeysIntoStepsIgnoredKeysAndOtherBindings() {
        let store = testLensLifecycle()
        XCTAssertNil(store.openingStripKey(keyCode: 48, flags: .command))
        let ticket = store.begin("recent", toggle: true, strip: StripGesture(keyCode: 48, invoking: .command))!
        // Another binding on the invoking key is not a step.
        XCTAssertEqual(store.openingStripKey(keyCode: 48, flags: .option), .ignored)
        XCTAssertEqual(store.openingStripKey(keyCode: 48, flags: [.command, .control]), .ignored)
        // Backtick with the strip's modifiers does nothing in `recent`, as when the strip is ready.
        XCTAssertEqual(store.openingStripKey(keyCode: 50, flags: .command), .consumed)
        XCTAssertEqual(store.openingStripKey(keyCode: 37, flags: [.command, .control]), .ignored)
        let model = stripSession()
        XCTAssertTrue(store.complete(model, ticket: ticket))
        XCTAssertEqual(model.selectedId, 2)
        XCTAssertNil(store.openingStripKey(keyCode: 48, flags: .command))
    }

    func testReleaseWhileOpeningSettlesTheSelectionAndIsHandedToTheSession() {
        let store = testLensLifecycle()
        let ticket = store.begin("recent", toggle: true, strip: StripGesture(keyCode: 48, invoking: .command))!
        store.openingFlagsChanged([.command, .shift])
        store.openingFlagsChanged([.option])
        store.openingFlagsChanged([])
        // A press after the release is consumed and does not move the selection.
        XCTAssertEqual(store.openingStripKey(keyCode: 48, flags: .command), .consumed)
        let model = stripSession()
        XCTAssertTrue(store.complete(model, ticket: ticket))
        XCTAssertEqual(model.selectedId, 2)
        XCTAssertEqual(model.stripReleasedWhileOpening, [.option])
        XCTAssertEqual(model.stripReleaseKey(flags: [.option]), "alt-enter")

        let held = store.begin("recent", toggle: true, strip: StripGesture(keyCode: 48, invoking: .command))!
        store.openingFlagsChanged([.command, .option])
        let second = stripSession()
        XCTAssertTrue(store.complete(second, ticket: held))
        XCTAssertNil(second.stripReleasedWhileOpening)
    }

    func testCancelledOpeningDoesNotTransferPendingSteps() {
        let store = testLensLifecycle()
        let gesture = StripGesture(keyCode: 48, invoking: .command)
        let ticket = store.begin("recent", toggle: true, strip: gesture)!
        XCTAssertTrue(store.cycleStrip(name: "recent", keyCode: 48, flags: .command))
        store.cancelOpening(ticket: ticket)
        XCTAssertFalse(store.cycleStrip(name: "recent", keyCode: 48, flags: .command))
        XCTAssertFalse(store.complete(session("recent"), ticket: ticket))
    }

    func testFailedOpenCanRetryOnceAndOldCleanupCannotCancelNewerOpen() {
        let store = testLensLifecycle()
        let failed = store.begin("search", toggle: true)!
        store.cancelOpening(ticket: failed)
        XCTAssertNotNil(store.begin("search", toggle: true))
        let newer = store.begin("other", toggle: true)!
        store.cancelOpening(ticket: failed)
        XCTAssertTrue(store.complete(session("other"), ticket: newer))
        store.cancelOpening(ticket: newer)
        XCTAssertEqual(store.session?.name, "other")
    }

    func testFilterBitsHandleShortAndLongResponses() {
        XCTAssertEqual(lensFilterMatches([1, 2, 3], bits: [false, true]), [2])
        XCTAssertEqual(lensFilterMatches([1], bits: [true, true]), [1])
    }

    func testSameLensTogglesAndAnotherReplacesRememberingSearch() {
        let store = testLensLifecycle()
        let first = store.begin("search", toggle: true)!
        store.complete(session("search", search: "notes"), ticket: first)
        XCTAssertNil(store.begin("search", toggle: true))
        XCTAssertNil(store.session)
        XCTAssertEqual(store.search(for: "search", override: nil), "notes")
        XCTAssertEqual(store.search(for: "search", override: "foo"), "foo")
        let second = store.begin("other", toggle: true)!
        store.complete(session("other"), ticket: second)
        let third = store.begin("search", toggle: true)!
        store.complete(session("search"), ticket: third)
        XCTAssertEqual(store.session?.name, "search")
    }

    func testOvertakenOpenAndDismissedOpenCannotAppearLater() {
        var shown: [String] = []
        let store = testLensLifecycle(show: { shown.append($0.name) })
        let old = store.begin("first", toggle: true)!
        let newer = store.begin("second", toggle: true)!
        store.complete(session("first"), ticket: old)
        XCTAssertNil(store.session)
        store.complete(session("second"), ticket: newer)
        XCTAssertEqual(store.session?.name, "second")
        let last = store.begin("third", toggle: true)!
        store.dismiss()
        store.complete(session("third"), ticket: last)
        XCTAssertNil(store.session)
        XCTAssertEqual(shown, ["second"], "An overtaken opening starts no presentation effects")
    }

    func testPresentationCallbackCannotReviveAReplacedSession() {
        var events: [ServerEvent] = []
        var owner: LensLifecycle!
        owner = testLensLifecycle(emit: { events.append($0) }, show: { [self] model in
            if model.name == "old" {
                let ticket = owner.begin("new", toggle: false)!
                owner.complete(session("new"), ticket: ticket)
            }
        })
        let old = owner.begin("old", toggle: false)!
        owner.complete(session("old"), ticket: old)
        XCTAssertEqual(owner.session?.name, "new")
        XCTAssertEqual(events.map(\.eventType), [.lensOpened])
        XCTAssertTrue(owner.ownedEffects.isEmpty)
        owner.dismiss()
    }

    func testFirstOpenAndConversionUseBasePresentationInstructions() {
        for presentation in ["list", "miniatures", "strip"] {
            var settings = LensConfig(); settings.presentation = presentation
            let model = LensSession(name: "demo", settings: settings, items: [], search: "remembered")
            var instructions: [LensLifecycle.ShowInstruction] = []
            let owner = testLensLifecycle()
            owner.finishShow = { _, instruction in instructions.append(instruction) }
            owner.complete(model, ticket: owner.begin("demo", toggle: false)!)
            XCTAssertEqual(instructions, [.init(activate: presentation != "strip", focusSearch: presentation != "strip")])
            model.send(.presentationChanged("list"))
            if presentation != "list" {
                XCTAssertEqual(instructions.last, .init(activate: false, focusSearch: false))
            }
            owner.dismiss()
        }
    }

    func testSessionIsCurrentDuringShowAndOpenedPrecedesActivation() {
        var order: [String] = []
        var owner: LensLifecycle!
        owner = testLensLifecycle(emit: { _ in order.append("opened") }, show: { model in
            XCTAssertTrue(owner.session === model)
            model.send(.searchChanged("during show"))
            order.append("present and order front")
        })
        owner.finishShow = { model, _ in
            XCTAssertTrue(owner.session === model)
            order.append("activate and make key")
        }
        let model = session("demo")
        owner.complete(model, ticket: owner.begin("demo", toggle: false)!)
        XCTAssertEqual(model.query, "during show")
        XCTAssertEqual(order, ["present and order front", "opened", "activate and make key"])
        owner.dismiss()
    }

    func testDismissalClearsSearchSnapshotAndContext() {
        let owner = testLensLifecycle()
        owner.complete(session("demo"), ticket: owner.begin("demo", toggle: false)!,
            context: .string("context"), windows: [.string("record")], ids: [1])
        XCTAssertEqual(owner.searchInput.windows.count, 1)
        owner.dismiss()
        XCTAssertEqual(owner.searchInput.context, .null)
        XCTAssertTrue(owner.searchInput.windows.isEmpty)
        XCTAssertTrue(owner.searchInput.ids.isEmpty)
    }

    func testLiveDependenciesReadTestEnvironmentOnceAtAssembly() {
        var reads = 0
        var requests = 0
        let dependencies = LensLifecycle.Dependencies.live(isTesting: { reads += 1; return false }, request: { _, _ in requests += 1 })
        XCTAssertEqual(reads, 1)
        setUpWorkspacesForTests()
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        for _ in 0..<5 { dependencies.requestThumbnail(window, 1) }
        XCTAssertEqual(reads, 1)
        XCTAssertEqual(requests, 5)
    }

    func testAcceptedStripInitializesOnceAndRejectedTicketDoesNotInitialize() {
        let owner = testLensLifecycle()
        let model = stripSession()
        var changes = 0
        let observation = model.objectWillChange.sink { changes += 1 }
        let gesture = StripGesture(keyCode: 48, invoking: .command)
        let ticket = owner.begin("recent", toggle: false)!
        XCTAssertFalse(owner.complete(model, ticket: ticket - 1, invocation: gesture))
        XCTAssertNil(model.stripGesture)
        XCTAssertEqual(changes, 0)
        XCTAssertTrue(owner.complete(model, ticket: ticket, invocation: gesture))
        XCTAssertNotNil(model.stripGesture)
        XCTAssertEqual(changes, 2, "One initialization and one application of accumulated steps")
        owner.dismiss()
        withExtendedLifetime(observation) {}
    }

    func testPanelDoesNotStartStripOrOwnSessionEffects() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let panel = try String(contentsOf: root.appendingPathComponent("AppBundle/ui/hud/SwitcherPalette.swift"), encoding: .utf8)
        XCTAssertFalse(panel.contains(".beginStrip("), "Only the owner initializes a strip, after accepting its ticket")
        for field in ["stripDisplay", "thumbnailRefresh", "thumbnailSession", "inlineSearch"] {
            XCTAssertFalse(panel.contains("var \(field)"), field)
        }
    }

    func testConfigReloadDoesNotChangeOpenEntriesOrKeyActions() {
        let item = SwitcherPaletteItem(id: 1, title: "Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false)
        let store = testLensLifecycle()
        let ticket = store.begin("demo", toggle: true)!
        var settings = LensConfig()
        settings.keys["cmd-x"] = ["close"]
        store.complete(LensSession(name: "demo", settings: settings, items: [item], search: ""), ticket: ticket)
        config.lenses = [:]
        XCTAssertEqual(store.session?.results.map(\.id), [1])
        XCTAssertEqual(store.session?.commands(for: "cmd-x"), ["close"])
    }

    func testInteractiveFailureKeepsAllAlreadyGatedCandidatesWithBanner() {
        let resolution = LensFilterResolution(candidateIds: [1, 2], result: .failure(.diagnostic("bad filter")))
        XCTAssertEqual(resolution.ids, [1, 2])
        XCTAssertEqual(resolution.banner, "Filter failed: bad filter")
        let success = LensFilterResolution(candidateIds: [1, 2], result: .success([false, true]))
        XCTAssertEqual(success.ids, [2])
        XCTAssertNil(success.banner)
    }
}
