@testable import AppBundle
import Common
import XCTest

@MainActor
final class ExternalCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests(); TrayMenuModel.shared.isEnabled = true }

    func testSocketSuccessfulRunPreservesOutputAndAppliesCompletionOnlyAfterRun() async {
        let previous = mayArrangeWindows
        mayArrangeWindows = true
        defer { mayArrangeWindows = previous }
        var completions = 0
        let result = await executeExternalCommand(["mode", "main"], stdin: "", windowId: nil, workspace: nil,
            traceOrigin: .internalNow(), didRun: { answer in completions += 1; return answer })
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(activeMode, "main")
        XCTAssertEqual(completions, 1)
        let help = await executeExternalCommand(["mode", "--help"], stdin: "", windowId: nil, workspace: nil,
            traceOrigin: .internalNow(), didRun: { answer in completions += 1; return answer })
        XCTAssertEqual(help.exitCode, 0)
        XCTAssertEqual(completions, 1, "socket completion notes must not be appended to help or refusals")
    }

    private func answer(_ args: [String], setup: FirstRunSetup? = nil) async -> ServerAnswer {
        await executeExternalCommand(args, stdin: "", windowId: nil, workspace: nil,
                                     traceOrigin: LensTraceOrigin.internalNow(), setup: setup ?? FirstRunSetup.shared)
    }

    func testSocketHelpAndParseFailureBeforeSetup() async {
        let help = await answer(["workspace", "--help"])
        XCTAssertEqual(help.exitCode, 0)
        XCTAssertTrue(help.stdout.contains("workspace"))
        let failure = await answer(["sections", "bad"])
        XCTAssertEqual(failure.exitCode, 2)
        XCTAssertFalse(failure.stderr.isEmpty)
    }

    func testSocketDisabledGuardPrecedesHelpAndParseErrorsButAllowsEnable() async {
        let previous = TrayMenuModel.shared.isEnabled
        TrayMenuModel.shared.isEnabled = false
        defer { TrayMenuModel.shared.isEnabled = previous }
        for args in [["workspace", "--help"], ["no-such-command"], ["workspace", "2"]] {
            let result = await answer(args)
            XCTAssertEqual(result.exitCode, 1)
            XCTAssertTrue(result.stderr.contains("server is disabled"))
        }
        let setup = FirstRunSetup(readGrants: { PermissionGrants(accessibility: false, screenRecording: false) })
        setup.waiting = true
        let result = await answer(["enable", "on"], setup: setup)
        XCTAssertEqual(result.stderr, setup.refusal)
        XCTAssertFalse(result.stderr.contains("server is disabled"))
    }

    func testSocketSetupRefusalAndConfigQuery() async {
        let setup = FirstRunSetup(readGrants: { PermissionGrants(accessibility: false, screenRecording: false) })
        setup.waiting = true
        let refusal = await answer(["workspace", "2"], setup: setup)
        XCTAssertEqual(refusal.stderr, setup.refusal)
        let query = await answer(["config", "status"], setup: setup)
        XCTAssertEqual(query.exitCode, 0)
        XCTAssertTrue(query.stdout.contains("permissions"))
    }

    func testSocketExecAndForgetIsAParseFailureAfterSetup() async {
        let previous = mayArrangeWindows
        mayArrangeWindows = true
        defer { mayArrangeWindows = previous }
        let args = ["exec-and-forget", "echo forbidden"]
        let result = await answer(args)
        XCTAssertEqual(result.exitCode, parseFailureExitCode(args.slice))
        XCTAssertEqual(result.stderr, parseCommand(args).unwrap().2)
        XCTAssertNotNil(parseCommand(args).unwrap().2)
    }
}
