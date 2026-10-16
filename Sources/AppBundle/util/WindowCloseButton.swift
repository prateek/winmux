import AppKit

func pressWindowCloseButton(_ button: (any AxUiElementMock)?, performPress: (any AxUiElementMock) -> AXError) -> WindowCloseResult {
    guard let button, button.get(Ax.enabledAttr) != false else { return .notClosed(.noCloseButton) }
    return performPress(button) == .success ? .closed : .notClosed(.appRefused)
}
