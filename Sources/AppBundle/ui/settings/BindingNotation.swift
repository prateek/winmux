import Foundation

func displayBindingNotation(_ notation: String) -> String {
    notation.split(separator: "-").map { component in
        switch component {
            case "alt": "⌥"
            case "ctrl": "⌃"
            case "cmd": "⌘"
            case "shift": "⇧"
            case "left": "←"
            case "right": "→"
            case "up": "↑"
            case "down": "↓"
            case "enter": "↩"
            case "esc": "⎋"
            case "space": "Space"
            case "tab": "⇥"
            case "backspace": "⌫"
            case "semicolon": ";"
            case "comma": ","
            case "period": "."
            case "slash": "/"
            case "minus": "-"
            case "equal": "="
            default: String(component).uppercased()
        }
    }.joined()
}

/// A tap binding names one modifier key and its side, `left-alt`, not a chord.
func displayTapNotation(_ notation: String) -> String {
    let parts = notation.split(separator: "-", maxSplits: 1).map(String.init)
    guard parts.count == 2, ["left", "right"].contains(parts[0]) else { return displayBindingNotation(notation) }
    return "\(parts[0].capitalized) \(displayBindingNotation(parts[1]))"
}
