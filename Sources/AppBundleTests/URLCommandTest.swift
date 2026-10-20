@testable import AppBundle
import Common
import AppKit
import XCTest

@MainActor
final class URLCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests(); TrayMenuModel.shared.isEnabled = true }

    func testRegisteredAppleEventEnqueuesArgumentsWithoutOpeningAWindow() async throws {
        let received = expectation(description: "Apple event command")
        let visibleWindows = NSApplication.shared.windows.filter(\.isVisible).map(\.windowNumber)
        var arguments: [String] = []
        let handler = URLAppleEventHandler(service: URLCommandService(enabled: { true }, waitForStartup: {}, execute: { words in
            arguments = words
            received.fulfill()
            return ServerAnswer(exitCode: 0, serverVersionAndHash: "test")
        }))
        handler.register()
        defer { NSAppleEventManager.shared().removeEventHandler(forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL)) }
        let event = NSAppleEventDescriptor(eventClass: AEEventClass(kInternetEventClass), eventID: AEEventID(kAEGetURL),
            targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(NSAppleEventDescriptor(string: "winmux://run/workspace/2"), forKeyword: keyDirectObject)
        var reply = AppleEvent()
        defer { AEDisposeDesc(&reply) }
        let descriptor = try XCTUnwrap(event.aeDesc)
        let status = withUnsafeMutablePointer(to: &reply) { reply in
            NSAppleEventManager.shared().dispatchRawAppleEvent(descriptor, withRawReply: reply, handlerRefCon: UnsafeMutableRawPointer(reply))
        }
        XCTAssertEqual(status, OSErr(noErr))
        await fulfillment(of: [received], timeout: 5)
        XCTAssertEqual(arguments, ["workspace", "2"])
        XCTAssertEqual(NSApplication.shared.windows.filter(\.isVisible).map(\.windowNumber), visibleWindows)
    }

    func testURLSettingDefaultsAndRejectsWrongType() {
        XCTAssertTrue(defaultConfig.urlScheme)
        let off = parseConfig(.object(["url-scheme": .bool(false)]))
        XCTAssertTrue(off.errors.isEmpty)
        XCTAssertFalse(off.config.urlScheme)
        XCTAssertFalse(parseConfig(.object(["url-scheme": .string("false")])).errors.isEmpty)
    }

    func testQueueSerializesArrivalsAcrossSuspensionAndWaitsForStartup() async {
        let signal = URLStartupSignal()
        let entered = expectation(description: "first arrived")
        var events: [String] = []
        var waits = 0
        let service = URLCommandService(enabled: { true }, waitForStartup: {
            waits += 1
            if waits == 1 { entered.fulfill() }
            await signal.wait()
        }, execute: { args in
            events.append("execute \(args[1])")
            return ServerAnswer(exitCode: 0, serverVersionAndHash: "test")
        })
        let queue = URLCommandQueue { url in
            events.append("start \(url)")
            _ = await service.handle("winmux://run/workspace/\(url)")
            events.append("end \(url)")
        }
        queue.enqueue("first")
        queue.enqueue("second")
        await fulfillment(of: [entered])
        XCTAssertEqual(events, ["start first"])
        signal.set(.ready)
        await queue.finish()
        XCTAssertEqual(events, ["start first", "execute first", "end first", "start second", "execute second", "end second"])
        await signal.wait() // readiness latches for later arrivals
    }

    func testSetupWaitingReleasesStartupWaitWithoutWaitingForThePerson() async {
        let signal = URLStartupSignal()
        signal.set(.waitingForPerson)
        await signal.wait()
        let setup = FirstRunSetup(readGrants: { PermissionGrants(accessibility: false, screenRecording: false) })
        setup.waiting = true
        let answer = await executeExternalCommand(["workspace", "2"], stdin: "", windowId: nil, workspace: nil,
            traceOrigin: .internalNow(), gate: urlCommandRefusal, setup: setup)
        XCTAssertEqual(answer.stderr, setup.refusal)
    }

    func testURLSegmentsAreWordsWithoutShellSplitting() throws {
        for (input, expected) in [
            ("winmux://run/workspace/2", ["workspace", "2"]),
            ("WINMUX://RUN/lens/overview", ["lens", "overview"]),
            ("winmux://run/mode/window", ["mode", "window"]),
            ("winmux://run/move-node-to-workspace/My%20Desk", ["move-node-to-workspace", "My Desk"]),
            ("winmux://run/workspace/a%2Fb", ["workspace", "a/b"]),
            ("winmux://run/workspace/a+b%252Fc", ["workspace", "a+b%2Fc"]),
            ("winmux://run/workspace/%E2%98%83", ["workspace", "☃"]),
        ] {
            XCTAssertEqual(try parseCommandURL(XCTUnwrap(URL(string: input))).get(), expected, input)
        }
    }

    func testEveryMalformedComponentIsRefused() throws {
        for input in ["https://run/workspace/2", "winmux://nope/workspace/2", "winmux://user@run/workspace/2",
                      "winmux://user:password@run/workspace/2", "winmux://run:80/workspace/2",
                      "winmux://run/workspace/2?", "winmux://run/workspace/2#", "winmux://run", "winmux://run/",
                      "winmux://run//workspace", "winmux://run/workspace/2/", "winmux://run/workspace/%FF"] {
            XCTAssertThrowsError(try parseCommandURL(XCTUnwrap(URL(string: input))).get(), input)
        }
    }

    func testEveryKindHasAnExplicitURLPolicy() {
        let refused: Set<CmdKind> = [.subscribe, .listWindows, .listMarks, .mark, .listWorkspaces, .listApps, .listMonitors,
                                    .listModes, .listExecEnvVars, .listLenses, .listColumns, .debugWindows,
                                    .debugLensTrace, .debugHooks, .doctor, .config, .agent, .place, .execAndForget]
        for kind in CmdKind.allCases {
            XCTAssertEqual(urlCommandRefusal(kind: kind, args: nil) != nil, refused.contains(kind), kind.rawValue)
        }
    }

    func testParsedVariantsRefuseOnlyTheirInputOrOutputForms() throws {
        for words in [["place", "--dry-run", "--window-id", "42"], ["place", "--dry-run", "--json", "--window-id", "42"],
                      ["workspace", "next", "--stdin"], ["move-node-to-workspace", "next", "--stdin"],
                      ["lens", "--filter", "-"], ["agent", "skill"], ["config", "status"], ["reload-config", "--dry-run"]] {
            let command = try XCTUnwrap(parseCommand(words).cmdOrNil, words.description)
            XCTAssertNotNil(urlCommandRefusal(command), words.description)
        }
        for words in [["column-count", "3"], ["workspace", "2"], ["workspace", "next", "--no-stdin"],
                      ["lens", "overview"], ["lens", "--filter", "all"], ["mode", "window"], ["reload-config"], ["enable", "on"]] {
            let command = try XCTUnwrap(parseCommand(words).cmdOrNil, words.description)
            XCTAssertNil(urlCommandRefusal(command), words.description)
        }
    }
    func testLensRunUsesTheWrappedCommandsURLGateIncludingBindings() throws {
        let parsed = parseConfig("""
        [mode.main.binding]
        alt-x = 'exec-and-forget true'
        alt-h = 'focus left'
        alt-t = 'lens run trigger-binding --mode main alt-h'
        """)
        XCTAssertTrue(parsed.errors.isEmpty)
        config = parsed.config
        for raw in ["lens run exec-and-forget true", "lens run list-windows --all", "lens run workspace next --stdin",
                    "lens run trigger-binding --mode main alt-x", "trigger-binding --mode main alt-t",
                    "lens run lens run list-modes --current"] {
            let command = try XCTUnwrap(parseCommand(raw).cmdOrNil)
            XCTAssertNotNil(urlCommandRefusal(command), raw)
        }
        for raw in ["lens run move-node-to-workspace 2", "lens focus", "lens step next", "lens run trigger-binding --mode main alt-h"] {
            let command = try XCTUnwrap(parseCommand(raw).cmdOrNil)
            XCTAssertNil(urlCommandRefusal(command), raw)
        }
    }

    func testURLRefusalsAndHelpNeverExecute() async {
        let previous = mayArrangeWindows
        mayArrangeWindows = true
        defer { mayArrangeWindows = previous }
        var runs = 0
        let service = URLCommandService(enabled: { true }, waitForStartup: {}, execute: { arguments in
            await executeExternalCommand(arguments, stdin: "", windowId: nil, workspace: nil,
                traceOrigin: .internalNow(), gate: urlCommandRefusal, refuseHelp: true, didRun: { answer in runs += 1; return answer })
        })
        for (input, reason) in [("winmux://run/list-windows/--all", "list-windows is refused in a URL"),
                                ("winmux://run/workspace/next/--stdin", "workspace --stdin is refused in a URL"),
                                ("winmux://run/reload-config/--dry-run", "reload-config --dry-run is refused in a URL"),
                                ("winmux://run/workspace/--help", "help is refused in a URL"),
                                ("winmux://run/mode/-h", "help is refused in a URL"),
                                ("winmux://nope/workspace/2", "Expected run host"),
                                ("winmux://run/no-such-command", "no-such-command")] {
            let result = await service.handle(input)
            XCTAssertNotEqual(result.exitCode, 0, input)
            XCTAssertTrue(result.stderr.contains(reason), "\(input): \(result.stderr)")
        }
        XCTAssertEqual(runs, 0)
    }

    func testSettingIsReadForEveryURLAndResultsArePreserved() async {
        var enabled = false
        var received: [[String]] = []
        let service = URLCommandService(enabled: { enabled }, waitForStartup: {}, execute: { args in
            received.append(args)
            return ServerAnswer(exitCode: 7, stdout: "output", stderr: "failure", serverVersionAndHash: "test")
        })
        let off = await service.handle("winmux://run/workspace/2")
        XCTAssertTrue(off.stderr.contains("url-scheme"))
        let malformedOff = await service.handle("winmux://nope/")
        XCTAssertTrue(malformedOff.stderr.contains("url-scheme"))
        enabled = true
        let on = await service.handle("winmux://run/workspace/2")
        XCTAssertEqual(on.exitCode, 7)
        XCTAssertEqual(on.stdout, "output")
        XCTAssertEqual(on.stderr, "failure")
        XCTAssertEqual(received, [["workspace", "2"]])
    }

    func testURLDisabledServerGuardAlsoPrecedesParseFailuresAndHelp() async {
        let previous = TrayMenuModel.shared.isEnabled
        TrayMenuModel.shared.isEnabled = false
        defer { TrayMenuModel.shared.isEnabled = previous }
        let service = URLCommandService(enabled: { true }, waitForStartup: {}, execute: { arguments in
            await executeExternalCommand(arguments, stdin: "", windowId: nil, workspace: nil,
                traceOrigin: .internalNow(), gate: urlCommandRefusal, refuseHelp: true)
        })
        for path in ["workspace/2", "no-such-command", "workspace/--help"] {
            let result = await service.handle("winmux://run/\(path)")
            XCTAssertEqual(result.exitCode, 1)
            XCTAssertTrue(result.stderr.contains("server is disabled"), result.stderr)
        }
    }

    func testGatePrecedesFirstRunAndExecRefusals() async {
        var gated = false
        let setup = FirstRunSetup(readGrants: { PermissionGrants(accessibility: false, screenRecording: false) })
        setup.waiting = true
        let result = await executeExternalCommand(["workspace", "2"], stdin: "", windowId: nil, workspace: nil,
            traceOrigin: .internalNow(), gate: { _ in gated = true; return "gate refusal" }, setup: setup)
        XCTAssertTrue(gated)
        XCTAssertEqual(result.stderr, "gate refusal")
    }

    func testTriggerBindingIsRefusedWhenItsBindingRunsWhatAURLMayNot() throws {
        let (parsed, errors) = parseConfig("""
        [mode.main.binding]
        alt-enter = 'exec-and-forget open -a Ghostty'
        alt-t = 'trigger-binding --mode main alt-2'
        alt-2 = 'workspace 2'
        esc-x = ['exec-and-forget true']
        """)
        XCTAssertTrue(errors.isEmpty, "\(errors)")
        config = parsed
        for chord in ["alt-enter", "alt-t", "esc-x"] {
            let command = try XCTUnwrap(parseCommand(["trigger-binding", "--mode", "main", chord]).cmdOrNil, chord)
            XCTAssertNotNil(urlCommandRefusal(command), chord)
        }
        let exec = try XCTUnwrap(parseCommand(["trigger-binding", "--mode", "main", "alt-enter"]).cmdOrNil)
        XCTAssertEqual(urlCommandRefusal(exec),
                       "trigger-binding alt-enter is refused in a URL: its binding runs exec-and-forget (it runs a shell command)")
        for chord in ["alt-2", "alt-missing"] {
            let command = try XCTUnwrap(parseCommand(["trigger-binding", "--mode", "main", chord]).cmdOrNil, chord)
            XCTAssertNil(urlCommandRefusal(command), chord)
        }
    }

    func testFirstRunSetupReleasesWaitingURLsWhileItWaitsAndHoldsThemAgainAfterGo() async throws {
        let signal = URLStartupSignal()
        let shown = expectation(description: "setup shown")
        let file = FileManager.default.temporaryDirectory.appending(path: "url-setup-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        var grants = PermissionGrants(accessibility: false, screenRecording: false)
        let setup = FirstRunSetup(readGrants: { grants }, stateUrl: file, present: { _ in shown.fulfill() }, startupSignal: signal)
        let run = Task { await setup.run() }
        await fulfillment(of: [shown], timeout: 1)
        XCTAssertEqual(signal.state, .waitingForPerson)
        grants = PermissionGrants(accessibility: true, screenRecording: true)
        setup.go()
        XCTAssertEqual(signal.state, .starting)
        let finished = expectation(description: "setup run finished")
        Task { await run.value; finished.fulfill() }
        await fulfillment(of: [finished], timeout: 1)
    }

    func testTriggerBindingRechecksTheBindingItRunsWhenTheRunnerHasAGate() async throws {
        let previous = mayArrangeWindows
        mayArrangeWindows = true
        defer { mayArrangeWindows = previous }
        let (parsed, errors) = parseConfig("""
        [mode.main.binding]
        alt-t = 'reload-config --dry-run'
        """)
        XCTAssertTrue(errors.isEmpty, "\(errors)")
        config = parsed
        let arguments = ["trigger-binding", "--mode", "main", "alt-t"]
        // A gate that lets everything through stands in for a config reload between the gate and the run:
        // the binding is checked again as it runs.
        let gated = await executeExternalCommand(arguments, stdin: "", windowId: nil, workspace: nil,
            traceOrigin: .internalNow(), gate: { _ in nil })
        XCTAssertEqual(gated.exitCode, 1)
        XCTAssertTrue(gated.stderr.contains("reload-config --dry-run"), gated.stderr)
        let socket = await executeExternalCommand(arguments, stdin: "", windowId: nil, workspace: nil, traceOrigin: .internalNow())
        XCTAssertFalse(socket.stderr.contains("refused in a URL"), socket.stderr)
    }
}
