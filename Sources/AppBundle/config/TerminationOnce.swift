import AppKit
import Common

@MainActor
final class TerminationOnce {
    private var task: Task<Void, Error>?
    private(set) var isFinished = false

    func run(_ cleanup: @escaping @MainActor () async throws -> Void) async throws {
        if let task { return try await task.value }
        let task = Task { @MainActor in
            defer { isFinished = true }
            try await cleanup()
        }
        self.task = task
        try await task.value
    }
}

@MainActor let terminationOnce = TerminationOnce()

@MainActor
public final class ApplicationTerminationDelegate: NSObject, NSApplicationDelegate {
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Before startup has registered a window (Accessibility denied, say) there is nothing to
        // restore, and a cleanup would only delete the frozen world a relaunch restores.
        if terminationOnce.isFinished || !isWinMuxRuntimeReady && MacWindow.allWindowsMap.isEmpty { return .terminateNow }
        let reply = ApplicationTerminationReply { sender.reply(toApplicationShouldTerminate: true) }
        DispatchQueue.main.asyncAfter(deadline: .now() + terminationTimeout) { reply.finish() }
        Task { @MainActor in
            defer { reply.finish() }
            try await terminationHandler.beforeTermination()
        }
        return .terminateLater
    }
}

@MainActor
final class ApplicationTerminationReply {
    private var reply: (() -> Void)?

    init(_ reply: @escaping () -> Void) { self.reply = reply }

    func finish() {
        let reply = self.reply
        self.reply = nil
        reply?()
    }
}
