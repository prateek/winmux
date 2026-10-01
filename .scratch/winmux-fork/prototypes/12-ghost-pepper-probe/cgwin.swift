import AppKit
import CoreGraphics

// usage: cgwin <bundle-id>   prints the app's activation policy and every CG window it owns
let bundleId = CommandLine.arguments[1]
let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
let front = NSWorkspace.shared.frontmostApplication
print("frontmost: \(front?.bundleIdentifier ?? "nil") pid=\(front?.processIdentifier ?? -1)")
for app in apps {
    let policy: String = switch app.activationPolicy {
        case .regular: "regular"
        case .accessory: "accessory"
        case .prohibited: "prohibited"
        @unknown default: "unknown"
    }
    print("app pid=\(app.processIdentifier) policy=\(policy) active=\(app.isActive) hidden=\(app.isHidden)")
}
let pids = Set(apps.map { Int($0.processIdentifier) })
let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list {
    guard let pid = w[kCGWindowOwnerPID as String] as? Int, pids.contains(pid) else { continue }
    let id = w[kCGWindowNumber as String] as? Int ?? -1
    let layer = w[kCGWindowLayer as String] as? Int ?? -1
    let onscreen = w[kCGWindowIsOnscreen as String] as? Bool ?? false
    let alpha = w[kCGWindowAlpha as String] as? Double ?? -1
    let name = w[kCGWindowName as String] as? String ?? ""
    let b = w[kCGWindowBounds as String] as? [String: Double] ?? [:]
    print("  cgwin id=\(id) layer=\(layer) onscreen=\(onscreen) alpha=\(alpha) bounds=\(Int(b["X"] ?? 0)),\(Int(b["Y"] ?? 0)) \(Int(b["Width"] ?? 0))x\(Int(b["Height"] ?? 0)) name=\"\(name)\"")
}
