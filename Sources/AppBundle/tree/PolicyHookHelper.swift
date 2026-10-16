import Common

@MainActor
protocol PolicyHookHelper: Sendable {
    func hook(_ path: String, args: [JSONValue]) async -> Result<JSONValue, NickelFailure>
    func recordHookFailure(_ message: String)
    var lastHookError: String? { get }
}

extension NickelSupervisor: PolicyHookHelper {
    var lastHookError: String? { status.lastError }
}

@MainActor
enum PolicyHooks {
    @TaskLocal static var scoped: (any PolicyHookHelper)?
    private static var testOverride: (any PolicyHookHelper)?
    static var current: any PolicyHookHelper { scoped ?? testOverride ?? NickelSupervisor.shared }

    static func setOverrideForTests(_ helper: (any PolicyHookHelper)?) {
        testOverride = helper
    }
}
