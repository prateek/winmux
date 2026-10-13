import XCTest

struct NickelLatencyLimits {
    let filter: Duration
    let hook: Duration

    init(environment: [String: String]) {
        let strict = environment["WINMUX_NICKEL_STRICT_LATENCY"] != nil
        filter = .milliseconds(strict ? 10 : 100)
        hook = .milliseconds(strict ? 2 : 20)
    }
}

final class NickelLatencyLimitsTest: XCTestCase {
    func testSharedRunnerBoundAndExplicitLocalBenchmark() {
        for value in [nil, "", "0", "1"] as [String?] {
            let environment = value.map { ["WINMUX_NICKEL_STRICT_LATENCY": $0] } ?? [:]
            let limits = NickelLatencyLimits(environment: environment)
            XCTAssertEqual(limits.filter, .milliseconds(value != nil ? 10 : 100))
            XCTAssertEqual(limits.hook, .milliseconds(value != nil ? 2 : 20))
        }
    }
}
