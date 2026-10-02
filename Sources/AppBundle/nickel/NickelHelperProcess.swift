import Foundation

enum NickelFailure: Error, Equatable, Sendable {
    /// The helper answered with an error. The text is Nickel's own diagnostic.
    case diagnostic(String)
    /// The helper did not answer in time, which means it is hung. It has been killed.
    case timedOut
    /// No helper could take the request: not found, not running, or stopped by the breaker.
    case unavailable(String)

    var message: String {
        switch self {
            case .diagnostic(let text): text
            case .timedOut: "The config helper did not answer in time and was restarted"
            case .unavailable(let reason): reason
        }
    }
}

struct NickelReply: Sendable {
    let result: JSONValue
    /// The helper's resident memory in bytes, as it reported it in this reply.
    let rss: Int
}

/// One running `winmux-nickel serve`. Requests go in as JSON lines on its stdin and replies come
/// back on its stdout in the same order, each carrying the id of its request.
actor NickelHelperProcess {
    nonisolated let pid: Int32
    private let process: Process
    private let stdin: FileHandle
    private var nextId = 1
    private var pending: [Int: CheckedContinuation<Result<NickelReply, NickelFailure>, Never>] = [:]
    private var buffer = Data()
    private var hasExited = false
    private var stopRequested = false
    private let onCrash: @Sendable (Int32) -> Void

    /// - Parameter onCrash: Called with the pid when the helper exits without having been asked to.
    init(executable: URL, onCrash: @escaping @Sendable (Int32) -> Void) throws {
        // Writing to a helper that has died must fail with an error, not end WinMux.
        signal(SIGPIPE, SIG_IGN)
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let process = Process()
        process.executableURL = executable
        process.arguments = ["serve"]
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        let (chunks, chunkSink) = AsyncStream.makeStream(of: Data.self)
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                chunkSink.finish()
            } else {
                chunkSink.yield(data)
            }
        }
        try process.run()
        // The child holds its own copies. While ours stay open, its stdout never reaches end of file.
        try? stdoutPipe.fileHandleForWriting.close()
        try? stdinPipe.fileHandleForReading.close()
        self.process = process
        self.stdin = stdinPipe.fileHandleForWriting
        self.pid = process.processIdentifier
        self.onCrash = onCrash
        Task {
            for await chunk in chunks {
                await self.receive(chunk)
            }
            await self.didExit()
        }
    }

    func send(_ request: [String: JSONValue], timeout: Duration) async -> Result<NickelReply, NickelFailure> {
        if hasExited { return .failure(.unavailable("The config helper is not running")) }
        let id = nextId
        nextId += 1
        var request = request
        request["id"] = .int(id)
        do {
            var line = try JSONEncoder().encode(request)
            line.append(0x0A)
            try stdin.write(contentsOf: line)
        } catch {
            return .failure(.unavailable("Cannot write to the config helper: \(error.localizedDescription)"))
        }
        let timer = Task {
            try await Task.sleep(for: timeout)
            self.timeOut(id)
        }
        let result = await withCheckedContinuation { pending[id] = $0 }
        timer.cancel()
        return result
    }

    /// Lets the helper finish the requests it already has, then exit.
    func close() {
        stopRequested = true
        try? stdin.close()
    }

    func kill() {
        stopRequested = true
        if !hasExited { Darwin.kill(pid, SIGKILL) }
    }

    private func timeOut(_ id: Int) {
        guard let continuation = pending.removeValue(forKey: id) else { return }
        kill()
        continuation.resume(returning: .failure(.timedOut))
    }

    private func receive(_ chunk: Data) {
        buffer.append(chunk)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex ..< newline]
            buffer.removeSubrange(buffer.startIndex ... newline)
            guard let reply = try? JSONDecoder().decode(WireReply.self, from: line),
                  // A reply to a request that already timed out has no one waiting for it.
                  let continuation = pending.removeValue(forKey: reply.id)
            else { continue }
            if reply.ok {
                continuation.resume(returning: .success(NickelReply(result: reply.result ?? .null, rss: reply.rss)))
            } else {
                continuation.resume(returning: .failure(.diagnostic(reply.error ?? "The config helper reported an error")))
            }
        }
    }

    private func didExit() {
        hasExited = true
        let waiting = pending
        pending = [:]
        for continuation in waiting.values {
            continuation.resume(returning: .failure(.unavailable("The config helper exited")))
        }
        if !stopRequested { onCrash(pid) }
    }
}

private struct WireReply: Decodable {
    let id: Int
    let ok: Bool
    let result: JSONValue?
    let error: String?
    let rss: Int
}
