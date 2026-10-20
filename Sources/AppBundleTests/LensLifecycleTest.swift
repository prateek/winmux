@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor
final class LensLifecycleTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests(); enterModeForTests("search") }
    func testAcceptedSessionSurvivesOpeningCleanupWhileModeDelaysDrawing() {
        var mode = Mode.zero; mode.lifetime = .held; mode.drawDelay = 100
        ModeEngine.shared.replace("held", mode: mode, invocation: .init(keyCode: 48, invoking: .command))
        var shown = 0
        let owner = testLensLifecycle(show: { _ in shown += 1 })
        let model = session("delayed")
        let ticket = owner.begin("delayed", toggle: false)!
        XCTAssertTrue(owner.complete(model, ticket: ticket))
        owner.cancelOpening(ticket: ticket)
        XCTAssertTrue(owner.session === model)
        XCTAssertEqual(shown, 0)
        owner.dismiss()
    }
    private func session(_ name: String, search: String = "") -> LensSession {
        LensSession(name: name, settings: LensConfig(), items: [], search: search)
    }


    private func stripSession() -> LensSession {
        var settings = LensConfig(); settings.presentation = "strip"
        let items = (1...3).map { SwitcherPaletteItem(id: UInt32($0), title: "Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: $0 == 1) }
        return LensSession(name: "recent", settings: settings, items: items, search: "")
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
    func testAdHocIdentityTogglesOnlyWhenFilterAndResolvedSettingsMatch() {
        let owner = testLensLifecycle()
        let identity = LensAdHocIdentity(filter: "true", settings: LensConfig())
        let first = owner.begin("<ad-hoc>", toggle: false, identity: identity)!
        owner.complete(session("<ad-hoc>"), ticket: first)
        XCTAssertNil(owner.begin("<ad-hoc>", toggle: false, identity: identity))
        let second = owner.begin("<ad-hoc>", toggle: false, identity: identity)!
        owner.complete(session("<ad-hoc>"), ticket: second)
        let other = LensAdHocIdentity(filter: "false", settings: LensConfig())
        XCTAssertNotNil(owner.begin("<ad-hoc>", toggle: false, identity: other))
        owner.dismiss()
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
            XCTAssertEqual(instructions, [.init(activate: true, focusSearch: true)])
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

    func testOnlyStripUsesReadyStateWhileFirstNonStripSessionIsCurrent() {
        for presentation in ["list", "miniatures"] {
            var owner: LensLifecycle!
            owner = testLensLifecycle(show: { model in
                XCTAssertTrue(owner.session === model)
                if case .closed = owner.state { XCTFail("Accepted sessions are current before show") }
            })
            var settings = LensConfig(); settings.presentation = presentation
            let model = LensSession(name: "demo", settings: settings, items: [], search: "")
            owner.complete(model, ticket: owner.begin("demo", toggle: false)!)
            guard case .presented = owner.state else { return XCTFail("Expected presented") }
            owner.dismiss()
        }
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
        let dependencies = LensLifecycle.Dependencies.live(isTesting: { reads += 1; return false }, request: { _, _, _ in requests += 1 })
        XCTAssertEqual(reads, 1)
        setUpWorkspacesForTests()
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        for _ in 0..<5 { dependencies.requestThumbnail(window, 1, .zero) }
        XCTAssertEqual(reads, 1)
        XCTAssertEqual(requests, 5)
    }



    func testConfigReloadDoesNotChangeOpenEntriesOrKeyActions() {
        let item = SwitcherPaletteItem(id: 1, title: "Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false)
        let store = testLensLifecycle()
        let ticket = store.begin("demo", toggle: true)!
        var settings = LensConfig()
        testModeBindings["cmd-x"] = ["close"]
        store.complete(LensSession(name: "demo", settings: settings, items: [item], search: ""), ticket: ticket)
        config.lenses = [:]
        XCTAssertEqual(store.session?.results.map(\.id), [1])
        XCTAssertEqual(store.session?.actionCommandsForTests(for: "cmd-x"), ["close"])
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
