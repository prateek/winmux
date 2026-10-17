import AppKit

guard CommandLine.arguments.count == 7, let pid = Int32(CommandLine.arguments[1]) else {
    fatalError("reshape pid title x y width height")
}
let title = CommandLine.arguments[2]
let numbers = CommandLine.arguments[3...6].map { Double($0)! }
let app = AXUIElementCreateApplication(pid)
var raw: CFTypeRef?
guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &raw) == .success,
      let windows = raw as? [AXUIElement] else { fatalError("no windows") }
let window = windows.first { window in
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value)
    return value as? String == title
}!
var point = CGPoint(x: numbers[0], y: numbers[1])
var size = CGSize(width: numbers[2], height: numbers[3])
precondition(AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!) == .success)
precondition(AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &point)!) == .success)
print("reshaped \(title): \(point), \(size)")
