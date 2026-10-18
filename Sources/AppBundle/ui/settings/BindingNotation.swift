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
