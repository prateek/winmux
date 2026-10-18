import AppKit
import ApplicationServices

let args = CommandLine.arguments
guard args.count == 4, let x = Double(args[2]), let y = Double(args[3]) else {
    fatalError("Usage: input middle|move x y")
}
let point = CGPoint(x: x, y: y)
let source = CGEventSource(stateID: .hidSystemState)
if args[1] == "middle" {
    let down = CGEvent(mouseEventSource: source, mouseType: .otherMouseDown, mouseCursorPosition: point, mouseButton: .center)!
    let up = CGEvent(mouseEventSource: source, mouseType: .otherMouseUp, mouseCursorPosition: point, mouseButton: .center)!
    down.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.05)
    up.post(tap: .cghidEventTap)
} else {
    CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)!.post(tap: .cghidEventTap)
}
