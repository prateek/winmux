import Foundation

struct LensSearchMatch: Equatable {
    let score: Int
    let matchedField: String
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
        for word in words {
            let best = fields.compactMap { name, value, weight -> (String, Int, Int)? in
                lensSearchTier(word, in: value).map { (name, $0, weight) }
            }.max { lhs, rhs in
                lhs.1 == rhs.1 ? lhs.2 < rhs.2 : lhs.1 < rhs.1
            }
            guard let best else { return nil }
            score += best.1 * best.2
            if !matched.contains(best.0) { matched.append(best.0) }
        }
        return LensSearchMatch(score: score, matchedField: matched.joined(separator: ","))
    }
}

func lensSearchTier(_ word: String, in text: String) -> Int? {
    let text = text.lowercased()
    if text == word { return 6 }
    if text.hasPrefix(word) { return 5 }
    let words = text.split { !$0.isLetter && !$0.isNumber }
    if words.contains(where: { $0.hasPrefix(word) }) { return 4 }
    if text.contains(word) { return 3 }
    if String(words.compactMap(\.first)).hasPrefix(word) { return 2 }
    var remaining = word[...]
    for char in text where remaining.first == char { remaining = remaining.dropFirst() }
    return remaining.isEmpty ? 1 : nil
}
