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

    func testRejectInvalidMouseZoneSnapConfig() {
        let (_, errors) = parseConfig(
            """
            [mouse.zone-snap]
                policy = 'snap-to-window'
                modifier = 'alt-unicorn'
                gesture = 'swipe'
                target = 'window'
            """,
        )

        XCTAssertEqual(Set(errors.descriptions), Set([
            "mouse.zone-snap.policy: Possible values: freeform, snap-on-modifier, snap-to-zone, float-unless-snap",
            "mouse.zone-snap.modifier: Unsupported modifier 'unicorn'. Possible values: alt, ctrl, cmd, shift, or '-' combinations like alt-shift",
            "mouse.zone-snap.gesture: Possible values: drag",
            "mouse.zone-snap.target: Possible values: zone",
        ]))
        XCTAssertEqual(errors.count, 4)
    }
}
