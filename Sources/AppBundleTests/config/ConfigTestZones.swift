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

    func testParseZoneBindings() {
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
        assertEquals(parsed.zoneBindings, [
            ZoneBindingConfig(
                zone: "left",
                workspace: WorkspaceName.parse("ReferenceDesk").getOrDie(),
            ),
            ZoneBindingConfig(
                monitor: .sequenceNumber(2),
                zone: "right",
                workspace: WorkspaceName.parse("CommsDesk").getOrDie(),
            ),
        ])
    }

    func testParseDefaultConfigTemplate() throws {
        let (parsed, errors) = parseConfig(
            try String(contentsOf: getDefaultConfigUrlFromProject(), encoding: .utf8)
        )
        assertEquals(errors, [])
        XCTAssertNotNil(parsed.modes[mainModeId])
        XCTAssertNotNil(parsed.modes[zoneModeId])
        XCTAssertTrue(
            parsed.modes[mainModeId]?.bindings.values
                .contains { $0.descriptionWithKeyNotation == "ctrl-up" } == true
        )
    }

    func testParseZoneNodeBindingsE2EConfig() throws {
        var fixtureUrl = getDefaultConfigUrlFromProject()
        fixtureUrl.deleteLastPathComponent()
        fixtureUrl.deleteLastPathComponent()
        fixtureUrl.append(path: "script/e2e/configs/zone-node-bindings.toml")

        let (parsed, errors) = parseConfig(try String(contentsOf: fixtureUrl, encoding: .utf8))

        assertEquals(errors, [])
        XCTAssertTrue(parsed.windowTabs.enabled)
        assertEquals(parsed.zoneLayouts.map(\.id), ["balanced"])
        assertEquals(parsed.zones.map(\.layoutPreset), ["balanced"])
        assertEquals(
            parsed.modes["main"]?.bindings.values
                .map { "\($0.descriptionWithKeyNotation)=\($0.commands.prettyDescription)" }
                .sorted(),
            [
                "alt-b=bind-node-to-zone Comms",
                "alt-u=unbind-node-zone-binding",
            ],
        )
    }

    func testParseZoneAffinitiesE2EConfig() throws {
        var fixtureUrl = getDefaultConfigUrlFromProject()
        fixtureUrl.deleteLastPathComponent()
        fixtureUrl.deleteLastPathComponent()
        fixtureUrl.append(path: "script/e2e/configs/zone-affinities.toml")

        let (parsed, errors) = parseConfig(try String(contentsOf: fixtureUrl, encoding: .utf8))

        assertEquals(errors, [])
        assertEquals(parsed.zoneAffinities.count, 1)
        XCTAssertEqual(parsed.zoneAffinities[0].zone, ZoneSelector("Comms"))
        XCTAssertNotNil(parsed.zoneAffinities[0].matcher.windowTitleRegexSubstring)
        XCTAssertTrue(parsed.zoneAffinities[0].failIfNoop)
        XCTAssertFalse(parsed.workspaceSidebar.enabled)
    }

    func testParseZoneAffinitiesBetaE2EConfig() throws {
        var fixtureUrl = getDefaultConfigUrlFromProject()
        fixtureUrl.deleteLastPathComponent()
        fixtureUrl.deleteLastPathComponent()
        fixtureUrl.append(path: "script/e2e/configs/zone-affinities-beta.toml")

        let (parsed, errors) = parseConfig(try String(contentsOf: fixtureUrl, encoding: .utf8))

        assertEquals(errors, [])
        assertEquals(parsed.zoneBindings, [
            ZoneBindingConfig(
                zone: "left",
                workspace: WorkspaceName.parse("reference").getOrDie(),
            ),
            ZoneBindingConfig(
                zone: "main",
                workspace: WorkspaceName.parse("work").getOrDie(),
            ),
            ZoneBindingConfig(
                zone: "right",
                workspace: WorkspaceName.parse("comms").getOrDie(),
            ),
        ])
        assertEquals(parsed.zoneAffinities.count, 5)
        XCTAssertEqual(parsed.zoneAffinities.map(\.zone), [
            ZoneSelector("Comms"),
            ZoneSelector("Reference"),
            ZoneSelector("Work"),
            ZoneSelector("Reference"),
            ZoneSelector("Comms"),
        ])
        XCTAssertEqual(parsed.zoneAffinities[0].matcher.appId, "com.apple.TextEdit")
        XCTAssertNotNil(parsed.zoneAffinities[1].matcher.appNameRegexSubstring)
        XCTAssertNotNil(parsed.zoneAffinities[2].matcher.windowTitleRegexSubstring)
        XCTAssertEqual(parsed.zoneAffinities[2].matcher.workspace, "work")
        XCTAssertEqual(parsed.zoneAffinities[3].matcher.appId, "com.apple.mail")
        XCTAssertFalse(parsed.workspaceSidebar.enabled)
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

    func testParseZoneStyleCycleE2EConfig() throws {
        var fixtureUrl = getDefaultConfigUrlFromProject()
        fixtureUrl.deleteLastPathComponent()
        fixtureUrl.deleteLastPathComponent()
        fixtureUrl.append(path: "script/e2e/configs/zone-style-cycle.toml")

        let (parsed, errors) = parseConfig(try String(contentsOf: fixtureUrl, encoding: .utf8))

        assertEquals(errors, [])
        assertEquals(parsed.zoneStyles, [
            ZoneStyleConfig(id: "urgent", color: "#D3455B"),
            ZoneStyleConfig(id: "calm", color: "#3EA2FF"),
        ])
        assertEquals(parsed.zoneLayouts.map(\.id), ["balanced"])
        assertEquals(parsed.zones.map(\.layoutPreset), ["balanced"])
        XCTAssertEqual(parsed.workspaceSidebar.enabled, true)
        XCTAssertEqual(
            parsed.modes["main"]?.bindings.values
                .map { "\($0.descriptionWithKeyNotation)=\($0.commands.prettyDescription)" },
            ["alt-y=cycle-zone-style Comms urgent calm"],
        )
    }

    func testParseZoneAvailabilitySets() {
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
        assertEquals(parsed.zoneAvailabilitySets, [
            ZoneAvailabilitySetConfig(id: "focus-only", enabledZones: ["main"]),
            ZoneAvailabilitySetConfig(id: "communications", enabledZones: ["main", "right"]),
        ])
    }

    func testParseZoneAvailabilityProfilesE2EConfig() throws {
        var fixtureUrl = getDefaultConfigUrlFromProject()
        fixtureUrl.deleteLastPathComponent()
        fixtureUrl.deleteLastPathComponent()
        fixtureUrl.append(path: "script/e2e/configs/zone-availability-profiles.toml")

        let (parsed, errors) = parseConfig(try String(contentsOf: fixtureUrl, encoding: .utf8))

        assertEquals(errors, [])
        assertEquals(parsed.zoneLayouts.map(\.id), ["balanced"])
        assertEquals(parsed.zones.map(\.layoutPreset), ["balanced"])
        assertEquals(parsed.zoneAvailabilitySets, [
            ZoneAvailabilitySetConfig(id: "focus-only", enabledZones: ["main"]),
            ZoneAvailabilitySetConfig(id: "communications", enabledZones: ["main", "right"]),
            ZoneAvailabilitySetConfig(id: "full-dashboard", enabledZones: ["left", "main", "right"]),
        ])
        XCTAssertEqual(parsed.workspaceSidebar.enabled, true)
        XCTAssertEqual(
            parsed.modes["main"]?.bindings.values
                .map { "\($0.descriptionWithKeyNotation)=\($0.commands.prettyDescription)" }
                .sorted(),
            [
                "alt-a=cycle-zone-profile focus-only communications full-dashboard",
                "alt-c=toggle-zone Comms",
                "alt-d=use-zone-profile full-dashboard",
                "alt-f=use-zone-profile focus-only",
                "alt-m=use-zone-profile communications",
            ],
        )
    }

    func testParseZoneChromePolishE2EConfig() throws {
        var fixtureUrl = getDefaultConfigUrlFromProject()
        fixtureUrl.deleteLastPathComponent()
        fixtureUrl.deleteLastPathComponent()
        fixtureUrl.append(path: "script/e2e/configs/zone-chrome-polish.toml")

        let (parsed, errors) = parseConfig(try String(contentsOf: fixtureUrl, encoding: .utf8))

        assertEquals(errors, [])
        assertEquals(parsed.zoneStyles, [
            ZoneStyleConfig(id: "urgent", color: "#D3455B"),
            ZoneStyleConfig(id: "calm", color: "#3EA2FF"),
        ])
        assertEquals(parsed.zoneLayouts.map(\.id), ["balanced"])
        assertEquals(parsed.zones.map(\.layoutPreset), ["balanced"])
        assertEquals(parsed.zoneAvailabilitySets, [
            ZoneAvailabilitySetConfig(id: "focus-only", enabledZones: ["main"]),
            ZoneAvailabilitySetConfig(id: "communications", enabledZones: ["main", "right"]),
            ZoneAvailabilitySetConfig(id: "full-dashboard", enabledZones: ["left", "main", "right"]),
        ])
        XCTAssertEqual(parsed.workspaceSidebar.enabled, true)
        XCTAssertEqual(
            parsed.modes["main"]?.bindings.values
                .map { "\($0.descriptionWithKeyNotation)=\($0.commands.prettyDescription)" }
                .sorted(),
            [
                "alt-a=cycle-zone-profile focus-only communications full-dashboard",
                "alt-c=focus-zone Comms",
                "alt-f=use-zone-profile focus-only",
                "alt-m=use-zone-profile communications",
                "alt-r=focus-zone Reference",
                "alt-w=focus-zone Work",
                "alt-y=cycle-zone-style current urgent calm",
            ],
        )
    }

    func testRenderConfigDoctorLinesWarnsWhenZoneModePolicyIsUnreachable() {
        let noZoneMode = renderConfigDoctorLines(
            configPath: "/tmp/winmux.toml",
            configText: "config-version = 2",
            runtimeOverlays: [:],
        )
        XCTAssertTrue(noZoneMode.contains { $0.contains("mouse.zone-divider-drag = 'zone-mode' but no [mode.zone.binding] exists") })

        let withZoneMode = renderConfigDoctorLines(
            configPath: "/tmp/winmux.toml",
            configText: """
            config-version = 2
            [mode.zone.binding]
                h = ['focus-zone prev', 'mode main']
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
        XCTAssertFalse(policyOff.contains { $0.contains("zone-divider-drag = 'zone-mode'") })
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
            "  zones: inline=1 inline-columns=0 layouts=1 layout-columns=3 styles=1 scenes=1 bindings=1 affinities=0 availability-sets=1",
            "  zone layout sums: OK",
            "  zone references: OK",
            "  warning: mouse.zone-divider-drag = 'zone-mode' but no [mode.zone.binding] exists, so divider dragging is unreachable; define the mode or set the policy to 'always' or 'off'",
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
        var overlay = ZoneRuntimeOverlay()
        overlay.activeLayoutId = "balanced"
        overlay.activeSceneId = "triage"
        overlay.activeAvailabilitySetId = "focus-only"
        overlay.zoneSnapPolicyOverride = .snapToZone
        overlay.disabledZoneIds = ["right", "left"]
        overlay.parkedWorkspaceByZoneId = ["right": WorkspaceId("workspace-right")]
        overlay.widthOverridesByLayoutIdentity = ["balanced": ["main": 0.7, "left": 0.3]]
        overlay.styleOverridesByZoneId = ["right": "urgent"]
        overlay.currentToggleRestoreZoneId = "right"

        let lines = renderConfigDoctorLines(
            configPath: "/tmp/winmux.toml",
            configText: "",
            runtimeOverlays: ["physical:0,0": overlay],
        )

        XCTAssertTrue(lines.contains("  runtime overlays:"))
        XCTAssertTrue(lines.contains("    physical:0,0: active-layout=balanced active-scene=triage active-availability=focus-only snap-policy=snap-to-zone"))
        XCTAssertTrue(lines.contains("      disabled=left,right"))
        XCTAssertTrue(lines.contains("      parked=right:workspace-right"))
        XCTAssertTrue(lines.contains("      width-overrides=balanced[left=0.3000,main=0.7000]"))
        XCTAssertTrue(lines.contains("      styles=right:urgent"))
        XCTAssertTrue(lines.contains("      toggle-restore-zone=right"))
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

    func testRejectInvalidZoneBindings() {
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

        assertEquals(errors.descriptions, [
            "zone-bindings[0].workspace: Missing required key",
            "zone-bindings: Contains duplicated zone binding targets: any:main",
            "zone-bindings[2].zone: Unknown zone id 'missing'",
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

    func testRejectInvalidZoneAvailabilitySets() {
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

        assertEquals(errors.descriptions, [
            "zone-availability-sets[0].enabled-zones: Must contain at least one zone id",
            "zone-availability-sets[1].enabled-zones: Contains duplicated zone ids: main",
            "zone-availability-sets: Contains duplicated availability set ids: focus",
            "zone-availability-sets[1].enabled-zones[2]: Unknown zone id 'missing'",
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
