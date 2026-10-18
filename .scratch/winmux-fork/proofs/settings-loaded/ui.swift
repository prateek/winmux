import AppKit
import ApplicationServices

let args = Array(CommandLine.arguments.dropFirst())
guard let pid = pid_t(args.first ?? "") else { fatalError("ui pid [dump|press label|search text|select label]") }
let app = AXUIElementCreateApplication(pid)
if args.count > 2, args[1] == "scroll", let amount = Int32(args[2]) {
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: 850, y: 520), mouseButton: .left)?.post(tap: .cghidEventTap)
    CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: amount, wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
    exit(0)
}
func attr(_ element: AXUIElement, _ key: String) -> AnyObject? {
    var value: AnyObject?
    AXUIElementCopyAttributeValue(element, key as CFString, &value)
    return value
}
func children(_ element: AXUIElement) -> [AXUIElement] {
    var result = attr(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    if element == app, let bar = attr(element, kAXExtrasMenuBarAttribute) { result.append(bar as! AXUIElement) }
    return result
}
func labels(_ element: AXUIElement) -> [String] {
    [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXIdentifierAttribute].compactMap { attr(element, $0) as? String }
}
func contains(_ element: AXUIElement, label: String) -> Bool {
    labels(element).contains(label) || children(element).contains { contains($0, label: label) }
}
var found = false
func walk(_ element: AXUIElement, depth: Int = 0) {
    guard depth < 28, !found else { return }
    let role = attr(element, kAXRoleAttribute) as? String ?? ""
    let text = labels(element)
    let action = args.count > 1 ? args[1] : "dump"
    let target = args.count > 2 ? args[2] : ""
    if action == "dump" {
        let position = attr(element, kAXPositionAttribute).map { "\($0)" } ?? ""
        let size = attr(element, kAXSizeAttribute).map { "\($0)" } ?? ""
        let extra = [kAXFocusedAttribute, kAXEnabledAttribute, kAXMenuItemMarkCharAttribute].compactMap { key in attr(element, key).map { "\(key)=\($0)" } }.joined(separator: " ")
        print(String(repeating: " ", count: depth) + "\(role) | \(text.joined(separator: " | ")) | \(position) \(size) \(extra)")
    } else if action == "pane", role == kAXRowRole, contains(element, label: target) {
        let result = AXUIElementSetAttributeValue(element, kAXSelectedAttribute as CFString, kCFBooleanTrue)
        print("pane \(target): \(result.rawValue)")
        found = result == .success
        return
    } else if action == "close-settings", role == kAXWindowRole, text.contains(where: { $0.hasSuffix(".shortcutSettings") }), let button = attr(element, kAXCloseButtonAttribute) {
        let result = AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
        print("close settings: \(result.rawValue)")
        found = result == .success
        return
    } else if action == "press", text.contains(target), role != kAXStaticTextRole {
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        if result == .success { print("pressed \(target)"); found = true; return }
    } else if action == "select", text.contains(target) {
        let result = AXUIElementSetAttributeValue(element, kAXSelectedAttribute as CFString, kCFBooleanTrue)
        if result == .success { print("selected \(target)"); found = true; return }
    } else if action == "search", role == kAXTextFieldRole {
        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, target as CFString)
        print("search AXValue result=\(result.rawValue) focused=\(attr(element, kAXFocusedAttribute) ?? "nil" as NSString) value=\(attr(element, kAXValueAttribute) ?? "nil" as NSString)")
        found = result == .success
        return
    }
    for child in children(element) { walk(child, depth: depth + 1) }
}
walk(app)
if args.count > 1, args[1] != "dump", !found { exit(2) }
