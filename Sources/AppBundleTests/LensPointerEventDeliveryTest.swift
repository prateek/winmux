@testable import AppBundle
import AppKit
import XCTest

@MainActor
private final class PointerTestPanel: NSPanel {
    var showing = true
    override var isVisible: Bool { showing }
}

@MainActor
final class LensPointerEventDeliveryTest: XCTestCase {
    func testLocalMovesReachOnlyTheirVisiblePanelAndStillPassThrough() throws {
        _ = NSApplication.shared
        let window = PointerTestPanel(contentRect: CGRect(x: 100, y: 100, width: 200, height: 200), styleMask: .borderless, backing: .buffered, defer: false)
        var local: ((NSEvent) -> NSEvent?)?
        let monitors = LensPointerEventDelivery.Monitors(local: { local = $0; return 1 }, global: { _ in 2 }, remove: { _ in })
        let delivery = LensPointerEventDelivery(monitors: monitors)
        var locations: [CGPoint] = []
        delivery.start(window: window) { locations.append($0.locationInWindow) }
        defer { delivery.stop() }
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .mouseMoved, location: CGPoint(x: 20, y: 30), modifierFlags: .command,
                                                   timestamp: 1, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0))
        XCTAssertTrue(local?(event) === event)
        XCTAssertEqual(locations, [CGPoint(x: 20, y: 30)])
        window.showing = false
        XCTAssertTrue(local?(event) === event)
        XCTAssertEqual(locations.count, 1)
        window.showing = true
        let other = try XCTUnwrap(NSEvent.mouseEvent(with: .mouseMoved, location: .zero, modifierFlags: [], timestamp: 2,
                                                   windowNumber: 0, context: nil, eventNumber: 0, clickCount: 0, pressure: 0))
        XCTAssertTrue(local?(other) === other)
        XCTAssertEqual(locations.count, 1)
    }

    func testGlobalMoveTranslatesToPanelCoordinatesAndIgnoresOutsideOrHiddenPanel() throws {
        _ = NSApplication.shared
        let window = PointerTestPanel(contentRect: CGRect(x: 100, y: 100, width: 200, height: 200), styleMask: .borderless, backing: .buffered, defer: false)
        var global: ((NSEvent) -> Void)?
        var point = CGPoint(x: 120, y: 150)
        let monitors = LensPointerEventDelivery.Monitors(local: { _ in 1 }, global: { global = $0; return 2 }, remove: { _ in })
        let delivery = LensPointerEventDelivery(monitors: monitors, pointerLocation: { point })
        var events: [NSEvent] = []
        delivery.start(window: window) { events.append($0) }
        defer { delivery.stop() }
        let original = try XCTUnwrap(NSEvent.mouseEvent(with: .mouseMoved, location: .zero, modifierFlags: .command, timestamp: 12,
                                                      windowNumber: 0, context: nil, eventNumber: 0, clickCount: 0, pressure: 0))
        global?(original)
        let forwarded = try XCTUnwrap(events.first)
        XCTAssertEqual(forwarded.type, .mouseMoved)
        XCTAssertEqual(forwarded.locationInWindow, CGPoint(x: 20, y: 50))
        XCTAssertTrue(forwarded.window === window)
        XCTAssertEqual(forwarded.modifierFlags, original.modifierFlags)
        XCTAssertEqual(forwarded.timestamp, original.timestamp)
        point = CGPoint(x: 99, y: 150)
        global?(original)
        window.showing = false
        point = CGPoint(x: 120, y: 150)
        global?(original)
        XCTAssertEqual(events.count, 1)
    }

    func testReplacingOrStoppingDeliveryRemovesBothMonitors() {
        var removed: [Int] = []
        let monitors = LensPointerEventDelivery.Monitors(local: { _ in 1 }, global: { _ in 2 }, remove: { removed.append($0 as! Int) })
        let delivery = LensPointerEventDelivery(monitors: monitors)
        let window = PointerTestPanel()
        delivery.start(window: window) { _ in }
        delivery.start(window: window) { _ in }
        XCTAssertEqual(removed, [1, 2])
        delivery.stop()
        delivery.stop()
        XCTAssertEqual(removed, [1, 2, 1, 2])
    }
}
