import XCTest

struct NickelLatencyLimits {
    let filter: Duration
    let hook: Duration

    let strict: Bool

    /// A shared runner has measured 76.9 ms and 5.0 ms where the build machine measures 1.6 and 0.5.
    init(environment: [String: String]) {
        let value = environment["WINMUX_NICKEL_STRICT_LATENCY"] ?? ""
        strict = !["", "0"].contains(value)
        filter = .milliseconds(strict ? 10 : 250)
        hook = .milliseconds(strict ? 2 : 50)
    }
}

final class NickelLatencyLimitsTest: XCTestCase {
    func testSharedRunnerBoundAndExplicitLocalBenchmark() {
        for (value, strict) in [(nil, false), ("", false), ("0", false), ("1", true)] as [(String?, Bool)] {
            let environment = value.map { ["WINMUX_NICKEL_STRICT_LATENCY": $0] } ?? [:]
            let limits = NickelLatencyLimits(environment: environment)
            XCTAssertEqual(limits.filter, .milliseconds(strict ? 10 : 250), "\(value ?? "unset")")
            XCTAssertEqual(limits.hook, .milliseconds(strict ? 2 : 50), "\(value ?? "unset")")
        }
    }
}
