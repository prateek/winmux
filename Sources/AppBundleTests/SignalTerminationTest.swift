@testable import AppBundle
import Foundation
import XCTest

final class SignalTerminationTest: XCTestCase {
    @MainActor
    func testSignalHandlerCreatedOnMainActorCanRestoreOnBackgroundQueue() async {
        await withCheckedContinuation { continuation in
            let handler = SignalTermination().eventHandler(timeout: 0, restore: {
                XCTAssertFalse(Thread.isMainThread)
            }, cleanup: { _ in }, terminate: {
                continuation.resume()
            })
            DispatchQueue.global(qos: .userInitiated).async(execute: handler)
        }
    }

    func testRestorePrecedesCleanupAndBlockedCleanupCannotPreventExit() {
        let exit = expectation(description: "bounded exit")
        let handler = SignalTermination()
        var restored = false
        handler.run(timeout: 0, restore: { restored = true }, cleanup: { _ in
            XCTAssertTrue(restored)
            // Never completing cleanup represents a blocked main queue or AX request.
        }, terminate: { exit.fulfill() })
        wait(for: [exit], timeout: 1)
    }

    func testCleanupCompletionExitsOnceAndRepeatedSignalsDoNotRestartCleanup() {
        let exit = expectation(description: "cleanup exit")
        let handler = SignalTermination()
        handler.run(timeout: 0, restore: {}, cleanup: { finish in finish(); finish() }, terminate: { exit.fulfill() })
        handler.run(timeout: 0, restore: { XCTFail("restored twice") }, cleanup: { _ in XCTFail("cleanup twice") }, terminate: { XCTFail("exit twice") })
        wait(for: [exit], timeout: 1)
    }
}
