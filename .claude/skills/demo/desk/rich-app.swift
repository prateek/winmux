import AppKit

let args = CommandLine.arguments
if args.count == 2, args[1] == "display", let screen = NSScreen.main {
    print("\(Int(screen.frame.width))x\(Int(screen.frame.height))@\(Int(screen.backingScaleFactor))")
} else if args.count == 5, args[1] == "activate", let occurrence = Int(args[4]), occurrence > 0 {
    let apps = NSWorkspace.shared.runningApplications.filter { $0.localizedName == args[2] }
        .sorted { $0.processIdentifier < $1.processIdentifier }
    var matches: [(NSRunningApplication, AXUIElement)] = []
    for app in apps {
        var value: CFTypeRef?
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementCopyAttributeValue(root, kAXWindowsAttribute as CFString, &value)
        for window in value as? [AXUIElement] ?? [] {
            var title: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
            if (title as? String ?? "").contains(args[3]) { matches.append((app, window)) }
        }
    }
    if matches.count >= occurrence {
        let (app, window) = matches[occurrence - 1]
        app.activate(options: [])
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    } else if let app = apps.last {
        app.activate(options: [])
    } else {
        exit(1)
    }
} else {
    exit(1)
}
