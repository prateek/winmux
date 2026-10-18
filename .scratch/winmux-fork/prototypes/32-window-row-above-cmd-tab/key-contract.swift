import CoreGraphics
import Foundation

func post(_ code: CGKeyCode, _ down: Bool, _ command: Bool = true) {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
    event.flags = command ? .maskCommand : []
    event.post(tap: .cghidEventTap)
}
func tap(_ code: CGKeyCode) { post(code, true); post(code, false) }
func open() { post(55, true); tap(48); usleep(600_000) }
let mode = CommandLine.arguments.last!
if mode == "pairs" {
    open()
    post(0, true)
    usleep(50_000)
    post(55, false, false)
    usleep(30_000)
    post(0, false, false)
    usleep(400_000)
} else if mode == "escape" {
    open(); tap(0); usleep(100_000)
    // All posted together: no inter-action sleep gives AX destruction no head start.
    tap(53); tap(0); tap(124); post(55, false, false)
    usleep(400_000)
} else if mode == "fade" {
    for delay: UInt32 in [0, 500, 1000, 2000, 5000, 10000] {
        open()
        post(55, false, false)
        usleep(delay)
        post(55, true)
        usleep(2000)
        tap(0)
        post(55, false, false)
        usleep(400_000)
    }
} else if mode == "new-session" {
    open(); tap(0); usleep(50_000)
    post(55, false, false)
    usleep(20_000)
    post(55, true); tap(48)
    usleep(600_000)
    tap(53); post(55, false, false)
}
