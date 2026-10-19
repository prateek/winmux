import AppKit
import Common
import Foundation

struct AgentCommand: Command {
    let args: AgentCmdArgs
    var shouldResetClosedWindowsCache: Bool { args.subcommand.val == .apply }
    var canSkipPostCommandRefresh: Bool { args.subcommand.val != .apply }

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        switch args.subcommand.val {
            case .query:
                let snapshot = try await AgentSnapshot.query()
                guard let json = JSONEncoder.winMuxDefault.encodeToString(snapshot) else {
                    return io.err("Failed to encode agent snapshot")
                }
                if let path = args.path {
                    try json.write(to: URL(filePath: path), atomically: true, encoding: .utf8)
                    return true
                }
                return io.out(json)
            case .check:
                let request: AgentRequest
                do {
                    request = try AgentRequest.read(path: args.path.orDie())
                } catch {
                    return io.err("Failed to read agent JSON: \(describeAgentJsonError(error))")
                }
                let errors = try await request.validate()
                if errors.isEmpty {
                    return io.out("OK")
                }
                return io.err(errors.joinErrors())
            case .apply:
                let request: AgentRequest
                do {
                    request = try AgentRequest.read(path: args.path.orDie())
                } catch {
                    return io.err("Failed to read agent JSON: \(describeAgentJsonError(error))")
                }
                let errors = try await request.validate()
                if !errors.isEmpty {
                    return io.err(errors.joinErrors())
                }
                try await request.apply()
                return true
            case .skill:
                return io.out(agentSkillText)
        }
    }
}

private func describeAgentJsonError(_ error: Error) -> String {
    func path(_ codingPath: [any CodingKey]) -> String {
        let result = codingPath.map(\.stringValue).joined(separator: ".")
        return result.isEmpty ? "<root>" : result
    }
    switch error {
        case DecodingError.keyNotFound(let key, let context):
            return "missing key '\(key.stringValue)' at \(path(context.codingPath)): \(context.debugDescription)"
        case DecodingError.typeMismatch(_, let context):
            return "type mismatch at \(path(context.codingPath)): \(context.debugDescription)"
        case DecodingError.valueNotFound(_, let context):
            return "missing value at \(path(context.codingPath)): \(context.debugDescription)"
        case DecodingError.dataCorrupted(let context):
            return "invalid data at \(path(context.codingPath)): \(context.debugDescription)"
        default:
            return error.localizedDescription
    }
}
