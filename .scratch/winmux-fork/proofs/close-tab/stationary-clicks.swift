import AppKit
import ApplicationServices

let args = CommandLine.arguments
guard args.count == 5, let x = Double(args[1]), let y = Double(args[2]), let count = Int(args[3]),
      let interval = Double(args[4]), count > 0, interval >= 0.1
else { fatalError("Usage: stationary-clicks x y count interval-seconds") }

let point = CGPoint(x: x, y: y)
let source = CGEventSource(stateID: .hidSystemState)
for index in 0..<count {
    let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)!
    let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)!
    down.setIntegerValueField(.mouseEventClickState, value: 1)
    up.setIntegerValueField(.mouseEventClickState, value: 1)
    print("click \(index + 1) down \(ProcessInfo.processInfo.systemUptime) at \(x),\(y)")
    down.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.05)
    up.post(tap: .cghidEventTap)
    if index + 1 < count { Thread.sleep(forTimeInterval: interval - 0.05) }
}
