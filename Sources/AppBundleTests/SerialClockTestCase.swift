import ConcurrencyExtras
import XCTest

// TestClock's background-priority megaYield can starve under CPU load. Scope
// the whole test so scheduling cancellation is controlled as well as advancing.
class SerialClockTestCase: XCTestCase {
    override func invokeTest() {
        withMainSerialExecutor {
            super.invokeTest()
        }
    }
}
