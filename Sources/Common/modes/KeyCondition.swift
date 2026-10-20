import Foundation

public struct KeyContext: Equatable {
    public var mode: String
    public var app: String? = nil
    public var lensOpen = false
    public var lens: String? = nil
    public var presentation: String? = nil
    public var columns: Int? = nil
    public var profile = "default"
    public init(mode: String, app: String? = nil, lensOpen: Bool = false, lens: String? = nil, presentation: String? = nil, columns: Int? = nil, profile: String = "default") {
        self.mode = mode; self.app = app; self.lensOpen = lensOpen; self.lens = lens
        self.presentation = presentation; self.columns = columns; self.profile = profile
    }

}

public struct KeyCondition: Sendable {
    public indirect enum Expression: Equatable, Sendable {
        case present(String), equal(String, String, Bool), not(Expression), and(Expression, Expression), or(Expression, Expression), group(Expression)

        func matches(_ c: KeyContext) -> Bool {
            switch self {
                case .present(let v): return v == "lens" ? c.lensOpen : c.columns != nil
                case .equal(let v, let expected, let equal):
                    let value: String? = switch v {
                        case "mode": c.mode
                        case "app": c.app
                        case "lens": c.lens
                        case "presentation": c.presentation
                        case "columns": c.columns.map(String.init)
                        default: c.profile
                    }
                    return (value == expected) == equal
                case .not(let x): return !x.matches(c)
                case .and(let a, let b): return a.matches(c) && b.matches(c)
                case .or(let a, let b): return a.matches(c) || b.matches(c)
                case .group(let x): return x.matches(c)
            }
        }
        var conjuncts: [Expression] {
            if case .and(let a, let b) = self { return a.conjuncts + b.conjuncts }
            return [self]
        }
    }
    enum Invalid: Error, CustomStringConvertible {
        case expression(String)
        var description: String { switch self { case .expression(let s): "Invalid keymap context: \(s)" } }
    }
    public let expression: Expression
    public init(_ source: String) throws {
        var parser = Parser(source: Array(source))
        expression = try parser.disjunction()
        parser.whitespace()
        guard parser.index == parser.source.count else { throw Invalid.expression(source) }
    }
    public var specificity: Int { expression.conjuncts.count }
    public func matches(_ context: KeyContext) -> Bool { expression.matches(context) }
    public func excludes(_ other: KeyCondition) -> Bool {
        for a in expression.conjuncts {
            guard case .equal(let variable, let value, true) = a else { continue }
            for b in other.expression.conjuncts {
                if case .equal(variable, let different, true) = b, value != different { return true }
            }
        }
        return false
    }

    private struct Parser {
        let source: [Character]
        var index = 0
        mutating func whitespace() { while index < source.count && source[index].isWhitespace { index += 1 } }
        mutating func take(_ s: String) -> Bool {
            whitespace()
            let chars = Array(s)
            guard source.dropFirst(index).starts(with: chars) else { return false }
            index += chars.count
            return true
        }
        mutating func word() throws -> String {
            whitespace()
            if take("'") {
                let start = index
                while index < source.count && source[index] != "'" { index += 1 }
                let result = String(source[start..<index])
                guard take("'") else { throw Invalid.expression("unterminated string") }
                return result
            }
            let start = index
            while index < source.count && (source[index].isLetter || source[index].isNumber || source[index] == "-" || source[index] == "_") { index += 1 }
            guard start != index else { throw Invalid.expression("expected identifier") }
            return String(source[start..<index])
        }
        mutating func atom() throws -> Expression {
            if take("!") { return try .not(atom()) }
            if take("(") {
                let result = try disjunction()
                guard take(")") else { throw Invalid.expression("expected closing parenthesis") }
                return .group(result)
            }
            let variable = try word()
            guard ["mode", "app", "lens", "presentation", "columns", "profile"].contains(variable) else { throw Invalid.expression("unknown variable '\(variable)'") }
            let equal: Bool
            if take("==") { equal = true }
            else if take("!=") { equal = false }
            else {
                guard variable == "lens" || variable == "columns" else { throw Invalid.expression("expected comparison after \(variable)") }
                return .present(variable)
            }
            let value = try word()
            if variable == "columns", Int(value) == nil { throw Invalid.expression("columns requires an integer") }
            return .equal(variable, value, equal)
        }
        mutating func conjunction() throws -> Expression {
            var result = try atom()
            while take("&&") { result = try .and(result, atom()) }
            return result
        }
        mutating func disjunction() throws -> Expression {
            var result = try conjunction()
            while take("||") { result = try .or(result, conjunction()) }
            return result
        }
    }
}
