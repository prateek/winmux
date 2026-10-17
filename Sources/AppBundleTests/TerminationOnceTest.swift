@testable import AppBundle
import XCTest

@MainActor
final class TerminationOnceTest: XCTestCase {
    func testCompletionAndDeadlineReplyOnlyOnce() {
        var replies = 0
        let reply = ApplicationTerminationReply { replies += 1 }
        reply.finish()
        reply.finish()
        XCTAssertEqual(replies, 1)
    }

    func testCleanupFailureStillFinishesAndIsNotRetried() async {
        let gate = TerminationOnce()
        do {
            try await gate.run { throw CancellationError() }
            XCTFail("expected cleanup failure")
        } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(gate.isFinished)
        do {
            try await gate.run { XCTFail("retried cleanup") }
            XCTFail("expected the original cleanup failure")
        } catch { XCTAssertTrue(error is CancellationError) }
    }

    func testMenuDelegateSignalAndFatalCleanupShareOneCompletion() async throws {
        let gate = TerminationOnce()
        var calls = 0
        var release: CheckedContinuation<Void, Never>?
        let started = expectation(description: "cleanup started")
        let menu = Task {
            try await gate.run {
                calls += 1
                await withCheckedContinuation { release = $0; started.fulfill() }
            }
        }
        await fulfillment(of: [started], timeout: 1)
        XCTAssertFalse(gate.isFinished)
        let signal = Task { try await gate.run { XCTFail("signal repeated cleanup") } }
        release?.resume()
        try await menu.value
        try await signal.value
        try await gate.run { XCTFail("delegate repeated menu cleanup") }
        try await gate.run { XCTFail("fatal path repeated cleanup") }
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(gate.isFinished)
    }
}
