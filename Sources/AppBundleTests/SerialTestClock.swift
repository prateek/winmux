import Clocks
import ConcurrencyExtras

// TestClock's background-priority megaYield can starve under CPU load. Clock
// advancement uses the library's test-only serial executor, not idle CPU time.
final class SerialTestClock: Clock, @unchecked Sendable {
    typealias Duration = Swift.Duration
    typealias Instant = Clocks.TestClock<Duration>.Instant

    private let base = Clocks.TestClock<Duration>()
    var now: Instant { base.now }
    var minimumResolution: Duration { base.minimumResolution }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        try await base.sleep(until: deadline, tolerance: tolerance)
    }

    @MainActor
    func advance(by duration: Duration = .zero) async {
        await withMainSerialExecutor { await base.advance(by: duration) }
    }

    @MainActor
    func checkSuspension() async throws {
        try await withMainSerialExecutor { try await base.checkSuspension() }
    }
}
