import Common

@MainActor
protocol PolicyHookHelper: Sendable {
    func hook(_ path: String, args: [JSONValue]) async -> Result<JSONValue, NickelFailure>
    func recordHookFailure(_ message: String)
    var lastHookError: String? { get }
}

@MainActor
enum PolicyHooks {
    private static var testOverride: (any PolicyHookHelper)?
    static var current: any PolicyHookHelper { testOverride ?? NickelSupervisor.shared }

    static func setOverrideForTests(_ helper: (any PolicyHookHelper)?) {
        testOverride = helper
    }
}
