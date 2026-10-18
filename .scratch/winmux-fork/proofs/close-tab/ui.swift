import AppKit
import ApplicationServices

func attr(_ element: AXUIElement, _ key: String) -> AnyObject? {
    var value: AnyObject?
    AXUIElementCopyAttributeValue(element, key as CFString, &value)
    return value
}

func walk(_ element: AXUIElement, depth: Int) {
    guard depth < 20 else { return }
    let text = [kAXRoleAttribute, kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXPositionAttribute, kAXSizeAttribute]
        .compactMap { attr(element, $0).map { "\($0)" } }.joined(separator: " | ")
    print(String(repeating: " ", count: depth) + text)
    for child in attr(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
        walk(child, depth: depth + 1)
    }
}

guard CommandLine.arguments.count == 2, let pid = Int32(CommandLine.arguments[1]) else {
    fatalError("Usage: ui pid")
}
walk(AXUIElementCreateApplication(pid), depth: 0)
