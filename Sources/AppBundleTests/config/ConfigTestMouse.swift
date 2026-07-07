@testable import AppBundle
import AppKit
import XCTest

extension ConfigTest {
    func testParseMouseZoneSnapConfig() {
        let (parsed, errors) = parseConfig(
            """
            [mouse.zone-snap]
                policy = 'snap-on-modifier'
                modifier = 'alt-cmd'
                gesture = 'drag'
                target = 'zone'
            """,
        )

        assertEquals(errors, [])
        XCTAssertEqual(parsed.mouse.columnSnap.policy, .snapOnModifier)
        XCTAssertEqual(parsed.mouse.columnSnap.modifier, [.option, .command])
        XCTAssertEqual(parsed.mouse.columnSnap.gesture, .drag)
        XCTAssertEqual(parsed.mouse.columnSnap.target, .column)
    }

    func testParseSecondaryButtonDragMouseZoneSnapGesture() {
        let (parsed, errors) = parseConfig(
            """
            [mouse.zone-snap]
                policy = 'float-unless-snap'
                gesture = 'secondary-button-drag'
                target = 'window'
            """,
        )

        assertEquals(errors, [])
        XCTAssertEqual(parsed.mouse.columnSnap.policy, .floatUnlessSnap)
        XCTAssertEqual(parsed.mouse.columnSnap.modifier, .option)
        XCTAssertEqual(parsed.mouse.columnSnap.gesture, .secondaryButtonDrag)
        XCTAssertEqual(parsed.mouse.columnSnap.target, .window)
    }

    func testMouseZoneSnapDefaultsForConciseConfig() {
        let (parsed, errors) = parseConfig(
            """
            [mouse.zone-snap]
                policy = 'snap-on-modifier'
            """,
        )

        assertEquals(errors, [])
        XCTAssertEqual(parsed.mouse.columnSnap.policy, .snapOnModifier)
        XCTAssertEqual(parsed.mouse.columnSnap.modifier, .option)
        XCTAssertEqual(parsed.mouse.columnSnap.gesture, .drag)
        XCTAssertEqual(parsed.mouse.columnSnap.target, .column)
    }

    func testParseFloatUnlessSnapE2EConfig() throws {
        let toml = try String(
            contentsOf: projectRoot.appending(component: "script/e2e/configs/float-unless-snap.toml"),
            encoding: .utf8,
        )

        let (parsed, errors) = parseConfig(toml)

        assertEquals(errors, [])
        XCTAssertEqual(parsed.mouse.columnSnap.policy, .floatUnlessSnap)
        XCTAssertEqual(parsed.mouse.columnSnap.modifier, .option)
        XCTAssertEqual(parsed.mouse.columnSnap.gesture, .drag)
        XCTAssertEqual(parsed.mouse.columnSnap.target, .column)
    }

    func testParseFloatUnlessSnapSecondaryButtonE2EConfig() throws {
        let toml = try String(
            contentsOf: projectRoot.appending(component: "script/e2e/configs/float-unless-snap-secondary-button.toml"),
            encoding: .utf8,
        )

        let (parsed, errors) = parseConfig(toml)

        assertEquals(errors, [])
        XCTAssertEqual(parsed.mouse.columnSnap.policy, .floatUnlessSnap)
        XCTAssertEqual(parsed.mouse.columnSnap.modifier, .option)
        XCTAssertEqual(parsed.mouse.columnSnap.gesture, .secondaryButtonDrag)
        XCTAssertEqual(parsed.mouse.columnSnap.target, .column)
    }

    func testParseMouseGestureConfigurabilityE2EConfig() throws {
        let toml = try String(
            contentsOf: projectRoot.appending(component: "script/e2e/configs/mouse-gesture-configurability.toml"),
            encoding: .utf8,
        )

        let (parsed, errors) = parseConfig(toml)

        assertEquals(errors, [])
        XCTAssertEqual(parsed.mouse.columnSnap.policy, .floatUnlessSnap)
        XCTAssertEqual(parsed.mouse.columnSnap.modifier, .option)
        XCTAssertEqual(parsed.mouse.columnSnap.gesture, .secondaryButtonDrag)
        XCTAssertEqual(parsed.mouse.columnSnap.target, .column)
    }

    func testParseDragOverlaySemanticsE2EConfig() throws {
        let toml = try String(
            contentsOf: projectRoot.appending(component: "script/e2e/configs/drag-overlay-semantics.toml"),
            encoding: .utf8,
        )

        let (parsed, errors) = parseConfig(toml)

        assertEquals(errors, [])
        XCTAssertEqual(parsed.mouse.columnSnap.policy, .floatUnlessSnap)
        XCTAssertEqual(parsed.mouse.columnSnap.modifier, .option)
        XCTAssertEqual(parsed.mouse.columnSnap.gesture, .secondaryButtonDrag)
        XCTAssertEqual(parsed.mouse.columnSnap.target, .column)
    }

    func testParseWindowSlotSnapE2EConfig() throws {
        let toml = try String(
            contentsOf: projectRoot.appending(component: "script/e2e/configs/window-slot-snap.toml"),
            encoding: .utf8,
        )

        let (parsed, errors) = parseConfig(toml)

        assertEquals(errors, [])
        XCTAssertEqual(parsed.mouse.columnSnap.policy, .floatUnlessSnap)
        XCTAssertEqual(parsed.mouse.columnSnap.modifier, .option)
        XCTAssertEqual(parsed.mouse.columnSnap.gesture, .secondaryButtonDrag)
        XCTAssertEqual(parsed.mouse.columnSnap.target, .window)
    }

    func testParseZoneDividerDragPolicy() {
        XCTAssertEqual(parseConfig("").0.mouse.columnDividerDrag, .columnMode)
        XCTAssertEqual(
            parseConfig("[mouse]\n    zone-divider-drag = 'always'").0.mouse.columnDividerDrag,
            .always,
        )
        XCTAssertEqual(
            parseConfig("[mouse]\n    zone-divider-drag = 'off'").0.mouse.columnDividerDrag,
            .off,
        )
        XCTAssertEqual(
            parseConfig("[mouse]\n    zone-divider-drag = 'column-mode'").0.mouse.columnDividerDrag,
            .columnMode,
        )
    }

    func testParseUpdatesConfig() {
        XCTAssertFalse(parseConfig("").0.updates.automaticCheck)
        let (parsed, errors) = parseConfig(
            """
            [updates]
                automatic-check = true
            """,
        )
        assertEquals(errors, [])
        XCTAssertTrue(parsed.updates.automaticCheck)
    }

    func testRejectInvalidZoneDividerDragPolicy() {
        let (_, errors) = parseConfig(
            """
            [mouse]
                zone-divider-drag = 'hover'
            """,
        )
        assertEquals(errors.descriptions, [
            "mouse.zone-divider-drag: Possible values: column-mode, always, off",
        ])
    }

    func testRejectInvalidMouseZoneSnapConfig() {
        let (_, errors) = parseConfig(
            """
            [mouse.zone-snap]
                policy = 'snap-to-window'
                modifier = 'alt-unicorn'
                gesture = 'swipe'
                target = 'slot'
            """,
        )

        XCTAssertEqual(Set(errors.descriptions), Set([
            "mouse.zone-snap.policy: Possible values: freeform, snap-on-modifier, snap-to-column, float-unless-snap",
            "mouse.zone-snap.modifier: Unsupported modifier 'unicorn'. Possible values: alt, ctrl, cmd, shift, or '-' combinations like alt-shift",
            "mouse.zone-snap.gesture: Possible values: drag, secondary-button-drag",
            "mouse.zone-snap.target: Possible values: column, window",
        ]))
        XCTAssertEqual(errors.count, 4)
    }
}
