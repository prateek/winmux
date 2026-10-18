import AppKit

let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0) as? [[String: Any]] ?? []
let panels = rows.filter { ($0[kCGWindowOwnerName as String] as? String) == "WinMuxApp" }
let data = try JSONSerialization.data(withJSONObject: panels, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: data, as: UTF8.self))
