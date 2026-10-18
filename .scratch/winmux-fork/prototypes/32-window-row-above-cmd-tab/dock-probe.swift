import AppKit
import ApplicationServices

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value
}

func dump(_ element: AXUIElement, depth: Int = 0) {
    guard depth < 12 else { return }
    AXUIElementSetMessagingTimeout(element, 1.0)
    let fields = ["AXRole", "AXSubrole", "AXTitle", "AXDescription", "AXPosition", "AXSize", "AXSelected", "AXValue", "AXIdentifier", "AXURL"]
    print(String(repeating: "  ", count: depth) + fields.map { "\($0)=\(attribute(element, $0).map { String(describing: $0) } ?? "nil")" }.joined(separator: " "))
    if attribute(element, "AXSubrole") as? String == "AXProcessSwitcherList" {
        var names: CFArray?
        AXUIElementCopyAttributeNames(element, &names)
        for name in names as? [String] ?? [] { print("SWITCHER \(name): \(String(describing: attribute(element, name)))") }
        for selected in attribute(element, "AXSelectedChildren") as? [AXUIElement] ?? [] { print("SELECTED TITLE: \(String(describing: attribute(selected, "AXTitle")))") }
        for button in attribute(element, "AXChildren") as? [AXUIElement] ?? [] {
            var attributes: CFArray?
            AXUIElementCopyAttributeNames(button, &attributes)
            for name in attributes as? [String] ?? [] { print("BUTTON \(name): \(String(describing: attribute(button, name)))") }
        }
    }
    for child in attribute(element, "AXChildren") as? [AXUIElement] ?? [] { dump(child, depth: depth + 1) }
}

if let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first {
    for app in NSWorkspace.shared.runningApplications { print("APP pid=\(app.processIdentifier) title=\(app.localizedName ?? "") url=\(app.bundleURL?.absoluteString ?? "") executable=\(app.executableURL?.absoluteString ?? "")") }
    print("Dock pid=\(dock.processIdentifier)")
    dump(AXUIElementCreateApplication(dock.processIdentifier))
    if CommandLine.arguments.contains("--observe") {
        var observer: AXObserver?
        AXObserverCreate(dock.processIdentifier, { _, element, name, _ in
            print("NOTIFICATION \(name) role=\(String(describing: attribute(element, "AXRole"))) subrole=\(String(describing: attribute(element, "AXSubrole"))) title=\(String(describing: attribute(element, "AXTitle")))")
            fflush(stdout)
        }, &observer)
        if let observer {
            for name in ["AXSelectedChildrenChanged", "AXCreated", "AXFocusedUIElementChanged", "AXUIElementDestroyed"] {
                print("REGISTER \(name): \(AXObserverAddNotification(observer, AXUIElementCreateApplication(dock.processIdentifier), name as CFString, nil).rawValue)")
            }
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 5))
        }
    }
}
