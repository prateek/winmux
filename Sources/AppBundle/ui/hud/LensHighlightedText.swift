import SwiftUI

func lensHighlightedText(_ text: String, ranges: [Range<Int>]) -> AttributedString {
    var result = AttributedString(text)
    for range in ranges {
        let start = result.characters.index(result.startIndex, offsetBy: range.lowerBound)
        let end = result.characters.index(result.startIndex, offsetBy: range.upperBound)
        result[start..<end].backgroundColor = Color(red: 1, green: 213 / 255, blue: 74 / 255)
        result[start..<end].foregroundColor = Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255)
    }
    return result
}
