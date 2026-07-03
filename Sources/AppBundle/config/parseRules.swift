import Common
import TOMLKit

private let ruleParser: [String: any ParserProtocol<RuleConfig>] = [
    "if": Parser(\.matcher, parseWindowDetectedMatcher),
    "card": Parser(\.card) { raw, backtrace in
        parseString(raw, backtrace).map(Optional.some)
    },
    "focus": Parser(\.focus, parseBool),
    "check-further-rules": Parser(\.checkFurtherRules, parseBool),
]

/// Parses the `[[rules]]` array-of-tables, reusing the `on-window-detected` matcher engine for
/// each `if` sub-table. Array order is the runtime evaluation order: a match stops evaluation
/// unless it opts into `check-further-rules`. Card names are intentionally not validated against
/// existing cards: a rule may name one that does not exist yet, and the runtime creates it.
func parseRules(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [RuleConfig] {
    guard let array = raw.array else {
        errors.append(expectedActualTypeError(expected: .array, actual: raw.type, backtrace))
        return []
    }

    return array.enumerated().compactMap { index, rawRule in
        let ruleBacktrace = backtrace + .index(index)
        var myErrors: [TomlParseError] = []
        let rule = parseTable(rawRule, RuleConfig(), ruleParser, ruleBacktrace, &myErrors)
        if rule.card == nil {
            myErrors.append(.semantic(ruleBacktrace + .key("card"), "Missing required key"))
        }
        if !myErrors.isEmpty {
            errors += myErrors
            return nil
        }
        return rule
    }
}
