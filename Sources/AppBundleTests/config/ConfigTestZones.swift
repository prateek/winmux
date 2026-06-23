@testable import AppBundle
import Common
import XCTest

extension ConfigTest {
    func testParseColumnZones() {
        let (parsed, errors) = parseConfig(
            """
            [[zones]]
                monitor = 1
                layout = 'columns'
                default-zone = 'main'
                columns = [
                    { id = 'left', name = 'Reference', width = 0.25 },
                    { id = 'main', name = 'Work', width = 0.50 },
                    { id = 'right', name = 'Comms', width = 0.25 },
                ]
            """,
        )

        assertEquals(errors, [])
        assertEquals(parsed.zones, [
            ZoneConfig(
                monitor: .sequenceNumber(1),
                layout: .columns,
                defaultZone: "main",
                columns: [
                    ZoneColumnConfig(id: "left", name: "Reference", width: 0.25),
                    ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
                    ZoneColumnConfig(id: "right", name: "Comms", width: 0.25),
                ],
            ),
        ])
    }

    func testRejectInvalidZones() {
        let (_, errors) = parseConfig(
            """
            [[zones]]
                monitor = 1
                layout = 'columns'
                default-zone = 'missing'
                columns = [
                    { id = 'left', width = 0.50 },
                    { id = 'left', width = 0.40 },
                ]
            """,
        )

        assertEquals(errors.descriptions, [
            "zones[0].columns: Contains duplicated zone ids: left",
            "zones[0].default-zone: Must name one of the configured zone ids",
            "zones[0].columns: Column widths must sum to 1.0",
        ])
    }

    func testRejectMissingZoneFields() {
        let (_, errors) = parseConfig(
            """
            [[zones]]
                columns = [
                    { width = 1.0 },
                ]
            """,
        )

        assertEquals(errors.descriptions, [
            "zones[0].columns[0].id: Missing required key",
            "zones[0].monitor: Missing required key",
            "zones[0].layout: Missing required key",
        ])
    }

    func testRejectInvalidZoneIdsAndWidths() {
        let (_, errors) = parseConfig(
            """
            [[zones]]
                monitor = 1
                layout = 'columns'
                columns = [
                    { id = 'bad space', width = 0.0 },
                    { id = 'negative', width = -0.2 },
                ]
            """,
        )

        assertEquals(errors.descriptions, [
            "zones[0].columns[0].id: Use only letters, numbers, hyphens, and underscores",
            "zones[0].columns[0].width: Must be greater than 0",
            "zones[0].columns[0].id: Missing required key",
            "zones[0].columns[1].width: Must be greater than 0",
            "zones[0].columns: Column widths must sum to 1.0",
        ])
    }

    func testRejectDuplicateZoneMonitorSelectors() {
        let (_, errors) = parseConfig(
            """
            [[zones]]
                monitor = 1
                layout = 'columns'
                columns = [
                    { id = 'left', width = 1.0 },
                ]

            [[zones]]
                monitor = 1
                layout = 'columns'
                columns = [
                    { id = 'main', width = 1.0 },
                ]
            """,
        )

        assertEquals(errors.descriptions, [
            "zones: Contains duplicated monitor selectors: 1",
        ])
    }
}
