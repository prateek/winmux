@testable import AppBundle
import Foundation
import XCTest

@MainActor
final class FirstRunLaunchTest: XCTestCase {
    private func context(saved: Bool = true) -> FirstRunLaunchContext {
        FirstRunLaunchContext(arguments: ["/tmp/WinMuxApp", "--config-path", "/tmp/config.ncl"],
                              environment: ["XDG_STATE_HOME": "/tmp/state", "WINMUX_NICKEL_HELPER": "/tmp/helper"],
                              stateURL: URL(filePath: "/tmp/state/winmux/setup.json"), stateWasSaved: saved, token: "take")
    }

    func testExistingLaunchWithoutAPendingContextKeepsItsEnvironment() {
        XCTAssertEqual(firstRunLaunchAction(context: nil, currentEnvironment: [:], pendingState: false), .normal)
        XCTAssertEqual(firstRunLaunchAction(context: context(), currentEnvironment: [:], pendingState: false), .normal)
    }

    func testSystemReopenReexecutesThePendingLaunchWithItsArgumentsAndEnvironment() {
        let pending = context()
        XCTAssertEqual(firstRunLaunchAction(context: pending, currentEnvironment: [:], pendingState: true), .reexecute(pending))
        XCTAssertEqual(firstRunLaunchAction(context: context(saved: false), currentEnvironment: [:], pendingState: false), .reexecute(context(saved: false)))
    }

    func testAnExplicitNewXdgLaunchKeepsItsOwnConfigurationAndHonoursThePendingGoGate() {
        for key in ["XDG_CONFIG_HOME", "XDG_STATE_HOME"] {
            XCTAssertEqual(firstRunLaunchAction(context: context(), currentEnvironment: [key: "/tmp/other"], pendingState: true), .resume)
            XCTAssertEqual(firstRunLaunchAction(context: context(), currentEnvironment: [key: "/tmp/other", setupResumeTokenKey: "take"], pendingState: true), .resume)
        }
    }

    func testMatchingXdgValuesDoNotBypassThePendingLaunchWhenOtherValuesWereLost() {
        var pending = context()
        pending.environment["XDG_CONFIG_HOME"] = "/tmp/config"
        XCTAssertEqual(firstRunLaunchAction(context: pending, currentEnvironment: ["XDG_CONFIG_HOME": "/tmp/config"], pendingState: true), .reexecute(pending))
        XCTAssertEqual(firstRunLaunchAction(context: pending, currentEnvironment: ["XDG_STATE_HOME": "/tmp/state"], pendingState: true), .reexecute(pending))
    }

    func testTheReexecutedProcessResumesSetupWithoutReexecutingAgain() {
        XCTAssertEqual(firstRunLaunchAction(context: context(), currentEnvironment: [setupResumeTokenKey: "take"], pendingState: true), .resume)
        XCTAssertEqual(firstRunLaunchAction(context: context(), currentEnvironment: [setupResumeTokenKey: "take"], pendingState: false), .normal)
    }

    func testReplayUsesTheCurrentExecutableAndOriginalArgumentsAndFailsClosedIfExecReturns() {
        var calls = 0
        XCTAssertThrowsError(try reexecuteFirstRunLaunch(context(), executable: "/tmp/current", execute: { path, arguments, environment in
            calls += 1
            XCTAssertEqual(path, "/tmp/current")
            XCTAssertEqual(arguments, ["/tmp/current", "--config-path", "/tmp/config.ncl"])
            XCTAssertEqual(environment, ["XDG_STATE_HOME": "/tmp/state", "WINMUX_NICKEL_HELPER": "/tmp/helper", setupResumeTokenKey: "take"])
        }))
        XCTAssertEqual(calls, 1)
    }

    func testVolatileContextRoundTripReplacementAndCleanup() throws {
        let name = "/wmx-" + UUID().uuidString.prefix(20)
        defer { clearFirstRunLaunchContext(name: name) }
        XCTAssertNil(readFirstRunLaunchContext(name: name))
        try writeFirstRunLaunchContext(context(), name: name)
        XCTAssertEqual(readFirstRunLaunchContext(name: name), context())
        try writeFirstRunLaunchContext(context(saved: false), name: name)
        XCTAssertEqual(readFirstRunLaunchContext(name: name), context(saved: false))
        var oversized = context()
        oversized.environment["large"] = String(repeating: "x", count: 1_048_577)
        XCTAssertThrowsError(try writeFirstRunLaunchContext(oversized, name: name))
        XCTAssertEqual(readFirstRunLaunchContext(name: name), context(saved: false))
        clearFirstRunLaunchContext(name: name)
        XCTAssertNil(readFirstRunLaunchContext(name: name))
    }

    func testResumedLaunchStillWaitsForGoWhenTheStateFileWasNotSaved() async throws {
        let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "setup.json")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let shown = expectation(description: "resumed go")
        var contexts = 0
        var clears = 0
        let setup = FirstRunSetup(readGrants: { PermissionGrants(accessibility: true, screenRecording: true) },
                                 stateUrl: file, present: { _ in shown.fulfill() }, resumePending: true,
                                 saveLaunchContext: { _ in contexts += 1 }, clearLaunchContext: { clears += 1 })
        var started = false
        let task = Task { await setup.run(); started = true }
        await fulfillment(of: [shown], timeout: 1)
        XCTAssertEqual(setup.step, .go)
        XCTAssertFalse(started)
        XCTAssertTrue(readFirstRunState(from: file).pending)
        XCTAssertEqual(contexts, 1)
        XCTAssertEqual(clears, 0)
        setup.go()
        await task.value
        XCTAssertTrue(started)
        XCTAssertEqual(clears, 1)
    }
}
