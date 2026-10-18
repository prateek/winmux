import AppKit
import ApplicationServices

var last = ""
let timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
    let app = NSWorkspace.shared.frontmostApplication
    var title = ""
    if let app {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 1.0)
        var window: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXFocusedWindow" as CFString, &window) == .success, let window {
            let w = window as! AXUIElement
            AXUIElementSetMessagingTimeout(w, 1.0)
            var value: CFTypeRef?
            AXUIElementCopyAttributeValue(w, "AXTitle" as CFString, &value)
            title = value as? String ?? ""
        }
    }
    let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
    let ids = windows.filter { ($0[kCGWindowLayer as String] as? Int) == 0 }.compactMap { $0[kCGWindowNumber as String] as? Int }
    let state = "\(app?.processIdentifier ?? 0)|\(title)|\(ids)"
    if state != last {
        last = state
        let fields: [String: Any] = ["time": ProcessInfo.processInfo.systemUptime, "pid": app?.processIdentifier ?? 0, "app": app?.localizedName ?? "", "title": title, "onscreen": ids]
        print(String(data: try! JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]), encoding: .utf8)!)
        fflush(stdout)
    }
}
RunLoop.main.run()
