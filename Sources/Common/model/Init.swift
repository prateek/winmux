import Foundation

nonisolated(unsafe) public var isCli = true
var isServer: Bool { !isCli }

nonisolated(unsafe) public var terminationHandler: TerminationHandler = EmptyTerminationHandler()
/// How long any quit waits for `beforeTermination` before the process ends anyway.
public let terminationTimeout: TimeInterval = 2

struct EmptyTerminationHandler: TerminationHandler {
    func beforeTermination() {}
}

@MainActor
public protocol TerminationHandler: Sendable {
    func beforeTermination() async throws
}
