import AppKit
import Foundation

let ui = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as! [[String: Any]]
let configured = Double(CommandLine.arguments[2])!
let buttons = ui.filter { ($0["role"] as? String) == "AXButton" && ($0["x"] as? Double ?? -1) >= 0 && ($0["x"] as? Double ?? 9999) < configured }
let columnButtonX = buttons.first { ($0["description"] as? String) == "Show Columns" }.map { ($0["x"] as! Double) + ($0["width"] as! Double) / 2 }

func width(_ text: String, _ size: CGFloat, _ weight: NSFont.Weight) -> Double {
    Double((text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width)
}

var result: [[String: Any]] = []
for row in buttons {
    let description = row["description"] as? String ?? ""
    guard description != "Show splits", description != "Show Columns" else { continue }
    let height = row["height"] as! Double
    guard height >= 17, height <= 25, !description.isEmpty else { continue }
    let frameWidth = row["width"] as! Double
    var title = description
    var natural = width(title, 12.5, title == "winmux.ncl — winmux.ncl" ? .semibold : .regular)
    var available = frameWidth - 28
    if description.hasPrefix("Workspace ") {
        let hasColumns = description == "Workspace 2" || description == "Workspace 3"
        natural = width(title, 15, description == "Workspace 1" ? .bold : .semibold)
        if hasColumns, let columnButtonX {
            available = columnButtonX - 92 - 20 - (row["x"] as! Double)
        } else {
            available = configured - 30 - 9 - 20 - (row["x"] as! Double)
        }
    } else if description.hasPrefix("Column ") || description.hasPrefix("↔") || description.hasPrefix("↕") {
        natural = width(title, 13, .regular)
        available = frameWidth
    } else if let range = description.range(of: ", ", options: .backwards), let count = Int(description[range.upperBound...]) {
        title = String(description[..<range.lowerBound])
        natural = width(title, 13, .regular)
        let icons = min(count, 4)
        let iconWidth = Double(icons * 14 - max(0, icons - 1) * 3)
        available = frameWidth - 8 - iconWidth - 18 - width(String(count), 10.5, .medium)
    }
    result.append(["title": title, "natural": natural, "available": available,
                   "clipped": natural > available + 0.5,
                   "requiredSidebarWidth": ceil(configured + natural - available)])
}
let data = try JSONSerialization.data(withJSONObject: ["configuredWidth": configured, "rows": result], options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(data)
