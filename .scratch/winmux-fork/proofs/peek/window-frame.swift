import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
func axWindowId(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

let args = Array(CommandLine.arguments.dropFirst())
guard args.count == 5, let id = UInt32(args[0]), AXIsProcessTrusted() else { exit(1) }
let rows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
guard let row = rows.first(where: { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == id }),
      let pid = row[kCGWindowOwnerPID as String] as? Int32 else { exit(2) }
let app = AXUIElementCreateApplication(pid)
var value: CFTypeRef?
guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
      let windows = value as? [AXUIElement] else { exit(3) }
for window in windows {
    var candidate: CGWindowID = 0
    guard axWindowId(window, &candidate) == .success, candidate == id else { continue }
    var point = CGPoint(x: Double(args[1])!, y: Double(args[2])!)
    var size = CGSize(width: Double(args[3])!, height: Double(args[4])!)
    let position = AXValueCreate(.cgPoint, &point)!, extent = AXValueCreate(.cgSize, &size)!
    guard AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, extent) == .success,
          AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position) == .success else { exit(4) }
    print("Prepared window \(id): \(point), \(size)")
    exit(0)
}
exit(5)
