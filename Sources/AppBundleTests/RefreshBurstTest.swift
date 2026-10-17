@testable import AppBundle
import AppKit
import Clocks
import Common
import XCTest

@MainActor
final class RefreshBurstTest: SerialClockTestCase {
    override func tearDown() async throws {
        setScheduledRefreshOverrideForTests(nil)
        try await super.tearDown()
    }

    func testTenEventsCoalesceWithoutCancellationAndKeepStrongestEventInEitherOrder() async throws {
        for reverse in [false, true] {
            let clock = TestClock<Duration>(), first = ReloadGate(), follow = ReloadGate()
            var events: [String] = [], optimistic: [Bool] = [], cancelled = false
            setScheduledRefreshOverrideForTests { event, prelayout in
                events.append(event.description)
                optimistic.append(prelayout)
                if events.count == 1 { await first.hold(); cancelled = Task.isCancelled }
                else if events.count == 2 { await follow.hold() }
                else { XCTFail("unexpected extra refresh") }
            }
            scheduleRefreshSession(.onTabSwitched)
            await first.entered.wait()
            for index in 0 ..< 10 {
                let barrier = reverse ? index == 0 : index == 9
                scheduleRefreshSession(barrier ? .configAutoReload : .onTabSwitched, optimisticallyPreLayoutWorkspaces: index == 3)
            }
            XCTAssertEqual(events.count, 1)
            first.release()
            await follow.entered.wait()
            XCTAssertFalse(cancelled)
            XCTAssertEqual(events, ["onTabSwitched", "configAutoReload"])
            XCTAssertEqual(optimistic, [false, true])
            follow.release()
            try await waitForScheduledRefreshForTests()
            await clock.advance()
            XCTAssertEqual(events.count, 2)
        }
    }

    func testContinuousBurstCompletesOneSessionPerRoundAndKeepsLastEvent() async throws {
        let gates = (0 ..< 5).map { _ in ReloadGate() }
        var events: [String] = [], completed = 0
        setScheduledRefreshOverrideForTests { event, _ in
            let index = events.count
            events.append(event.description)
            guard index < gates.count else { return XCTFail("extra refresh") }
            await gates[index].hold()
            XCTAssertFalse(Task.isCancelled)
            completed += 1
        }
        scheduleRefreshSession(.onTabSwitched)
        for round in 0 ..< gates.count {
            await gates[round].entered.wait()
            if round < gates.count - 1 {
                for _ in 0 ..< 10 { scheduleRefreshSession(round == 3 ? .startup : .onFocusChanged) }
            }
            gates[round].release()
        }
        try await waitForScheduledRefreshForTests()
        XCTAssertEqual(completed, 5)
        XCTAssertEqual(events.last, "startup")
    }

    func testGeometryIsDroppedOnlyWhileGeometryOrMouseResetIsActiveOrPending() async throws {
        for active in [RefreshSessionEvent.ax(kAXMovedNotification as String), .resetManipulatedWithMouse, .onTabSwitched] {
            for pending in [false, true] {
                let clock = TestClock<Duration>(), gate = ReloadGate()
                var events: [String] = []
                setScheduledRefreshOverrideForTests { event, _ in
                    events.append(event.description)
                    if events.count == 1 { await gate.hold() }
                }
                scheduleRefreshSession(pending ? .onTabSwitched : active)
                await gate.entered.wait()
                if pending { scheduleRefreshSession(active) }
                scheduleRefreshSession(.ax(kAXResizedNotification as String))
                gate.release()
                try await waitForScheduledRefreshForTests()
                await clock.advance()
                if active.description == "onTabSwitched" {
                    XCTAssertEqual(events.last, "ax(AXResized)")
                } else {
                    XCTAssertEqual(events.count, pending ? 2 : 1)
                    XCTAssertEqual(events.last, active.description)
                }
            }
        }
    }

    func testWaitingDoesNotClearSchedulerStateOrStartConcurrentSession() async throws {
        let clock = TestClock<Duration>(), first = ReloadGate(), next = ReloadGate()
        var running = 0, maximum = 0, count = 0
        setScheduledRefreshOverrideForTests { _, _ in
            count += 1; running += 1; maximum = max(maximum, running)
            if count == 1 { await first.hold() } else { await next.hold() }
            running -= 1
        }
        scheduleRefreshSession(.startup)
        await first.entered.wait()
        let waiter = Task { try await waitForScheduledRefreshForTests() }
        await clock.advance()
        scheduleRefreshSession(.onFocusChanged)
        await clock.advance()
        XCTAssertEqual(count, 1, "waiting must not relinquish the scheduler's ownership")
        first.release()
        await next.entered.wait()
        next.release()
        try await waiter.value
        XCTAssertEqual(maximum, 1)
    }

    func testOlderCancelledSessionCannotDrainOrClearNewerSessionsPendingWork() async throws {
        setUpWorkspacesForTests()
        let clock = TestClock<Duration>(), old = ReloadGate(), newer = ReloadGate(), last = ReloadGate()
        var events: [String] = [], oldCancelled = false
        setScheduledRefreshOverrideForTests { event, _ in
            events.append(event.description)
            switch events.count {
                case 1: await old.hold(); oldCancelled = Task.isCancelled
                case 2: await newer.hold()
                case 3: await last.hold()
                default: XCTFail("old session drained newer pending work")
            }
        }
        scheduleRefreshSession(.startup)
        await old.entered.wait()
        try await runLightSession(.onTabSwitched, .forceRun, shouldSchedulePostRefresh: false) {}
        scheduleRefreshSession(.onFocusChanged)
        await newer.entered.wait()
        scheduleRefreshSession(.configAutoReload)
        old.release()
        await clock.advance()
        XCTAssertTrue(oldCancelled)
        XCTAssertEqual(events.count, 2, "old defer must not drain newer pending request")
        scheduleRefreshSession(.onTabSwitched)
        await clock.advance()
        XCTAssertEqual(events.count, 2, "old defer must not clear newer active task")
        newer.release()
        await last.entered.wait()
        XCTAssertEqual(events.last, "configAutoReload")
        last.release()
        try await waitForScheduledRefreshForTests()
    }
}
