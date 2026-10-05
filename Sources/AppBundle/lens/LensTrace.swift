import Common
import Foundation
import os

struct LensTraceOrigin: Sendable {
    let start: Double
    let received: Double
    let source: String
}
@TaskLocal var lensTraceOrigin: LensTraceOrigin?

struct LensTraceStage: Codable, Equatable {
    let name: String
    let startMs: Double
    let durationMs: Double
}
struct LensTraceSnapshot: Codable, Equatable {
    let id: Int
    let presentation: String
    let source: String
    let startedAt: Double
    let totalMs: Double
    let signal: String?
    let stages: [LensTraceStage]
}

@MainActor
final class LensTraceStore {
    static let shared = LensTraceStore()
    private let capacity: Int
    let stamp: () -> Double
    private var traces: [LensOpeningTrace] = []
    private var nextId = 0
    init(capacity: Int = 20, stamp: @escaping () -> Double = LensTimebase.now) {
        precondition(capacity > 0)
        self.capacity = capacity
        self.stamp = stamp
    }
    @discardableResult
    func begin(presentation: String, origin: LensTraceOrigin) -> LensOpeningTrace {
        nextId += 1
        let trace = LensOpeningTrace(id: nextId, presentation: presentation, origin: origin, stamp: stamp)
        traces.append(trace)
        if traces.count > capacity { traces.removeFirst(traces.count - capacity) }
        return trace
    }
    func snapshots(last: Int) -> [LensTraceSnapshot] { traces.suffix(max(0, last)).map { $0.snapshot } }
    func json(last: Int) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try! encoder.encode(snapshots(last: last)), as: UTF8.self)
    }
    func text(last: Int) -> String {
        snapshots(last: last).map { trace in
            let rows = trace.stages.map { $0.name.padding(toLength: 34, withPad: " ", startingAt: 0) + String(format: " %10.3f %12.3f", $0.startMs, $0.durationMs) }
            return "Opening \(trace.id)  \(trace.presentation)  \(trace.source)  total \(String(format: "%.3f", trace.totalMs)) ms  signal \(trace.signal ?? "pending")\nStage                                Start ms  Duration ms\n" + rows.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }
}

@MainActor
final class LensOpeningTrace {
    private let id: Int
    private let presentation: String
    private let origin: LensTraceOrigin
    private let stamp: () -> Double
    private var stages: [LensTraceStage] = []
    private var last: Double
    private var signal: String?
    private var interval: OSSignpostIntervalState?
    private var intervalName: StaticString?
    private var poster: OSSignposter { lensOpeningSignposter }

    init(id: Int, presentation: String, origin: LensTraceOrigin, stamp: @escaping () -> Double) {
        self.id = id; self.presentation = presentation; self.origin = origin; self.stamp = stamp
        last = origin.start
        record("event reaching WinMux", at: origin.received)
        startInterval("binding resolved")
    }
    func advance(_ name: StaticString, at time: Double? = nil) {
        guard signal == nil else { return }
        endInterval()
        record(name, at: time ?? stamp())
    }
    func startInterval(_ name: StaticString) {
        guard signal == nil, poster.isEnabled else { return }
        endInterval()
        intervalName = name
        interval = poster.beginInterval(name, id: poster.makeSignpostID())
    }
    private func endInterval() {
        if let interval, let intervalName { poster.endInterval(intervalName, interval) }
        interval = nil; intervalName = nil
    }
    private func record(_ name: StaticString, at time: Double) {
        let end = max(last, time)
        stages.append(LensTraceStage(name: String(describing: name), startMs: (last - origin.start) * 1000, durationMs: (end - last) * 1000))
        last = end
    }
    func finish(signal: String, at time: Double? = nil) {
        guard self.signal == nil else { return }
        advance("first frame presented", at: time)
        self.signal = signal
    }
    var snapshot: LensTraceSnapshot {
        LensTraceSnapshot(id: id, presentation: presentation, source: origin.source, startedAt: origin.start,
                          totalMs: (last - origin.start) * 1000, signal: signal, stages: stages)
    }
}
