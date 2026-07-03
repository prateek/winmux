@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor
private func exposeKeyEvent(keyCode: UInt16, characters: String = "") -> NSEvent {
    NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: characters,
        charactersIgnoringModifiers: characters,
        isARepeat: false,
        keyCode: keyCode,
    )!
}

final class ZoneDividerDragPolicyTest: XCTestCase {
    func testDragAllowedByPolicyAndMode() {
        XCTAssertTrue(isZoneDividerDragAllowed(policy: .always, activeMode: "main"))
        XCTAssertTrue(isZoneDividerDragAllowed(policy: .always, activeMode: nil))

        XCTAssertFalse(isZoneDividerDragAllowed(policy: .off, activeMode: "zone"))

        XCTAssertTrue(isZoneDividerDragAllowed(policy: .zoneMode, activeMode: "zone"))
        XCTAssertFalse(isZoneDividerDragAllowed(policy: .zoneMode, activeMode: "main"))
        XCTAssertFalse(isZoneDividerDragAllowed(policy: .zoneMode, activeMode: nil))
    }

    @MainActor func testZoneExposeKeyboardSelection() {
        let controller = ZoneExposePanelController.shared
        var selected: [Int] = []
        let tiles = (0 ..< 3).map { index in
            ZoneExposeTile(
                id: "tile-\(index)",
                title: "Tile \(index)",
                subtitle: "",
                preview: nil,
                icon: nil,
                select: { selected.append(index) },
            )
        }

        controller.setTilesForTests(tiles, scope: .display)
        XCTAssertTrue(controller.handleKeyDown(exposeKeyEvent(keyCode: 124))) // right
        XCTAssertEqual(controller.selectedIndex, 1)
        XCTAssertTrue(controller.handleKeyDown(exposeKeyEvent(keyCode: 123))) // left
        XCTAssertTrue(controller.handleKeyDown(exposeKeyEvent(keyCode: 123))) // clamped at 0
        XCTAssertEqual(controller.selectedIndex, 0)
        XCTAssertTrue(controller.handleKeyDown(exposeKeyEvent(keyCode: 36))) // return selects
        XCTAssertEqual(selected, [0])

        controller.setTilesForTests(tiles, scope: .zone)
        XCTAssertTrue(controller.handleKeyDown(exposeKeyEvent(keyCode: 18, characters: "3")))
        XCTAssertEqual(selected, [0, 2])
        XCTAssertFalse(controller.handleKeyDown(exposeKeyEvent(keyCode: 18, characters: "9")))

        controller.setTilesForTests(tiles, scope: .zone)
        XCTAssertTrue(controller.handleKeyDown(exposeKeyEvent(keyCode: 53))) // escape hides
        XCTAssertTrue(controller.tiles.isEmpty)
    }

    func testSlowAxBenchDecisions() {
        let now = ContinuousClock.now
        // Serving the cache requires an unexpired penalty and a non-frontmost app.
        XCTAssertTrue(MacApp.shouldServeBenchedCache(isFrontmost: false, penaltyUntil: now + .seconds(5), now: now))
        XCTAssertFalse(MacApp.shouldServeBenchedCache(isFrontmost: true, penaltyUntil: now + .seconds(5), now: now))
        XCTAssertFalse(MacApp.shouldServeBenchedCache(isFrontmost: false, penaltyUntil: now - .seconds(1), now: now))
        XCTAssertFalse(MacApp.shouldServeBenchedCache(isFrontmost: false, penaltyUntil: nil, now: now))

        // Benching requires exceeding the budget AND a servable cache: a slow refresh that
        // enumerated nothing must not hide the app behind an empty cache.
        XCTAssertNotNil(MacApp.penaltyAfterRefresh(elapsed: .seconds(2), hasServableCache: true, now: now))
        XCTAssertNil(MacApp.penaltyAfterRefresh(elapsed: .seconds(2), hasServableCache: false, now: now))
        XCTAssertNil(MacApp.penaltyAfterRefresh(elapsed: .milliseconds(100), hasServableCache: true, now: now))
    }

    func testDeferredWindowRegistrationFlagIsReadAndCleared() {
        _ = takeWindowRegistrationDeferredDuringMouseDown()
        XCTAssertFalse(takeWindowRegistrationDeferredDuringMouseDown())
        noteWindowRegistrationDeferredDuringMouseDown()
        XCTAssertTrue(takeWindowRegistrationDeferredDuringMouseDown())
        XCTAssertFalse(takeWindowRegistrationDeferredDuringMouseDown())
    }

    func testDesktopMouseUpEventSkipsWindowRefreshBarrier() {
        // A mouse up over empty desktop must not trigger the heavy refresh path: no window
        // enumeration barrier and no re-assertion of hidden window frames.
        XCTAssertFalse(RefreshSessionEvent.globalObserverLeftMouseUpOutsideWindows.requiresWindowRefreshBarrier)
        XCTAssertTrue(RefreshSessionEvent.globalObserverLeftMouseUpOutsideWindows.canReuseLastAppliedWindowFrames)

        // A mouse up over a window keeps the barrier: it may be a close-button click on an
        // unfocused window or delayed new-window detection.
        XCTAssertTrue(RefreshSessionEvent.globalObserverLeftMouseUp.requiresWindowRefreshBarrier)
        XCTAssertFalse(RefreshSessionEvent.globalObserverLeftMouseUp.canReuseLastAppliedWindowFrames)
    }
}
