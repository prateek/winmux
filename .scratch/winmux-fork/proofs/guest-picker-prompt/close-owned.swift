import AppKit
import ApplicationServices
let bundles: Set<String> = ["dev.zed.Zed", "com.mitchellh.ghostty", "com.apple.Safari", "com.apple.Notes"]
for app in NSWorkspace.shared.runningApplications where bundles.contains(app.bundleIdentifier ?? "") {
    let element = AXUIElementCreateApplication(app.processIdentifier)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
          let windows = value as? [AXUIElement] else { continue }
    for window in windows {
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
        var button: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &button) == .success,
           let button, CFGetTypeID(button) == AXUIElementGetTypeID() {
            let result = AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
            print("close \(app.bundleIdentifier ?? ""): \(title ?? "" as CFString) result=\(result.rawValue)")
        }
    }
}
