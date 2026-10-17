import AppKit
let app = NSWorkspace.shared.runningApplications.first { $0.localizedName == "stage" }!
let root = AXUIElementCreateApplication(app.processIdentifier)
var value: CFTypeRef?
AXUIElementCopyAttributeValue(root, kAXWindowsAttribute as CFString, &value)
for window in value as? [AXUIElement] ?? [] {
    var title: CFTypeRef?
    AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
    guard title as? String == "Window 01" else { continue }
    if !CommandLine.arguments.contains("--inspect") {
        var size = CGSize(width: 180, height: 120)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
    }
    var current: CFTypeRef?
    AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &current)
    var size = CGSize.zero
    if let current { AXValueGetValue(current as! AXValue, .cgSize, &size) }
    print("Window 01 native frame size: \(size)")
}
