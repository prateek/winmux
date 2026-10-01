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

    private func standIn(bundleId: String, cls: String = "tiled") -> JSONValue {
        .object([
            "title": .string("Inbox"),
            "private": .bool(false),
            "class": .string(cls),
            "app": .object(["bundleId": .string(bundleId)]),
        ])
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
        let context = standIn(bundleId: "ctx")
        let windows = (0 ..< 50).map { standIn(bundleId: $0 % 5 == 0 ? "com.apple.mail" : "com.example.other") }

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
