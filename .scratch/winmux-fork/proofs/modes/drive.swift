import CoreGraphics
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 3 else { fatalError("drive <root> <capture-directory> <step>...") }
let root = arguments[0], output = arguments[1]
let home = FileManager.default.homeDirectoryForCurrentUser.path
let codes: [String: CGKeyCode] = ["tab": 48, "backtick": 50, "escape": 53, "return": 36, "backspace": 51,
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
    "w": 13, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20,
    "o": 31, "u": 32, "l": 37, "j": 38, "semicolon": 41, "k": 40, "slash": 44,
    "left": 123, "right": 124, "down": 125, "up": 126]
let modifiers: [String: (CGKeyCode, CGEventFlags)] = ["cmd": (55, .maskCommand), "shift": (56, .maskShift), "alt": (58, .maskAlternate), "ctrl": (59, .maskControl)]
var flags = CGEventFlags()
func post(_ code: CGKeyCode, down: Bool) {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
    event.flags = flags
    event.post(tap: .cghidEventTap)
    usleep(20_000)
}
for argument in arguments.dropFirst(2) {
    let parts = argument.split(separator: ":", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { fatalError("Invalid step: \(argument)") }
    switch parts[0] {
        case "wait": usleep(UInt32(Double(parts[1])! * 1_000_000))
        case "down":
            let (code, flag) = modifiers[parts[1]]!
            flags.formUnion(flag); post(code, down: true)
        case "up":
            let (code, flag) = modifiers[parts[1]]!
            flags.subtract(flag); post(code, down: false)
        case "tap": let code = codes[parts[1]]!; post(code, down: true); post(code, down: false)
        case "text":
            let units = Array(parts[1].utf16)
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down)!
                event.flags = flags
                units.withUnsafeBufferPointer { event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: $0.baseAddress!) }
                event.post(tap: .cghidEventTap)
                usleep(20_000)
            }
        case "snapshot":
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [home + "/modes/snapshot.sh", root, output, parts[1]]
            try process.run(); process.waitUntilExit()
            guard process.terminationStatus == 0 else { fatalError("Snapshot failed: \(parts[1])") }
        default: fatalError("Unknown step: \(argument)")
    }
}
