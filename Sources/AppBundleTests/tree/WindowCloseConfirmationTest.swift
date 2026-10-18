@testable import AppBundle
import Clocks
import XCTest

@MainActor
final class WindowCloseConfirmationTest: SerialClockTestCase {
    func testGoneWindowCollectsOnceWithoutWaitingOrReadingSheets() async {
        let clock = TestClock<Duration>()
        let start = clock.now
        var collections = 0
        let gone = await confirmWindowClose(timeout: 1, clock: clock,
            isPresent: { false },
            hasSheet: { XCTFail("A gone window has no sheet to read"); return false },
            collect: { collections += 1 })
        XCTAssertEqual(gone, .gone)
        XCTAssertEqual(collections, 1)
        XCTAssertEqual(clock.now, start)
    }

    func testSheetReturnsImmediatelyWithoutCollecting() async {
        let clock = TestClock<Duration>()
        let start = clock.now
        let gone = await confirmWindowClose(timeout: 1, clock: clock,
            isPresent: { true }, hasSheet: { true },
            collect: { XCTFail("A sheet must keep its window") })
        XCTAssertEqual(gone, .sheetSeen)
        XCTAssertEqual(clock.now, start)
    }

    func testPollChecksEveryHundredMillisecondsAndStopsAtOneSecond() async {
        let clock = TestClock<Duration>()
        var reads = 0
        var finished = false
        let task = Task { @MainActor in
            let result = await confirmWindowClose(timeout: 1, clock: clock,
                isPresent: { reads += 1; return reads == 1 ? nil : true },
                hasSheet: { false }, collect: { XCTFail("Unknown or present is not gone") })
            finished = true
            return result
        }
        await clock.advance()
        XCTAssertEqual(reads, 1)
        await clock.advance(by: .milliseconds(99))
        XCTAssertEqual(reads, 1)
        await clock.advance(by: .milliseconds(1))
        XCTAssertEqual(reads, 2)
        await clock.advance(by: .milliseconds(899))
        XCTAssertFalse(finished)
        await clock.advance(by: .milliseconds(1))
        let gone = await task.value
        XCTAssertEqual(gone, .timedOut)
        XCTAssertEqual(reads, 10)
    }

    func testDisappearanceOnTheNextPollCollectsOnce() async {
        let clock = TestClock<Duration>()
        var present = true
        var collections = 0
        let task = Task { @MainActor in
            await confirmWindowClose(timeout: 1, clock: clock,
                isPresent: { present }, hasSheet: { false }, collect: { collections += 1 })
        }
        await clock.advance()
        present = false
        await clock.advance(by: .milliseconds(100))
        let gone = await task.value
        XCTAssertEqual(gone, .gone)
        XCTAssertEqual(collections, 1)
    }
}
