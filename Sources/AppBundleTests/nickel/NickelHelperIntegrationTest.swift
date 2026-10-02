@testable import AppBundle
import Common
import XCTest

/// Runs the real `winmux-nickel` built in `nickel-helper/`. Skipped when it has not been built.
@MainActor
final class NickelHelperIntegrationTest: XCTestCase {
    private func fixture(_ name: String) -> URL {
        projectRootUrl.appending(path: "nickel-helper/tests/fixtures").appending(path: name)
    }

    private func supervisor() throws -> NickelSupervisor {
        guard nickelHelperUrl() != nil else { throw XCTSkip("winmux-nickel is not built: run cargo build --release in nickel-helper") }
        return NickelSupervisor()
    }

    /// The records WinMux builds for its windows: one mail window among `count`, with nothing
    /// focused.
    private func records(count: Int) async -> (context: JSONValue, windows: [JSONValue]) {
        setUpWorkspacesForTests()
        var windows: [JSONValue] = []
        for id in 0 ..< count {
            let window = TestWindow.new(id: UInt32(id + 1), parent: focus.workspace.rootTilingContainer)
            window.testAxRecordAttributes = WindowAxRecordAttributes(title: "Inbox", subrole: "AXStandardWindow", hasCloseButton: true, document: "")
            var record = await window.windowRecord().orDie()
            record.app.bundleId = id % 5 == 0 ? "com.apple.mail" : "com.example.other"
            windows.append(record.json)
        }
        return (await filterContextRecord(mouse: .zero).json, windows)
    }

    private func schema() throws -> JSONValue {
        let process = Process()
        process.executableURL = try XCTUnwrap(nickelHelperUrl())
        process.arguments = ["schema", "--json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    private func fieldNames(_ record: JSONValue?) -> [String] {
        guard case .object(let fields) = record else { return [] }
        return fields.keys.sorted()
    }

    func testRecordsWinMuxBuildsHoldExactlyTheFieldsOfTheSchema() async throws {
        _ = try supervisor()
        let schema = try schema()
        func schemaFields(_ record: String) -> [String] {
            (schema["records"]?[record]?.arrayOrNil ?? []).compactMap { $0["name"]?.stringOrNil }.sorted()
        }
        let workspace = focus.workspace
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        check(window.focusWindow())

        let record = await window.windowRecord().orDie().json
        let context = await filterContextRecord(mouse: .zero).json

        assertEquals(schema["contract-version"], .int(1))
        assertEquals(fieldNames(record), schemaFields("Window"))
        assertEquals(fieldNames(record["app"]), schemaFields("App"))
        assertEquals(fieldNames(record["monitor"]), schemaFields("Monitor"))
        assertEquals(fieldNames(context), schemaFields("FilterContext"))
        assertEquals(fieldNames(context["workspace"]), schemaFields("Workspace"))
        assertEquals(fieldNames(context["focused"]), schemaFields("Window"))
    }

    func testFilterReadsTheRecordsWinMuxBuilds() async throws {
        let supervisor = try supervisor()
        supervisor.adopt(try await supervisor.load(fixture("config.ncl")).get())
        setUpWorkspacesForTests()
        let workspace = focus.workspace
        let tiled = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let floating = TestWindow.new(id: 2, parent: workspace)
        let minimized = TestWindow.new(id: 3, parent: workspace.rootTilingContainer)
        minimized.nativeIsMacosMinimized = true
        try await normalizeLayoutReason()
        check(tiled.focusWindow())
        var windows: [JSONValue] = []
        for window in [tiled, floating, minimized] {
            windows.append(await window.windowRecord().orDie().json)
        }
        let context = await filterContextRecord(mouse: .zero).json

        let isFloating = await supervisor.evalFilter("w.class == 'floating", context: context, windows: windows)
        let isMinimizedHere = await supervisor.evalFilter(
            "w.class == 'minimized && w.workspace == ctx.workspace.name",
            context: context,
            windows: windows,
        )
        let sameApp = await supervisor.filter(lens: "same-app", context: context, windows: windows)
        let isRegular = await supervisor.evalFilter("w.app.activationPolicy == 'regular && !w.app.accessory", context: context, windows: windows)

        assertEquals(isFloating, .success([false, true, false]))
        assertEquals(isMinimizedHere, .success([false, false, true]))
        assertEquals(sameApp, .success([true, true, true]))
        assertEquals(isRegular, .success([true, true, true]))
    }

    func testConfigWithFiltersParsesIntoWinMuxSettings() async throws {
        let supervisor = try supervisor()

        for name in ["config.ncl", "every-field.ncl"] {
            let loaded = try await supervisor.load(fixture(name)).get()
            supervisor.discard(loaded)
            let (_, errors) = parseConfig(loaded.settings)

            assertEquals(errors, [])
        }
    }

    func testConfigOverTheDefaultsParsesIntoWinMuxSettings() async throws {
        let supervisor = try supervisor()

        let loaded = try await supervisor.load(fixture("over-defaults.ncl")).get()
        supervisor.discard(loaded)
        let (config, errors) = parseConfig(loaded.settings)

        assertEquals(errors, [])
        assertEquals(config.defaultRootContainerLayout, .tabGroup)
        assertEquals(config.gaps.inner.horizontal, .constant(0))
        assertEquals(config.gaps.inner.vertical, .constant(8))
        assertEquals(config.modes[mainModeId]?.bindings.count, defaultConfig.modes[mainModeId]?.bindings.count)
        XCTAssertTrue(loaded.imports.contains { $0.path.hasSuffix("winmux/defaults.ncl") })
    }

    func testNoConfigFileLoadsTheShippedDefaultsWhichMatchTheBuiltInOnes() async throws {
        let supervisor = try supervisor()

        let loaded = try await supervisor.load(nil).get()
        supervisor.discard(loaded)
        let builtIn = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: defaultConfigUrl))

        assertEquals(loaded.settings, builtIn)
    }

    func testContractErrorComesBackAsNickelsDiagnostic() async throws {
        let supervisor = try supervisor()

        let result = await supervisor.load(fixture("unknown-key.ncl"))

        guard case .failure(.diagnostic(let diagnostic)) = result else { return XCTFail("\(result)") }
        XCTAssertTrue(diagnostic.contains("extra field `gapz`"), diagnostic)
    }

    func testFilterAndHookRequestsStayWithinTheirLatencyLimits() async throws {
        let supervisor = try supervisor()
        guard try XCTUnwrap(nickelHelperUrl()).path.contains("/release/") else {
            throw XCTSkip("Latency is only checked against a release build of winmux-nickel")
        }
        supervisor.adopt(try await supervisor.load(fixture("config.ncl")).get())
        let (context, windows) = await records(count: 50)

        func median(_ body: () async -> Void) async -> Duration {
            await body() // Warm up
            var samples: [Duration] = []
            for _ in 0 ..< 21 {
                let start = ContinuousClock.now
                await body()
                samples.append(ContinuousClock.now - start)
            }
            return samples.sorted()[samples.count / 2]
        }

        var bits: Result<[Bool], NickelFailure> = .success([])
        let filterTime = await median { bits = await supervisor.filter(lens: "mail", context: context, windows: windows) }
        var hook: Result<JSONValue, NickelFailure> = .success(.null)
        let hookTime = await median { hook = await supervisor.hook("arrive", args: [windows[0], context]) }

        assertEquals(try bits.get().filter { $0 }.count, 10)
        assertEquals(hook, .success(.object(["workspace": .string("Inbox"), "column": .int(2)])))
        XCTAssertLessThanOrEqual(filterTime, .milliseconds(10), "50-window Filter request: \(filterTime)")
        XCTAssertLessThanOrEqual(hookTime, .milliseconds(2), "hook request: \(hookTime)")
        print("winmux-nickel latency: 50-window filter \(filterTime), hook \(hookTime)")
    }
}

/// `readConfig` is what startup and `reload-config` call. WinMux falls back to its built-in
/// defaults when it fails at startup; that step runs inside `initAppBundle` and has no test.
@MainActor
final class ReadConfigTest: XCTestCase {
    private func fixture(_ name: String) -> URL {
        projectRootUrl.appending(path: "nickel-helper/tests/fixtures").appending(path: name)
    }

    func testValidConfigIsLoadedAndParsed() async throws {
        guard nickelHelperUrl() != nil else { throw XCTSkip("winmux-nickel is not built") }

        let loaded = try await readConfig(forceConfigUrl: fixture("over-defaults.ncl")).get()
        NickelSupervisor.shared.discard(loaded.helper)

        assertEquals(loaded.url, fixture("over-defaults.ncl"))
        assertEquals(loaded.config.gaps.inner.horizontal, .constant(0))
    }

    func testBrokenConfigFailsWithThePathAndNickelsDiagnostic() async throws {
        guard nickelHelperUrl() != nil else { throw XCTSkip("winmux-nickel is not built") }

        let result = await readConfig(forceConfigUrl: fixture("unknown-key.ncl"))

        guard case .failure(let message) = result else { return XCTFail("Expected a failure") }
        XCTAssertTrue(message.hasPrefix("Failed to load \(fixture("unknown-key.ncl").path)"), message)
        XCTAssertTrue(message.contains("extra field `gapz`"), message)
    }
}
