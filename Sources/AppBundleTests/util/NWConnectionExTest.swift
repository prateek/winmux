@testable import Common
import Network
import XCTest

final class NWConnectionExTest: XCTestCase {
    func testStartBlockingTimesOutForMissingUnixSocket() async {
        let socketPath = "/tmp/winmux-missing-\(UUID().uuidString).sock"
        let connection = NWConnection(to: .unix(path: socketPath), using: .tcp)
        let start = Date()

        let result = await connection.startBlocking(timeoutNanoseconds: 100_000_000)

        XCTAssertNotNil(result.error)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.0)
    }
}
