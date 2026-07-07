import Network
import Foundation

extension NWConnection {
    public func writeAtomic(_ msg: Codable, _ encoder: JSONEncoder = JSONEncoder()) async -> ((), error: NWError?) {
        let payload = Result { try encoder.encode(msg) }.getOrDie()
        var data = withUnsafeBytes(of: UInt32(payload.count)) { Data($0) }
        check(data.count == 4)
        data.append(payload)
        return await withCheckedContinuation { cont in
            send(content: data, completion: .contentProcessed { error in
                if let error {
                    cont.resume(returning: ((), error))
                } else {
                    cont.resume(returning: ((), nil))
                }
            })
        }
    }

    public func startBlocking(timeoutNanoseconds: UInt64 = 3_000_000_000) async -> ((), error: NWError?) {
        await withCheckedContinuation { cont in
            let isDone = IsDone()
            let finish: @Sendable (NWError?) -> Void = { error in
                Task {
                    if await isDone.markAsDone().wasAlreadyDone {
                        return
                    }
                    self.stateUpdateHandler = nil
                    if error != nil {
                        self.cancel()
                    }
                    cont.resume(returning: ((), error))
                }
            }
            stateUpdateHandler = { state in
                let error: NWError?
                switch state {
                    case .cancelled, .preparing, .setup: return
                    case .ready: error = nil
                    case .failed(let e), .waiting(let e): error = e
                    @unknown default: die("Unknown NWConnection.State: \(state)")
                }
                finish(error)
            }
            if timeoutNanoseconds > 0 {
                Task {
                    try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                    finish(.posix(.ETIMEDOUT))
                }
            }
            start(queue: .global())
        }
    }

    private func read(bytes size: Int) async -> Result<Data, NWError> {
        var data = Data(capacity: size)
        while data.count < size {
            let remaining = size - data.count
            let chunk: Result<Data, NWError> = await withCheckedContinuation { cont in
                receive(minimumIncompleteLength: remaining, maximumLength: remaining) { data, context, isComplete, error in
                    if let error {
                        cont.resume(returning: .failure(error))
                    } else {
                        cont.resume(returning: .success(data ?? Data()))
                    }
                }
            }
            switch chunk {
                case .success(let chunk): data.append(chunk)
                case .failure: return chunk
            }
        }
        return .success(data)
    }

    public func readTillError() async {
        while true {
            let isError = await withCheckedContinuation { cont in
                receive(minimumIncompleteLength: 1, maximumLength: Int.max) { data, context, isComplete, error in
                    cont.resume(returning: error != nil || data == nil || data?.count == 0)
                }
            }
            if isError { return }
        }
    }

    public func readNonAtomic() async -> Result<Data, NWError> {
        switch await read(bytes: 4) {
            case .success(let header):
                let count = header.withUnsafeBytes { $0.load(as: UInt32.self) }
                return await read(bytes: Int(count))
            case .failure(let e):
                return .failure(e)
        }
    }
}

private actor IsDone {
    private var isDone: Bool = false

    func markAsDone() -> (wasAlreadyDone: Bool, ()) {
        let old = isDone
        isDone = true
        return (old, ())
    }
}
