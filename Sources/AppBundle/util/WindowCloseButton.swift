import AppKit

/// `lookup` is the error from reading the window's `AXCloseButton`; `button` is its value.
/// A window AX reports as destroyed (`.invalidUIElement`) is already closed.
func pressWindowCloseButton(lookup: AXError, button: (any AxUiElementMock)?, performPress: (any AxUiElementMock) -> AXError) -> WindowCloseResult {
    switch lookup {
        case .success: break
        case .noValue, .attributeUnsupported: return .notClosed(.noCloseButton)
        case .invalidUIElement: return .closed
        default: return .notClosed(.appRefused)
    }
    guard let button, button.get(Ax.enabledAttr) != false else { return .notClosed(.noCloseButton) }
    return [.success, .invalidUIElement].contains(performPress(button)) ? .closed : .notClosed(.appRefused)
}
