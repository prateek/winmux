import AppKit
import ApplicationServices

func attribute(_ e: AXUIElement, _ key: String) -> CFTypeRef? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(e, key as CFString, &value)
    return value
}
let args = Array(CommandLine.arguments.dropFirst())
let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
for app in apps where args.isEmpty || app.localizedName?.localizedCaseInsensitiveContains(args[0]) == true {
    print("APP \(app.localizedName ?? "") \(app.processIdentifier)")
    let root = AXUIElementCreateApplication(app.processIdentifier)
    func visit(_ e: AXUIElement, _ depth: Int) {
        if depth > 11 { return }
        let role = attribute(e, kAXRoleAttribute) as? String ?? ""
        let title = attribute(e, kAXTitleAttribute) as? String ?? ""
        let description = attribute(e, kAXDescriptionAttribute) as? String ?? ""
        if !title.isEmpty || !description.isEmpty || role == "AXWindow" {
            print(String(repeating: " ", count: depth) + "\(role) | \(title) | \(description) | \(String(describing: attribute(e, kAXPositionAttribute))) | \(String(describing: attribute(e, kAXSizeAttribute)))")
        }
        for child in attribute(e, kAXChildrenAttribute) as? [AXUIElement] ?? [] { visit(child, depth + 1) }
    }
    visit(root, 0)
}
