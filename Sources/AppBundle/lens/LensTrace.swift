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
    /// An action run from a timer or a command task, where the current event is unrelated.
    static func internalNow() -> Self {
        let now = LensTimebase.now()
        return Self(start: now, received: now, source: "internal")
    }
    init(event: NSEvent, received: Double) {
        self.init(start: event.timestamp, received: received, source: "NSEvent")
    }
}
@TaskLocal var lensTraceOrigin: LensTraceOrigin?

@MainActor struct LensModeKeyTrace {
    private let trace: LensOpeningTrace?
    private let model: LensSession?
    private let code: UInt16
    private let flags: NSEvent.ModifierFlags
    private let characters: String
    private let origin: LensTraceOrigin
    private let mode: String
    private let held: Bool
    private let editor: Bool
    private let presentation: String

    init(code: UInt16, flags: NSEvent.ModifierFlags, characters: String, origin: LensTraceOrigin?) {
        let panel = SwitcherPalettePanel.shared
        trace = panel.inputTrace; model = panel.session
        self.code = code; self.flags = flags; self.characters = characters
        self.origin = origin ?? .internalNow()
        mode = activeMode ?? mainModeId
        held = !ModeEngine.shared.entryModifiers.isEmpty
        editor = panel.firstResponder is NSTextView
        presentation = panel.openPresentation ?? "list"
    }

    func finish(_ destination: String) {
        trace?.key(code: code, characters: characters, flags: flags, timestamp: origin.start,
                   presentation: presentation, state: mode, hold: held, path: origin.source,
                   destination: destination, search: model?.query ?? "", selectedId: model?.selectedId,
                   fieldEditor: editor, receivedAt: origin.received)
    }
}

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
    let recordedAt: Double
    let presentation: String
    let state: String
    let hold: Bool
    let path: String
    let destination: String
    let search: String
    let selectedId: UInt32?
    let fieldEditor: Bool
}
struct LensSessionRecord: Codable, Equatable {
    let presentation: String
    let state: String
    let hold: Bool
    let search: String
    let selectedId: UInt32?
    let active: Bool
    var hoveredTileId: UInt32? = nil
    var hints: String = "hidden"
    var peek: UInt32? = nil
    var peekCaptureMs: Double? = nil
    var capturesRequested = 0
    var capturesCompleted = 0
    var presentedMs: Double = 0
    var droppedFrames: Int? = nil
    var longestFrameIntervalMs: Double? = nil

    enum CodingKeys: String, CodingKey { case presentation, state, hold, search, selectedId, active, hoveredTileId, hints, peek, peekCaptureMs, capturesRequested, capturesCompleted, presentedMs, droppedFrames, longestFrameIntervalMs }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(presentation, forKey: .presentation)
        try container.encode(state, forKey: .state)
        try container.encode(hold, forKey: .hold)
        try container.encode(search, forKey: .search)
        try container.encodeIfPresent(selectedId, forKey: .selectedId)
        try container.encode(active, forKey: .active)
        try container.encode(hints, forKey: .hints)
        try container.encode(peek, forKey: .peek)
        try container.encodeIfPresent(peekCaptureMs, forKey: .peekCaptureMs)
        try container.encode(hoveredTileId, forKey: .hoveredTileId)
        try container.encode(capturesRequested, forKey: .capturesRequested)
        try container.encode(capturesCompleted, forKey: .capturesCompleted)
        try container.encode(presentedMs, forKey: .presentedMs)
        try container.encodeIfPresent(droppedFrames, forKey: .droppedFrames)
        try container.encodeIfPresent(longestFrameIntervalMs, forKey: .longestFrameIntervalMs)
    }
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
    let session: LensSessionRecord?
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
        snapshots(last: last).map { trace -> String in
            let stages = trace.stages.map { stage in
                stage.name.padding(toLength: 34, withPad: " ", startingAt: 0) + String(format: " %10.3f %12.3f", stage.startMs, stage.durationMs)
            }.joined(separator: "\n")
            let keys = trace.keys.map { key -> String in
                "\(key.keyCode) \(key.characters.debugDescription) \(key.modifiers) \(key.timestamp) \(key.receivedAt) \(key.recordedAt) \(key.presentation) \(key.state) \(key.hold) \(key.path) \(key.destination) \(key.search.debugDescription) \(String(describing: key.selectedId)) \(key.fieldEditor)"
            }.joined(separator: "\n")
            let opening = "Opening \(trace.id)  \(trace.presentation)  \(trace.source)  total \(String(format: "%.3f", trace.totalMs)) ms  signal \(trace.signal ?? "pending")"
            var lines = [opening, "Stage                                Start ms  Duration ms", stages,
                         "Keys: code text flags boot-seconds received-seconds recorded-seconds Presentation state Hold path destination Search selection field-editor", keys]
            if let session = trace.session {
                lines.append("Session: \(session.presentation) state=\(session.state) hints=\(session.hints) Hold=\(session.hold) Search=\(session.search.debugDescription) selection=\(String(describing: session.selectedId)) hovered=\(session.hoveredTileId.map(String.init) ?? "none") peek=\(session.peek.map(String.init) ?? "none")\(session.peekCaptureMs.map { String(format: " peek-capture=%.3fms", $0) } ?? "") active=\(session.active)")
                lines.append("Captures: captures-requested=\(session.capturesRequested) captures-completed=\(session.capturesCompleted) presented=\(String(format: "%.3f", session.presentedMs))ms")
                if let dropped = session.droppedFrames, let longest = session.longestFrameIntervalMs {
                    lines.append("Frames: dropped=\(dropped) longest-interval=\(String(format: "%.3f", longest))ms")
                }
            }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

}

@MainActor
final class LensOpeningTrace {
    let statistics: LensSessionStatistics
    private let id: Int
    private let presentation: String
    private let origin: LensTraceOrigin
    private let stamp: () -> Double
    private let signposting = lensOpeningRecordingGate.isEnabled
    private var stages: [LensTraceStage] = []
    private var keys: [LensKeyRecord] = []
    private var sessionRecord: LensSessionRecord?
    private weak var liveSession: LensSession?
    private var last: Double
    private var signal: String?
    private var stageStart: Double?
    private var interval: OSSignpostIntervalState?
    private var intervalName: StaticString?
    private var poster: OSSignposter { lensOpeningSignposter }

    init(id: Int, presentation: String, origin: LensTraceOrigin, stamp: @escaping () -> Double) {
        statistics = LensSessionStatistics(stamp: stamp)
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
    func session(_ model: LensSession, active: Bool = true) {
        // An open session is read when the trace is; only its last state is kept.
        liveSession = active ? model : nil
        sessionRecord = active ? nil : Self.record(model, active: false)
    }
    private static func record(_ model: LensSession, active: Bool) -> LensSessionRecord {
        LensSessionRecord(presentation: model.settings.presentation, state: activeMode ?? mainModeId, hold: model.isHeld,
                          search: model.query, selectedId: model.selectedId, active: active, hoveredTileId: model.hoveredTileId, hints: model.hintsShown ? "shown" : "hidden", peek: model.peekedId, peekCaptureMs: model.peekCaptureMs)
    }
    func key(code: UInt16, characters: String, flags: NSEvent.ModifierFlags, timestamp: Double,
             presentation: String, state: String, hold: Bool, path: String, destination: String,
             search: String, selectedId: UInt32?, fieldEditor: Bool, receivedAt: Double? = nil) {
        let recordedAt = stamp()
        keys.append(LensKeyRecord(keyCode: code, characters: characters, modifiers: flags.rawValue,
                                 timestamp: timestamp, receivedAt: receivedAt ?? recordedAt, recordedAt: recordedAt, presentation: presentation,
                                 state: state, hold: hold, path: path, destination: destination, search: search,
                                 selectedId: selectedId, fieldEditor: fieldEditor))
        if keys.count > 256 { keys.removeFirst(keys.count - 256) }
    }
    var snapshot: LensTraceSnapshot {
        var session = sessionRecord ?? liveSession.map { Self.record($0, active: true) }
        session?.capturesRequested = statistics.capturesRequested
        session?.capturesCompleted = statistics.capturesCompleted
        session?.presentedMs = statistics.presentedMs
        session?.droppedFrames = statistics.droppedFrames
        session?.longestFrameIntervalMs = statistics.longestFrameIntervalMs
        return LensTraceSnapshot(id: id, presentation: presentation, source: origin.source, startedAt: origin.start,
                          totalMs: (last - origin.start) * 1000, signal: signal, signposting: signposting, stages: stages, keys: keys, session: session)
    }
}
