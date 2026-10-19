import AppKit
import ApplicationServices

let bundle = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "com.apple.Safari"
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else { exit(1) }
func read(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
    var result: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success ? result : nil
}
var rows: [[String: Any]] = []
func visit(_ element: AXUIElement, depth: Int = 0) {
    guard depth < 45 else { return }
    let role = read(element, kAXRoleAttribute) as? String ?? ""
    if [kAXStaticTextRole, kAXButtonRole, kAXTextFieldRole, kAXCheckBoxRole, kAXHeadingRole].contains(role) {
        var row: [String: Any] = ["role": role]
        for key in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
            if let value = read(element, key) as? String, !value.isEmpty { row[key] = value }
        }
        if let position = read(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
           let size = read(element, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() {
            var point = CGPoint.zero, dimensions = CGSize.zero
            AXValueGetValue(unsafeBitCast(position, to: AXValue.self), .cgPoint, &point)
            AXValueGetValue(unsafeBitCast(size, to: AXValue.self), .cgSize, &dimensions)
            row["frame"] = [point.x, point.y, dimensions.width, dimensions.height]
        }
        if row.count > 2 { rows.append(row) }
    }
    for child in read(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] { visit(child, depth: depth + 1) }
}
visit(AXUIElementCreateApplication(app.processIdentifier))
let output = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: output, as: UTF8.self))
