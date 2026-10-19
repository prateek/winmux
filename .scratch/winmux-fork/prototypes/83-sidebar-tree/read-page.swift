import AppKit
import ApplicationServices

guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first else { exit(1) }
let root = AXUIElementCreateApplication(app.processIdentifier)
func read(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success ? value : nil
}
func visit(_ element: AXUIElement, depth: Int = 0) {
    guard depth < 35 else { return }
    let role = read(element, kAXRoleAttribute) as? String ?? ""
    if role == kAXStaticTextRole || role == kAXTextFieldRole {
        if let value = read(element, kAXValueAttribute) as? String, !value.isEmpty {
            print(value)
        }
    }
    for child in read(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
        visit(child, depth: depth + 1)
    }
}
if let window = read(root, kAXFocusedWindowAttribute), CFGetTypeID(window) == AXUIElementGetTypeID() {
    visit(unsafeBitCast(window, to: AXUIElement.self))
}
