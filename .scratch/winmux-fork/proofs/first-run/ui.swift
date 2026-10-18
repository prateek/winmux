import AppKit
import ApplicationServices

let bundle = CommandLine.arguments[1]
let press = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : nil
func attr(_ element: AXUIElement, _ key: String) -> AnyObject? {
    var value: AnyObject?
    AXUIElementCopyAttributeValue(element, key as CFString, &value)
    return value
}
func walk(_ element: AXUIElement, depth: Int) {
    guard depth < 18 else { return }
    let keys = [kAXRoleAttribute, kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXPositionAttribute, kAXSizeAttribute]
    let text = keys.compactMap { attr(element, $0).map { "\($0)" } }.joined(separator: " | ")
    if let press, attr(element, kAXRoleAttribute) as? String == kAXButtonRole,
       attr(element, kAXDescriptionAttribute) as? String == press || attr(element, kAXTitleAttribute) as? String == press {
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        print("PRESS \(press): \(result.rawValue)")
        exit(result == .success ? 0 : 1)
    }
    print(String(repeating: " ", count: depth) + text)
    for child in attr(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] { walk(child, depth: depth + 1) }
}
for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundle) {
    print("APP \(app.localizedName ?? "") pid=\(app.processIdentifier) active=\(app.isActive) policy=\(app.activationPolicy.rawValue)")
    walk(AXUIElementCreateApplication(app.processIdentifier), depth: 0)
}
if let press {
    fputs("No button named \(press) in \(bundle)\n", stderr)
    exit(2)
}
