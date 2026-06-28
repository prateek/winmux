import AppKit
import CoreGraphics

struct ZoneSnapInputState: Equatable, Sendable {
    var modifierFlags: CGEventFlags
    var pressedMouseButtons: Int
}

func currentZoneSnapInputState() -> ZoneSnapInputState {
    ZoneSnapInputState(
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

func zoneSnapActivationInputIsPressed(_ config: ZoneSnapConfig, inputState: ZoneSnapInputState) -> Bool {
    switch config.gesture {
        case .drag:
            return zoneSnapModifierIsPressed(config.modifier, in: inputState.modifierFlags)
        case .secondaryButtonDrag:
            return isSecondaryMouseButtonPressed(in: inputState.pressedMouseButtons)
    }
}
