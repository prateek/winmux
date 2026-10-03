@testable import AppBundle
import Common
import XCTest

/// Exercises the supervisor against a stand-in helper: a script that speaks the helper's
/// protocol and misbehaves on request. The Lens name in a Filter request picks the misbehaviour.
@MainActor
final class NickelSupervisorTest: XCTestCase {
    private var stubUrl: URL!
    private var opened: [String] = []

    override func setUp() async throws {
        stubUrl = FileManager.default.temporaryDirectory.appending(path: "winmux-stub-helper-\(UUID().uuidString)")
        try stubHelperScript.write(to: stubUrl, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stubUrl.path)
        opened = []
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: stubUrl)
    }

    private func supervisor(_ adjust: (inout NickelSupervisor.Settings) -> Void = { _ in }) -> NickelSupervisor {
        var settings = NickelSupervisor.Settings()
        let stubUrl: URL = stubUrl
        settings.executable = { stubUrl }
        // The stub is a Python script, and a cold interpreter start on a CI runner can take seconds.
        settings.loadTimeout = .seconds(20)
        settings.firstRestartDelay = .milliseconds(400)
        adjust(&settings)
        let supervisor = NickelSupervisor(settings: settings)
        supervisor.onBreakerOpened = { [weak self] in self?.opened.append($0) }
        return supervisor
    }

    private func loadAndAdopt(_ supervisor: NickelSupervisor, _ path: String = "/config/good.ncl") async throws {
        supervisor.adopt(try await supervisor.load(URL(filePath: path)).get())
    }

    private func matches(_ supervisor: NickelSupervisor, lens: String = "all") async -> Result<[Bool], NickelFailure> {
        await supervisor.filter(lens: lens, context: .object([:]), windows: [.object([:]), .object([:])])
    }

    private func eventually(_ what: String, _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(30)
        while !condition() {
            if ContinuousClock.now > deadline { return XCTFail("Timed out waiting until \(what)") }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func testLoadReturnsTheSettingsAndTheFilesRead() async throws {
        let supervisor = supervisor()

        let loaded = try await supervisor.load(URL(filePath: "/config/good.ncl")).get()

        assertEquals(loaded.settings, .object(["gaps": .object(["inner": .object(["horizontal": .int(4)])])]))
        assertEquals(loaded.imports.map(\.path), ["/config/good.ncl"])
        assertEquals(supervisor.status.state, .failed) // Nothing serves requests until a load is adopted
        supervisor.adopt(loaded)
        assertEquals(supervisor.status.state, .ready)
        assertEquals(supervisor.status.pid, loaded.process.pid)
        assertEquals(supervisor.status.configPath, "/config/good.ncl")
        assertEquals(supervisor.status.recycles, 0)
    }

    func testRequestsAreAnsweredByTheAdoptedHelper() async throws {
        let supervisor = supervisor()
        try await loadAndAdopt(supervisor)

        let bits = await matches(supervisor)
        let hook = await supervisor.hook("arrive", args: [.string("w")])

        assertEquals(bits, .success([true, true]))
        assertEquals(hook, .success(.object(["hook": .string("arrive"), "args": .int(1)])))
        XCTAssertGreaterThan(supervisor.status.rss, 0)
    }

    func testConfigThatFailsToLoadLeavesTheOldHelperServing() async throws {
        let supervisor = supervisor()
        try await loadAndAdopt(supervisor)
        let pid = supervisor.status.pid

        let broken = await supervisor.load(URL(filePath: "/config/broken.ncl"))

        guard case .failure(.diagnostic(let diagnostic)) = broken else { return XCTFail("\(broken)") }
        assertEquals(diagnostic, "error: contract broken by a value")
        assertEquals(supervisor.status.pid, pid)
        assertEquals(supervisor.status.lastError, nil)
        assertEquals(await matches(supervisor), .success([true, true]))
    }

    func testFailedFirstLoadIsTheStatusLastError() async throws {
        let supervisor = supervisor()

        _ = await supervisor.load(URL(filePath: "/config/broken.ncl"))

        assertEquals(supervisor.status.state, .failed)
        assertEquals(supervisor.status.lastError, "error: contract broken by a value")
    }

    func testReloadSwapsInANewHelperAndCountsARecycle() async throws {
        let supervisor = supervisor()
        try await loadAndAdopt(supervisor)
        let firstPid = supervisor.status.pid

        try await loadAndAdopt(supervisor)

        XCTAssertNotEqual(supervisor.status.pid, firstPid)
        assertEquals(supervisor.status.recycles, 1)
        assertEquals(await matches(supervisor), .success([true, true]))
    }

    func testMissingHelperIsAFailureNotACrash() async throws {
        let supervisor = supervisor { $0.executable = { nil } }

        let result = await supervisor.load(nil)

        guard case .failure(.unavailable) = result else { return XCTFail("\(result)") }
        assertEquals(await matches(supervisor), .failure(.unavailable("The config helper is not running")))
    }

    func testLoadThatDoesNotAnswerInTimeFails() async throws {
        let supervisor = supervisor { $0.loadTimeout = .milliseconds(300) }
        let start = ContinuousClock.now

        let result = await supervisor.load(URL(filePath: "/config/slow.ncl"))

        guard case .failure(.timedOut) = result else { return XCTFail("\(result)") }
        XCTAssertLessThan(ContinuousClock.now - start, .seconds(2))
    }

    func testFilterThatLoopsFailsAfterTheTimeoutAndTheNextRequestSucceeds() async throws {
        let supervisor = supervisor()
        try await loadAndAdopt(supervisor)
        let hungPid = try XCTUnwrap(supervisor.status.pid)
        let start = ContinuousClock.now

        let hung = await matches(supervisor, lens: "hang")
        let elapsed = ContinuousClock.now - start
        let next = await matches(supervisor)

        assertEquals(hung, .failure(.timedOut))
        XCTAssertGreaterThanOrEqual(elapsed, .milliseconds(100))
        XCTAssertLessThan(elapsed, .milliseconds(600))
        assertEquals(next, .success([true, true]))
        XCTAssertNotEqual(supervisor.status.pid, hungPid)
        try await eventually("the hung helper is gone") { kill(hungPid, 0) != 0 }
        assertEquals(opened, [])
    }

    func testHookThatDoesNotAnswerFailsAfterItsTimeout() async throws {
        let supervisor = supervisor()
        try await loadAndAdopt(supervisor)
        let start = ContinuousClock.now

        let result = await supervisor.hook("hang", args: [])

        assertEquals(result, .failure(.timedOut))
        XCTAssertLessThan(ContinuousClock.now - start, .milliseconds(500))
    }

    func testKilledHelperRestartsAtOnceAndTheSecondKillWaits() async throws {
        let supervisor = supervisor { $0.firstRestartDelay = .seconds(3) }
        try await loadAndAdopt(supervisor)
        let firstPid = try XCTUnwrap(supervisor.status.pid)

        // The first restart is immediate, so the new helper may be ready by the time the old one is
        // seen to be gone. Only the time from the kill to a ready helper is checked.
        let killed = ContinuousClock.now
        kill(firstPid, SIGKILL)
        try await eventually("a new helper is ready") { supervisor.status.pid != firstPid && supervisor.status.state == .ready }
        XCTAssertLessThan(ContinuousClock.now - killed, .milliseconds(2500), "the first restart does not wait")
        let secondPid = try XCTUnwrap(supervisor.status.pid)
        assertEquals(supervisor.status.recycles, 1)

        kill(secondPid, SIGKILL)
        try await eventually("the second helper is seen to be gone") { supervisor.status.pid != secondPid }
        let killedAgain = ContinuousClock.now
        assertEquals(supervisor.status.state, .restarting)
        try await eventually("a third helper is ready") { supervisor.status.state == .ready }
        XCTAssertGreaterThanOrEqual(ContinuousClock.now - killedAgain, .milliseconds(2900), "the second restart waits")
        assertEquals(await matches(supervisor), .success([true, true]))
    }

    func testThreeKillsWithinAMinuteOpenTheBreakerAndAReloadClosesIt() async throws {
        let supervisor = supervisor { $0.firstRestartDelay = .milliseconds(20) }
        try await loadAndAdopt(supervisor)

        for round in 1 ... 3 {
            let pid = try XCTUnwrap(supervisor.status.pid)
            kill(pid, SIGKILL)
            try await eventually("kill \(round) is seen") { supervisor.status.pid != pid }
            if round < 3 {
                try await eventually("helper \(round + 1) is ready") { supervisor.status.state == .ready }
            }
        }

        assertEquals(supervisor.status.state, .failed)
        assertEquals(opened.count, 1)
        let refused = await matches(supervisor)
        guard case .failure(.unavailable) = refused else { return XCTFail("\(refused)") }
        XCTAssertNotNil(supervisor.status.lastError)

        try await loadAndAdopt(supervisor)

        assertEquals(supervisor.status.state, .ready)
        assertEquals(supervisor.status.lastError, nil)
        assertEquals(await matches(supervisor), .success([true, true]))
    }

    func testStatusShowsTheNewerOfAFailedReloadAndACrash() async throws {
        let supervisor = supervisor()
        try await loadAndAdopt(supervisor)

        supervisor.recordFailedReload("extra field `gapz`")
        let afterTheReload = supervisor.status
        let pid = try XCTUnwrap(supervisor.status.pid)
        kill(pid, SIGKILL)
        try await eventually("the crash is seen") { supervisor.status.pid != pid }
        let afterTheCrash = supervisor.status.lastError
        try await loadAndAdopt(supervisor)

        assertEquals(afterTheReload.state, .ready, additionalMsg: "the old helper keeps serving")
        assertEquals(afterTheReload.lastError, "extra field `gapz`")
        assertEquals(afterTheCrash, "The config helper exited unexpectedly")
        assertEquals(supervisor.status.lastError, nil)
    }

    func testHelperOverTheMemoryLimitIsReplacedWithoutFailingARequest() async throws {
        let supervisor = supervisor { $0.rssLimit = 1_000_000 }
        try await loadAndAdopt(supervisor)
        let fatPid = supervisor.status.pid

        let overLimit = await matches(supervisor, lens: "fat")
        try await eventually("the helper is replaced") { supervisor.status.pid != fatPid && supervisor.status.state == .ready }
        let next = await matches(supervisor)

        assertEquals(overLimit, .success([true, true]))
        assertEquals(next, .success([true, true]))
        assertEquals(supervisor.status.recycles, 1)
        assertEquals(opened, [])
    }
}

private let stubHelperScript = """
    #!/usr/bin/env python3
    import json, os, sys, time

    for line in sys.stdin:
        request = json.loads(line)
        op, rss, result, error = request["op"], 500_000, None, None
        if op == "load":
            path = request["path"] or ""
            if path.endswith("slow.ncl"):
                time.sleep(30)
            if path.endswith("broken.ncl"):
                error = "error: contract broken by a value"
            else:
                result = {"config": {"gaps": {"inner": {"horizontal": 4}}}, "imports": [path]}
        elif op == "filter":
            if request["lens"] == "hang":
                time.sleep(30)
            if request["lens"] == "fat":
                rss = 2_000_000
            result = [True for _ in request["windows"]]
        elif op == "hook":
            if request["hook"] == "hang":
                time.sleep(30)
            result = {"hook": request["hook"], "args": len(request["args"])}
        reply = {"id": request["id"], "ok": error is None, "rss": rss}
        reply.update({"result": result} if error is None else {"error": error})
        print(json.dumps(reply), flush=True)
    """
