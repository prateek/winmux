import Foundation

/// The helper's byte transport. Output ends when the process exits.
protocol NickelByteChannel: Sendable {
    var pid: Int32 { get }
    var chunks: AsyncStream<Data> { get }
    func write(_ line: Data) throws
    func close()
    func kill()
}

final class NickelProcessChannel: NickelByteChannel, @unchecked Sendable {
    let pid: Int32
    let chunks: AsyncStream<Data>
    private let process: Process
    private let stdin: FileHandle

    init(executable: URL) throws {
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
        self.chunks = chunks
    }
    func write(_ line: Data) throws { try stdin.write(contentsOf: line) }
    func close() { try? stdin.close() }
    func kill() { Darwin.kill(pid, SIGKILL) }
}
