import AppKit

let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let rows = windows.filter { ($0[kCGWindowLayer as String] as? Int) == 0 }.compactMap { window -> [String: Any]? in
    guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let id = window[kCGWindowNumber as String] as? Int,
          let pid = window[kCGWindowOwnerPID as String] as? Int else { return nil }
    return ["id": id, "pid": pid, "app": window[kCGWindowOwnerName as String] ?? "",
            "title": window[kCGWindowName as String] ?? "", "bounds": bounds,
            "onscreen": window[kCGWindowIsOnscreen as String] ?? false]
}.sorted { ($0["id"] as! Int) < ($1["id"] as! Int) }
let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: data, as: UTF8.self))
