@testable import AppBundle
import Common
import XCTest

@MainActor
final class EmptyBindingTest: XCTestCase {
    func testEmptyChordsAndSequencesAreAbsentButTapAndNonemptyBindingsRemain() throws {
        let (parsed, errors) = parseConfig("""
        on-mode-changed = []
        after-startup-command = []
        [mode.main.binding]
        alt-slash = []
        cmd-tab = 'focus left'
        esc-h = []
        esc-l = ['focus right']
        [mode.main.binding-tap]
        left-alt = []
        right-alt = 'focus left'
        """)
        XCTAssertTrue(errors.isEmpty, "\(errors)")
        let mode = try XCTUnwrap(parsed.modes["main"])
        XCTAssertEqual(Set(mode.bindings.values.map(\.descriptionWithKeyNotation)), ["cmd-tab"])
        XCTAssertEqual(Set(mode.sequenceBindings.keys), ["esc-l"])
        XCTAssertEqual(mode.sequenceBindings["esc-l"]?.commands.count, 1)
        XCTAssertEqual(mode.tapBindings["left-alt"]?.commands.count, 0)
        XCTAssertEqual(mode.tapBindings["right-alt"]?.commands.count, 1)
        XCTAssertTrue(parsed.onModeChanged.isEmpty)
        XCTAssertTrue(parsed.afterStartupCommand.isEmpty)
    }

    func testEmptyChordStillParticipatesInRedeclarationChecks() {
        for (first, second) in [("[]", "'focus left'"), ("'focus left'", "[]"), ("[]", "[]")] {
            let (_, errors) = parseConfig("""
            key-mapping.key-notation-to-key-code.alias = 'slash'
            [mode.main.binding]
            alt-slash = \(first)
            alt-alias = \(second)
            """)
            XCTAssertEqual(errors.count, 1)
            XCTAssertTrue(errors.first?.description.contains("Binding redeclaration") == true, "\(errors)")
        }
    }

    func testEmptyBindingsAreUnboundForDispatchConfigAndSettings() async throws {
        setUpWorkspacesForTests()
        let (parsed, errors) = parseConfig("""
        [mode.main.binding]
        alt-slash = []
        esc-h = []
        alt-j = 'focus down'
        """)
        XCTAssertTrue(errors.isEmpty, "\(errors)")
        config = parsed
        XCTAssertNil(activeHotkeyBinding("alt-slash", mode: "main", modes: config.modes))
        XCTAssertNotNil(activeHotkeyBinding("alt-j", mode: "main", modes: config.modes))
        for chord in ["alt-slash", "esc-h"] {
            let result = try await parseCommand("trigger-binding --mode main \(chord)").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(result.exitCode, 1)
            XCTAssertEqual(result.stderr.joined(), "Binding '\(chord)' is not presented in mode 'main'")
        }
        let listed = try await parseCommand("config --get mode.main.binding --json").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(listed.exitCode, 0)
        let bindings = try JSONDecoder().decode([String: String].self, from: Data(listed.stdout.joined().utf8))
        XCTAssertEqual(bindings, ["alt-j": "focus down"])
        let settings = ShortcutSettingsModel.shared
        settings.reload()
        XCTAssertFalse(settings.customBindings.contains { $0.notation == "alt-slash" })
        XCTAssertFalse(settings.assignments.values.contains("alt-slash"))
    }
}
