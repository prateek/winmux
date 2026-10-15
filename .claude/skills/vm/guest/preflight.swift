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
let approvals = Process()
approvals.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
approvals.arguments = [URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent().appendingPathComponent("approvals.py").path, "check"]
let approvalOutput = Pipe()
approvals.standardOutput = approvalOutput
approvals.standardError = approvalOutput
do {
    try approvals.run()
    let detail = String(data: approvalOutput.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    approvals.waitUntilExit()
    check("approvals", approvals.terminationStatus == 0, detail.trimmingCharacters(in: .whitespacesAndNewlines))
} catch {
    check("approvals", false, "rebuild the golden image: vm build-image (\(error.localizedDescription))")
}
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
