import Foundation

public struct LensCommandList {
    private let lenses: [LensCmdArgs]
    public init(_ commands: [String]) {
        lenses = commands.compactMap { raw in
            guard case .success(let words) = raw.splitArgs(), case .cmd(let args) = parseCmdArgs(words.slice) else { return nil }
            return args as? LensCmdArgs
        }
    }
    public var containsOpener: Bool { lenses.contains { $0.verb == nil } }
    public var containsStepPrev: Bool { lenses.contains { $0.verb == "step" && $0.operands == ["prev"] } }
    public var containsFocus: Bool { lenses.contains { $0.verb == "focus" } }
}
