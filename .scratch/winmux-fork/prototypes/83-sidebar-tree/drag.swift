import CoreGraphics
import Foundation

let args = CommandLine.arguments.dropFirst().compactMap(Double.init)
guard args.count == 4 else { fatalError("drag x1 y1 x2 y2") }
let start = CGPoint(x: args[0], y: args[1]), end = CGPoint(x: args[2], y: args[3])
func post(_ type: CGEventType, at point: CGPoint) {
    let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)!
    event.flags = []
    event.post(tap: .cghidEventTap)
}
post(.mouseMoved, at: start)
usleep(200_000)
post(.leftMouseDown, at: start)
usleep(200_000)
for step in 1...40 {
    let progress = Double(step) / 40
    post(.leftMouseDragged, at: CGPoint(x: start.x + (end.x - start.x) * progress,
                                      y: start.y + (end.y - start.y) * progress))
    usleep(30_000)
}
usleep(700_000)
post(.leftMouseDragged, at: end)
usleep(200_000)
post(.leftMouseUp, at: end)
