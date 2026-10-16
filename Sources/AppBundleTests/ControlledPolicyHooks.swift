import Common
import XCTest
@testable import AppBundle

@MainActor
final class ControlledPolicyHooks: PolicyHookHelper {
    struct Call {
        let path: String
        let args: [JSONValue]
    }
    var answers: [String: Result<JSONValue, NickelFailure>] = [:]
    var gates: [String: ReloadGate] = [:]
    var onCall: ((Call) -> Void)?
    private(set) var calls: [Call] = []
    private(set) var failures: [String] = []
    var lastHookError: String? { failures.last }

    func hook(_ path: String, args: [JSONValue]) async -> Result<JSONValue, NickelFailure> {
        let call = Call(path: path, args: args)
        calls.append(call)
        onCall?(call)
        guard let answer = answers[path] else {
            XCTFail("Unconfigured Policy hook: \(path)")
            return .failure(.unavailable("Unconfigured Policy hook: \(path)"))
        }
        if let gate = gates.removeValue(forKey: path) { await gate.hold() }
        return answer
    }
    func recordHookFailure(_ message: String) { failures.append(message) }
}
