import Foundation

/// Upper bound on how long one app may hold up the window-refresh barrier. A CPU-starved
/// app answers each AX message only at the messaging timeout, so its enumeration can take
/// (windows × timeout); every other app's layout would wait behind it. On deadline the app
/// falls back to the model's current windows (equivalent to "nothing changed"), and a later
/// refresh reconciles once the app responds.
let singleAppRefreshDeadline: Duration = .milliseconds(1500)

/// Cancels `operation` at the deadline and waits for it to end. Work that ignores the
/// cancellation still holds the caller until it returns, and what it returns is used.
@MainActor
func appRefreshWithDeadline(
    clock: any Clock<Duration> = ContinuousClock(),
    work operation: @escaping @MainActor () async throws -> [UInt32],
    fallback: @MainActor () -> [UInt32],
) async throws -> [UInt32] {
    let work = Task { @MainActor in try await operation() }
    let deadline = Task { @MainActor in
        do { try await clock.sleep(for: singleAppRefreshDeadline) }
        catch { return }
        work.cancel()
    }
    defer { deadline.cancel() }
    return try await withTaskCancellationHandler {
        do {
            return try await work.value
        } catch is CancellationError {
            // Propagate if the whole refresh session was cancelled; otherwise the deadline
            // fired — report the model's current windows for this app as alive.
            try checkCancellation()
            return fallback()
        }
    } onCancel: {
        work.cancel()
    }
}
