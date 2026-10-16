import XCTest
@testable import AppBundle

final class ConfigReloadStateTest: XCTestCase {
    func testOnlyNewestUnadoptedLoadCanBeginInEitherCompletionOrder() {
        for olderFirst in [true, false] {
            var state = ConfigReloadState()
            let a = state.requested(dryRun: false).id
            let b = state.requested(dryRun: false).id
            if olderFirst {
                XCTAssertEqual(state.loaded(a), .supersede)
                XCTAssertNil(state.applying)
            }
            XCTAssertEqual(state.loaded(b), .begin)
            XCTAssertEqual(state.applying, b)
            if !olderFirst { XCTAssertEqual(state.loaded(a), .supersede) }
            XCTAssertNil(state.applicationFinished(b))
            XCTAssertNil(state.applying)
        }
    }

    func testPendingIsAuthoritativeAndNewRequestSupersedesIt() {
        var state = ConfigReloadState()
        let a = state.requested(dryRun: false).id
        XCTAssertEqual(state.loaded(a), .begin)
        let b = state.requested(dryRun: false).id
        XCTAssertEqual(state.loaded(b), .wait)
        XCTAssertEqual(state.pending, b)
        XCTAssertEqual(state.applying, a)
        let c = state.requested(dryRun: false)
        XCTAssertEqual(c.superseded, b)
        XCTAssertNil(state.pending)
        XCTAssertEqual(state.loaded(c.id), .wait)
        XCTAssertEqual(state.applicationFinished(a), c.id)
        XCTAssertEqual(state.applying, c.id)
        XCTAssertNil(state.pending)
        XCTAssertNil(state.applicationFinished(c.id))
    }

    func testDryRequestDoesNotAlterOrdinaryOrdering() {
        var state = ConfigReloadState()
        let ordinary = state.requested(dryRun: false).id
        let dry = state.requested(dryRun: true)
        XCTAssertNil(dry.superseded)
        XCTAssertEqual(state.newest, ordinary)
        XCTAssertEqual(state.loaded(ordinary), .begin)
        XCTAssertNil(state.applicationFinished(ordinary))
    }

    func testFallbackHoldsTheSameApplicationSlotWithoutSupersedingLoads() {
        var state = ConfigReloadState()
        let ordinary = state.requested(dryRun: false).id
        let fallback = state.beginFallback()
        XCTAssertEqual(state.newest, ordinary)
        XCTAssertEqual(state.loaded(ordinary), .wait)
        XCTAssertEqual(state.applicationFinished(fallback), ordinary)
        XCTAssertNil(state.applicationFinished(ordinary))
    }
    func testDepartedPendingAttemptLeavesNoTurnToHandOff() {
        var state = ConfigReloadState()
        let applying = state.requested(dryRun: false).id
        XCTAssertEqual(state.loaded(applying), .begin)
        let pending = state.requested(dryRun: false).id
        XCTAssertEqual(state.loaded(pending), .wait)
        state.pendingDeparted(pending)
        XCTAssertNil(state.pending)
        XCTAssertNil(state.applicationFinished(applying))
        let newer = state.requested(dryRun: false).id
        XCTAssertEqual(state.loaded(newer), .begin)
        let next = state.requested(dryRun: false).id
        XCTAssertEqual(state.loaded(next), .wait)
        state.pendingDeparted(pending)
        XCTAssertEqual(state.pending, next, "an older cancellation cannot remove a newer waiter")
    }

}
