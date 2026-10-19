@testable import AppBundle
import Common
import XCTest

@MainActor
final class HookCaptureTest: XCTestCase {
    private var directory: URL!
    private var store: HookCaptureStore!
    private var now = Date(timeIntervalSince1970: 1_700_000_000)
    private var events: [ServerEvent] = []
    private var previous: HookCaptureStore!
    private var clockReads = 0

    override func setUp() async throws {
        setUpWorkspacesForTests()
        now = Date(timeIntervalSince1970: 1_700_000_000)
        events = []
        clockReads = 0
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        store = HookCaptureStore(path: directory.appending(path: "nested/hook-capture.jsonl"), now: { self.clockReads += 1; return self.now }, emit: { self.events.append($0) })
        previous = HookCaptureStore.shared
        HookCaptureStore.shared = store
    }

    override func tearDown() async throws {
        HookCaptureStore.shared = previous
        try? FileManager.default.removeItem(at: directory)
        store = nil
        previous = nil
    }

    private func records() throws -> [JSONValue] {
        let text = try String(contentsOf: store.path, encoding: .utf8)
        return try text.split(separator: "\n").map { try JSONDecoder().decode(JSONValue.self, from: Data($0.utf8)) }
    }

    private func call(_ path: String?, answer: Result<JSONValue, NickelFailure> = .success(.object([:])), edge: Bool? = nil) async -> (JSONValue?, ControlledPolicyHooks) {
        let ws = Workspace.get(byName: "Capture")
        ws.columns = ColumnState(count: 3)
        ws.enforceColumnInvariant()
        let window = TestWindow.new(id: 42, parent: ws)
        let helper = ControlledPolicyHooks()
        if let path { helper.answers[path] = answer }
        let result = await PolicyHookCompletion.call(path, window: window, workspace: ws, edge: edge, supervisor: helper, initialClass: .tiled)
        window.unbindFromParent()
        return (result, helper)
    }

    func testOffPreservesArrivePlaceBoundaryAndPreviewCallsWithoutCreatingFile() async throws {
        for (path, edge, answer): (String, Bool?, JSONValue) in [
            ("arrive", nil, .object([:])),
            ("columns.place", nil, .object(["column": .int(2), "overflow": .string("tab-group")])),
            ("workspace.3.columns.place", nil, .object(["column": .int(2), "overflow": .string("tab-group")])),
            ("columns.move-boundary", true, .object(["action": .string("stop")])),
        ] {
            let (result, helper) = await call(path, answer: .success(answer), edge: edge)
            XCTAssertEqual(result, answer, path)
            XCTAssertEqual(helper.calls.count, 1, path)
            XCTAssertEqual(helper.calls[0].args.count, edge == nil ? 3 : 4)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.path.path))
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(clockReads, 0, "Capture off must not read the capture clock")
    }

    func testCapturesExactHelperRequestAnswerAndEventForEveryHook() async throws {
        try store.start()
        for (path, edge, answer): (String, Bool?, JSONValue) in [
            ("arrive", nil, .object([:])),
            ("workspace.3.columns.place", nil, .object(["column": .int(2), "overflow": .string("tab-group")])),
            ("columns.move-boundary", false, .object(["action": .string("stop")])),
        ] {
            let (_, helper) = await call(path, answer: .success(answer), edge: edge)
            let record = try XCTUnwrap(records().last)
            XCTAssertEqual(record["hook"], .string(path))
            XCTAssertEqual(record["kind"], .string(String(path.split(separator: ".").last!)))
            XCTAssertEqual(record["window-id"], .int(42))
            XCTAssertEqual(record["args"], .array(helper.calls[0].args))
            XCTAssertEqual(record["result"], answer)
            XCTAssertEqual(record["error"], .null)
            XCTAssertEqual(record["time"], .string("2023-11-14T22:13:20.000Z"))
            XCTAssertNotNil(record["arguments-ms"])
            XCTAssertNotNil(record["duration-ms"])
            let eventData = try JSONEncoder().encode(XCTUnwrap(events.last))
            let event = try JSONDecoder().decode(JSONValue.self, from: eventData)
            XCTAssertEqual(event["_event"], .string("hook-called"))
            for key in ["time", "hook", "kind", "window-id", "args", "result", "error", "arguments-ms", "duration-ms"] {
                XCTAssertEqual(event[key], record[key], key)
            }
        }
        XCTAssertEqual(store.status().records, 3)
    }

    func testFailureAndRejectedAnswerKeepTheHelpersErrorAndRawResult() async throws {
        try store.start()
        for answer: Result<JSONValue, NickelFailure> in [
            .failure(.unavailable("helper unavailable")), .failure(.timedOut),
            .failure(.diagnostic("raised Nickel error")), .success(.string("invalid")),
        ] {
            let (result, helper) = await call("columns.place", answer: answer)
            XCTAssertNil(result)
            let record = try XCTUnwrap(records().last)
            XCTAssertEqual(record["error"], helper.failures.last.map(JSONValue.string))
            switch answer {
                case .success(let raw): XCTAssertEqual(record["result"], raw)
                case .failure: XCTAssertEqual(record["result"], .null)
            }
        }
    }

    func testArgumentFailureIsCapturedButMissingWindowAndCancellationAndNilPathAreSilent() async throws {
        try store.start()
        let ws = Workspace.get(byName: "Capture")
        let window = TestWindow.new(id: 43, parent: ws)
        let helper = ControlledPolicyHooks()
        window.testAxRecordError = NSError(domain: "capture", code: 7)
        _ = await PolicyHookCompletion.call("arrive", window: window, workspace: ws, supervisor: helper)
        XCTAssertEqual(try records().count, 1)
        let record = try XCTUnwrap(records().first)
        XCTAssertEqual(record["args"], .null)
        XCTAssertEqual(record["error"], helper.failures.last.map(JSONValue.string))
        window.testAxRecordError = CancellationError()
        _ = await PolicyHookCompletion.call("arrive", window: window, workspace: ws, supervisor: helper)
        window.testAxRecordError = nil
        window.testAxElementIsGone = true
        _ = await PolicyHookCompletion.call("arrive", window: window, workspace: ws, supervisor: helper)
        _ = await call(nil)
        XCTAssertEqual(try records().count, 1)
        XCTAssertTrue(helper.calls.isEmpty)
    }

    func testRestartExtendsDeadlineWithoutTruncatingAndOffThenOnTruncates() async throws {
        try store.start()
        _ = await call("arrive")
        now.addTimeInterval(800)
        try store.start()
        now.addTimeInterval(101)
        _ = await call("arrive")
        XCTAssertEqual(try records().count, 2)
        store.stop()
        _ = await call("arrive")
        XCTAssertEqual(try records().count, 2)
        XCTAssertFalse(store.status().capturing)
        try store.start()
        XCTAssertEqual(try records().count, 0)
        XCTAssertEqual(store.status().records, 0)
    }

    func testDeadlineCheckedOnWriteAndStatusWithoutTimer() async throws {
        try store.start()
        now.addTimeInterval(900)
        _ = await call("arrive")
        XCTAssertEqual(try records().count, 0)
        XCTAssertFalse(store.status().capturing)
        XCTAssertEqual(store.status().until, .null)
        try store.start()
        now.addTimeInterval(900)
        XCTAssertFalse(store.status().capturing)
        XCTAssertTrue(events.isEmpty)
    }

    func testWriteFailureStopsCaptureAndDoesNotEmit() async throws {
        try store.start()
        try FileManager.default.removeItem(at: store.path)
        try FileManager.default.createDirectory(at: store.path, withIntermediateDirectories: true)
        _ = await call("arrive")
        XCTAssertFalse(store.status().capturing)
        XCTAssertNotEqual(store.status().error, .null)
        XCTAssertEqual(store.status().records, 0)
        XCTAssertTrue(events.isEmpty)
    }

    func testAcceptedOutOfRangeAnswerRecordsNoErrorBeforePlacementRejectsIt() async throws {
        try store.start()
        let ws = Workspace.get(byName: "Capture")
        ws.columns = ColumnState(count: 3)
        ws.enforceColumnInvariant()
        let window = TestWindow.new(id: 44, parent: ws)
        config.columns = ColumnsConfig(.object(["count": .int(3), "place": .string("columns.place")]), workspaces: nil)
        let helper = ControlledPolicyHooks()
        let answer: JSONValue = .object(["column": .int(7), "overflow": .string("tab-group")])
        helper.answers["columns.place"] = .success(answer)
        let decision = await ColumnPolicy.decision(window: window, workspace: ws, supervisor: helper)
        XCTAssertNotEqual(decision.slot, 7)
        XCTAssertTrue(helper.lastHookError?.contains("exceeds count") == true)
        let record = try XCTUnwrap(records().first)
        XCTAssertEqual(record["result"], answer)
        XCTAssertEqual(record["error"], .null)
    }

    func testDeadlineAndStopDuringHelperRoundTripDoNotLeakIntoNewCapture() async throws {
        for action in ["deadline", "restart", "off"] {
            try store.start()
            let gate = ReloadGate()
            let helper = ControlledPolicyHooks()
            helper.answers["arrive"] = .success(.object([:]))
            helper.gates["arrive"] = gate
            let ws = Workspace.get(byName: "Capture")
            let window = TestWindow.new(id: 45, parent: ws)
            let task = Task { await PolicyHookCompletion.call("arrive", window: window, workspace: ws, supervisor: helper) }
            await gate.entered.wait()
            if action == "deadline" { now.addTimeInterval(900) }
            else { store.stop() }
            if action == "restart" { try store.start() }
            gate.release()
            let answer = await task.value
            XCTAssertEqual(answer, .object([:]))
            XCTAssertEqual(try records().count, 0)
            store.stop()
            window.unbindFromParent()
        }
    }

    func testDisallowedRunErrorDoesNotRewriteAnAcceptedHookRecord() async throws {
        try store.start()
        let ws = Workspace.get(byName: "Capture")
        let window = TestWindow.new(id: 46, parent: ws)
        let helper = ControlledPolicyHooks()
        let answer: JSONValue = .object(["run": .array([.string("debug-hooks off")])])
        helper.answers["arrive"] = .success(answer)
        let result = await PolicyHookCompletion.call("arrive", window: window, workspace: ws, supervisor: helper)
        try await PolicyHookCompletion.run(PolicyHookCompletion.commands(result), window: window, path: "arrive", helper: helper)
        XCTAssertTrue(helper.lastHookError?.contains("command is not allowed") == true)
        let record = try XCTUnwrap(records().first)
        XCTAssertEqual(record["result"], answer)
        XCTAssertEqual(record["error"], .null)
        XCTAssertTrue(store.status().capturing)
        XCTAssertEqual(try records().count, 1)
    }

    func testCommandTextAndStartFailureStatus() async throws {
        for form in ["", " on", " off", " off"] {
            let result = try await parseCommand("debug-hooks\(form)").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(result.exitCode, 0)
            XCTAssertTrue(result.stdout.joined().contains(store.path.path))
            if form == " on" { XCTAssertTrue(result.stdout.joined().contains("Stops at")) }
        }
        try FileManager.default.removeItem(at: directory)
        try Data().write(to: directory)
        let result = try await parseCommand("debug-hooks on --json").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertFalse(store.status().capturing)
        XCTAssertNotEqual(store.status().error, .null)
        let json = try JSONDecoder().decode(JSONValue.self, from: Data(result.stdout.joined().utf8))
        XCTAssertEqual(json["capturing"], .bool(false))
        XCTAssertEqual(json["error"], store.status().error)
    }

    func testCommandFormsJSONAndConfigRefusal() async throws {
        for form in ["", " status", " on", " on", " off", " off"] {
            let command = parseCommand("debug-hooks\(form) --json").cmdOrDie
            XCTAssertFalse(command.info.allowInConfig)
            let result = try await command.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(result.exitCode, 0)
            let json = try JSONDecoder().decode(JSONValue.self, from: Data(result.stdout.joined(separator: "\n").utf8))
            XCTAssertEqual(json["path"], .string(store.path.path))
            XCTAssertEqual(json["capturing"], .bool(form == " on"))
            XCTAssertNotNil(json["until"])
            XCTAssertEqual(json["records"], .int(0))
            XCTAssertEqual(json["error"], .null)
        }
        XCTAssertNil(parseCmdArgs(["debug-hooks", "bad"].slice).cmdOrNil)
        XCTAssertTrue((parseCmdArgs(["subscribe", "--all"].slice).cmdOrNil as? SubscribeCmdArgs)?.events.contains(.hookCalled) == true)
    }

    func testOnWhileOnRecreatesARemovedFileAndKeepsItPrivate() async throws {
        try store.start()
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: store.path.path)[.posixPermissions] as? Int, 0o600)
        _ = await call("arrive")
        try FileManager.default.removeItem(at: store.path)
        try store.start()
        _ = await call("arrive")
        XCTAssertTrue(store.status().capturing)
        XCTAssertEqual(store.status().error, .null)
        XCTAssertEqual(try records().count, 1)
        XCTAssertEqual(store.status().records, 2)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: store.path.path)[.posixPermissions] as? Int, 0o600)
    }

    func testRecordLinesDoNotEscapeSlashes() async throws {
        try store.start()
        _ = await call("workspace.a/b.columns.place", answer: .success(.object(["column": .int(2), "overflow": .string("tab-group")])))
        let text = try String(contentsOf: store.path, encoding: .utf8)
        XCTAssertTrue(text.contains("\"workspace.a/b.columns.place\""), text)
    }

    func testOffAfterTheDeadlineSaysCaptureStoppedItself() async throws {
        _ = try await parseCommand("debug-hooks on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        now.addTimeInterval(901)
        let result = try await parseCommand("debug-hooks off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertTrue(result.stdout.joined().contains("stopped itself at"), result.stdout.joined())
        _ = try await parseCommand("debug-hooks on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        let again = try await parseCommand("debug-hooks off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertFalse(again.stdout.joined().contains("stopped itself"))
    }
}
