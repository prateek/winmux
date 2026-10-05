import AppKit
import ApplicationServices

func attribute(_ node: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(node, name as CFString, &value)
    return value
}
func descendants(_ node: AXUIElement, _ depth: Int = 0) -> [AXUIElement] {
    guard depth < 20 else { return [] }
    return [node] + (attribute(node, kAXChildrenAttribute) as? [AXUIElement] ?? []).flatMap { descendants($0, depth + 1) }
}
func notice(_ root: AXUIElement) -> AXUIElement? {
    descendants(root).first {
        (attribute($0, kAXRoleAttribute) as? String) == kAXGroupRole &&
        (attribute($0, kAXDescriptionAttribute) as? String ?? "").contains("Dock Tile Extension Added")
    }
}
let deadline = Date().addingTimeInterval(30)
while Date() < deadline {
    if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == "Notification Center" }) {
        let root = AXUIElementCreateApplication(app.processIdentifier)
        if let banner = notice(root) {
            // The labelled Close button appears only while the pointer is over the AX banner.
            if let position = attribute(banner, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID() {
                var point = CGPoint.zero
                AXValueGetValue(position as! AXValue, .cgPoint, &point)
                point.x += 5; point.y += 5
                CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
            }
            Thread.sleep(forTimeInterval: 0.3)
            if let close = descendants(banner).first(where: {
                (attribute($0, kAXTitleAttribute) as? String) == "Close" || (attribute($0, kAXDescriptionAttribute) as? String) == "Close"
            }), AXUIElementPerformAction(close, kAXPressAction as CFString) == .success {
                Thread.sleep(forTimeInterval: 1)
                guard notice(root) == nil else { fputs("Registration notice remained after Close\n", stderr); exit(1) }
                print("dismissed Dock tile registration notice by Close label")
                exit(0)
            }
        }
    }
    Thread.sleep(forTimeInterval: 0.2)
}
fputs("No labelled Dock tile registration notice arrived\n", stderr)
exit(1)
