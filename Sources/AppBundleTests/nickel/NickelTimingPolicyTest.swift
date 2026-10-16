@testable import AppBundle
import Clocks
import Common
import Foundation
import XCTest

/// A byte channel that continues delivering replies after kill, as a slow dependency can.
final class ControlledNickelChannel: NickelByteChannel, @unchecked Sendable {
    let pid: Int32
    let chunks: AsyncStream<Data>
    private let sink: AsyncStream<Data>.Continuation
    private let lock = NSLock()
    private var requests: [[String: JSONValue]] = []
    private var expected: [(String, JSONValue?, Int)] = []
    private var killed = false
    private var closed = false
    init(pid: Int32) {
        self.pid = pid
        (chunks, sink) = AsyncStream.makeStream()
    }
    var wasKilled: Bool { lock.withLock { killed } }
    var wasClosed: Bool { lock.withLock { closed } }
    var lines: [[String: JSONValue]] { lock.withLock { requests } }
    func expect(_ op: String, reply: JSONValue? = nil, rss: Int = 10) {
        lock.withLock { expected.append((op, reply, rss)) }
    }
    func write(_ line: Data) throws {
        let request = try JSONDecoder().decode([String: JSONValue].self, from: line)
        let action = lock.withLock { () -> (String, JSONValue?, Int)? in
            requests.append(request)
            return expected.isEmpty ? nil : expected.removeFirst()
        }
        guard let action else { return XCTFail("Unconfigured controlled channel request: \(request["op"] ?? .null)") }
        XCTAssertEqual(request["op"], .string(action.0), "controlled channel request")
        if let result = action.1 { reply(to: request, result: result, rss: action.2) }
    }
    func reply(to request: [String: JSONValue], result: JSONValue, rss: Int = 10) {
        var data = try! JSONEncoder().encode(["id": request["id"]!, "ok": .bool(true), "result": result, "rss": .int(rss)])
        data.append(10)
        sink.yield(data)
    }
    func kill() { lock.withLock { killed = true } }
    func close() { lock.withLock { closed = true } }
    func crash() { sink.finish() }
}

@MainActor
final class ControlledNickelFactory {
    private(set) var channels: [ControlledNickelChannel] = []
    private var configured: [ControlledNickelChannel] = []
    deinit { for channel in channels + configured { channel.crash() } }
    func prepare(load: Bool = true) -> ControlledNickelChannel {
        let channel = ControlledNickelChannel(pid: Int32(1000 + channels.count + configured.count))
        if load { channel.expect("load", reply: .object(["config": .object([:])])) }
        configured.append(channel)
        return channel
    }
    func start(_ executable: URL) throws -> any NickelByteChannel {
        guard !configured.isEmpty else {
            XCTFail("Unconfigured controlled channel factory: start")
            throw CocoaError(.fileNoSuchFile)
        }
        let channel = configured.removeFirst()
        channels.append(channel)
        return channel
    }
}

@MainActor
final class NickelTimingPolicyTest: SerialClockTestCase {
    private func supervisor(_ clock: TestClock<Duration>, _ factory: ControlledNickelFactory,
                            adjust: (inout NickelSupervisor.Settings) -> Void = { _ in }) -> NickelSupervisor {
        var settings = NickelSupervisor.Settings()
        settings.executable = { URL(filePath: "/controlled-helper") }
        adjust(&settings)
        return NickelSupervisor(settings: settings, clock: clock, channel: factory.start)
    }
    private func adopt(_ supervisor: NickelSupervisor) async throws {
        supervisor.adopt(try await supervisor.load(nil).get())
    }
    private func drain(_ clock: TestClock<Duration>) async { await clock.advance() }

    func testCancelledFilterAndHookReturnImmediatelyWithoutKillingHelper() async throws {
        for op in ["filter", "hook"] {
            let clock = TestClock(), factory = ControlledNickelFactory()
            let channel = factory.prepare()
            let supervisor = supervisor(clock, factory)
            try await adopt(supervisor)
            channel.expect(op)
            var finished = false
            let task = Task { @MainActor in
                let result: Result<JSONValue, NickelFailure>
                if op == "filter" {
                    result = await supervisor.filter(lens: "all", context: .null, windows: []).map { .array($0.map(JSONValue.bool)) }
                } else { result = await supervisor.hook("arrive", args: []) }
                assertEquals(result, .failure(.cancelled))
                finished = true
            }
            await drain(clock)
            let held = channel.lines.last!
            task.cancel()
            await drain(clock)
            XCTAssertTrue(finished, "cancelled \(op) caller must return before any reply or deadline")
            XCTAssertFalse(channel.wasKilled)
            channel.expect("hook")
            var next: Result<JSONValue, NickelFailure>?
            let nextTask = Task { next = await supervisor.hook("next", args: []) }
            await drain(clock)
            channel.reply(to: held, result: .string("late"), rss: 99999)
            await drain(clock)
            XCTAssertNil(next, "late reply cannot reach the next caller")
            channel.reply(to: channel.lines.last!, result: .string("next"))
            await nextTask.value
            assertEquals(next, .success(.string("next")))
            await task.value
            channel.close()
        }
    }

    func testCancelledLoadKeepsWaitingForItsOwnReply() async throws {
        let clock = TestClock(), factory = ControlledNickelFactory()
        let channel = factory.prepare(load: false)
        let supervisor = supervisor(clock, factory)
        channel.expect("load")
        var finished = false
        let task = Task { @MainActor in
            let loaded = try await supervisor.load(nil).get()
            finished = true
            supervisor.discard(loaded)
        }
        await drain(clock)
        task.cancel()
        await drain(clock)
        XCTAssertFalse(finished)
        XCTAssertFalse(channel.wasKilled)
        channel.reply(to: channel.lines.last!, result: .object(["config": .object([:])]))
        try await task.value
        XCTAssertNil(supervisor.status.lastError)
    }

    func testLoadFilterAndHookDeadlinesRejectLateReplies() async throws {
        for op in ["load", "filter", "hook"] {
            let clock = TestClock(), factory = ControlledNickelFactory()
            let old = factory.prepare(load: op != "load")
            let supervisor = supervisor(clock, factory)
            if op != "load" { try await adopt(supervisor) }
            old.expect(op)
            var result: NickelFailure?
            var finished = false
            let request = Task { @MainActor in
                if op == "load" {
                    let r = await supervisor.load(nil)
                    if case .failure(let error) = r { result = error }
                } else if op == "filter" {
                    let r = await supervisor.filter(lens: "all", context: .null, windows: [])
                    if case .failure(let error) = r { result = error }
                } else {
                    let r = await supervisor.hook("arrive", args: [])
                    if case .failure(let error) = r { result = error }
                }
                finished = true
            }
            await drain(clock)
            let timeout: Duration = op == "load" ? .seconds(2) : op == "filter" ? .milliseconds(100) : .milliseconds(50)
            await clock.advance(by: timeout - .nanoseconds(1))
            XCTAssertFalse(finished, "\(op) must not finish early")
            XCTAssertFalse(old.wasKilled)
            let replacement = factory.prepare()
            await clock.advance(by: .nanoseconds(1))
            await request.value
            XCTAssertEqual(result, .timedOut)
            XCTAssertTrue(old.wasKilled)
            if op != "load" { XCTAssertEqual(supervisor.status.pid, replacement.pid, "timed-out serving helper restarts") }
            let status = supervisor.status
            old.reply(to: old.lines.last!, result: .array([.bool(false)]), rss: 99999)
            await drain(clock)
            XCTAssertEqual(supervisor.status, status, "late \(op) reply changes no status")
            if op == "load" { try await adopt(supervisor) }
            replacement.expect("hook", reply: .string("own answer"))
            assertEquals(await supervisor.hook("next", args: []), .success(.string("own answer")))
            replacement.close()
        }
    }
    func testBackoffDoublesToCapAndStreakResetsAfterFiveMinutes() async throws {
        let clock = TestClock(), factory = ControlledNickelFactory()
        var current = factory.prepare()
        let supervisor = supervisor(clock, factory) { $0.breakerCrashCount = 100 }
        try await adopt(supervisor)
        for delay in [0, 1, 2, 4, 8, 16, 30, 30] {
            let next = factory.prepare()
            let count = factory.channels.count
            current.crash()
            await drain(clock)
            if delay > 0 {
                XCTAssertEqual(supervisor.status.state, .restarting)
                await clock.advance(by: .seconds(delay) - .nanoseconds(1))
                XCTAssertEqual(factory.channels.count, count, "restart before \(delay)s")
                await clock.advance(by: .nanoseconds(1))
            }
            await drain(clock)
            XCTAssertEqual(supervisor.status.pid, next.pid)
            current = next
        }
        await clock.advance(by: .seconds(301))
        let next = factory.prepare()
        current.crash()
        await drain(clock)
        XCTAssertEqual(supervisor.status.pid, next.pid, "streak reset restarts at once")
        next.close()
    }

    func testBreakerWindowAndAdoptionClearsHistory() async throws {
        for spread in [false, true] {
            let clock = TestClock(), factory = ControlledNickelFactory()
            var current = factory.prepare()
            let supervisor = supervisor(clock, factory)
            var opened: [String] = []
            supervisor.onBreakerOpened = { opened.append($0) }
            try await adopt(supervisor)
            for round in 0 ..< 3 {
                let next = factory.prepare()
                if spread { await clock.advance(by: .seconds(31)) }
                current.crash()
                await drain(clock)
                if round == 2 && !spread { break }
                if round > 0 { await clock.advance(by: .seconds(1 << (round - 1))) }
                await drain(clock)
                XCTAssertEqual(supervisor.status.pid, next.pid)
                current = next
            }
            if spread {
                XCTAssertEqual(supervisor.status.state, .ready)
                XCTAssertTrue(opened.isEmpty)
            } else {
                XCTAssertEqual(supervisor.status.state, .failed)
                XCTAssertEqual(opened.count, 1)
                XCTAssertTrue(opened[0].contains("crashed 3 times within a minute"))
                try await adopt(supervisor)
                XCTAssertNil(supervisor.status.lastError)
                let next = factory.prepare()
                factory.channels.last!.crash()
                await drain(clock)
                XCTAssertEqual(supervisor.status.pid, next.pid, "adoption resets breaker and backoff")
                XCTAssertEqual(opened.count, 1)
            }
            factory.channels.last!.close()
        }
    }

    func testRecycleThrottleAtTenSeconds() async throws {
        let clock = TestClock(), factory = ControlledNickelFactory()
        let first = factory.prepare()
        let supervisor = supervisor(clock, factory) { $0.rssLimit = 100 }
        try await adopt(supervisor)
        let second = factory.prepare()
        first.expect("hook", reply: .null, rss: 101)
        _ = await supervisor.hook("fat", args: [])
        await drain(clock)
        XCTAssertEqual(supervisor.status.pid, second.pid)
        second.expect("hook", reply: .null, rss: 101)
        _ = await supervisor.hook("fat", args: [])
        await drain(clock)
        XCTAssertEqual(factory.channels.count, 2)
        await clock.advance(by: .seconds(10) - .nanoseconds(1))
        second.expect("hook", reply: .null, rss: 101)
        _ = await supervisor.hook("fat", args: [])
        await drain(clock)
        XCTAssertEqual(factory.channels.count, 2)
        await clock.advance(by: .nanoseconds(1))
        let third = factory.prepare()
        second.expect("hook", reply: .null, rss: 101)
        _ = await supervisor.hook("fat", args: [])
        await drain(clock)
        XCTAssertEqual(supervisor.status.pid, third.pid)
        third.close()
    }

    func testAdoptCancelsRestartBackoffAndRestartLoad() async throws {
        for duringLoad in [false, true] {
            let clock = TestClock(), factory = ControlledNickelFactory()
            let first = factory.prepare()
            let supervisor = supervisor(clock, factory)
            try await adopt(supervisor)
            let adoptedChannel = factory.prepare()
            let adopted = try await supervisor.load(nil).get()
            let second = factory.prepare()
            first.crash()
            await drain(clock)
            let restartLoad = factory.prepare(load: false)
            restartLoad.expect("load")
            second.crash()
            await drain(clock)
            if duringLoad { await clock.advance(by: .seconds(1)) }
            supervisor.adopt(adopted)
            let status = supervisor.status
            if duringLoad { restartLoad.reply(to: restartLoad.lines.last!, result: .object(["config": .object([:])]), rss: 99999) }
            await clock.advance(by: .seconds(5))
            XCTAssertEqual(supervisor.status, status, "cancelled restart cannot overwrite adopted state")
            XCTAssertEqual(supervisor.status.pid, adoptedChannel.pid)
            XCTAssertFalse(adoptedChannel.wasClosed)
            if duringLoad { XCTAssertTrue(restartLoad.wasClosed, "cancelled restart's loaded helper is discarded") }
            else { XCTAssertTrue(restartLoad.lines.isEmpty, "cancelled backoff starts no helper") }
            adoptedChannel.close()
        }
    }

    func testRecycleCannotInstallOverAdoptionOrCrashRestart() async throws {
        for crash in [false, true] {
            let clock = TestClock(), factory = ControlledNickelFactory()
            let first = factory.prepare()
            let supervisor = supervisor(clock, factory) { $0.rssLimit = 100 }
            try await adopt(supervisor)
            let recycling = factory.prepare(load: false)
            recycling.expect("load")
            first.expect("hook", reply: .null, rss: 101)
            _ = await supervisor.hook("fat", args: [])
            await drain(clock)
            let newest = factory.prepare()
            if crash { first.crash(); await drain(clock) }
            else { try await adopt(supervisor) }
            XCTAssertEqual(supervisor.status.pid, newest.pid)
            let status = supervisor.status
            recycling.reply(to: recycling.lines.last!, result: .object(["config": .object([:])]), rss: 99999)
            await drain(clock)
            XCTAssertEqual(supervisor.status, status, "cancelled recycle cannot overwrite newer state")
            XCTAssertTrue(recycling.wasClosed, "obsolete recycle helper is discarded")
            XCTAssertFalse(newest.wasClosed, "obsolete recycle cannot close newest helper")
            XCTAssertEqual(supervisor.status.pid, newest.pid)
            newest.close()
        }
    }

    func testOldRequestTimeoutCannotOverwriteAdoptedHelpersStatus() async throws {
        let clock = TestClock(), factory = ControlledNickelFactory()
        let old = factory.prepare()
        let supervisor = supervisor(clock, factory)
        try await adopt(supervisor)
        old.expect("hook")
        let request = Task { await supervisor.hook("held", args: []) }
        await drain(clock)
        let current = factory.prepare()
        try await adopt(supervisor)
        supervisor.recordFailedReload("newer operation")
        let status = supervisor.status
        await clock.advance(by: .milliseconds(50))
        assertEquals(await request.value, .failure(.timedOut))
        XCTAssertEqual(supervisor.status, status)
        XCTAssertFalse(current.wasClosed)
        current.close()
    }

    func testOldSuccessfulReplyCannotOverwriteAdoptedHelpersStatus() async throws {
        let clock = TestClock(), factory = ControlledNickelFactory()
        let old = factory.prepare()
        let supervisor = supervisor(clock, factory)
        try await adopt(supervisor)
        old.expect("hook")
        let request = Task { await supervisor.hook("held", args: []) }
        await drain(clock)
        let current = factory.prepare()
        try await adopt(supervisor)
        supervisor.recordFailedReload("newer operation")
        let status = supervisor.status
        old.reply(to: old.lines.last!, result: .string("older caller"), rss: 99999)
        assertEquals(await request.value, .success(.string("older caller")))
        XCTAssertEqual(supervisor.status, status, "older caller keeps its result without replacing serving helper state")
        XCTAssertFalse(current.wasClosed)
        current.close()
    }

}
