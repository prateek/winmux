import AppKit

let position = CGPoint(x: 1100, y: 60)
let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: position, mouseButton: .left)!
move.flags = CGEventSource.flagsState(.combinedSessionState)
move.post(tap: .cghidEventTap)
usleep(100_000)
let scroll = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: -1000, wheel3: 0)!
scroll.flags = CGEventSource.flagsState(.combinedSessionState)
scroll.post(tap: .cghidEventTap)
