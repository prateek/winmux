@testable import AppBundle
import Common
import XCTest

@MainActor
final class ExternalCommandTest: XCTestCase {
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
        let result = await answer(["enable", "on"])
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

    func testSocketExecAndForgetRefusalAfterSetup() async {
        let previous = mayArrangeWindows
        mayArrangeWindows = true
        defer { mayArrangeWindows = previous }
        let result = await answer(["exec-and-forget", "echo forbidden"])
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertEqual(result.stderr, "exec-and-forget is prohibited in CLI")
    }
}
