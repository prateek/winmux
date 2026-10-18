import AppKit
import ApplicationServices

let args = CommandLine.arguments
guard args.count == 5, let x = Double(args[1]), let y = Double(args[2]),
      let targetX = Double(args[3]), let targetY = Double(args[4])
else { fatalError("Usage: drag start-x start-y end-x end-y") }
let source = CGEventSource(stateID: .hidSystemState)
func post(_ type: CGEventType, _ point: CGPoint) {
    CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)!.post(tap: .cghidEventTap)
}
post(.mouseMoved, CGPoint(x: x, y: y))
Thread.sleep(forTimeInterval: 0.3)
post(.leftMouseDown, CGPoint(x: x, y: y))
Thread.sleep(forTimeInterval: 0.3)
for step in 1...100 {
    let progress = Double(step) / 100
    post(.leftMouseDragged, CGPoint(x: x + (targetX - x) * progress, y: y + (targetY - y) * progress))
    Thread.sleep(forTimeInterval: 0.02)
}
Thread.sleep(forTimeInterval: 0.6)
post(.leftMouseUp, CGPoint(x: targetX, y: targetY))
