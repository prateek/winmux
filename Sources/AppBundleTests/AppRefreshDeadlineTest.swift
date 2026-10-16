@testable import AppBundle
import Clocks
import XCTest

@MainActor
final class AppRefreshDeadlineTest: SerialClockTestCase {
    func testWorkBeforeDeadlineReturnsItsOwnWindows() async throws {
        let clock = TestClock(), gate = ReloadGate()
        let task = Task { try await appRefreshWithDeadline(clock: clock, work: { await gate.hold(); return [1] }, fallback: { [2] }) }
        await gate.entered.wait()
        await clock.advance(by: .milliseconds(1499))
        gate.release()
        let result = try await task.value
        XCTAssertEqual(result, [1])
    }

    func testDeadlineCancelsWorkAndRejectsItsLateResultButWaitsForItToYield() async throws {
        let clock = TestClock(), gate = ReloadGate()
        var completed = false, wasCancelled = false, cancellationObserved = false
        let cancellation = ReloadSignal()
        let observer = Task { await cancellation.wait(); cancellationObserved = true }
        let task = Task { @MainActor in
            let result = try await appRefreshWithDeadline(clock: clock, work: {
                await withTaskCancellationHandler {
                    await gate.hold()
                } onCancel: {
                    Task { @MainActor in cancellation.send() }
                }
                wasCancelled = Task.isCancelled
                return [1]
            }, fallback: { [2] })
            completed = true
            return result
        }
        await gate.entered.wait()
        await clock.advance(by: .milliseconds(1500) - .nanoseconds(1))
        XCTAssertFalse(completed)
        XCTAssertFalse(cancellationObserved, "work must not be cancelled before 1500 ms")
        await clock.advance(by: .nanoseconds(1))
        XCTAssertTrue(cancellationObserved, "work cancellation fires at 1500 ms")
        await observer.value
        XCTAssertFalse(completed, "deadline cancels enumeration but does not abandon it")
        await clock.advance(by: .seconds(10))
        XCTAssertFalse(completed, "uncooperative AX work overshoots the deadline")
        gate.release()
        let result = try await task.value
        XCTAssertTrue(wasCancelled)
        XCTAssertEqual(result, [2], "deadline returns model windows, never the cancelled enumeration's late result")
    }

    func testCancellingRefreshSessionPropagatesCancellation() async throws {
        let clock = TestClock(), gate = ReloadGate()
        var fallback = false
        let task = Task { try await appRefreshWithDeadline(clock: clock, work: { await gate.hold(); return [1] }, fallback: { fallback = true; return [2] }) }
        await gate.entered.wait()
        task.cancel()
        gate.release()
        do { _ = try await task.value; XCTFail("cancelled refresh returned") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertFalse(fallback)
    }
}
