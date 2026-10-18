import AppKit
import ApplicationServices

let command = CommandLine.arguments.dropFirst().first ?? "focus"
if command == "focus" {
    let app = NSWorkspace.shared.frontmostApplication!
    let element = AXUIElementCreateApplication(app.processIdentifier)
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &value)
    var title: CFTypeRef?
    if let value {
        AXUIElementCopyAttributeValue(value as! AXUIElement, kAXTitleAttribute as CFString, &title)
    }
    print("frontmost=\(app.localizedName ?? "") title=\(title as? String ?? "")")
} else {
    let start = ProcessInfo.processInfo.systemUptime
    repeat {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let overlays = windows.filter {
            ($0[kCGWindowOwnerName as String] as? String) == "WinMuxApp" &&
            ($0[kCGWindowLayer as String] as? Int) == 25 &&
            (($0[kCGWindowBounds as String] as? [String: Double])?["Height"] ?? 0) > 600
        }
        let alpha = overlays.first?[kCGWindowAlpha as String] as? Double ?? 0
        print(String(format: "%.4f,%d,%.4f", ProcessInfo.processInfo.systemUptime - start, overlays.count, alpha))
        Thread.sleep(forTimeInterval: 1.0 / 60)
    } while ProcessInfo.processInfo.systemUptime - start < 3
}
