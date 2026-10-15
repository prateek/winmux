import Foundation
import CoreGraphics
let directory = CommandLine.arguments[1]
let furniture: Set<String> = ["Finder", "Dock", "Window Server", "Control Center", "Notification Center", "Wallpaper", "WindowManager", "Spotlight", "TextInputMenuAgent", "SystemUIServer"]
var previous = ""
while true {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    let strangers = windows.filter { !furniture.contains($0[kCGWindowOwnerName as String] as? String ?? "") }
    let summary = strangers.map { "\($0[kCGWindowOwnerName as String] ?? "?") | \($0[kCGWindowName as String] ?? "") | layer=\($0[kCGWindowLayer as String] ?? 0)" }.sorted().joined(separator: "; ")
    let count = (try? String(contentsOfFile: directory + "/count", encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
    let approvals = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist")
    let data = try? Data(contentsOf: approvals)
    let records = data.flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) } as? [String: [String: Any]]
    let uses = records?["/usr/libexec/sshd-keygen-wrapper"]?["kScreenCaptureAlertableUsageCount"].map { String(describing: $0) } ?? "unknown"
    let now = ISO8601DateFormatter().string(from: Date())
    print("\(now) count=\(count) replayd-uses=\(uses) windows=\(summary)")
    fflush(stdout)
    if !summary.isEmpty && summary != previous {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture"); p.arguments = ["-x", directory + "/window-\(Int(Date().timeIntervalSince1970)).png"]
        try? p.run(); p.waitUntilExit()
    }
    previous = summary
    Thread.sleep(forTimeInterval: 3)
}
