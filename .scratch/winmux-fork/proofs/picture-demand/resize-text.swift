import AppKit
let app = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.TextEdit" }!
let root = AXUIElementCreateApplication(app.processIdentifier)
var value: CFTypeRef?
AXUIElementCopyAttributeValue(root, kAXWindowsAttribute as CFString, &value)
for window in value as? [AXUIElement] ?? [] {
    var point = CGPoint(x: 0, y: 45), size = CGSize(width: 1920, height: 970)
    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &point)!)
    AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
}
