@testable import AppBundle
import Common
import XCTest

extension ConfigTest {
    func testParseColumnZones() {
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
        assertEquals(parsed.columnLayouts, [
            ColumnLayoutConfig(
                id: "balanced",
                layout: .columns,
                defaultZone: "main",
                columns: [
                    ColumnConfig(id: "left", name: "Reference", width: 0.25),
                    ColumnConfig(id: "main", name: "Work", width: 0.50),
                    ColumnConfig(id: "right", name: "Comms", width: 0.25),
                ],
            ),
        ])
        assertEquals(parsed.zones, [
            DisplayLayoutConfig(
                monitor: .sequenceNumber(1),
                layoutPreset: "balanced",
            ),
        ])
    }

    func testParseNamedColumnLayoutPreset() {
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
        assertEquals(parsed.columnLayouts, [
            ColumnLayoutConfig(
                id: "balanced",
                layout: .columns,
                defaultZone: "main",
                columns: [
                    ColumnConfig(id: "left", name: "Reference", width: 0.25),
                    ColumnConfig(id: "main", name: "Work", width: 0.50),
                    ColumnConfig(id: "right", name: "Comms", width: 0.25),
                ],
            ),
        ])
        assertEquals(parsed.zones, [
            DisplayLayoutConfig(
                monitor: .sequenceNumber(1),
                layoutPreset: "balanced",
            ),
        ])
    }

    func testIgnoreRetiredZoneScenesInLegacyConfig() {
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
        assertEquals(parsed.columnLayouts.count, 1)
        assertEquals(parsed.zones.count, 1)
    }

    func testIgnoreRetiredZoneBindingsInLegacyConfig() {
        let (parsed, errors) = parseConfig(
            """
            [[zone-layouts]]
                id = 'balanced'
                layout = 'columns'
                columns = [
                    { id = 'left', width = 0.25 },
                    { id = 'main', width = 0.50 },
                    { id = 'right', width = 0.25 },
                ]

            [[zone-bindings]]
                zone = 'left'
                workspace = 'ReferenceDesk'

            [[zone-bindings]]
                monitor = 2
                zone = 'right'
                workspace = 'CommsDesk'
            """,
        )

        assertEquals(errors, [])
        assertEquals(parsed.columnLayouts.count, 1)
    }

    func testParseDefaultConfigTemplate() throws {
        let (parsed, errors) = parseConfig(
            try String(contentsOf: getDefaultConfigUrlFromProject(), encoding: .utf8)
        )
        assertEquals(errors, [])
        XCTAssertNotNil(parsed.modes[mainModeId])
        XCTAssertNotNil(parsed.modes["column"])
        XCTAssertTrue(
            parsed.modes[mainModeId]?.bindings.values
                .contains { $0.descriptionWithKeyNotation == "ctrl-up" } == true
        )
    }

    func testIgnoreRetiredZoneAffinitiesE2EConfig() throws {
        var fixtureUrl = getDefaultConfigUrlFromProject()
        fixtureUrl.deleteLastPathComponent()
        fixtureUrl.deleteLastPathComponent()
        fixtureUrl.append(path: "script/e2e/configs/zone-affinities.toml")

        let (parsed, errors) = parseConfig(try String(contentsOf: fixtureUrl, encoding: .utf8))

        assertEquals(errors, [])
        XCTAssertFalse(parsed.workspaceSidebar.enabled)
    }

    func testIgnoreRetiredZoneAffinitiesBetaE2EConfig() throws {
        var fixtureUrl = getDefaultConfigUrlFromProject()
        fixtureUrl.deleteLastPathComponent()
        fixtureUrl.deleteLastPathComponent()
        fixtureUrl.append(path: "script/e2e/configs/zone-affinities-beta.toml")

        let (parsed, errors) = parseConfig(try String(contentsOf: fixtureUrl, encoding: .utf8))

        assertEquals(errors, [])
        XCTAssertFalse(parsed.workspaceSidebar.enabled)
    }

    func testIgnoreRetiredZoneAvailabilitySetsInLegacyConfig() {
        let (parsed, errors) = parseConfig(
            """
            [[zone-layouts]]
                id = 'balanced'
                layout = 'columns'
                columns = [
                    { id = 'left', width = 0.25 },
                    { id = 'main', width = 0.50 },
                    { id = 'right', width = 0.25 },
                ]

            [[zone-availability-sets]]
                id = 'focus-only'
                enabled-zones = ['main']

            [[zone-availability-sets]]
                id = 'communications'
                enabled-zones = ['main', 'right']

            [[zones]]
                monitor = 1
                layout-preset = 'balanced'
            """,
        )

        assertEquals(errors, [])
        assertEquals(parsed.columnLayouts.count, 1)
    }

    func testRenderConfigDoctorLinesWarnsWhenZoneModePolicyIsUnreachable() {
        let noZoneMode = renderConfigDoctorLines(
            configPath: "/tmp/winmux.toml",
            configText: "config-version = 2",
            runtimeOverlays: [:],
        )
        XCTAssertTrue(noZoneMode.contains { $0.contains("mouse.column-divider-drag = 'column-mode' but no [mode.column.binding] exists") })

        let withZoneMode = renderConfigDoctorLines(
            configPath: "/tmp/winmux.toml",
            configText: """
            config-version = 2
            [mode.column.binding]
                h = ['focus-column prev', 'mode main']
            """,
            runtimeOverlays: [:],
        )
        XCTAssertFalse(withZoneMode.contains { $0.contains("zone-divider-drag") })

        let policyOff = renderConfigDoctorLines(
            configPath: "/tmp/winmux.toml",
            configText: """
            config-version = 2
            [mouse]
                zone-divider-drag = 'off'
            """,
            runtimeOverlays: [:],
        )
        XCTAssertFalse(policyOff.contains { $0.contains("zone-divider-drag = 'column-mode'") })
    }

    func testRenderConfigDoctorLinesForValidZonesConfig() {
        let lines = renderConfigDoctorLines(
            configPath: "/tmp/winmux.toml",
            configText: """
            [[zone-styles]]
                id = 'urgent'
                color = '#D3455B'

            [[zone-layouts]]
                id = 'balanced'
                layout = 'columns'
                columns = [
                    { id = 'left', width = 0.25 },
                    { id = 'main', width = 0.50 },
                    { id = 'right', width = 0.25 },
                ]

            [[zone-scenes]]
                id = 'triage'
                layout-preset = 'balanced'
                workspaces = [
                    { zone = 'left', workspace = 'Reference' },
                ]

            [[zone-bindings]]
                zone = 'right'
                workspace = 'Comms'

            [[zone-availability-sets]]
                id = 'focus-only'
                enabled-zones = ['main']

            [[zones]]
                monitor = 1
                layout-preset = 'balanced'
            """,
            runtimeOverlays: [:],
        )

        XCTAssertEqual(lines, [
            "Config doctor:",
            "  config path: /tmp/winmux.toml",
            "  config status: OK",
            "  zones: displays=1 layouts=1 layout-columns=3",
            "  zone layout sums: OK",
            "  zone references: OK",
            "  warning: mouse.column-divider-drag = 'column-mode' but no [mode.column.binding] exists, so divider dragging is unreachable; define the mode or set the policy to 'always' or 'off'",
            "  runtime overlays: none",
        ])
    }

    func testRenderConfigDoctorLinesForInvalidZonesConfig() {
        let lines = renderConfigDoctorLines(
            configPath: "/tmp/winmux.toml",
            configText: """
            [[zone-layouts]]
                id = 'bad'
                layout = 'columns'
                columns = [
                    { id = 'main', width = 0.2 },
                ]
            """,
            runtimeOverlays: [:],
        )

        XCTAssertEqual(lines.prefix(4), [
            "Config doctor:",
            "  config path: /tmp/winmux.toml",
            "  config status: ERROR",
            "  parse errors:",
        ])
        XCTAssertTrue(lines.contains("    zone-layouts[0].columns: Column widths must sum to 1.0"))
    }

    func testRenderConfigDoctorLinesIncludesRuntimeOverlayState() {
        var overlay = ColumnRuntimeOverlay()
        overlay.activeLayoutId = "balanced"
        overlay.activeSceneId = "triage"
        overlay.columnSnapPolicyOverride = .snapToColumn
        overlay.disabledColumnIds = ["right", "left"]
        overlay.widthOverridesByLayoutIdentity = ["balanced": ["main": 0.7, "left": 0.3]]
        overlay.styleOverridesByColumnId = ["right": "urgent"]
        overlay.currentToggleRestoreColumnId = "right"

        let lines = renderConfigDoctorLines(
            configPath: "/tmp/winmux.toml",
            configText: "",
            runtimeOverlays: ["physical:0,0": overlay],
        )

        XCTAssertTrue(lines.contains("  runtime overlays:"))
        XCTAssertTrue(lines.contains("    physical:0,0: active-layout=balanced active-scene=triage snap-policy=snap-to-column"))
        XCTAssertTrue(lines.contains("      disabled=left,right"))
        XCTAssertTrue(lines.contains("      width-overrides=balanced[left=0.3000,main=0.7000]"))
        XCTAssertTrue(lines.contains("      styles=right:urgent"))
        XCTAssertTrue(lines.contains("      toggle-restore-zone=right"))
    }

    func testRejectInvalidZones() {
        let (_, errors) = parseConfig(
            """
            [[zone-layouts]]
                id = 'bad'
                layout = 'columns'
                default-zone = 'missing'
                columns = [
                    { id = 'left', width = 0.50 },
                    { id = 'left', width = 0.40 },
                ]

            [[zones]]
                monitor = 1
                layout-preset = 'bad'
            """,
        )

        assertEquals(errors.descriptions, [
            "zone-layouts[0].columns: Contains duplicated zone ids: left",
            "zone-layouts[0].default-zone: Must name one of the configured zone ids",
            "zone-layouts[0].columns: Column widths must sum to 1.0",
        ])
    }

    func testIgnoreInvalidRetiredZoneScenesInLegacyConfig() {
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

        assertEquals(errors, [])
    }

    func testIgnoreInvalidRetiredZoneBindingsInLegacyConfig() {
        let (_, errors) = parseConfig(
            """
            [[zone-layouts]]
                id = 'balanced'
                layout = 'columns'
                columns = [
                    { id = 'main', width = 1.0 },
                ]

            [[zone-bindings]]
                zone = 'main'

            [[zone-bindings]]
                zone = 'main'
                workspace = 'WorkDesk'

            [[zone-bindings]]
                zone = 'missing'
                workspace = 'OtherDesk'
            """,
        )

        assertEquals(errors.descriptions, [])
    }

    func testIgnoreInvalidRetiredZoneAvailabilitySetsInLegacyConfig() {
        let (_, errors) = parseConfig(
            """
            [[zone-layouts]]
                id = 'balanced'
                layout = 'columns'
                columns = [
                    { id = 'main', width = 1.0 },
                ]

            [[zone-availability-sets]]
                id = 'focus'
                enabled-zones = []

            [[zone-availability-sets]]
                id = 'focus'
                enabled-zones = ['main', 'main', 'missing']
            """,
        )

        assertEquals(errors.descriptions, [])
    }

    func testRejectInvalidColumnLayoutPresetReferences() {
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
            """,
        )

        assertEquals(errors.descriptions, [
            "zone-layouts: Contains duplicated layout ids: focus",
            "zones[0].layout-preset: Unknown zone layout preset 'missing'",
        ])
    }

    func testRejectMissingZoneFields() {
        let (_, errors) = parseConfig(
            """
            [[zones]]
            """,
        )

        assertEquals(errors.descriptions, [
            "zones[0].monitor: Missing required key",
            "zones[0].layout-preset: Missing required key",
        ])
    }

    func testRejectInvalidColumnIdsAndWidths() {
        let (_, errors) = parseConfig(
            """
            [[zone-layouts]]
                id = 'bad'
                layout = 'columns'
                columns = [
                    { id = 'bad space', width = 0.0 },
                    { id = 'negative', width = -0.2 },
                ]

            [[zones]]
                monitor = 1
                layout-preset = 'bad'
            """,
        )

        assertEquals(errors.descriptions, [
            "zone-layouts[0].columns[0].id: Use only letters, numbers, hyphens, and underscores",
            "zone-layouts[0].columns[0].width: Must be greater than 0",
            "zone-layouts[0].columns[0].id: Missing required key",
            "zone-layouts[0].columns[1].width: Must be greater than 0",
            "zone-layouts[0].columns: Column widths must sum to 1.0",
        ])
    }

    func testRejectDuplicateColumnMonitorSelectors() {
        let (_, errors) = parseConfig(
            """
            [[zone-layouts]]
                id = 'single'
                layout = 'columns'
                columns = [
                    { id = 'left', width = 1.0 },
                ]

            [[zones]]
                monitor = 1
                layout-preset = 'single'

            [[zones]]
                monitor = 1
                layout-preset = 'single'
            """,
        )

        assertEquals(errors.descriptions, [
            "zones: Contains duplicated monitor selectors: 1",
        ])
    }
}
