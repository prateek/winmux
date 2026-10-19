import Common
import Foundation
import OSLog

struct HookCaptureRecord: Codable, Sendable {
    let time: String
    let hook: String
    let kind: String
    let windowId: UInt32
    let args: JSONValue
    let result: JSONValue
    let error: JSONValue
    let argumentsMs: Double
    let durationMs: Double

    enum CodingKeys: String, CodingKey {
        case time, hook, kind, args, result, error
        case windowId = "window-id"
        case argumentsMs = "arguments-ms"
        case durationMs = "duration-ms"
    }
}

struct HookCaptureStatus: Encodable {
    let capturing: Bool
    let path: String
    let until: JSONValue
    let records: Int
    let error: String?
}

@MainActor
final class HookCaptureStore {
    static var shared = HookCaptureStore()
    let path: URL
    private let now: () -> Date
    private let emit: (ServerEvent) -> Void
    private var until: Date?
    private var records = 0
    private var error: String?
    private var generation = UUID()
    private let log = Logger(subsystem: winMuxAppId, category: "hook-capture")

    init(path: URL = winMuxStateDirectory().appending(path: "hook-capture.jsonl"), now: @escaping () -> Date = Date.init,
         emit: @escaping (ServerEvent) -> Void = broadcastEvent) {
        self.path = path
        self.now = now
        self.emit = emit
    }

    struct Call {
        let time: Date
        let generation: UUID
    }

    static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    func start() throws {
        if !isCapturing() {
            do {
                try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data().write(to: path)
                records = 0
                error = nil
                generation = UUID()
            } catch {
                fail(error)
                throw error
            }
        }
        until = now().addingTimeInterval(15 * 60)
    }

    func stop() { until = nil }

    private func isCapturing() -> Bool {
        guard let deadline = until else { return false }
        guard now() < deadline else {
            until = nil
            log.info("Hook capture stopped itself after 15 minutes")
            return false
        }
        return true
    }

    func status() -> HookCaptureStatus {
        let capturing = isCapturing()
        return HookCaptureStatus(capturing: capturing, path: path.path, until: until.map { .string(Self.timestamp($0)) } ?? .null, records: records, error: error)
    }

    func beginCall() -> Call? {
        guard until != nil, isCapturing() else { return nil }
        return Call(time: now(), generation: generation)
    }

    func append(_ record: HookCaptureRecord, call: Call) {
        guard isCapturing(), call.generation == generation else { return }
        do {
            var data = try JSONEncoder().encode(record)
            data.append(0x0a)
            let file = try FileHandle(forWritingTo: path)
            defer { try? file.close() }
            try file.seekToEnd()
            try file.write(contentsOf: data)
            try file.synchronize()
            records += 1
            emit(.hookCalled(record))
        } catch { fail(error) }
    }

    private func fail(_ failure: any Error) {
        until = nil
        error = "Hook capture could not write \(path.path): \(failure.localizedDescription)"
        log.error("\(self.error!, privacy: .public)")
    }
}
