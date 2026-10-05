import AppKit
import Common
import Foundation
import os

struct LensTraceOrigin: Sendable {
    let start: Double
    let received: Double
    let source: String
    init(start: Double, received: Double, source: String) {
        // An event stamped after its own receipt is on another clock; the trace then starts at receipt.
        self.start = min(start, received); self.received = received; self.source = source
    }
    init(event: NSEvent, received: Double) {
        self.init(start: event.timestamp, received: received, source: "NSEvent")
    }
}
@TaskLocal var lensTraceOrigin: LensTraceOrigin?

struct LensTraceStage: Codable, Equatable {
    let name: String
    let startMs: Double
    let durationMs: Double
}
struct LensKeyRecord: Codable, Equatable {
    let keyCode: UInt16
    let characters: String
    let modifiers: UInt
    let timestamp: Double
    let receivedAt: Double
    let presentation: String
    let hold: Bool
    let path: String
    let destination: String
    let search: String
    let selectedId: UInt32?
    let fieldEditor: Bool
}
struct LensTraceSnapshot: Codable, Equatable {
    let id: Int
    let presentation: String
    let source: String
    let startedAt: Double
    let totalMs: Double
    let signal: String?
    let signposting: Bool
    let stages: [LensTraceStage]
    let keys: [LensKeyRecord]
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
    /// Forgets a trace that turned out not to be an opening, such as a toggle that closed the Lens.
    func discard(_ trace: LensOpeningTrace) { traces.removeAll { $0 === trace } }
    func snapshots(last: Int) -> [LensTraceSnapshot] { traces.suffix(max(0, last)).map { $0.snapshot } }
    func json(last: Int) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try! encoder.encode(snapshots(last: last)), as: UTF8.self)
    }
    func text(last: Int) -> String {
        snapshots(last: last).map { trace in
            let rows = trace.stages.map { $0.name.padding(toLength: 34, withPad: " ", startingAt: 0) + String(format: " %10.3f %12.3f", $0.startMs, $0.durationMs) }
            return "Opening \(trace.id)  \(trace.presentation)  \(trace.source)  total \(String(format: "%.3f", trace.totalMs)) ms  signal \(trace.signal ?? "pending")\nStage                                Start ms  Duration ms\n" + rows.joined(separator: "\n") + "\nKeys: code text flags boot-seconds received-seconds Presentation Hold path destination Search selection field-editor\n" + trace.keys.map { "\($0.keyCode) \($0.characters.debugDescription) \($0.modifiers) \($0.timestamp) \($0.receivedAt) \($0.presentation) \($0.hold) \($0.path) \($0.destination) \($0.search.debugDescription) \(String(describing: $0.selectedId)) \($0.fieldEditor)" }.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }
}

@MainActor
final class LensOpeningTrace {
    private let id: Int
    private let presentation: String
    private let origin: LensTraceOrigin
    private let stamp: () -> Double
    private let signposting = lensOpeningRecordingGate.isEnabled
    private var stages: [LensTraceStage] = []
    private var keys: [LensKeyRecord] = []
    private var last: Double
    private var signal: String?
    private var stageStart: Double?
    private var interval: OSSignpostIntervalState?
    private var intervalName: StaticString?
    private var poster: OSSignposter { lensOpeningSignposter }

    init(id: Int, presentation: String, origin: LensTraceOrigin, stamp: @escaping () -> Double) {
        self.id = id; self.presentation = presentation; self.origin = origin; self.stamp = stamp
        last = origin.start
        advance("event reaching WinMux", at: origin.received)
        startInterval("binding resolved", at: origin.received)
    }
    func advance(_ name: StaticString, at time: Double? = nil) {
        guard signal == nil else { return }
        let wasRecording = interval != nil
        endInterval()
        if !wasRecording, lensOpeningRecordingGate.isEnabled, poster.isEnabled {
            let marker = poster.beginInterval(name, id: poster.makeSignpostID())
            poster.endInterval(name, marker)
        }
        record(name, at: time ?? stamp())
    }
    func startInterval(_ name: StaticString, at time: Double? = nil) {
        guard signal == nil else { return }
        stageStart = time ?? stamp()
        endInterval()
        guard lensOpeningRecordingGate.isEnabled, poster.isEnabled else { return }
        intervalName = name
        interval = poster.beginInterval(name, id: poster.makeSignpostID())
    }
    private func endInterval() {
        if let interval, let intervalName { poster.endInterval(intervalName, interval) }
        interval = nil; intervalName = nil
    }
    private func record(_ name: StaticString, at time: Double) {
        let start = max(last, stageStart ?? last)
        let end = max(start, time)
        if start > last {
            stages.append(LensTraceStage(name: "gap", startMs: (last - origin.start) * 1000, durationMs: (start - last) * 1000))
        }
        stages.append(LensTraceStage(name: String(describing: name), startMs: (start - origin.start) * 1000, durationMs: (end - start) * 1000))
        last = end
        stageStart = nil
    }
    func finish(signal: String, at time: Double? = nil) {
        guard self.signal == nil else { return }
        advance("first frame presented", at: time)
        self.signal = signal
    }
    func cancel() {
        guard signal == nil else { return }
        advance("opening cancelled")
        signal = "cancelled before first frame"
    }
    func key(code: UInt16, characters: String, flags: NSEvent.ModifierFlags, timestamp: Double,
             presentation: String, hold: Bool, path: String, destination: String,
             search: String, selectedId: UInt32?, fieldEditor: Bool) {
        keys.append(LensKeyRecord(keyCode: code, characters: characters, modifiers: flags.rawValue,
                                 timestamp: timestamp, receivedAt: stamp(), presentation: presentation,
                                 hold: hold, path: path, destination: destination, search: search,
                                 selectedId: selectedId, fieldEditor: fieldEditor))
        if keys.count > 256 { keys.removeFirst(keys.count - 256) }
    }
    var snapshot: LensTraceSnapshot {
        LensTraceSnapshot(id: id, presentation: presentation, source: origin.source, startedAt: origin.start,
                          totalMs: (last - origin.start) * 1000, signal: signal, signposting: signposting, stages: stages, keys: keys)
    }
}
