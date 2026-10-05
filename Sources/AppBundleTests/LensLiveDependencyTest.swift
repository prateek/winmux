@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor
final class LensLiveDependencyTest: XCTestCase {
    func testUnconfiguredLiveSearchFailsWithDependencyName() async throws {
        let probe = "WINMUX_TEST_UNCONFIGURED_LENS"
        if ProcessInfo.processInfo.environment[probe] == "1" {
            let panel = SwitcherPalettePanel(emit: { _ in })
            let ticket = panel.beginLens("unconfigured", toggle: false)!
            await panel.openLens(name: "unconfigured", settings: LensConfig(), entries: [], search: "= true", banner: nil, context: .null, ticket: ticket)
            let signal = LensEffectSignal()
            await signal.wait()
            return
        }
        let runner = Process()
        runner.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        runner.arguments = ["-XCTest", "AppBundleTests.LensLiveDependencyTest/testUnconfiguredLiveSearchFailsWithDependencyName", Bundle(for: Self.self).bundlePath]
        var environment = ProcessInfo.processInfo.environment
        environment[probe] = "1"
        runner.environment = environment
        let output = Pipe()
        runner.standardOutput = output
        runner.standardError = output
        try runner.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        runner.waitUntilExit()
        XCTAssertNotEqual(runner.terminationStatus, 0)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("Unconfigured Lens dependency: NickelSupervisor.evalFilter"))
    }
}
