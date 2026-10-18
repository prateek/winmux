import CoreGraphics
import Foundation

let targets: Set<String> = ["Zed", "Ghostty", "Safari", "Notes"]
let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let rows = windows.filter {
    targets.contains($0[kCGWindowOwnerName as String] as? String ?? "") && ($0[kCGWindowLayer as String] as? Int) == 0
}.map { window -> [String: Any] in
    ["id": window[kCGWindowNumber as String] ?? 0,
     "app": window[kCGWindowOwnerName as String] ?? "",
     "title": window[kCGWindowName as String] ?? "",
     "frame": window[kCGWindowBounds as String] ?? [:]]
}.sorted { ($0["id"] as? Int ?? 0) < ($1["id"] as? Int ?? 0) }
let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(data)
print()
