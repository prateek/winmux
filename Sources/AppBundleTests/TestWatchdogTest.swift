import Foundation
import TestWatchdog
import XCTest

final class TestWatchdogTest: XCTestCase {
    func testTimeoutNamesTheRunningTest() {
        let fired = expectation(description: "watchdog fired")
        let watchdog = WMTestWatchdog(seconds: 0.02) { name in
            XCTAssertEqual(name, "Suite.testBlocked")
            fired.fulfill()
        }
        watchdog.startTest("Suite.testBlocked")
        wait(for: [fired], timeout: 1)
    }

    func testFinishingAndReplacingTestsCancelsTheirDeadlines() {
        let fired = expectation(description: "only the current test expires")
        fired.assertForOverFulfill = true
        let watchdog = WMTestWatchdog(seconds: 0.02) { name in
            XCTAssertEqual(name, "Suite.testCurrent")
            fired.fulfill()
        }
        watchdog.startTest("Suite.testFinished")
        watchdog.finishTest("Suite.testFinished")
        watchdog.startTest("Suite.testReplaced")
        watchdog.startTest("Suite.testCurrent")
        watchdog.finishTest("Suite.testReplaced")
        wait(for: [fired], timeout: 1)
        watchdog.finishTest("Suite.testCurrent")
    }
}
