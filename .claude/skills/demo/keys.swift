// keys: press keys in the guest and log when each chord went out.
//
//   keys <t0> <events.json> down:cmd tap:tab wait:1.0 tap:tab wait:1.3 up:cmd
//
// <t0> is the take's start as seconds since the epoch; each tap is logged with its time since
// then and the chord as the renderer draws it: {"t": 1.62, "keys": "⌘ Tab"}.
import CoreGraphics
import Foundation

let keyCodes: [String: CGKeyCode] = [
    "backspace": 51, "tab": 48, "escape": 53, "return": 36, "space": 49, "backtick": 50, "left": 123, "right": 124, "down": 125, "up": 126,
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14,
    "r": 15, "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
    "semicolon": 41, "slash": 44,
]
let keyLabels = ["backspace": "⌫","tab": "Tab", "escape": "Esc", "return": "↩", "space": "Space", "backtick": "`", "left": "←", "right": "→", "down": "↓", "up": "↑", "semicolon": ";", "slash": "/"]
let modifiers: [(name: String, code: CGKeyCode, flag: CGEventFlags, label: String)] = [
    ("ctrl", 59, .maskControl, "⌃"), ("alt", 58, .maskAlternate, "⌥"), ("shift", 56, .maskShift, "⇧"), ("cmd", 55, .maskCommand, "⌘"),
]

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 3, let t0 = Double(args[0]) else { fatalError("usage: keys <t0> <events.json> <step>…") }
var postDelay: UInt32 = 15_000
var held: [String] = []
var events: [[String: Any]] = []
var flags: CGEventFlags { modifiers.filter { held.contains($0.name) }.reduce(CGEventFlags()) { $0.union($1.flag) } }

@discardableResult
func post(_ code: CGKeyCode, down: Bool) -> Double {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
    event.flags = flags
    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    event.timestamp = UInt64(Double(mach_absolute_time()) * Double(timebase.numer) / Double(timebase.denom))
    event.post(tap: .cghidEventTap)
    let stamp = Double(event.timestamp) / 1e9
    usleep(postDelay)
    return stamp
}

for step in args.dropFirst(2) {
    let parts = step.split(separator: ":", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { fatalError("bad step: \(step)") }
    switch parts[0] {
    case "delay": postDelay = UInt32((Double(parts[1]) ?? 0) * 1_000_000)
    case "wait": usleep(UInt32((Double(parts[1]) ?? 0) * 1_000_000))
    case "down":
        guard let modifier = modifiers.first(where: { $0.name == parts[1] }) else { fatalError("no modifier \(parts[1])") }
        held.append(modifier.name)
        post(modifier.code, down: true)
    case "up":
        guard let modifier = modifiers.first(where: { $0.name == parts[1] }) else { fatalError("no modifier \(parts[1])") }
        held.removeAll { $0 == modifier.name }
        post(modifier.code, down: false)
    case "tap":
        guard let code = keyCodes[parts[1]] else { fatalError("no key \(parts[1])") }
        let chord = modifiers.filter { held.contains($0.name) }.map(\.label) + [keyLabels[parts[1]] ?? parts[1].uppercased()]
        let elapsed = Date().timeIntervalSince1970 - t0
        let bootSeconds = post(code, down: true)
        events.append(["t": elapsed.rounded3, "bootSeconds": bootSeconds, "keys": chord.joined(separator: " ")])
        post(code, down: false)
    default: fatalError("bad step: \(step)")
    }
}
try! JSONSerialization.data(withJSONObject: events, options: [.prettyPrinted]).write(to: URL(fileURLWithPath: args[1]))

extension Double { var rounded3: Double { (self * 1000).rounded() / 1000 } }
