@testable import AppBundle
import Common
import Clocks
import XCTest

@MainActor
final class LensInlineSearchTest: XCTestCase {
    func testDisplayDeadlineKeepsLastResultAndIgnoresLateSuccess() async throws {
        let clock = TestClock()
        let item = SwitcherPaletteItem(id: 1, title: "Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false)
        let model = LensSession(name: "demo", settings: LensConfig(), items: [item], search: "= true")
        model.acceptInlineResult([1])
        let started = LensEffectSignal()
        var finish: CheckedContinuation<Result<[Bool], NickelFailure>, Never>?
        let scheduler = LensInlineSearch(clock: clock, debounce: .zero, deadline: .milliseconds(20)) { _, _, _ in
            await withCheckedContinuation { continuation in finish = continuation; started.send() }
        }
        let task = scheduler.update(model, context: .object([:]), windows: [.object([:])], ids: [1])!
        await clock.advance()
        await started.wait()
        await clock.advance(by: .milliseconds(20) - .nanoseconds(1))
        XCTAssertNil(model.searchError)
        XCTAssertEqual(model.results.map(\.id), [1])
        await clock.advance(by: .nanoseconds(1))
        XCTAssertEqual(model.searchError, "Filter too slow")
        XCTAssertEqual(model.results.map(\.id), [1])
        finish?.resume(returning: .success([false]))
        await task.value
        XCTAssertEqual(model.results.map(\.id), [1])
        XCTAssertEqual(model.searchError, "Filter too slow")
        XCTAssertNil(scheduler.current)
        try await clock.checkSuspension()
    }

    func testCancelledEvaluationCannotPublishOverNewerSearchOrClearItsHandle() async throws {
        let clock = TestClock()
        let model = LensSession(name: "demo", settings: LensConfig(), items: [], search: "= old")
        let reached = LensEffectSignal()
        var finishes: [CheckedContinuation<Result<[Bool], NickelFailure>, Never>] = []
        let scheduler = LensInlineSearch(clock: clock, debounce: .zero, deadline: .seconds(1)) { _, _, _ in
            await withCheckedContinuation { finishes.append($0); reached.send() }
        }
        let old = scheduler.update(model, context: .null, windows: [], ids: [])!
        await clock.advance()
        await reached.wait()
        model.send(.searchChanged("= new"))
        let newer = scheduler.update(model, context: .null, windows: [], ids: [])!
        await clock.advance()
        await reached.wait(2)
        finishes[0].resume(returning: .failure(.diagnostic("old error")))
        await old.value
        XCTAssertEqual(scheduler.current, newer)
        XCTAssertNil(model.searchError)
        finishes[1].resume(returning: .failure(.diagnostic("new error")))
        await newer.value
        XCTAssertEqual(model.searchError, "new error")
        XCTAssertNil(scheduler.current)
        try await clock.checkSuspension()
    }

    func testTypingCancelsDebounceAndOnlyLatestSearchEvaluates() async throws {
        let clock = TestClock()
        let model = LensSession(name: "demo", settings: LensConfig(), items: [], search: "= false")
        var bodies: [String] = []
        let scheduler = LensInlineSearch(clock: clock, debounce: .milliseconds(10), deadline: .seconds(1)) { body, _, _ in
            bodies.append(body)
            return .success([])
        }
        let old = scheduler.update(model, context: .object([:]), windows: [], ids: [])!
        model.send(.searchChanged("= true"))
        let current = scheduler.update(model, context: .object([:]), windows: [], ids: [])!
        await clock.advance(by: .milliseconds(10) - .nanoseconds(1))
        XCTAssertTrue(bodies.isEmpty)
        await clock.advance(by: .nanoseconds(1))
        await current.value
        await old.value
        XCTAssertEqual(bodies, [" true"])
        try await clock.checkSuspension()
    }
}
