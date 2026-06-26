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

    func testParseNamedZoneLayoutPreset() {
        let (parsed, errors) = parseConfig(
            """
            [[zone-layouts]]
                id = 'balanced'
                layout = 'columns'
                default-zone = 'main'
                columns = [
                    { id = 'left', name = 'Reference', width = 0.25 },
                    { id = 'main', name = 'Work', width = 0.50 },
                    { id = 'right', name = 'Comms', width = 0.25 },
                ]

            [[zones]]
                monitor = 1
                layout-preset = 'balanced'
            """,
        )

        assertEquals(errors, [])
        assertEquals(parsed.zoneLayouts, [
            ZoneLayoutConfig(
                id: "balanced",
                layout: .columns,
                defaultZone: "main",
                columns: [
                    ZoneColumnConfig(id: "left", name: "Reference", width: 0.25),
                    ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
                    ZoneColumnConfig(id: "right", name: "Comms", width: 0.25),
                ],
            ),
        ])
        assertEquals(parsed.zones, [
            ZoneConfig(
                monitor: .sequenceNumber(1),
                layoutPreset: "balanced",
            ),
        ])
    }

    func testParseZoneSceneWorkspaceBindings() {
        let (parsed, errors) = parseConfig(
            """
            [[zone-layouts]]
                id = 'focus'
                layout = 'columns'
                default-zone = 'main'
                columns = [
                    { id = 'left', name = 'Queue', width = 0.20 },
                    { id = 'main', name = 'Build', width = 0.60 },
                    { id = 'right', name = 'Notes', width = 0.20 },
                ]

            [[zone-scenes]]
                id = 'deep-work'
                layout-preset = 'focus'
                workspaces = [
                    { zone = 'left', workspace = 'FocusQueue' },
                    { zone = 'main', workspace = 'FocusBuild' },
                    { zone = 'right', workspace = 'FocusNotes' },
                ]

            [[zones]]
                monitor = 1
                layout-preset = 'focus'
            """,
        )

        assertEquals(errors, [])
        assertEquals(parsed.zoneScenes.count, 1)
        assertEquals(parsed.zoneScenes[0].id, "deep-work")
        assertEquals(parsed.zoneScenes[0].layoutPreset, "focus")
        assertEquals(parsed.zoneScenes[0].workspaces.map(\.zone), ["left", "main", "right"])
        assertEquals(parsed.zoneScenes[0].workspaces.compactMap { $0.workspace?.raw }, ["FocusQueue", "FocusBuild", "FocusNotes"])
    }

    func testParseZoneStyles() {
        let (parsed, errors) = parseConfig(
            """
            [[zone-styles]]
                id = 'urgent'
                color = '#d3455b'

            [[zone-styles]]
                id = 'calm'
                color = '3EA2FF'
            """,
        )

        assertEquals(errors, [])
        assertEquals(parsed.zoneStyles, [
            ZoneStyleConfig(id: "urgent", color: "#D3455B"),
            ZoneStyleConfig(id: "calm", color: "#3EA2FF"),
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

    func testRejectInvalidZoneSceneReferences() {
        let (_, errors) = parseConfig(
            """
            [[zone-layouts]]
                id = 'focus'
                layout = 'columns'
                columns = [
                    { id = 'main', width = 1.0 },
                ]

            [[zone-scenes]]
                id = 'bad'
                layout-preset = 'missing'
                workspaces = [
                    { zone = 'main', workspace = 'FocusBuild' },
                ]

            [[zone-scenes]]
                id = 'bad'
                layout-preset = 'focus'
                workspaces = [
                    { zone = 'left', workspace = 'FocusQueue' },
                    { zone = 'left', workspace = 'FocusNotes' },
                ]
            """,
        )

        assertEquals(errors.descriptions, [
            "zone-scenes[1].workspaces: Contains duplicated zone bindings: left",
            "zone-scenes: Contains duplicated scene ids: bad",
            "zone-scenes[0].layout-preset: Unknown zone layout preset 'missing'",
            "zone-scenes[1].workspaces[0].zone: Must name one of the zones in layout preset 'focus'",
            "zone-scenes[1].workspaces[1].zone: Must name one of the zones in layout preset 'focus'",
        ])
    }

    func testRejectInvalidZoneStyles() {
        let (_, errors) = parseConfig(
            """
            [[zone-styles]]
                id = 'urgent'
                color = 'not-a-color'

            [[zone-styles]]
                id = 'urgent'

            [[zone-styles]]
                color = '#3EA2FF'
            """,
        )

        assertEquals(errors.descriptions, [
            "zone-styles[0].color: Must be a hex color like '#RRGGBB'",
            "zone-styles[0].color: Missing required key",
            "zone-styles[1].color: Missing required key",
            "zone-styles[2].id: Missing required key",
            "zone-styles: Contains duplicated style ids: urgent",
        ])
    }

    func testRejectInvalidZoneLayoutPresetReferences() {
        let (_, errors) = parseConfig(
            """
            [[zone-layouts]]
                id = 'focus'
                layout = 'columns'
                columns = [
                    { id = 'main', width = 1.0 },
                ]

            [[zone-layouts]]
                id = 'focus'
                layout = 'columns'
                columns = [
                    { id = 'main', width = 1.0 },
                ]

            [[zones]]
                monitor = 1
                layout-preset = 'missing'

            [[zones]]
                monitor = 2
                layout-preset = 'focus'
                layout = 'columns'
                columns = [
                    { id = 'main', width = 1.0 },
                ]
            """,
        )

        assertEquals(errors.descriptions, [
            "zone-layouts: Contains duplicated layout ids: focus",
            "zones[1].layout: Cannot be combined with layout-preset",
            "zones[1].columns: Cannot be combined with layout-preset",
            "zones[0].layout-preset: Unknown zone layout preset 'missing'",
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
