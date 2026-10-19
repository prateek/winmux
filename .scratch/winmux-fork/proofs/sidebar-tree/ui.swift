import AppKit
import ApplicationServices

func attribute(_ element: AXUIElement, _ key: String) -> AnyObject? {
    var value: AnyObject?
    AXUIElementCopyAttributeValue(element, key as CFString, &value)
    return value
}

func point(_ value: AnyObject?) -> CGPoint? {
    guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var result = CGPoint.zero
    return AXValueGetValue(value as! AXValue, .cgPoint, &result) ? result : nil
}

func size(_ value: AnyObject?) -> CGSize? {
    guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var result = CGSize.zero
    return AXValueGetValue(value as! AXValue, .cgSize, &result) ? result : nil
}

var rows: [[String: Any]] = []
func walk(_ element: AXUIElement, depth: Int) {
    guard depth < 28 else { return }
    let role = attribute(element, kAXRoleAttribute) as? String ?? ""
    let title = attribute(element, kAXTitleAttribute) as? String ?? ""
    let description = attribute(element, kAXDescriptionAttribute) as? String ?? ""
    let value = attribute(element, kAXValueAttribute) as? String ?? ""
    if let position = point(attribute(element, kAXPositionAttribute)), let dimensions = size(attribute(element, kAXSizeAttribute)) {
        rows.append(["role": role, "title": title, "description": description, "value": value,
                     "x": position.x, "y": position.y, "width": dimensions.width, "height": dimensions.height])
    }
    for child in attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] { walk(child, depth: depth + 1) }
}

let pid = pid_t(CommandLine.arguments[1])!
walk(AXUIElementCreateApplication(pid), depth: 0)
let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(data)
