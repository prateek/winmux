@testable import AppBundle
import AppKit
import XCTest

private final class CloseButtonElement: AxUiElementMock {
    let enabled: Bool?
    init(enabled: Bool?) { self.enabled = enabled }
    func get<Attr: ReadableAttr>(_ attr: Attr) -> Attr.T? {
        attr.key == kAXEnabledAttribute ? enabled as? Attr.T : nil
    }
    func containingWindowId() -> CGWindowID? { nil }
}

final class WindowCloseButtonTest: XCTestCase {
    func testAbsentAndDisabledButtonsAreNotPressed() {
        for button in [nil, CloseButtonElement(enabled: false)] {
            var pressed = false
            let result = pressWindowCloseButton(lookup: .success, button: button) { _ in pressed = true; return .success }
            XCTAssertEqual(result, .notClosed(.noCloseButton))
            XCTAssertFalse(pressed)
        }
    }

    func testTheLookupDecidesBeforeAnythingIsPressed() {
        let expected: [(AXError, WindowCloseResult)] = [
            (.noValue, .notClosed(.noCloseButton)),
            (.attributeUnsupported, .notClosed(.noCloseButton)),
            (.invalidUIElement, .closed),
            (.cannotComplete, .notClosed(.appRefused)),
            (.failure, .notClosed(.appRefused)),
        ]
        for (lookup, result) in expected {
            var pressed = false
            XCTAssertEqual(pressWindowCloseButton(lookup: lookup, button: CloseButtonElement(enabled: true)) { _ in pressed = true; return .success }, result, "\(lookup)")
            XCTAssertFalse(pressed)
        }
    }

    func testEnabledAndUnreadableButtonsReportTheActualPressResult() {
        for enabled in [true, nil] as [Bool?] {
            for error in [AXError.success, .invalidUIElement, .cannotComplete, .actionUnsupported, .failure] {
                var pressed = false
                let result = pressWindowCloseButton(lookup: .success, button: CloseButtonElement(enabled: enabled)) { _ in
                    pressed = true
                    return error
                }
                XCTAssertTrue(pressed)
                XCTAssertEqual(result, [.success, .invalidUIElement].contains(error) ? .closed : .notClosed(.appRefused))
            }
        }
    }
}
