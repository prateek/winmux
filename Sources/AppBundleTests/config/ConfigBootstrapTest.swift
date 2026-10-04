@testable import AppBundle
import Common
import Foundation
import XCTest

@MainActor
final class ConfigBootstrapTest: XCTestCase {
    private var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appending(path: "WinMuxTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func write(_ text: String, to name: String) throws -> URL {
        let url = tempDir.appending(path: name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testFirstLaunchWithNoFileLoadsDefaultsWithoutWritingAStarter() throws {
        let target = tempDir.appending(path: "fresh/winmux.ncl")
        XCTAssertFalse(try materializeBootstrapConfigIfNeeded(targetUrl: target, existingLegacyUrls: [], createStarter: false))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        XCTAssertTrue(try materializeBootstrapConfigIfNeeded(targetUrl: target, existingLegacyUrls: []))
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), starterConfigText())
    }

    func testFirstLaunchWritesTheStarterConfig() throws {
        let targetUrl = tempDir.appending(path: "winmux/winmux.ncl")

        let didMaterialize = try materializeBootstrapConfigIfNeeded(targetUrl: targetUrl, existingLegacyUrls: [])

        XCTAssertTrue(didMaterialize)
        assertEquals(try String(contentsOf: targetUrl, encoding: .utf8), starterConfigText())
    }

    func testExistingConfigIsLeftAlone() throws {
        let targetUrl = try write("{}", to: "winmux.ncl")

        let didMaterialize = try materializeBootstrapConfigIfNeeded(targetUrl: targetUrl, existingLegacyUrls: [])

        XCTAssertFalse(didMaterialize)
        assertEquals(try String(contentsOf: targetUrl, encoding: .utf8), "{}")
    }

    func testStarterConfigLoadsWithEveryDefault() async throws {
        guard nickelHelperUrl() != nil else { throw XCTSkip("winmux-nickel is not built") }
        let starterUrl = try write(starterConfigText(), to: "winmux.ncl")
        let supervisor = NickelSupervisor()

        let loaded = try await supervisor.load(starterUrl).get()
        supervisor.discard(loaded)
        let builtIn = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: defaultConfigUrl))

        assertEquals(loaded.settings, builtIn)
    }

    func testTomlConfigIsConvertedPreferringTheFirstOne() throws {
        let preferredUrl = try write("alt-h = 'focus left'", to: "preferred.toml")
        let secondaryUrl = try write("alt-l = 'focus right'", to: "secondary.toml")
        let targetUrl = tempDir.appending(path: "winmux.ncl")

        let didMaterialize = try materializeBootstrapConfigIfNeeded(
            targetUrl: targetUrl,
            existingLegacyUrls: [preferredUrl, secondaryUrl],
            convert: { "converted \($0.lastPathComponent)" },
        )

        XCTAssertTrue(didMaterialize)
        assertEquals(try String(contentsOf: targetUrl, encoding: .utf8), "converted preferred.toml")
    }

    func testAerospaceImportConvertsOnlyTheKeyboardConfiguration() throws {
        let aerospaceUrl = try write(
            """
            start-at-login = false
            default-root-container-layout = 'accordion'
            accordion-padding = 22
            exec-on-workspace-change = ['/bin/sh', '-c', 'echo $AEROSPACE_FOCUSED_WORKSPACE']

            [workspace-sidebar]
            enabled = false

            [key-mapping]
            preset = 'dvorak'

            [mode.main.binding]
            alt-h = 'layout accordion tiles'
            alt-j = 'layout h_accordion v_accordion'
            alt-l = 'exec-and-forget echo $AEROSPACE_WINDOW_ID'
            """,
            to: "aerospace.toml",
        )
        let targetUrl = tempDir.appending(path: "winmux.ncl")
        var convertedToml = ""

        let didMaterialize = try materializeBootstrapConfigIfNeeded(
            targetUrl: targetUrl,
            existingLegacyUrls: [],
            aerospaceImportUrl: aerospaceUrl,
            convert: {
                convertedToml = try String(contentsOf: $0, encoding: .utf8)
                return "converted"
            },
        )

        XCTAssertTrue(didMaterialize)
        assertEquals(
            convertedToml,
            """
            [key-mapping]
            preset = 'dvorak'

            [mode.main.binding]
            alt-h = 'layout tab-group tiles'
            alt-j = 'layout h_tab_group v_tab_group'
            alt-l = 'exec-and-forget echo $WINMUX_WINDOW_ID'
            """,
        )
        let written = try String(contentsOf: targetUrl, encoding: .utf8)
        XCTAssertTrue(written.hasPrefix("# Migrated from the AeroSpace config \(aerospaceUrl.path)."), written)
        XCTAssertTrue(written.hasSuffix("converted"), written)
    }

    func testAerospaceConfigWithoutKeyboardConfigurationGetsTheStarterConfig() throws {
        let aerospaceUrl = try write("start-at-login = false", to: "aerospace.toml")
        let targetUrl = tempDir.appending(path: "winmux.ncl")

        _ = try materializeBootstrapConfigIfNeeded(
            targetUrl: targetUrl,
            existingLegacyUrls: [],
            aerospaceImportUrl: aerospaceUrl,
            convert: { _ in "converted" },
        )

        assertEquals(try String(contentsOf: targetUrl, encoding: .utf8), starterConfigText())
    }

    func testConvertedTomlConfigPreservesBindingsAndKeepsOnlyForkDefaults() async throws {
        guard nickelHelperUrl() != nil else { throw XCTSkip("winmux-nickel is not built") }
        let tomlUrl = try write(
            """
            [gaps]
                inner.horizontal = 3

            [mode.main.binding]
                alt-h = 'focus left'
            """,
            to: "winmux.toml",
        )
        let targetUrl = tempDir.appending(path: "winmux.ncl")
        let supervisor = NickelSupervisor()

        _ = try materializeBootstrapConfigIfNeeded(targetUrl: targetUrl, existingLegacyUrls: [tomlUrl])
        let loaded = try await supervisor.load(targetUrl).get()
        supervisor.discard(loaded)
        let (config, errors) = parseConfig(loaded.settings)

        assertEquals(errors, [])
        assertEquals(config.gaps.inner.horizontal, .constant(3))
        assertEquals(config.gaps.inner.vertical, .constant(8))
        var expectedModes = defaultConfig.modes
        expectedModes["main"]?.bindings = defaultConfig.modes["main"]!.bindings.filter {
            ["alt-h", "cmd-tab", "cmd-shift-tab", "cmd-backtick", "alt-slash", "alt-semicolon"].contains($0.key)
        }
        assertEquals(config.modes, expectedModes)
        XCTAssertNil(config.modes["main"]?.bindings["alt-tab"])
        assertEquals(config.lenses, defaultConfig.lenses)
    }
}
