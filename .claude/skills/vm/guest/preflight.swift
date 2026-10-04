// Prints what a take depends on, one fact per line, and exits 1 when the guest is not ready to film.
import AppKit
import ApplicationServices
import CoreGraphics

var ready = true
func check(_ name: String, _ ok: Bool, _ detail: String = "") {
    print("\(ok ? "ok  " : "FAIL") \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    if !ok { ready = false }
}

let session = CGSessionCopyCurrentDictionary() as? [String: Any] ?? [:]
check("unlocked", (session["CGSSessionScreenIsLocked"] as? Bool) != true)
check("accessibility", AXIsProcessTrusted())
check("screen recording", CGPreflightScreenCaptureAccess())
if let mode = CGDisplayCopyDisplayMode(CGMainDisplayID()) {
    print("     display: \(mode.width)x\(mode.height)@\(mode.pixelWidth / max(mode.width, 1))")
}
// A window from anything but the desktop's own furniture is a leftover or a system prompt.
let furniture: Set<String> = ["Finder", "Dock", "Window Server", "Control Center", "Notification Center", "Wallpaper", "WindowManager", "Spotlight", "TextInputMenuAgent", "SystemUIServer"]
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let strangers = Set(windows.filter { ($0[kCGWindowLayer as String] as? Int) == 0 || ($0[kCGWindowLayer as String] as? Int ?? 0) > 20 }
    .compactMap { $0[kCGWindowOwnerName as String] as? String }).subtracting(furniture)
check("clean desktop", strangers.isEmpty, strangers.sorted().joined(separator: ", "))
exit(ready ? 0 : 1)
