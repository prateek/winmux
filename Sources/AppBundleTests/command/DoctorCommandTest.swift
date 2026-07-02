@testable import AppBundle
import Common
import Foundation
import XCTest

@MainActor
final class DoctorCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParseZoneSupportBundle() {
        let expected = DoctorCmdArgs(rawArgs: [])
            .copy(\.subject, .zones)
            .copy(\.supportBundle, true)
            .copy(\.outputPath, "/tmp/winmux-zone-bundle")
            .copy(\.includeWindowTitles, true)
        testParseCommandSucc(
            "doctor zones --support-bundle --output /tmp/winmux-zone-bundle --include-window-titles",
            expected,
        )
        assertEquals(parseCommand("doctor zones").errorOrNil, "doctor zones requires --support-bundle")
        assertEquals(parseCommand("doctor --support-bundle").errorOrNil, "--support-bundle requires 'zones'")
    }

    func testZoneSupportBundleWritesRequiredFilesAndRedactsPrivateFields() async throws {
        configureSupportBundleZones()
        config.zoneAffinities = [supportBundleAffinity()]

        try await withTemporaryDoctorConfig { outputDirectory in
            let result = try await parseCommand("doctor zones --support-bundle --output \(outputDirectory.path)").cmdOrDie
                .run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(result.exitCode, 0, result.stderr.joined(separator: "\n"))
            XCTAssertTrue(result.stdout.joined(separator: "\n").contains("Zone support bundle: \(outputDirectory.path)"))

            let bundleFiles = try FileManager.default.contentsOfDirectory(atPath: outputDirectory.path).sorted()
            XCTAssertEqual(
                Set(bundleFiles),
                Set([
                    "active-workspaces.tsv",
                    "command-failures.tsv",
                    "config-doctor.txt",
                    "config-redacted.toml",
                    "logs.txt",
                    "manifest.txt",
                    "monitor-topology.tsv",
                    "node-zone-bindings.tsv",
                    "permissions.txt",
                    "recent-window-routing-decisions.tsv",
                    "redaction-summary.txt",
                    "zone-affinities.tsv",
                    "zone-runtime-overlay.tsv",
                ]),
            )

            let allText = try bundleFiles.map { file in
                try String(contentsOf: outputDirectory.appending(component: file), encoding: .utf8)
            }.joined(separator: "\n")

            XCTAssertFalse(allText.contains(FileManager.default.homeDirectoryForCurrentUser.path))
            XCTAssertFalse(allText.contains(NSUserName()))
            XCTAssertFalse(allText.contains("Secret Board"))
            XCTAssertFalse(allText.contains("com.secret.Mail"))
            XCTAssertFalse(allText.contains("multi-line-token-secret"))
            XCTAssertFalse(allText.contains("comment-poison-secret"))
            XCTAssertFalse(allText.contains("abc]def"))
            XCTAssertTrue(allText.contains("<redacted-window-title>"))
            XCTAssertTrue(allText.contains("<redacted-app-identifier>"))
            XCTAssertTrue(allText.contains(#"if.app-id = "<redacted>""#))
            XCTAssertTrue(allText.contains(#"if."app-id" = "<redacted>""#))
            XCTAssertTrue(allText.contains(#"if."app\u002Did" = "<redacted>""#))
            XCTAssertTrue(allText.contains(#"#app-id = "<redacted>""#))
            XCTAssertTrue(allText.contains(#"api-token = "<redacted>""#))
            XCTAssertTrue(allText.contains("monitor-id\tzone-id\tzone-name\tphysical-identity\tactive-workspace"))
            XCTAssertTrue(allText.contains("zone-support-bundle") || allText.contains("winmux-zone-support-bundle"))
        }
    }

    func testZoneSupportBundleRedactsSensitiveParseErrors() async throws {
        configureSupportBundleZones()

        try await withTemporaryDoctorConfig(extraConfigText: """

        [[zone-affinities]]
        zone = "Comms"
        if.window-title-regex-substring = "Secret Board ("
        """) { outputDirectory in
            let result = try await parseCommand("doctor zones --support-bundle --output \(outputDirectory.path)").cmdOrDie
                .run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(result.exitCode, 0, result.stderr.joined(separator: "\n"))
            let doctorText = try String(contentsOf: outputDirectory.appending(component: "config-doctor.txt"), encoding: .utf8)
            XCTAssertTrue(doctorText.contains("config status: ERROR"))
            XCTAssertFalse(doctorText.contains("Secret Board"))
            XCTAssertTrue(doctorText.contains("<redacted-config-value>"))
        }
    }

    func testZoneSupportBundleResolvesRelativeAndTildeOutputPathsFromClient() async throws {
        configureSupportBundleZones()

        try await withTemporaryDoctorConfig { outputDirectory in
            let baseDirectory = outputDirectory.deletingLastPathComponent()
            let relativeResult = try await parseCommand("doctor zones --support-bundle --output bundle").cmdOrDie
                .run(.defaultEnv.copy(\.clientCurrentDirectory, baseDirectory.path), .emptyStdin)

            XCTAssertEqual(relativeResult.exitCode, 0, relativeResult.stderr.joined(separator: "\n"))
            XCTAssertTrue(FileManager.default.fileExists(atPath: outputDirectory.appending(component: "manifest.txt").path))
            XCTAssertTrue(relativeResult.stdout.joined(separator: "\n").contains("Zone support bundle: \(outputDirectory.path)"))
        }

        try await withTemporaryDoctorConfig { _ in
            let bundleName = ".winmux-doctor-tilde-\(UUID().uuidString)"
            let homeOutput = FileManager.default.homeDirectoryForCurrentUser.appending(component: bundleName)
            defer { try? FileManager.default.removeItem(at: homeOutput) }

            let tildeResult = try await parseCommand("doctor zones --support-bundle --output ~/\(bundleName)").cmdOrDie
                .run(.defaultEnv, .emptyStdin)

            XCTAssertEqual(tildeResult.exitCode, 0, tildeResult.stderr.joined(separator: "\n"))
            XCTAssertTrue(FileManager.default.fileExists(atPath: homeOutput.appending(component: "manifest.txt").path))
            XCTAssertTrue(tildeResult.stdout.joined(separator: "\n").contains("Zone support bundle: \(homeOutput.path)"))
        }
    }

    func testZoneSupportBundleRefusesNonEmptyOutputDirectory() async throws {
        configureSupportBundleZones()

        let directory = FileManager.default.temporaryDirectory
            .appending(component: "winmux-doctor-non-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "occupied".write(to: directory.appending(component: "marker.txt"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = try await parseCommand("doctor zones --support-bundle --output \(directory.path)").cmdOrDie
            .run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.stderr.joined(separator: "\n").contains("Output directory must be empty"))
    }
}

@MainActor
private func configureSupportBundleZones() {
    let main = TestMonitor(
        monitorAppKitNsScreenScreensId: 1,
        name: "Main",
        rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        isMain: true,
    )
    setMonitorsForTests([main])
    config.gaps = .zero
    config.workspaceSidebar.enabled = false
    config.zones = [
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
    ]
}

private func supportBundleAffinity() -> ZoneAffinityConfig {
    var matcher = WindowDetectedCallbackMatcher()
    matcher.appId = "com.secret.Mail"
    matcher.workspace = "Inbox"

    var affinity = ZoneAffinityConfig()
    affinity.matcher = matcher
    affinity.zone = ZoneSelector("Comms")
    affinity.focusFollowsWindow = true
    return affinity
}

@MainActor
private func withTemporaryDoctorConfig(
    extraConfigText: String = "",
    _ body: (URL) async throws -> Void,
) async throws {
    let previousConfigUrl = configUrl
    let directory = FileManager.default.temporaryDirectory
        .appending(component: "winmux-doctor-support-\(UUID().uuidString)")
    let outputDirectory = directory.appending(component: "bundle")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let configFile = directory.appending(component: "winmux.toml")
    let configText = try String(contentsOf: defaultConfigUrl, encoding: .utf8) + """

    # token = "super-secret-token"
    # app-id = "com.secret.Mail"
    #app-id = "com.secret.Mail"
    # window-title-regex-substring = "Secret Board"
    # private-path = "\(FileManager.default.homeDirectoryForCurrentUser.path)/Secret"
    zone-affinities = [{ if.app-id = 'com.secret.Mail', zone = 'comms' }]
    quoted-zone-affinities = [{ if."app-id" = "com.secret.Mail", zone = "comms" }]
    escaped-key-zone-affinities = [{ if."app\\u002Did" = "com.secret.Mail", zone = "comms" }]
    # don't let this comment apostrophe hide the next sensitive assignment
    comment-poison-api-token = "comment-poison-secret"
    api-token = \"\"\"
    multi-line-token-secret
    \"\"\"
    bracket-token = ["abc]def"]
    \(extraConfigText)
    """
    try configText.write(to: configFile, atomically: true, encoding: .utf8)
    configUrl = configFile
    defer {
        configUrl = previousConfigUrl
        try? FileManager.default.removeItem(at: directory)
    }
    try await body(outputDirectory)
}
