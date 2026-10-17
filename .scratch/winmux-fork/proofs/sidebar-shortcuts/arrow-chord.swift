import CoreGraphics
import Foundation

let codes: [String: CGKeyCode] = ["up": 126, "down": 125, "left": 123, "right": 124]
guard CommandLine.arguments.count == 2, let code = codes[CommandLine.arguments[1]] else {
    fatalError("usage: arrow-chord <up|down|left|right>")
}
func post(_ code: CGKeyCode, down: Bool, flags: CGEventFlags) {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
    event.flags = flags
    event.post(tap: .cghidEventTap)
    usleep(100_000)
}
post(59, down: true, flags: .maskControl)
post(code, down: true, flags: [.maskControl, .maskSecondaryFn])
post(code, down: false, flags: [.maskControl, .maskSecondaryFn])
post(59, down: false, flags: [])
