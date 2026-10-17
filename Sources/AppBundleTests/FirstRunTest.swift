@testable import AppBundle
import Common
import AppKit
import XCTest

@MainActor
final class FirstRunTest: XCTestCase {
    func testStatusRefreshDetectsAGrantAfterSetupHasFinishedWithoutScreenRecording() async {
        var freshGrant = false
        var probes = 0
        let setup = FirstRunSetup(readGrants: { PermissionGrants(accessibility: true, screenRecording: false) },
                                 probeScreenRecording: { probes += 1; return freshGrant })
        await setup.refreshPermissions()
        XCTAssertEqual(setup.permissions.screenRecording, "missing")
        freshGrant = true
        await setup.refreshPermissions()
        XCTAssertEqual(setup.permissions.screenRecording, "granted-relaunch-needed")
        XCTAssertEqual(setup.permissions.setup, "done")
        freshGrant = false
        await setup.refreshPermissions()
        XCTAssertEqual(setup.permissions.screenRecording, "missing")
        XCTAssertEqual(probes, 3)
    }

    func testBundleRelaunchStartsANewInstanceWithArgumentsAndXdgBeforeQuitting() async throws {
        let bundle = URL(filePath: "/tmp/WinMux.app")
        let arguments = ["--config-path", "/tmp/config with spaces.ncl", "--read-only"]
        let environment = ["XDG_CONFIG_HOME": "/tmp/config", "XDG_STATE_HOME": "/tmp/state", "WINMUX_NICKEL_HELPER": "/tmp/helper"]
        var events: [String] = []
        try await relaunchFirstRunApplication(bundleURL: bundle, executableURL: bundle.appending(path: "Contents/MacOS/WinMux"),
            arguments: arguments, environment: environment, openBundle: { url, options in
                XCTAssertEqual(url, bundle)
                XCTAssertTrue(options.createsNewApplicationInstance)
                XCTAssertEqual(options.arguments, arguments)
                XCTAssertEqual(options.environment, environment)
                events.append("launch")
            }, runExecutable: { _, _, _ in XCTFail("used the unbundled launcher") }, terminate: { events.append("quit") })
        XCTAssertEqual(events, ["launch", "quit"])
    }

    func testUnbundledRelaunchRunsItsOwnExecutableWithArgumentsAndEnvironment() async throws {
        let executable = URL(filePath: "/tmp/debug/WinMuxApp")
        let arguments = ["--read-only"]
        let environment = ["XDG_STATE_HOME": "/tmp/state"]
        var events: [String] = []
        try await relaunchFirstRunApplication(bundleURL: URL(filePath: "/tmp/debug"), executableURL: executable,
            arguments: arguments, environment: environment, openBundle: { _, _ in XCTFail("used LaunchServices") },
            runExecutable: { url, args, env in
                XCTAssertEqual(url, executable)
                XCTAssertEqual(args, arguments)
                XCTAssertEqual(env, environment)
                events.append("launch")
            }, terminate: { events.append("quit") })
        XCTAssertEqual(events, ["launch", "quit"])
    }

    func testFailedRelaunchKeepsTheCurrentSetupProcessAlive() async {
        for bundled in [false, true] {
            do {
                try await relaunchFirstRunApplication(bundleURL: URL(filePath: bundled ? "/tmp/WinMux.app" : "/tmp/debug"),
                    executableURL: URL(filePath: "/tmp/debug/WinMuxApp"), arguments: [], environment: [:],
                    openBundle: { _, _ in throw CancellationError() }, runExecutable: { _, _, _ in throw CancellationError() },
                    terminate: { XCTFail("quit after a failed relaunch") })
                XCTFail("lost the launch error")
            } catch { XCTAssertTrue(error is CancellationError) }
        }
    }

    func testUnwritablePendingStateCannotLetGoStartWindowManagement() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("blocked parent".utf8).write(to: directory)
        let file = directory.appending(path: "setup.json")
        var grants = PermissionGrants(accessibility: false, screenRecording: false)
        let shown = expectation(description: "setup shows its save error")
        let setup = FirstRunSetup(readGrants: { grants }, stateUrl: file, present: { _ in shown.fulfill() })
        var started = false
        let task = Task { await setup.run(); started = true }
        await fulfillment(of: [shown], timeout: 1)
        XCTAssertNotNil(setup.error)
        grants = PermissionGrants(accessibility: true, screenRecording: true)
        setup.go()
        XCTAssertTrue(setup.waiting)
        XCTAssertFalse(started)
        try FileManager.default.removeItem(at: directory)
        setup.go()
        await task.value
        XCTAssertTrue(started)
        XCTAssertNil(setup.error)
    }
    func testSignalCleanupDuringSetupPreservesTheFrozenWorldFromThePreviousRun() throws {
        let previous = mayArrangeWindows
        mayArrangeWindows = false
        defer { mayArrangeWindows = previous }
        let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let saved = Data("previous frozen world".utf8)
        try saved.write(to: file)
        persistFrozenWorldForRestartIfPossible(file: file)
        XCTAssertEqual(try Data(contentsOf: file), saved)
    }

    func testStartedWindowManagementStillSavesAndClearsFrozenWorldAsBefore() throws {
        setUpWorkspacesForTests()
        let previous = mayArrangeWindows
        mayArrangeWindows = true
        defer { mayArrangeWindows = previous }
        let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let window = TestWindow.new(id: 701, parent: focus.workspace.rootTilingContainer)
        persistFrozenWorldForRestartIfPossible(file: file)
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        let world = try XCTUnwrap(saved["world"] as? [String: Any])
        XCTAssertEqual(world["windowIds"] as? [UInt32], [701])
        window.unbindFromParent()
        persistFrozenWorldForRestartIfPossible(file: file)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }
    func testPermissionButtonRequestsAfterReturningFromTheInputCallbackThenOpensSettings() async {
        var calls: [String] = []
        let opened = expectation(description: "settings opened after request")
        enqueueSetupPermissionRequest(request: { calls.append("request") }, openSettings: {
            calls.append("settings")
            opened.fulfill()
        })
        XCTAssertEqual(calls, [], "Permission requests must leave the input callback before opening Settings")
        await fulfillment(of: [opened], timeout: 1)
        XCTAssertEqual(calls, ["request", "settings"])
    }
    func testStartupWaitsThroughPermissionsUntilExplicitGoAndRemembersInterruptedSetup() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "setup.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var grants = PermissionGrants(accessibility: false, screenRecording: false)
        let shown = expectation(description: "setup shown")
        let setup = FirstRunSetup(readGrants: { grants }, stateUrl: url, present: { _ in shown.fulfill() })
        var arranged = false
        let startup = Task { await setup.run(); arranged = true }
        await fulfillment(of: [shown], timeout: 1)
        XCTAssertTrue(readFirstRunState(from: url).pending)
        XCTAssertFalse(arranged)
        setup.go()
        XCTAssertTrue(setup.waiting)
        grants = PermissionGrants(accessibility: true, screenRecording: true)
        XCTAssertEqual(setup.step, .go)
        XCTAssertFalse(arranged)
        let reopened = expectation(description: "pending setup reopened at go")
        let next = FirstRunSetup(readGrants: { grants }, stateUrl: url, present: { model in
            XCTAssertEqual(model.step, .go)
            reopened.fulfill()
        })
        let relaunch = Task { await next.run() }
        await fulfillment(of: [reopened], timeout: 1)
        next.go()
        await relaunch.value
        XCTAssertFalse(readFirstRunState(from: url).pending)
        setup.go()
        await startup.value
        XCTAssertTrue(arranged)
    }

    func testExistingGrantedInstallAndRecordedDeclineStartWithoutShowingSetup() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "setup.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let granted = FirstRunSetup(readGrants: { PermissionGrants(accessibility: true, screenRecording: true) }, stateUrl: url, present: { _ in XCTFail("existing install interrupted") })
        await granted.run()
        XCTAssertFalse(granted.waiting)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        try writeFirstRunState(FirstRunState(screenRecordingDeclined: true), to: url)
        let declined = FirstRunSetup(readGrants: { PermissionGrants(accessibility: true, screenRecording: false) }, stateUrl: url, present: { _ in XCTFail("decline forgotten") })
        await declined.run()
        XCTAssertFalse(declined.waiting)
    }

    func testDecliningScreenRecordingStillWaitsForGoAndRequiresAccessibility() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "setup.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var grants = PermissionGrants(accessibility: false, screenRecording: false)
        let shown = expectation(description: "setup shown")
        let setup = FirstRunSetup(readGrants: { grants }, stateUrl: url, present: { _ in shown.fulfill() })
        let startup = Task { await setup.run() }
        await fulfillment(of: [shown], timeout: 1)
        setup.continueWithoutScreenRecording()
        XCTAssertFalse(readFirstRunState(from: url).screenRecordingDeclined)
        grants.accessibility = true
        setup.continueWithoutScreenRecording()
        XCTAssertEqual(setup.step, .go)
        XCTAssertEqual(setup.permissions.setup, "waiting-for-go")
        XCTAssertTrue(readFirstRunState(from: url).screenRecordingDeclined)
        XCTAssertTrue(setup.waiting)
        setup.go()
        await startup.value
    }
    func testLightSessionCannotReadOrRefreshWindowModelBeforeGo() async {
        let previous = mayArrangeWindows
        mayArrangeWindows = false
        defer { mayArrangeWindows = previous }
        do {
            try await runLightSession(.menuBarButton, .forceRun) { XCTFail("ran before go") }
            XCTFail("accepted a session before go")
        } catch { XCTAssertTrue(error is CancellationError) }
        do {
            try await runRefreshSessionBlocking(.startup)
            XCTFail("accepted discovery before go")
        } catch { XCTAssertTrue(error is CancellationError) }
    }
    func testStepChoiceForEveryGrantAndPendingBranch() {
        let cases: [(Bool, Bool, Bool, FirstRunStep, FirstRunStep)] = [
            (false, false, false, .permissions, .permissions),
            (false, false, true, .done, .go),
            (false, true, false, .relaunch, .relaunch),
            (false, true, true, .done, .go),
            (true, false, false, .done, .go),
            (true, false, true, .done, .go),
            (true, true, false, .done, .go),
            (true, true, true, .done, .go),
        ]
        for accessibility in [false, true] {
            for (screen, relaunch, declined, withoutPending, withPending) in cases {
                for pending in [false, true] {
                    let grants = PermissionGrants(accessibility: accessibility, screenRecording: screen, screenRecordingAfterRelaunch: relaunch)
                    let expected: FirstRunStep = accessibility ? (pending ? withPending : withoutPending) : .permissions
                    XCTAssertEqual(firstRunStep(grants: grants, state: FirstRunState(pending: pending, screenRecordingDeclined: declined)),
                                   expected, "AX=\(accessibility), screen=\(screen), relaunch=\(relaunch), pending=\(pending), declined=\(declined)")
                }
            }
        }
    }

    func testRelaunchFallbackAfterRequestStillRequiresAccessibilityAndAllowsDeclining() {
        let missing = PermissionGrants(accessibility: true, screenRecording: false)
        XCTAssertEqual(firstRunStep(grants: missing, state: FirstRunState(pending: true), screenRecordingRequested: true), .relaunch)
        XCTAssertEqual(firstRunStep(grants: PermissionGrants(accessibility: false, screenRecording: false), state: FirstRunState(pending: true), screenRecordingRequested: true), .permissions)
        XCTAssertEqual(firstRunStep(grants: missing, state: FirstRunState(pending: true, screenRecordingDeclined: true), screenRecordingRequested: true), .go)
    }

    func testPendingAndDeclineSurviveRelaunchAndGoClearsOnlyPending() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "setup.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertEqual(readFirstRunState(from: url), FirstRunState())
        try writeFirstRunState(FirstRunState(pending: true, screenRecordingDeclined: true), to: url)
        var state = readFirstRunState(from: url)
        XCTAssertTrue(state.pending)
        XCTAssertTrue(state.screenRecordingDeclined)
        state.pending = false
        try writeFirstRunState(state, to: url)
        XCTAssertEqual(readFirstRunState(from: url), FirstRunState(pending: false, screenRecordingDeclined: true))
    }

    func testExistingConfigQueryPathsRunDirectlyDuringSetup() async throws {
        let setup = FirstRunSetup(readGrants: { PermissionGrants(accessibility: false, screenRecording: false) })
        setup.waiting = true
        for args in [["config", "status"], ["config", "--config-path"], ["config", "--get", "mode", "--keys"], ["config", "--major-keys"], ["config", "--all-keys"]] {
            let command = try XCTUnwrap(parseCommand(args).cmdOrNil)
            let result = await setup.answerBeforeStartup(command)
            let answer = try XCTUnwrap(result)
            XCTAssertEqual(answer.exitCode, 0, args.description)
            XCTAssertFalse(answer.stdout.isEmpty, args.description)
        }
    }

    func testExistingCommandPathsPassThroughWhenSetupIsOff() async throws {
        let setup = FirstRunSetup(readGrants: { PermissionGrants(accessibility: true, screenRecording: true) })
        for args in [["config", "status"], ["list-windows", "--all"], ["workspace", "1"], ["enable", "off"]] {
            let command = parseCommand(args).cmdOrNil!
            let answer = await setup.answerBeforeStartup(command)
            XCTAssertNil(answer, args.description)
        }
        XCTAssertNil(setup.refusal)
    }

    func testAllOtherCommandsRefusedWithoutAnyWindowModel() async throws {
        var grants = PermissionGrants(accessibility: false, screenRecording: false)
        let setup = FirstRunSetup(readGrants: { grants })
        setup.waiting = true
        for (next, message) in [
            (PermissionGrants(accessibility: false, screenRecording: true), "Accessibility"),
            (PermissionGrants(accessibility: true, screenRecording: false), "Screen Recording"),
            (PermissionGrants(accessibility: true, screenRecording: false, screenRecordingAfterRelaunch: true), "relaunch"),
            (PermissionGrants(accessibility: true, screenRecording: true), "start it"),
        ] {
            grants = next
            for args in [["list-windows", "--all"], ["workspace", "1"], ["enable", "off"]] {
                let result = await setup.answerBeforeStartup(parseCommand(args).cmdOrNil!)
                let answer = try XCTUnwrap(result)
                XCTAssertEqual(answer.exitCode, 1)
                XCTAssertTrue(answer.stderr.joined().contains(message), answer.stderr.description)
                XCTAssertTrue(answer.stdout.isEmpty)
            }
            XCTAssertTrue(try XCTUnwrap(setup.refusal).contains(message))
        }
    }

    func testStatusReadsCurrentInjectedGrantsAndKeepsHelperKeys() throws {
        var grants = PermissionGrants(accessibility: false, screenRecording: true)
        let setup = FirstRunSetup(readGrants: { grants })
        setup.waiting = true
        for (next, ax, screen, phase) in [
            (grants, "missing", "granted", "waiting-for-permissions"),
            (PermissionGrants(accessibility: true, screenRecording: false), "granted", "missing", "waiting-for-permissions"),
            (PermissionGrants(accessibility: true, screenRecording: false, screenRecordingAfterRelaunch: true), "granted", "granted-relaunch-needed", "waiting-for-permissions"),
            (PermissionGrants(accessibility: true, screenRecording: true), "granted", "granted", "waiting-for-go"),
        ] {
            grants = next
            let data = try JSONEncoder().encode(ConfigHelperStatus(NickelStatus(state: .ready, pid: nil, rss: 0, recycles: 0, lastError: nil, configPath: nil), permissions: setup.permissions))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["state", "pid", "rss", "recycles", "last-error", "config-path", "permissions"])
            let permissions = try XCTUnwrap(json["permissions"] as? [String: String])
            XCTAssertEqual(permissions, ["accessibility": ax, "screen-recording": screen, "setup": phase])
        }
        setup.waiting = false
        XCTAssertEqual(setup.permissions.setup, "done")
    }

    func testQuitExplanationUsesLoadedConfig() {
        XCTAssertTrue(firstRunQuitExplanation(restore: true).contains("back where they were"))
        XCTAssertTrue(firstRunQuitExplanation(restore: false).contains("centres"))
    }
}
