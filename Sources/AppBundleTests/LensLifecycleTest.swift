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
            let store = LensLifecycle()
            let gesture = StripGesture(keyCode: 48, invoking: .command, openedAt: 0)
            let ticket = store.begin("recent", toggle: true, strip: gesture)!
            XCTAssertFalse(store.cycleStrip(name: "other", keyCode: 48, flags: .command))
            XCTAssertFalse(store.cycleStrip(keyCode: 50, flags: .command))
            XCTAssertTrue(store.cycleStrip(keyCode: 48, flags: flags))
            var settings = LensConfig(); settings.presentation = "strip"
            let items = (1...3).map { SwitcherPaletteItem(id: UInt32($0), title: "Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: $0 == 1) }
            let model = LensSession(name: "recent", settings: settings, items: items, search: "")
            XCTAssertTrue(store.complete(model, ticket: ticket))
            XCTAssertEqual(model.selectedId, expected)
            XCTAssertTrue(store.cycleStrip(keyCode: 48, flags: .command))
            XCTAssertNotNil(store.session)
        }
    }

    func testCancelledOpeningDoesNotTransferPendingSteps() {
        let store = LensLifecycle()
        let gesture = StripGesture(keyCode: 48, invoking: .command, openedAt: 0)
        let ticket = store.begin("recent", toggle: true, strip: gesture)!
        XCTAssertTrue(store.cycleStrip(keyCode: 48, flags: .command))
        store.cancelOpening(ticket: ticket)
        XCTAssertFalse(store.cycleStrip(keyCode: 48, flags: .command))
        XCTAssertFalse(store.complete(session("recent"), ticket: ticket))
    }

    func testFailedOpenCanRetryOnceAndOldCleanupCannotCancelNewerOpen() {
        let store = LensLifecycle()
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
