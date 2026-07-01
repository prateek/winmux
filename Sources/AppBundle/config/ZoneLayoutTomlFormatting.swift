import Foundation

func normalizedZoneLayoutWidths(_ rawWidths: [Double]) -> [Double] {
    guard rawWidths.count > 1 else { return [1.0] }
    var result: [Double] = []
    var used = 0.0
    for (index, width) in rawWidths.enumerated() {
        if index == rawWidths.count - 1 {
            result.append(max(0.000001, 1.0 - used))
        } else {
            let rounded = (width * 1_000_000).rounded() / 1_000_000
            result.append(rounded)
            used += rounded
        }
    }
    return result
}

func formatTomlFloat(_ value: Double) -> String {
    var text = String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    while text.last == "0" {
        text.removeLast()
    }
    if text.last == "." {
        text.append("0")
    }
    return text == "-0.0" ? "0.0" : text
}

func tomlBasicString(_ value: String) -> String {
    var result = "\""
    for scalar in value.unicodeScalars {
        switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\t": result += "\\t"
            case "\r": result += "\\r"
            default: result.unicodeScalars.append(scalar)
        }
    }
    result += "\""
    return result
}
