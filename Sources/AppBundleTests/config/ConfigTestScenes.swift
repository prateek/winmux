@testable import AppBundle
import Common
import XCTest

extension ConfigTest {
    func testParseScenesSynthesizesBackingLayoutsAndZones() {
        let (parsed, errors) = parseConfig(
            """
            [scene.desk]
            display = 1
            default-column = 'main'
            columns = [
                { id = 'ref', name = 'Reference', width = 0.20, color = '#3EA2FF' },
                { id = 'main', name = 'Work', width = 0.55 },
                { id = 'comms', name = 'Comms', width = 0.25, color = '#D3455B' },
            ]

            [scene.focus]
            display = 1
            columns = [ { id = 'main', name = 'Work', width = 1.0 } ]
            """,
        )

        assertEquals(errors, [])
        assertEquals(parsed.scenes, [
            SceneConfig(id: "desk", monitor: .sequenceNumber(1), layoutId: "scene-desk", defaultColumn: "main"),
            SceneConfig(id: "focus", monitor: .sequenceNumber(1), layoutId: "scene-focus", defaultColumn: nil),
        ])
        // Each scene owns a backing layout carrying its columns, widths, and colors.
        assertEquals(parsed.zoneLayouts, [
            ZoneLayoutConfig(
                id: "scene-desk",
                layout: .columns,
                defaultZone: "main",
                columns: [
                    ZoneColumnConfig(id: "ref", name: "Reference", width: 0.20, color: "#3EA2FF"),
                    ZoneColumnConfig(id: "main", name: "Work", width: 0.55),
                    ZoneColumnConfig(id: "comms", name: "Comms", width: 0.25, color: "#D3455B"),
                ],
            ),
            ZoneLayoutConfig(
                id: "scene-focus",
                layout: .columns,
                defaultZone: nil,
                columns: [ZoneColumnConfig(id: "main", name: "Work", width: 1.0)],
            ),
        ])
        // One synthesized zone per display targets the default (first-declared) scene.
        assertEquals(parsed.zones, [ZoneConfig(monitor: .sequenceNumber(1), layoutPreset: "scene-desk")])
    }

    func testSceneDefaultIsFirstDeclaredNotAlphabetical() {
        let (parsed, errors) = parseConfig(
            """
            [scene.work]
            display = 1
            columns = [ { id = 'main', width = 1.0 } ]

            [scene.alpha]
            display = 1
            columns = [ { id = 'main', width = 1.0 } ]
            """,
        )

        assertEquals(errors, [])
        assertEquals(parsed.scenes.map(\.id), ["work", "alpha"])
        // The display's synthesized zone points at the first-declared scene, not the alphabetical one.
        assertEquals(parsed.zones, [ZoneConfig(monitor: .sequenceNumber(1), layoutPreset: "scene-work")])
    }

    func testRejectReservedSceneNames() {
        let (_, errors) = parseConfig(
            """
            [scene.next]
            display = 1
            columns = [ { id = 'main', width = 1.0 } ]

            [scene.new]
            display = 1
            columns = [ { id = 'main', width = 1.0 } ]
            """,
        )

        assertTrue(errors.descriptions.contains("scene.next: 'next' is a reserved scene name"))
        assertTrue(errors.descriptions.contains("scene.new: 'new' is a reserved scene name"))
    }

    func testRejectReservedColumnDirectionWords() {
        let (_, errors) = parseConfig(
            """
            [scene.desk]
            display = 1
            columns = [
                { id = 'left', width = 0.5 },
                { id = 'right', width = 0.5 },
            ]
            """,
        )

        assertTrue(errors.descriptions.contains("scene.desk.columns: Column ids may not use the reserved direction words: left, right"))
    }

    func testRejectInvalidSceneBlocks() {
        let (_, errors) = parseConfig(
            """
            [scene.desk]
            default-column = 'nope'
            columns = [
                { id = 'main', width = 0.4 },
                { id = 'main', width = 0.4 },
            ]
            """,
        )

        assertTrue(errors.descriptions.contains("scene.desk.display: Missing required key"))
        assertTrue(errors.descriptions.contains("scene.desk.columns: Contains duplicated column ids: main"))
        assertTrue(errors.descriptions.contains("scene.desk.default-column: Must name one of the configured column ids"))
        assertTrue(errors.descriptions.contains("scene.desk.columns: Column widths must sum to 1.0"))
    }

    func testRejectSceneAndZoneTargetingSameDisplay() {
        let (_, errors) = parseConfig(
            """
            [[zones]]
                monitor = 1
                layout = 'columns'
                columns = [ { id = 'main', width = 1.0 } ]

            [scene.desk]
            display = 1
            columns = [ { id = 'main', width = 1.0 } ]
            """,
        )

        assertTrue(errors.descriptions.contains("scene: Displays are configured by both [[zones]] and [scene.*]: 1"))
    }
}
