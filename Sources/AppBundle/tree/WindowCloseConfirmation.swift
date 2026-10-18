import Foundation

@MainActor
func windowCloseSession<T>(
    _ token: RunSessionGuard?,
    body: @MainActor () async -> T,
) async -> T? {
    if let token {
        guard RunSessionGuard.isServerEnabled != nil else { return nil }
        return try? await runLightSession(.menuBarButton, token, body: body)
    }
    return await body()
}

@MainActor
func confirmWindowClose(
    timeout: TimeInterval,
    clock: some Clock<Duration> = ContinuousClock(),
    isPresent: () async -> Bool?,
    hasSheet: () async -> Bool,
    collect: () async -> Void,
) async -> Bool {
    let deadline = clock.now.advanced(by: .seconds(timeout))
    while clock.now < deadline {
        if await isPresent() == false {
            await collect()
            return true
        }
        if await hasSheet() { return false }
        try? await clock.sleep(for: .milliseconds(100))
    }
    return false
}
