import AppKit
import CoreGraphics

struct ColumnSnapInputState: Equatable, Sendable {
    var modifierFlags: CGEventFlags
    var pressedMouseButtons: Int
}

func currentColumnSnapInputState() -> ColumnSnapInputState {
    ColumnSnapInputState(
        modifierFlags: currentSessionModifierFlags(),
        pressedMouseButtons: NSEvent.pressedMouseButtons,
    )
}

func mouseButtonMask(buttonNumber: Int) -> Int {
    1 << buttonNumber
}

func isMouseButtonPressed(buttonNumber: Int, in mask: Int) -> Bool {
    (mask & mouseButtonMask(buttonNumber: buttonNumber)) != 0
}

func isSecondaryMouseButtonPressed(in mask: Int) -> Bool {
    isMouseButtonPressed(buttonNumber: 1, in: mask)
}

func columnSnapActivationInputIsPressed(_ config: ColumnSnapConfig, inputState: ColumnSnapInputState) -> Bool {
    switch config.gesture {
        case .drag:
            return columnSnapModifierIsPressed(config.modifier, in: inputState.modifierFlags)
        case .secondaryButtonDrag:
            return isSecondaryMouseButtonPressed(in: inputState.pressedMouseButtons)
    }
}
