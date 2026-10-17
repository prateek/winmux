@testable import AppBundle
import AppKit
import Clocks
import Common
import XCTest

@MainActor
final class LensSessionStatisticsTest: SerialClockTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testPresentedDurationAndCaptureCountsSurviveDismissalInBothReaders() async throws {
        let clock = TestClock<Duration>()
        let epoch = clock.now
        let store = LensTraceStore(stamp: {
            let elapsed = epoch.duration(to: clock.now).components
            return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        })
        let trace = store.begin(presentation: "grid", origin: .init(start: 0, received: 0, source: "test"))
        var statistics: LensSessionStatistics?
        var dependencies = LensLifecycle.Dependencies(evaluate: { _, _, _ in .success([]) },
            requestThumbnail: { _, _, _ in }, closeThumbnails: { _ in }, flags: { [] })
        dependencies.observeThumbnails = { _, value in statistics = value }
        let owner = LensLifecycle(clock: clock, dependencies: dependencies, emit: { _ in }, show: { _ in }, hide: {})
        var settings = LensConfig(); settings.presentation = "grid"
        let model = LensSession(name: "windows", settings: settings, items: [], search: "")
        await clock.advance(by: .milliseconds(40))
        owner.complete(model, ticket: owner.begin("windows", toggle: false, trace: trace)!)
        await clock.advance(by: .seconds(30))
        let counters = try XCTUnwrap(statistics)
        counters.requestedCapture(); counters.requestedCapture(); counters.completedCapture()
        XCTAssertEqual(trace.snapshot.session?.presentedMs ?? -1, 30_000, accuracy: 0.001)
        owner.dismiss()
        await clock.advance(by: .seconds(5))
        counters.requestedCapture(); counters.completedCapture()
        let result = try XCTUnwrap(trace.snapshot.session)
        XCTAssertEqual(result.capturesRequested, 2)
        XCTAssertEqual(result.capturesCompleted, 1)
        XCTAssertEqual(result.presentedMs, 30_000, accuracy: 0.001)
        XCTAssertNil(result.droppedFrames)
        XCTAssertNil(result.longestFrameIntervalMs)
        XCTAssertTrue(store.text(last: 1).contains("captures-requested=2 captures-completed=1 presented=30000.000ms"))
        XCTAssertEqual(try JSONDecoder().decode([LensTraceSnapshot].self, from: Data(store.json(last: 1).utf8))[0].session, result)
        try await clock.checkSuspension()
    }

    func testInjectedFrameSourceCountsLongIntervalsAndStopsAtDismissal() throws {
        let statistics = LensSessionStatistics(stamp: { 0 })
        statistics.presented()
        var tick: ((Double, Double) -> Void)?
        var stops = 0
        statistics.observeFrames { callback in
            tick = callback
            return { stops += 1 }
        }
        let send = try XCTUnwrap(tick)
        send(1, 0.02)
        send(1.02, 0.02)
        send(1.049, 0.02)
        send(1.080, 0.02)
        send(1.140, 0.02)
        XCTAssertEqual(statistics.droppedFrames, 2)
        XCTAssertEqual(statistics.longestFrameIntervalMs ?? -1, 60, accuracy: 0.0001)
        statistics.stop()
        send(2, 0.02)
        statistics.stop()
        XCTAssertEqual(stops, 1)
        XCTAssertEqual(statistics.droppedFrames, 2)
    }

    func testNeverPresentedAndDisabledFrameObservationReportNoSamples() {
        let statistics = LensSessionStatistics(stamp: { 42 })
        XCTAssertEqual(statistics.presentedMs, 0)
        statistics.observeFrames { _ in XCTFail("An unpresented Lens must not subscribe"); return {} }
        statistics.requestedCapture(); statistics.completedCapture()
        XCTAssertEqual(statistics.capturesRequested, 0)
        XCTAssertEqual(statistics.capturesCompleted, 0)
        XCTAssertNil(statistics.droppedFrames)
        statistics.presented()
        statistics.observeFrames(enabled: false) { _ in XCTFail("A disabled observer must cost no display link"); return {} }
        XCTAssertNil(statistics.droppedFrames)
        statistics.stop()
        let cancelled = LensSessionStatistics(stamp: { 42 })
        cancelled.stop()
        cancelled.presented()
        XCTAssertEqual(cancelled.presentedMs, 0)
    }

    func testFrameObservationReportsThroughTraceReadersAndIgnoresInvalidTicks() throws {
        let store = LensTraceStore(stamp: { 0 })
        let trace = store.begin(presentation: "grid", origin: .init(start: 0, received: 0, source: "test"))
        var settings = LensConfig(); settings.presentation = "grid"
        let model = LensSession(name: "windows", settings: settings, items: [], search: "")
        let owner = testLensLifecycle()
        var tick: LensSessionStatistics.Tick?
        var subscriptions = 0
        owner.observeFrames = { statistics in
            statistics.observeFrames { callback in tick = callback; subscriptions += 1; return {} }
        }
        owner.complete(model, ticket: owner.begin("windows", toggle: false, trace: trace)!)
        owner.presented(model)
        XCTAssertEqual(subscriptions, 1)
        let send = try XCTUnwrap(tick)
        send(.nan, 0.02); send(0, 0); send(1, 0.02); send(0.5, 0.02); send(1.02, 0.02); send(1.06, 0.02)
        owner.dismiss()
        XCTAssertEqual(trace.snapshot.session?.droppedFrames, 1)
        XCTAssertTrue(store.text(last: 1).contains("Frames: dropped=1 longest-interval=40.000ms"))
        let result = try JSONDecoder().decode([LensTraceSnapshot].self, from: Data(store.json(last: 1).utf8))[0]
        XCTAssertEqual(result.session?.droppedFrames, 1)
        XCTAssertEqual(result.session?.longestFrameIntervalMs ?? -1, 40, accuracy: 0.0001)
    }
}
