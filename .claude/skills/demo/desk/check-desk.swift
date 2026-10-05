import AppKit
import ApplicationServices
import CoreGraphics
import Vision

let expected = Set(CommandLine.arguments.dropFirst().flatMap { $0.split(separator: " ").compactMap { UInt32($0) } })
var failures: [String] = []
let furniture: Set<String> = ["Window Server", "Dock", "Wallpaper", "WindowManager", "SystemUIServer", "TextInputMenuAgent", "Spotlight"]
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows {
    let owner = window[kCGWindowOwnerName as String] as? String ?? "unknown"
    let id = window[kCGWindowNumber as String] as? UInt32 ?? 0
    let layer = window[kCGWindowLayer as String] as? Int ?? 0
    let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
    let height = bounds["Height"] ?? 0
    let width = bounds["Width"] ?? 0
    if height <= 30 || width <= 1 || furniture.contains(owner) || owner == "WinMuxApp" { continue }
    if !expected.contains(id) {
        failures.append("\(owner): \(window[kCGWindowName as String] as? String ?? "untitled") (layer \(layer))")
    }
}
func attribute(_ node: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(node, name as CFString, &value)
    return value
}
func inspect(_ node: AXUIElement, _ owner: String, _ depth: Int) {
    guard depth < 25 else { return }
    let role = attribute(node, kAXRoleAttribute) as? String ?? ""
    if role == kAXSheetRole || role == "AXDialog" {
        failures.append("\(owner): \(role) \(attribute(node, kAXTitleAttribute) as? String ?? "untitled")")
    }
    for child in attribute(node, kAXChildrenAttribute) as? [AXUIElement] ?? [] { inspect(child, owner, depth + 1) }
}
for app in NSWorkspace.shared.runningApplications where ["Notes", "Safari", "Ghostty", "Zed"].contains(app.localizedName ?? "") {
    let root = AXUIElementCreateApplication(app.processIdentifier)
    for window in attribute(root, kAXWindowsAttribute) as? [AXUIElement] ?? [] { inspect(window, app.localizedName!, 0) }
}
// Zed renders its trust screen inside the editor window without AX children.
let screenshot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".png")
let capture = Process()
capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
capture.arguments = ["-x", screenshot.path]
do {
    try capture.run()
    capture.waitUntilExit()
    defer { try? FileManager.default.removeItem(at: screenshot) }
    guard capture.terminationStatus == 0,
          let image = NSImage(contentsOf: screenshot),
          let pixels = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw NSError(domain: "desk screenshot", code: 1)
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    try VNImageRequestHandler(cgImage: pixels).perform([request])
    let forbidden = ["unrecognized project", "restricted mode", "trust and continue", "enable automatic updates", "welcome to notes", "turn on icloud", "click wallpaper to show desktop items", "dock tile extension added"]
    for text in request.results?.compactMap({ $0.topCandidates(1).first?.string }) ?? [] {
        if forbidden.contains(where: { text.lowercased().contains($0) }) { failures.append("first-run screen: " + text) }
    }
} catch { failures.append("could not inspect first-run screen text: \(error)") }
for failure in Set(failures).sorted() { fputs("stage-desk: stranger: \(failure)\n", stderr) }
if failures.isEmpty { print("ok: no unstaged windows, sheets, banners or widgets") }
exit(failures.isEmpty ? 0 : 1)
