import Foundation

struct LensSearchMatch: Equatable {
    let score: Int
    let matchedField: String
    var titleRanges: [Range<Int>] = []
    var appRanges: [Range<Int>] = []

    // Ranking identity predates the display spans.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.score == rhs.score && lhs.matchedField == rhs.matchedField
    }
}

struct LensSearchFields {
    var title: String
    var app: String
    var workspace: String
    var project: String

    func match(_ search: String) -> LensSearchMatch? {
        let words = search.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        if words.isEmpty { return LensSearchMatch(score: 0, matchedField: "") }
        let fields = [("title", title, 2), ("app", app, 2), ("workspace", workspace, 1), ("project", project, 1)]
        var score = 0
        var matched: [String] = []
        var titleRanges: [Range<Int>] = [], appRanges: [Range<Int>] = []
        for word in words {
            let best = fields.compactMap { name, value, weight -> (String, Int, Int, [Range<Int>])? in
                lensSearchTierMatch(word, in: value).map { (name, $0.tier * weight, weight, $0.ranges) }
            }.reduce(nil as (String, Int, Int, [Range<Int>])?) { best, candidate in
                guard let best else { return candidate }
                if candidate.1 > best.1 || (candidate.1 == best.1 && candidate.2 > best.2) { return candidate }
                return best
            }
            guard let best else { return nil }
            score += best.1
            if !matched.contains(best.0) { matched.append(best.0) }
            if best.0 == "title" { titleRanges += best.3 }
            if best.0 == "app" { appRanges += best.3 }
        }
        return LensSearchMatch(score: score, matchedField: matched.joined(separator: ","),
                               titleRanges: mergedLensRanges(titleRanges), appRanges: mergedLensRanges(appRanges))
    }
}

func mergedLensRanges(_ ranges: [Range<Int>]) -> [Range<Int>] {
    var result: [Range<Int>] = []
    for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
        if let last = result.last, last.upperBound >= range.lowerBound {
            result[result.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
        } else { result.append(range) }
    }
    return result
}

func lensSearchTier(_ word: String, in text: String) -> Int? {
    lensSearchTierMatch(word, in: text)?.tier
}

private struct LensSearchTierMatch {
    let tier: Int
    let ranges: [Range<Int>]
}

private func lensSearchTierMatch(_ word: String, in original: String) -> LensSearchTierMatch? {
    let text = original.lowercased()
    // Map lowercased scalar positions back to characters of the displayed string. In particular,
    // İ expands to two scalars; neither a later match nor a partial match may shift the highlight.
    func match(_ tier: Int, _ ranges: [Range<String.Index>]) -> LensSearchTierMatch {
        // Built only for a field that matched; most fields miss on every keystroke.
        let scalarOwners = original.enumerated().flatMap { offset, character in
            Array(repeating: offset, count: String(character).lowercased().unicodeScalars.count)
        }
        let offsets = ranges.flatMap { range -> [Range<Int>] in
            let start = text.unicodeScalars.distance(from: text.startIndex, to: range.lowerBound)
            let end = text.unicodeScalars.distance(from: text.startIndex, to: range.upperBound)
            return scalarOwners[start..<end].map { $0..<($0 + 1) }
        }
        return LensSearchTierMatch(tier: tier, ranges: mergedLensRanges(offsets))
    }
    if text == word { return match(6, [text.startIndex..<text.endIndex]) }
    if text.hasPrefix(word) { return match(5, [text.startIndex..<text.index(text.startIndex, offsetBy: word.count)]) }
    let words = text.split { !$0.isLetter && !$0.isNumber }
    if let first = words.first(where: { $0.hasPrefix(word) }) {
        return match(4, [first.startIndex..<text.index(first.startIndex, offsetBy: word.count)])
    }
    if let range = text.range(of: word) { return match(3, [range]) }
    if String(words.compactMap(\.first)).hasPrefix(word) {
        return match(2, words.prefix(word.count).map { $0.startIndex..<text.index(after: $0.startIndex) })
    }
    var remaining = word[...]
    var consumed: [Range<String.Index>] = []
    for index in text.indices where remaining.first == text[index] {
        remaining = remaining.dropFirst()
        consumed.append(index..<text.index(after: index))
    }
    return remaining.isEmpty ? match(1, consumed) : nil
}
