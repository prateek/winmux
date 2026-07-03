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
        XCTAssertEqual(parsed.mouse.zoneSnap.policy, .snapOnModifier)
        XCTAssertEqual(parsed.mouse.zoneSnap.modifier, [.option, .command])
        XCTAssertEqual(parsed.mouse.zoneSnap.gesture, .drag)
        XCTAssertEqual(parsed.mouse.zoneSnap.target, .zone)
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
        XCTAssertEqual(parsed.mouse.zoneSnap.policy, .floatUnlessSnap)
        XCTAssertEqual(parsed.mouse.zoneSnap.modifier, .option)
        XCTAssertEqual(parsed.mouse.zoneSnap.gesture, .secondaryButtonDrag)
        XCTAssertEqual(parsed.mouse.zoneSnap.target, .window)
    }

    func testMouseZoneSnapDefaultsForConciseConfig() {
        let (parsed, errors) = parseConfig(
            """
            [mouse.zone-snap]
                policy = 'snap-on-modifier'
            """,
        )

        assertEquals(errors, [])
        XCTAssertEqual(parsed.mouse.zoneSnap.policy, .snapOnModifier)
        XCTAssertEqual(parsed.mouse.zoneSnap.modifier, .option)
        XCTAssertEqual(parsed.mouse.zoneSnap.gesture, .drag)
        XCTAssertEqual(parsed.mouse.zoneSnap.target, .zone)
    }

    func testParseZoneSnapPolicySwitchingE2EConfig() throws {
        let toml = try String(
            contentsOf: projectRoot.appending(component: "script/e2e/configs/zone-snap-policy-switching.toml"),
            encoding: .utf8,
        )

        let (parsed, errors) = parseConfig(toml)

        assertEquals(errors, [])
        XCTAssertEqual(parsed.mouse.zoneSnap.policy, .freeform)
        XCTAssertEqual(parsed.mouse.zoneSnap.modifier, .option)
        XCTAssertEqual(parsed.mouse.zoneSnap.gesture, .drag)
        XCTAssertEqual(parsed.mouse.zoneSnap.target, .zone)
        XCTAssertEqual(
            Set(parsed.modes["main"]?.bindings.values
                .map { "\($0.descriptionWithKeyNotation)=\($0.commands.prettyDescription)" } ?? []),
            [
                "alt-z=set-zone-snap-policy snap-to-zone",
                "alt-x=cycle-zone-snap-policy freeform snap-to-zone",
            ],
        )
    }

    func testParseFloatUnlessSnapE2EConfig() throws {
        let toml = try String(
            contentsOf: projectRoot.appending(component: "script/e2e/configs/float-unless-snap.toml"),
            encoding: .utf8,
        )

        let (parsed, errors) = parseConfig(toml)

        assertEquals(errors, [])
        XCTAssertEqual(parsed.mouse.zoneSnap.policy, .floatUnlessSnap)
        XCTAssertEqual(parsed.mouse.zoneSnap.modifier, .option)
        XCTAssertEqual(parsed.mouse.zoneSnap.gesture, .drag)
        XCTAssertEqual(parsed.mouse.zoneSnap.target, .zone)
    }

    func testParseFloatUnlessSnapSecondaryButtonE2EConfig() throws {
        let toml = try String(
            contentsOf: projectRoot.appending(component: "script/e2e/configs/float-unless-snap-secondary-button.toml"),
            encoding: .utf8,
        )

        let (parsed, errors) = parseConfig(toml)

        assertEquals(errors, [])
        XCTAssertEqual(parsed.mouse.zoneSnap.policy, .floatUnlessSnap)
        XCTAssertEqual(parsed.mouse.zoneSnap.modifier, .option)
        XCTAssertEqual(parsed.mouse.zoneSnap.gesture, .secondaryButtonDrag)
        XCTAssertEqual(parsed.mouse.zoneSnap.target, .zone)
    }

    func testParseMouseGestureConfigurabilityE2EConfig() throws {
        let toml = try String(
            contentsOf: projectRoot.appending(component: "script/e2e/configs/mouse-gesture-configurability.toml"),
            encoding: .utf8,
        )

        let (parsed, errors) = parseConfig(toml)

        assertEquals(errors, [])
        XCTAssertEqual(parsed.mouse.zoneSnap.policy, .floatUnlessSnap)
        XCTAssertEqual(parsed.mouse.zoneSnap.modifier, .option)
        XCTAssertEqual(parsed.mouse.zoneSnap.gesture, .secondaryButtonDrag)
        XCTAssertEqual(parsed.mouse.zoneSnap.target, .zone)
    }

    func testParseDragOverlaySemanticsE2EConfig() throws {
        let toml = try String(
            contentsOf: projectRoot.appending(component: "script/e2e/configs/drag-overlay-semantics.toml"),
            encoding: .utf8,
        )

        let (parsed, errors) = parseConfig(toml)

        assertEquals(errors, [])
        XCTAssertEqual(parsed.mouse.zoneSnap.policy, .floatUnlessSnap)
        XCTAssertEqual(parsed.mouse.zoneSnap.modifier, .option)
        XCTAssertEqual(parsed.mouse.zoneSnap.gesture, .secondaryButtonDrag)
        XCTAssertEqual(parsed.mouse.zoneSnap.target, .zone)
    }

    func testParseWindowSlotSnapE2EConfig() throws {
        let toml = try String(
            contentsOf: projectRoot.appending(component: "script/e2e/configs/window-slot-snap.toml"),
            encoding: .utf8,
        )

        let (parsed, errors) = parseConfig(toml)

        assertEquals(errors, [])
        XCTAssertEqual(parsed.mouse.zoneSnap.policy, .floatUnlessSnap)
        XCTAssertEqual(parsed.mouse.zoneSnap.modifier, .option)
        XCTAssertEqual(parsed.mouse.zoneSnap.gesture, .secondaryButtonDrag)
        XCTAssertEqual(parsed.mouse.zoneSnap.target, .window)
    }

    func testParseZoneDividerDragPolicy() {
        XCTAssertEqual(parseConfig("").0.mouse.zoneDividerDrag, .zoneMode)
        XCTAssertEqual(
            parseConfig("[mouse]\n    zone-divider-drag = 'always'").0.mouse.zoneDividerDrag,
            .always,
        )
        XCTAssertEqual(
            parseConfig("[mouse]\n    zone-divider-drag = 'off'").0.mouse.zoneDividerDrag,
            .off,
        )
        XCTAssertEqual(
            parseConfig("[mouse]\n    zone-divider-drag = 'zone-mode'").0.mouse.zoneDividerDrag,
            .zoneMode,
        )
    }

    func testRejectInvalidZoneDividerDragPolicy() {
        let (_, errors) = parseConfig(
            """
            [mouse]
                zone-divider-drag = 'hover'
            """,
        )
        assertEquals(errors.descriptions, [
            "mouse.zone-divider-drag: Possible values: zone-mode, always, off",
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
            "mouse.zone-snap.policy: Possible values: freeform, snap-on-modifier, snap-to-zone, float-unless-snap",
            "mouse.zone-snap.modifier: Unsupported modifier 'unicorn'. Possible values: alt, ctrl, cmd, shift, or '-' combinations like alt-shift",
            "mouse.zone-snap.gesture: Possible values: drag, secondary-button-drag",
            "mouse.zone-snap.target: Possible values: zone, window",
        ]))
        XCTAssertEqual(errors.count, 4)
    }
}
