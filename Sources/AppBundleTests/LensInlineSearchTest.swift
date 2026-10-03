@testable import AppBundle
import Common
import Combine
import XCTest

@MainActor
final class LensInlineSearchTest: XCTestCase {
    func testDisplayDeadlineKeepsLastResultAndIgnoresLateSuccess() async throws {
        let item = SwitcherPaletteItem(id: 1, title: "Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false)
        let model = LensSession(name: "demo", settings: LensConfig(), items: [item], search: "= true")
        model.acceptInlineResult([1])
        let started = expectation(description: "evaluation started")
        let expired = expectation(description: "display deadline reported")
        var finish: CheckedContinuation<Result<[Bool], NickelFailure>, Never>?
        let scheduler = LensInlineSearch(debounce: .zero, deadline: .milliseconds(20)) { _, _, _ in
            await withCheckedContinuation { continuation in finish = continuation; started.fulfill() }
        }
        let observation = model.$searchError.sink { if $0 == "Filter too slow" { expired.fulfill() } }
        let task = scheduler.update(model, context: .object([:]), windows: [.object([:])], ids: [1])!
        await fulfillment(of: [started, expired], timeout: 5)
        XCTAssertEqual(model.results.map(\.id), [1])
        finish?.resume(returning: .success([false]))
        await task.value
        XCTAssertEqual(model.results.map(\.id), [1])
        XCTAssertEqual(model.searchError, "Filter too slow")
        withExtendedLifetime(observation) {}
    }

    func testTypingCancelsDebounceAndOnlyLatestSearchEvaluates() async {
        let model = LensSession(name: "demo", settings: LensConfig(), items: [], search: "= false")
        var bodies: [String] = []
        let scheduler = LensInlineSearch(debounce: .milliseconds(10), deadline: .seconds(1)) { body, _, _ in
            bodies.append(body)
            return .success([])
        }
        let old = scheduler.update(model, context: .object([:]), windows: [], ids: [])!
        model.query = "= true"
        let current = scheduler.update(model, context: .object([:]), windows: [], ids: [])!
        await current.value
        await old.value
        XCTAssertEqual(bodies, [" true"])
    }
}
