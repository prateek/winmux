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
    let error: JSONValue
}

@MainActor
final class HookCaptureStore {
    static var shared = HookCaptureStore()
    let path: URL
    private let now: () -> Date
    private let emit: (ServerEvent) -> Void
    private var until: Date?
    /// When the last capture passed its deadline, until the next `on`.
    private(set) var stoppedItselfAt: Date?
    private var records = 0
    private var error: String?
    private var generation = UUID()
    private let log = Logger(subsystem: winMuxAppId, category: "hook-capture")

    init(path: URL = winMuxStateDirectory().appending(path: isDebug ? "hook-capture-debug.jsonl" : "hook-capture.jsonl"), now: @escaping () -> Date = Date.init,
         emit: @escaping (ServerEvent) -> Void = broadcastEvent) {
        self.path = path
        self.now = now
        self.emit = emit
    }

    struct Call {
        let time: Date
        let generation: UUID
    }

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func timestamp(_ date: Date) -> String { formatter.string(from: date) }

    func start() throws {
        let extending = isCapturing()
        stoppedItselfAt = nil
        do {
            // Extending keeps the records; a file removed meanwhile is created again, empty.
            if !extending || !FileManager.default.fileExists(atPath: path.path) {
                try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data().write(to: path)
                // The records hold window titles and documents.
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
            }
        } catch {
            fail(error)
            throw error
        }
        if !extending {
            records = 0
            error = nil
            generation = UUID()
        }
        until = now().addingTimeInterval(15 * 60)
    }

    func stop() { until = nil }

    private func isCapturing() -> Bool {
        guard let deadline = until else { return false }
        guard now() < deadline else {
            until = nil
            stoppedItselfAt = deadline
            log.info("Hook capture stopped itself after 15 minutes")
            return false
        }
        return true
    }

    func status() -> HookCaptureStatus {
        let capturing = isCapturing()
        return HookCaptureStatus(capturing: capturing, path: path.path, until: until.map { .string(Self.timestamp($0)) } ?? .null, records: records, error: error.map(JSONValue.string) ?? .null)
    }

    func beginCall() -> Call? {
        guard isCapturing() else { return nil }
        return Call(time: now(), generation: generation)
    }

    func append(_ record: HookCaptureRecord, call: Call) {
        guard isCapturing(), call.generation == generation else { return }
        do {
            var data = try subscriptionEncoder.encode(record)
            data.append(0x0a)
            let file = try FileHandle(forWritingTo: path)
            defer { try? file.close() }
            try file.seekToEnd()
            try file.write(contentsOf: data)
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
