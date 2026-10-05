@testable import AppBundle
import AppKit
import Clocks
import Common
import XCTest

@MainActor
final class LensTraceTest: XCTestCase {
    func testKeysContinueAfterFirstFrameWithoutChangingStagesAndStayBounded() {
        var now = 10.0
        let store = LensTraceStore(stamp: { now })
        let trace = store.begin(presentation: "strip", origin: .init(start: 10, received: 10, source: "test"))
        trace.finish(signal: "test")
        let before = trace.snapshot
        now = 11
        for _ in 0..<300 {
            trace.key(code: 4, characters: "h", flags: .command, timestamp: 10.9,
                      presentation: "list", hold: true, path: "sendEvent", destination: "Search",
                      search: "gh", selectedId: 7, fieldEditor: false)
        }
        XCTAssertEqual(trace.snapshot.stages, before.stages)
        XCTAssertEqual(trace.snapshot.totalMs, before.totalMs)
        XCTAssertEqual(trace.snapshot.keys.count, 256)
        XCTAssertEqual(trace.snapshot.keys.last?.receivedAt, 11)
        XCTAssertEqual(trace.snapshot.keys.last?.search, "gh")
        XCTAssertTrue(store.text(last: 1).contains("sendEvent Search"))
    }

    func testStagesUseInjectedClockAndExposeGapsAndBoundedHistory() throws {
        var now = 10.0
        let store = LensTraceStore(capacity: 2, stamp: { now })
        let trace = store.begin(presentation: "strip", origin: .init(start: 9.998, received: 10, source: "Carbon"))
        now = 10.003; trace.advance("binding resolved")
        now = 10.010; trace.advance("windows collected")
        now = 10.012; trace.advance("Filter evaluated")
        now = 10.015; trace.advance("session ready")
        now = 10.100; trace.advance("display delay")
        now = 10.102; trace.advance("view built")
        now = 10.104; trace.advance("panel ordered front")
        now = 10.110; trace.advance("first layout")
        now = 10.111; trace.advance("first-frame thumbnails ready")
        now = 10.125; trace.finish(signal: "test")
        let rows = store.snapshots(last: 1)
        XCTAssertEqual(rows[0].stages.map(\.name), ["event reaching WinMux", "binding resolved", "windows collected", "Filter evaluated", "session ready", "display delay", "view built", "panel ordered front", "first layout", "first-frame thumbnails ready", "first frame presented"])
        XCTAssertEqual(rows[0].totalMs, 127, accuracy: 0.0001)
        XCTAssertEqual(rows[0].stages[2].durationMs, 7, accuracy: 0.0001)
        XCTAssertTrue(store.text(last: 1).contains("127.000"))
        XCTAssertEqual(try JSONDecoder().decode([LensTraceSnapshot].self, from: Data(store.json(last: 1).utf8)), rows)
        for name in ["list", "miniatures"] { store.begin(presentation: name, origin: .init(start: now, received: now, source: "CLI")).finish(signal: "test") }
        XCTAssertEqual(store.snapshots(last: 10).map(\.presentation), ["list", "miniatures"])
        XCTAssertFalse(store.snapshots(last: 2).flatMap(\.stages).contains { $0.name == "display delay" })
    }

    func testLifecycleTracesAllPresentationsOnControlledClock() async throws {
        for presentation in ["strip", "list", "miniatures"] {
            let clock = TestClock<Duration>()
            let epoch = clock.now
            let store = LensTraceStore(stamp: {
                let duration = epoch.duration(to: clock.now).components
                return Double(duration.seconds) + Double(duration.attoseconds) / 1e18
            })
            let trace = store.begin(presentation: presentation, origin: .init(start: 0, received: 0, source: "test"))
            await clock.advance(by: .milliseconds(2)); trace.advance("binding resolved")
            await clock.advance(by: .milliseconds(3)); trace.advance("windows collected")
            await clock.advance(by: .milliseconds(4)); trace.advance("Filter evaluated")
            let prepareView = { (_: LensSession) in
                trace.advance("view built")
                trace.advance("first layout")
                trace.advance("first-frame thumbnails ready")
            }
            let owner = testLensLifecycle(clock: clock, show: { model in
                if presentation != "strip" { prepareView(model) }
                trace.advance("panel ordered front")
            })
            owner.prepare = prepareView
            let gesture = StripGesture(keyCode: 48, invoking: .command, clock: clock)
            let ticket = owner.begin("demo", toggle: false, strip: presentation == "strip" ? gesture : nil, trace: trace)!
            var settings = LensConfig(); settings.presentation = presentation
            let model = LensSession(name: "demo", settings: settings, items: [], search: "")
            await clock.advance(by: .milliseconds(1))
            XCTAssertTrue(owner.complete(model, ticket: ticket))
            if presentation == "strip" { await clock.advance(by: .milliseconds(99)) }
            await clock.advance(by: .milliseconds(16))
            trace.finish(signal: "controlled presentation")
            let snapshot = store.snapshots(last: 1)[0]
            XCTAssertEqual(snapshot.totalMs, presentation == "strip" ? 125 : 26, accuracy: 0.00001)
            XCTAssertEqual(snapshot.stages.contains { $0.name == "display delay" }, presentation == "strip")
            var end = 0.0
            for stage in snapshot.stages {
                XCTAssertLessThanOrEqual(stage.startMs - end, 5)
                if stage.name == "gap" { XCTAssertLessThanOrEqual(stage.durationMs, 5) }
                end = stage.startMs + stage.durationMs
            }
            XCTAssertEqual(snapshot.stages.map(\.name), ["event reaching WinMux", "binding resolved", "windows collected", "Filter evaluated", "session ready", "view built", "first layout", "first-frame thumbnails ready"] + (presentation == "strip" ? ["display delay"] : []) + ["panel ordered front", "first frame presented"])
            XCTAssertEqual(try JSONDecoder().decode([LensTraceSnapshot].self, from: Data(store.json(last: 1).utf8)), [snapshot])
            XCTAssertTrue(store.text(last: 1).contains("first frame presented"))
            owner.dismiss()
            try await clock.checkSuspension()
        }
    }

    func testReaderNamesTimeOutsideAnIntervalAsAGap() {
        var now = 0.0
        let store = LensTraceStore(stamp: { now })
        let trace = store.begin(presentation: "list", origin: .init(start: 0, received: 0, source: "CLI"))
        now = 0.010; trace.advance("binding resolved")
        now = 0.022; trace.startInterval("windows collected")
        now = 0.030; trace.advance("windows collected")
        trace.finish(signal: "test")
        let gap = store.snapshots(last: 1)[0].stages.first { $0.name == "gap" }
        XCTAssertEqual(gap?.startMs, 10)
        XCTAssertEqual(gap?.durationMs ?? -1, 12, accuracy: 0.00001)
        XCTAssertTrue(store.text(last: 1).contains("gap"))
    }

    func testNativeEventOriginIncludesDispatchTimeOnTheSameClock() throws {
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 42.125, windowNumber: 0, context: nil, characters: "r", charactersIgnoringModifiers: "r", isARepeat: false, keyCode: 15))
        let origin = LensTraceOrigin(event: event, received: 42.130)
        let store = LensTraceStore(stamp: { 42.140 })
        store.begin(presentation: "list", origin: origin).finish(signal: "controlled native input")
        let result = store.snapshots(last: 1)[0]
        XCTAssertEqual(result.source, "NSEvent")
        XCTAssertEqual(result.totalMs, 15, accuracy: 0.00001)
        XCTAssertEqual(result.stages[0].durationMs, 5, accuracy: 0.00001)
    }

    func testTimebaseConversionsAndRequestRoundTrip() throws {
        let timebase = LensTimebase(numerator: 125, denominator: 3)
        XCTAssertEqual(timebase.seconds(ticks: 24_000_000), 1, accuracy: 0.00001)
        let request = ClientRequest(args: ["lens", "recent"], stdin: "", windowId: nil, workspace: nil, sentAt: 42.125)
        XCTAssertEqual(try JSONDecoder().decode(ClientRequest.self, from: JSONEncoder().encode(request)).sentAt, 42.125)
    }

    func testCommandReadsTheCompletedOpeningAsTextAndJSON() async throws {
        let now = LensTimebase.now()
        let trace = LensTraceStore.shared.begin(presentation: "list", origin: .init(start: now, received: now, source: "test"))
        trace.advance("binding resolved", at: now + 0.002)
        trace.finish(signal: "controlled presentation", at: now + 0.020)
        for json in [false, true] {
            let command = parseCommand("debug-lens-trace --last 1" + (json ? " --json" : "")).cmdOrDie
            let io = CmdIo(stdin: .emptyStdin)
            let succeeded = try await command.run(.defaultEnv, io)
            XCTAssertTrue(succeeded)
            XCTAssertTrue(io.stderr.isEmpty)
            if json {
                let result = try JSONDecoder().decode([LensTraceSnapshot].self, from: Data(io.stdout.joined().utf8))
                XCTAssertEqual(result.count, 1)
                XCTAssertEqual(result[0].totalMs, 20, accuracy: 0.001)
                XCTAssertEqual(result[0].stages.map(\.name), ["event reaching WinMux", "binding resolved", "first frame presented"])
            } else {
                XCTAssertTrue(io.stdout.joined().contains("20.000 ms"))
                XCTAssertTrue(io.stdout.joined().contains("controlled presentation"))
            }
        }
    }

    func testDismissedOpeningEndsWithCancellationRatherThanAPendingFrame() {
        var now = 0.0
        let store = LensTraceStore(stamp: { now })
        let trace = store.begin(presentation: "strip", origin: .init(start: 0, received: 0, source: "test"))
        now = 0.003
        trace.cancel()
        now = 0.500
        trace.finish(signal: "late display link")
        XCTAssertEqual(store.snapshots(last: 1)[0].signal, "cancelled before first frame")
        XCTAssertEqual(store.snapshots(last: 1)[0].totalMs, 3, accuracy: 0.00001)
        XCTAssertEqual(store.snapshots(last: 1)[0].stages.last?.name, "opening cancelled")
    }

    func testAnEventStampedAfterItsReceiptStartsTheTraceAtReceipt() {
        let origin = LensTraceOrigin(start: 99, received: 42.130, source: "NSEvent")
        let store = LensTraceStore(stamp: { 42.140 })
        store.begin(presentation: "list", origin: origin).finish(signal: "test")
        XCTAssertEqual(store.snapshots(last: 1)[0].totalMs, 10, accuracy: 0.00001)
        XCTAssertEqual(store.snapshots(last: 1)[0].stages[0].durationMs, 0, accuracy: 0.00001)
    }

    func testAToggleThatClosesALensLeavesNoOpeningBehind() {
        let store = LensTraceStore(stamp: { 0 })
        let opened = store.begin(presentation: "list", origin: .init(start: 0, received: 0, source: "CLI"))
        opened.finish(signal: "test")
        let closing = store.begin(presentation: "list", origin: .init(start: 0, received: 0, source: "CLI"))
        closing.cancel()
        store.discard(closing)
        XCTAssertEqual(store.snapshots(last: 5).map(\.signal), ["test"])
    }

    func testCommandArguments() {
        let args = parseCmdArgs(["debug-lens-trace", "--json", "--last", "5"].slice).cmdOrNil as? DebugLensTraceCmdArgs
        XCTAssertEqual(args?.last, 5)
        XCTAssertEqual(args?.json, true)
        XCTAssertNil(parseCmdArgs(["debug-lens-trace", "--last", "0"].slice).cmdOrNil)
        XCTAssertNil(parseCmdArgs(["debug-lens-trace", "--last", "-1"].slice).cmdOrNil)
        XCTAssertNil(parseCmdArgs(["debug-lens-trace", "--last", "no"].slice).cmdOrNil)
    }
}
