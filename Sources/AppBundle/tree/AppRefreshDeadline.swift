import Foundation

@MainActor
func appRefreshWithDeadline(
    clock: any Clock<Duration> = ContinuousClock(),
    work operation: @escaping @MainActor () async throws -> [UInt32],
    fallback: @MainActor () -> [UInt32],
) async throws -> [UInt32] {
    let work = Task { @MainActor in try await operation() }
    let deadline = Task { @MainActor in
        do { try await clock.sleep(for: .milliseconds(1500)) }
        catch { return }
        work.cancel()
    }
    defer { deadline.cancel() }
    return try await withTaskCancellationHandler {
        do {
            let result = try await work.value
            try Task.checkCancellation()
            if work.isCancelled { return fallback() }
            return result
        } catch is CancellationError {
            try Task.checkCancellation()
            return fallback()
        }
    } onCancel: {
        work.cancel()
    }
}
