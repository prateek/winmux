@testable import AppBundle
import AppKit
import Common
import XCTest

/// The config-version-3 vocabulary cut: retired zone-era keys become hard errors naming their
/// replacement, renamed keys point at their new spelling, and the new surface parses clean. The cut
/// is gated on `config-version = 3`, so the frozen version-2 fixtures elsewhere stay valid.
extension ConfigTest {
    func testConfigVersion3AcceptedByVersionGate() {
        let (parsed, errors) = parseConfig(
            """
            config-version = 3
            """,
        )
        assertEquals(errors, [])
        XCTAssertEqual(parsed.configVersion, 3)
    }

    func testConfigVersion3RetiredKeysAreHardErrorsNamingReplacement() {
        // Each retired key, in its own minimal-valid version-3 config, is the sole diagnostic.
        let cases: [(toml: String, hint: String)] = [
            (
                """
                config-version = 3
                [[zones]]
                    monitor = 1
                    layout = 'columns'
                    columns = [ { id = 'main', width = 1.0 } ]
                """,
                "zones: 'zones' was replaced by [scene.*] (config-version 3)"
            ),
            (
                """
                config-version = 3
                [[zone-layouts]]
                    id = 'balanced'
                    layout = 'columns'
                    columns = [ { id = 'main', width = 1.0 } ]
                """,
                "zone-layouts: 'zone-layouts' was replaced by [scene.*] (config-version 3)"
            ),
            (
                """
                config-version = 3
                [[zone-scenes]]
                    id = 'triage'
                    layout-preset = 'balanced'
                    workspaces = [ { zone = 'main', workspace = 'Foo' } ]
                """,
                "zone-scenes: 'zone-scenes' was replaced by [scene.*] (config-version 3)"
            ),
            (
                """
                config-version = 3
                [[zone-availability-sets]]
                    id = 'focus-only'
                    enabled-zones = ['main']
                """,
                "zone-availability-sets: 'zone-availability-sets' was replaced by [scene.*] (config-version 3)"
            ),
            (
                """
                config-version = 3
                [[zone-styles]]
                    id = 'urgent'
                    color = '#D3455B'
                """,
                "zone-styles: 'zone-styles' was replaced by the column 'color' attribute (config-version 3)"
            ),
            (
                """
                config-version = 3
                [[zone-affinities]]
                    zone = 'Comms'
                    if.app-id = 'com.apple.mail'
                """,
                "zone-affinities: 'zone-affinities' was replaced by [[rules]] (config-version 3)"
            ),
            (
                """
                config-version = 3
                [[zone-bindings]]
                    zone = 'left'
                    workspace = 'Reference'
                """,
                "zone-bindings: 'zone-bindings' was removed; column decks record card membership (config-version 3)"
            ),
            (
                """
                config-version = 3
                [workspace-sidebar]
                    enabled = true
                """,
                "workspace-sidebar: 'workspace-sidebar' was renamed to 'sidebar' (config-version 3)"
            ),
            (
                """
                config-version = 3
                persistent-workspaces = ['Scratch']
                """,
                "persistent-workspaces: 'persistent-workspaces' was renamed to 'persistent-cards' (config-version 3)"
            ),
            (
                """
                config-version = 3
                [mouse.zone-snap]
                    policy = 'freeform'
                """,
                "mouse.zone-snap: 'mouse.zone-snap' was renamed to 'mouse.column-snap' (config-version 3)"
            ),
            (
                """
                config-version = 3
                [mouse]
                    zone-divider-drag = 'off'
                """,
                "mouse.zone-divider-drag: 'mouse.zone-divider-drag' was renamed to 'mouse.column-divider-drag' (config-version 3)"
            ),
        ]

        for (toml, hint) in cases {
            let (_, errors) = parseConfig(toml)
            assertEquals(errors.descriptions, [hint])
        }
    }

    func testConfigVersion3RetiredSidebarProjectKeysAreErrors() {
        let (_, errors) = parseConfig(
            """
            config-version = 3
            [sidebar]
                enabled = true
                project-deletion-action = 'close-windows'
            [sidebar.project-labels]
                default = 'Personal'
            [sidebar.project-colors]
                default = '#FF8844'
            """,
        )

        assertEquals(Set(errors.descriptions), Set([
            "sidebar.project-deletion-action: 'sidebar.project-deletion-action' was removed; projects are gone in config-version 3",
            "sidebar.project-labels: 'sidebar.project-labels' was removed; projects are gone in config-version 3",
            "sidebar.project-colors: 'sidebar.project-colors' was removed; projects are gone in config-version 3",
        ]))
    }

    func testConfigVersion3RenamedKeysParseUnderNewSpelling() {
        let (parsed, errors) = parseConfig(
            """
            config-version = 3
            persistent-cards = ['Scratch']

            [sidebar]
                enabled = true
                width = 240

            [mouse]
                column-divider-drag = 'column-mode'
            [mouse.column-snap]
                policy = 'snap-to-column'
                target = 'column'
            """,
        )

        assertEquals(errors, [])
        assertEquals(parsed.persistentWorkspaces.sorted(), ["Scratch"])
        XCTAssertTrue(parsed.workspaceSidebar.enabled)
        XCTAssertEqual(parsed.workspaceSidebar.width, 240)
        XCTAssertEqual(parsed.mouse.zoneDividerDrag, .zoneMode)
        // 'snap-to-column' and 'column' are the version-3 surface spellings; the internal cases
        // keep their upstream names until the internals rename.
        XCTAssertEqual(parsed.mouse.zoneSnap.policy, .snapToZone)
        XCTAssertEqual(parsed.mouse.zoneSnap.target, .zone)
    }

    func testConfigVersion3KeepsSceneAndRuleParsers() {
        let (parsed, errors) = parseConfig(
            """
            config-version = 3
            [scene.desk]
            display = 1
            columns = [ { id = 'main', width = 1.0 } ]

            [[rules]]
            if.app-id = 'com.tinyspeck.slackmacgap'
            card = 'Chat'
            """,
        )

        assertEquals(errors, [])
        assertEquals(parsed.scenes.map(\.id), ["desk"])
        assertEquals(parsed.rules.map(\.card), ["Chat"])
    }

    func testRetiredKeysStillParseUnderConfigVersion2() {
        // The cut is version-gated: a version-2 config keeps parsing the old vocabulary so the
        // frozen slice-51..55 fixtures and the current default template stay valid.
        let (_, sidebarErrors) = parseConfig(
            """
            config-version = 2
            [workspace-sidebar]
                enabled = true
            """,
        )
        assertEquals(sidebarErrors, [])

        let (parsed, zoneErrors) = parseConfig(
            """
            config-version = 2
            [[zones]]
                monitor = 1
                layout = 'columns'
                columns = [ { id = 'main', width = 1.0 } ]
            """,
        )
        assertEquals(zoneErrors, [])
        assertEquals(parsed.zones.count, 1)
    }
}
