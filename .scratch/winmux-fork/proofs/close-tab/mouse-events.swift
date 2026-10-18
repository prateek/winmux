import AppKit
import ApplicationServices

final class MouseLog {
    static let shared = MouseLog()
    var events: [[String: Any]] = []
}

let mask = (CGEventMask(1) << CGEventType.leftMouseDown.rawValue) | (CGEventMask(1) << CGEventType.leftMouseUp.rawValue)
guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: mask, callback: { _, type, event, _ in
    MouseLog.shared.events.append([
        "type": type == .leftMouseDown ? "down" : "up",
        "machSeconds": Double(event.timestamp) / 1_000_000_000,
        "x": event.location.x, "y": event.location.y,
    ])
    return Unmanaged.passUnretained(event)
}, userInfo: nil) else { fatalError("Mouse event tap unavailable") }
let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
CFRunLoopRunInMode(.defaultMode, Double(CommandLine.arguments[2])!, false)
try JSONSerialization.data(withJSONObject: MouseLog.shared.events, options: [.prettyPrinted]).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
