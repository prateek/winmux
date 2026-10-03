@testable import AppBundle
import Common
import XCTest

@MainActor
final class LensLifecycleTest: XCTestCase {
    private func session(_ name: String, search: String = "") -> LensSession {
        LensSession(name: name, settings: LensConfig(), items: [], search: search)
    }

    func testSameLensTogglesAndAnotherReplacesRememberingSearch() {
        let store = LensLifecycle()
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
        let store = LensLifecycle()
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
    }

    func testConfigReloadDoesNotChangeOpenEntriesOrKeyActions() {
        let item = SwitcherPaletteItem(id: 1, title: "Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false)
        let store = LensLifecycle()
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
