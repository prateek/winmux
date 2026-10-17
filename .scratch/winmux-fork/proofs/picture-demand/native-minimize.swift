import AppKit
let app = NSWorkspace.shared.runningApplications.first { $0.localizedName == "stage" }!
let root = AXUIElementCreateApplication(app.processIdentifier)
var value: CFTypeRef?
AXUIElementCopyAttributeValue(root, kAXWindowsAttribute as CFString, &value)
for window in value as? [AXUIElement] ?? [] {
    var title: CFTypeRef?
    AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
    guard title as? String == "Window 01" else { continue }
    if CommandLine.arguments.contains("--restore") {
        let error = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        precondition(error == .success)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }
    var minimized: CFTypeRef?
    AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized)
    print("Window 01 native minimized: \(minimized as? Bool ?? false)")
}
