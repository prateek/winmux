import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
func axWindowID(_ element: AXUIElement, _ id: inout CGWindowID) -> AXError

let records = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
let safari = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari")
let pids = Set(safari.map(\.processIdentifier))
let windows = records.filter { record in
    (record[kCGWindowOwnerPID as String] as? Int32).map(pids.contains) ?? false
}
let data = try JSONSerialization.data(withJSONObject: windows, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: data, as: UTF8.self))
for app in safari {
    let ax = AXUIElementCreateApplication(app.processIdentifier)
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &value)
    for window in value as? [AXUIElement] ?? [] {
        var id: CGWindowID = 0
        let error = axWindowID(window, &id)
        var attributes: [String: String] = [:]
        for key in [kAXRoleAttribute, kAXSubroleAttribute, kAXTitleAttribute, kAXPositionAttribute, kAXSizeAttribute] {
            var result: CFTypeRef?
            AXUIElementCopyAttributeValue(window, key as CFString, &result)
            attributes[key] = result.map { String(describing: $0) }
        }
        print("AX pid=\(app.processIdentifier) id=\(id) error=\(error.rawValue) \(attributes)")
    }
}
