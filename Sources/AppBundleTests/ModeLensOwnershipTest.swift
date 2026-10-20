@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor final class ModeLensOwnershipTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testUnownedLensClosePreservesHeldRelease() async throws {
        for ending in ["dismiss", "toggle", "cancel"] {
            let engine = ModeEngine(liveModifiers: { .command })
            let lens = testLensLifecycle(modeEngine: engine)
            var mode = Mode.zero; mode.lifetime = .held; mode.onRelease = ["focus left"]
            var releases = 0
            engine.execute = { _ in releases += 1 }
            engine.replace("held-pass", mode: mode, invocation: .init(keyCode: 48, invoking: .command))
            let ticket = try XCTUnwrap(lens.begin("windows", toggle: false))
            switch ending {
                case "cancel": lens.cancelOpening(ticket: ticket)
                case "toggle": XCTAssertNil(lens.begin("windows", toggle: true))
                default: lens.dismiss()
            }
            await engine.waitForInput()
            XCTAssertEqual(engine.current, "held-pass")
            XCTAssertEqual(engine.entryModifiers, .command)
            await engine.observeModifiers([])
            XCTAssertEqual(releases, 1)
            XCTAssertEqual(engine.current, mainModeId)
        }
    }

    func testOpenLensIsAdoptedOnlyByAModeThatNeedsIt() async throws {
        for policy in [Mode.Unbound.pass, .consume, .type, .latch] {
            let engine = ModeEngine(liveModifiers: { [] })
            engine.execute = { _ in }
            let lens = testLensLifecycle(modeEngine: engine)
            _ = lens.begin("windows", toggle: false)
            var mode = Mode.zero; mode.unbound = policy
            try await engine.enter("adopter", mode: mode)
            lens.dismiss()
            await engine.waitForInput()
            XCTAssertEqual(engine.current, policy == .pass ? "adopter" : mainModeId)
        }
    }

    func testCancelledOwnedOpeningDoesNotEndModeEnteredByParkedKey() async throws {
        let engine = ModeEngine(liveModifiers: { [] })
        let lens = testLensLifecycle(modeEngine: engine)
        var opener = Mode.zero; opener.onEnter = ["lens recent"]
        var leader = Mode.zero; leader.unbound = .consume; leader.lifetime = .transient
        engine.execute = { _ in
            let ticket = try XCTUnwrap(lens.begin("recent", toggle: false))
            engine.whenLensReady { try? await engine.enter("leader", mode: leader) }
            lens.cancelOpening(ticket: ticket)
        }
        try await engine.enter("opener", mode: opener)
        await engine.waitForInput()
        XCTAssertEqual(engine.current, "leader")
    }

    func testParkedCmdTabReadsLiveModifiersAfterFailedOpening() async throws {
        let engine = ModeEngine(liveModifiers: { .command })
        let lens = testLensLifecycle(modeEngine: engine)
        var held = Mode.zero; held.lifetime = .held; held.onEnter = ["lens recent"]; held.onRelease = ["focus left"]
        var commits = 0
        engine.execute = { commands in
            if commands.first?.args.description == "lens recent" {
                _ = lens.begin("recent", toggle: false)
                engine.presentLens(show: {}, flags: .command)
            } else { commits += 1 }
        }
        let ticket = try XCTUnwrap(lens.begin("failed", toggle: false))
        engine.whenLensReady { try? await engine.enter("cmd-tab", mode: held, invocation: .init(keyCode: 48, invoking: .command)) }
        lens.cancelOpening(ticket: ticket)
        await engine.waitForInput()
        XCTAssertEqual(engine.current, "cmd-tab")
        XCTAssertEqual(engine.entryModifiers, .command)
        XCTAssertEqual(commits, 0)
        await engine.observeModifiers([])
        XCTAssertEqual(commits, 1)
    }

    func testCancelledDrainDoesNotConsumeANewerOpeningBeforeBeginLens() async throws {
        let engine = ModeEngine(liveModifiers: { .command })
        let lens = testLensLifecycle(modeEngine: engine)
        let blocked = expectation(description: "input blocked")
        var resumeInput: CheckedContinuation<Void, Never>?
        engine.enqueueInput { blocked.fulfill(); await withCheckedContinuation { resumeInput = $0 } }
        await fulfillment(of: [blocked], timeout: 2)
        let ticket = try XCTUnwrap(lens.begin("failed", toggle: false))
        var seen: [String] = []
        engine.whenLensReady { seen.append("old") }
        lens.cancelOpening(ticket: ticket)
        var opener = Mode.zero; opener.onEnter = ["lens recent"]
        let entering = expectation(description: "entry awaiting before begin")
        var resumeEntry: CheckedContinuation<Void, Never>?
        engine.didEnter = { _, _ in entering.fulfill(); await withCheckedContinuation { resumeEntry = $0 } }
        engine.execute = { _ in _ = lens.begin("recent", toggle: false) }
        let entry = Task { try await engine.enter("opener", mode: opener) }
        await fulfillment(of: [entering], timeout: 2)
        engine.whenLensReady { seen.append("new") }
        resumeInput?.resume()
        await engine.waitForInput()
        XCTAssertTrue(engine.isOpening)
        XCTAssertEqual(seen, ["old"])
        engine.didEnter = { _, _ in }
        resumeEntry?.resume()
        try await entry.value
        XCTAssertEqual(seen, ["old", "new"])
    }

    func testReleaseClosesOwnedLensButKeepsLensOpenedOnRelease() async throws {
        for replaceLens in [false, true] {
            var closes = 0
            let engine = ModeEngine(liveModifiers: { .command }, closeLens: { closes += 1 })
            var mode = Mode.zero; mode.lifetime = .held
            mode.onEnter = ["lens recent"]
            mode.onRelease = [replaceLens ? "lens overview" : "lens presentation list"]
            engine.execute = { commands in
                if commands.first?.args.description == "lens recent" || commands.first?.args.description == "lens overview" { engine.lensOpening() }
            }
            try await engine.enter("held", mode: mode, invocation: .init(keyCode: 48, invoking: .command))
            await engine.observeModifiers([])
            XCTAssertEqual(closes, replaceLens ? 0 : 1)
            XCTAssertEqual(engine.current, mainModeId)
        }
    }

    func testInterruptsRunInOrderAndLaterKeyWaitsForBoth() async throws {
        let engine = ModeEngine()
        let first = expectation(description: "first interrupt")
        var resume: CheckedContinuation<Void, Never>?
        var seen: [String] = []
        engine.interruptOpening {
            seen.append("first start"); first.fulfill()
            await withCheckedContinuation { resume = $0 }
            seen.append("first end")
        }
        await fulfillment(of: [first], timeout: 2)
        engine.interruptOpening { seen.append("second") }
        engine.enqueueInput { seen.append("key") }
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(seen, ["first start"])
        resume?.resume()
        await engine.waitForInput()
        XCTAssertEqual(seen, ["first start", "first end", "second", "key"])
    }

    func testRejectedNamesPreserveTheLensModeAndTrace() async throws {
        let panel = SwitcherPalettePanel.shared
        defer { panel.dismiss() }
        for name in ["missing", "disabled"] {
            var disabled = LensConfig(); disabled.enabled = false
            config.lenses["disabled"] = disabled
            let ticket = try XCTUnwrap(panel.beginLens("disabled", toggle: false))
            await panel.openLens(name: "disabled", settings: LensConfig(), entries: [], search: "", banner: nil, context: .null, ticket: ticket)
            var browse = Mode.zero; browse.unbound = .consume
            try await ModeEngine.shared.enter("browse", mode: browse)
            let session = panel.session
            let traces = LensTraceStore.shared.json(last: 100)
            let result = try await parseCommand("lens \(name)").cmdOrDie.run(.defaultEnv, .emptyStdin)
            await ModeEngine.shared.waitForInput()
            XCTAssertEqual(result.exitCode, 2)
            XCTAssertTrue(panel.session === session)
            XCTAssertEqual(activeMode, "browse")
            XCTAssertEqual(LensTraceStore.shared.json(last: 100), traces)
        }
    }

    func testRejectedOnEnterWithoutBeginEndsItsOwnerAfterParkedKeys() async throws {
        for raw in ["lens missing", "lens overview --tile card", "lens overview --sections app", "lens --filter 'w.'", "lens --filter -"] {
            var miniature = LensConfig(); miniature.presentation = "miniatures"
            config.lenses["overview"] = miniature
            let engine = ModeEngine(liveModifiers: { [] })
            var mode = Mode.zero; mode.onEnter = [raw]
            var seen: String?
            engine.execute = { commands in
                engine.whenLensReady { seen = engine.current }
                let result = try await commands[0].run(CmdEnv(isFromURL: raw == "lens --filter -"), .emptyStdin)
                XCTAssertNotEqual(result.exitCode, 0)
            }
            try await engine.enter("opener", mode: mode)
            await engine.waitForInput()
            XCTAssertEqual(seen, "opener")
            XCTAssertEqual(engine.current, mainModeId, raw)
        }
    }

    func testLensCloseCommandDoesNotEndAnUnownedMode() async throws {
        let panel = SwitcherPalettePanel.shared
        let ticket = try XCTUnwrap(panel.beginLens("demo", toggle: false))
        await panel.openLens(name: "demo", settings: LensConfig(), entries: [], search: "", banner: nil, context: .null, ticket: ticket)
        ModeEngine.shared.replace("window", mode: .zero)
        let result = try await parseCommand("lens close").cmdOrDie.run(.defaultEnv, .emptyStdin)
        await ModeEngine.shared.waitForInput()
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertFalse(panel.isLensOpen)
        XCTAssertEqual(activeMode, "window")
    }

    func testExplicitMainClosesAnUnownedLens() async throws {
        var closes = 0
        let engine = ModeEngine(closeLens: { closes += 1 })
        engine.execute = { _ in }
        engine.replace("window", mode: .zero)
        engine.lensOpening()
        try await engine.enter(mainModeId, mode: .zero)
        XCTAssertEqual(closes, 1)
    }

    func testLensOpenedBesideAnAwaitingOnEnterIsUnowned() async throws {
        let engine = ModeEngine()
        let lens = testLensLifecycle(modeEngine: engine)
        var mode = Mode.zero; mode.onEnter = ["focus left"]
        let started = expectation(description: "on-enter waits")
        var resume: CheckedContinuation<Void, Never>?
        engine.execute = { _ in
            started.fulfill()
            await withCheckedContinuation { resume = $0 }
        }
        let entry = Task { try await engine.enter("window", mode: mode) }
        await fulfillment(of: [started], timeout: 2)
        _ = lens.begin("cli", toggle: false)
        resume?.resume()
        try await entry.value
        lens.dismiss()
        await engine.waitForInput()
        XCTAssertEqual(engine.current, "window")
    }

    func testUnownedDismissSurvivesReloadAndInterruptWithoutChangingMode() async throws {
        let engine = ModeEngine(liveModifiers: { [] })
        let lens = testLensLifecycle(modeEngine: engine)
        var browse = Mode.zero; browse.unbound = .consume
        engine.replace("browse", mode: browse)
        _ = lens.begin("unowned", toggle: false)
        let started = expectation(description: "input in flight")
        var resume: CheckedContinuation<Void, Never>?
        engine.enqueueInput {
            started.fulfill()
            await withCheckedContinuation { resume = $0 }
        }
        await fulfillment(of: [started], timeout: 2)
        var keys: [String?] = []
        engine.enqueueInput { keys.append(engine.current) }
        lens.dismiss()
        engine.reconfigure(browse)
        engine.interruptOpening {}
        engine.enqueueInput { keys.append(engine.current) }
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(engine.current, "browse")
        resume?.resume()
        await engine.waitForInput()
        XCTAssertEqual(keys, ["browse"])
    }

    func testFailedOpeningPreservesTypingModifiersAfterParkedLatch() async throws {
        let engine = ModeEngine(liveModifiers: { .option })
        let lens = testLensLifecycle(modeEngine: engine)
        var held = Mode.zero; held.lifetime = .held
        engine.replace("held", mode: held, invocation: .init(keyCode: 44, invoking: .option))
        let ticket = try XCTUnwrap(lens.begin("unowned", toggle: false))
        var search = Mode.zero; search.unbound = .type
        engine.whenLensReady { try? await engine.enter("search", mode: search) }
        lens.cancelOpening(ticket: ticket)
        await engine.waitForInput()
        XCTAssertEqual(engine.current, "search")
        XCTAssertEqual(engine.textModifiers, .option)
    }

    func testBindingReplacingAnOwnedLensKeepsItsOwnerAndParkedKeys() async throws {
        let engine = ModeEngine(liveModifiers: { [] })
        engine.execute = { _ in }
        let lens = testLensLifecycle(modeEngine: engine)
        var browse = Mode.zero; browse.unbound = .consume
        _ = lens.begin("overview", toggle: false)
        engine.replace("browse", mode: browse)
        _ = lens.begin("recent", toggle: false)
        var seen: [String?] = []
        engine.whenLensReady { seen.append(engine.current) }
        await engine.waitForInput()
        XCTAssertEqual(engine.current, "browse", "the replacement is browse's Lens, so browse does not end")
        await engine.lensReady(show: {}, flags: [])
        XCTAssertEqual(seen, ["browse"], "keys parked for the replacement run in browse, not main")
        lens.dismiss()
        await engine.waitForInput()
        XCTAssertEqual(engine.current, mainModeId)
    }

    func testTransientReturnKeepsAnUnownedLens() async throws {
        var closes = 0
        let engine = ModeEngine(liveModifiers: { [] }, closeLens: { closes += 1 })
        engine.execute = { _ in }
        let lens = testLensLifecycle(modeEngine: engine)
        _ = lens.begin("windows", toggle: false)
        var once = Mode.zero; once.lifetime = .transient
        try await engine.enter("window-once", mode: once)
        try await engine.transientFinished("window-once")
        XCTAssertEqual(engine.current, mainModeId)
        XCTAssertEqual(closes, 0)
    }

    func testOwnedLensClosesWhenItsModeIsReplacedByAPassMode() async throws {
        var closes = 0
        let engine = ModeEngine(liveModifiers: { [] }, closeLens: { closes += 1 })
        let lens = testLensLifecycle(modeEngine: engine)
        var browse = Mode.zero; browse.unbound = .consume
        _ = lens.begin("windows", toggle: false)
        engine.replace("browse", mode: browse)
        engine.replace("search", mode: { var m = Mode.zero; m.unbound = .type; return m }())
        XCTAssertEqual(closes, 0, "search adopts browse's Lens")
        engine.replace("window", mode: .zero)
        XCTAssertEqual(closes, 1)
    }

    func testReleaseDuringACancelledOpeningIsReadByTheNewerLens() async throws {
        let engine = ModeEngine(liveModifiers: { [] })
        var releases = 0
        engine.execute = { _ in releases += 1 }
        let lens = testLensLifecycle(modeEngine: engine)
        var held = Mode.zero; held.lifetime = .held; held.onRelease = ["focus left"]
        engine.replace("held", mode: held, invocation: .init(keyCode: 48, invoking: .command))
        let first = try XCTUnwrap(lens.begin("first", toggle: false))
        engine.noteModifiers([])
        lens.cancelOpening(ticket: first)
        _ = lens.begin("second", toggle: false)
        await engine.lensReady(show: {}, flags: [])
        await engine.waitForInput()
        XCTAssertEqual(releases, 1)
        XCTAssertEqual(engine.current, mainModeId)
    }

    func testClosingAnUnownedOpeningReadsADroppedReleaseAgain() async throws {
        let engine = ModeEngine(liveModifiers: { [] })
        var releases = 0
        engine.execute = { _ in releases += 1 }
        let lens = testLensLifecycle(modeEngine: engine)
        var held = Mode.zero; held.lifetime = .held; held.onRelease = ["focus left"]
        engine.replace("held-pass", mode: held, invocation: .init(keyCode: 48, invoking: .command))
        _ = lens.begin("windows", toggle: false)
        engine.noteModifiers([])
        lens.dismiss()
        await engine.waitForInput()
        XCTAssertEqual(releases, 1)
        XCTAssertEqual(engine.current, mainModeId)
    }

    func testOnEnterReplacingAnAdoptedLensKeepsKeysParkedDuringEntry() async throws {
        let engine = ModeEngine(liveModifiers: { [] })
        let lens = testLensLifecycle(modeEngine: engine)
        _ = lens.begin("overview", toggle: false)
        var opener = Mode.zero; opener.onEnter = ["lens recent"]
        var seen: [String] = []
        engine.didEnter = { _, _ in engine.whenLensReady { seen.append("key") } }
        engine.execute = { _ in
            _ = lens.begin("recent", toggle: false)
            engine.presentLens(show: {}, flags: [])
        }
        try await engine.enter("opener", mode: opener)
        await engine.waitForInput()
        XCTAssertEqual(seen, ["key"])
    }

    func testTaskSpawnedByOnEnterOpensAnUnownedLens() async throws {
        let engine = ModeEngine(liveModifiers: { [] })
        let lens = testLensLifecycle(modeEngine: engine)
        var mode = Mode.zero; mode.onEnter = ["focus left"]
        let opened = expectation(description: "spawned opening")
        engine.execute = { _ in
            Task { @MainActor in
                await Task.yield()
                _ = lens.begin("windows", toggle: false)
                opened.fulfill()
            }
        }
        try await engine.enter("spawner", mode: mode)
        await fulfillment(of: [opened], timeout: 2)
        lens.dismiss()
        await engine.waitForInput()
        XCTAssertEqual(engine.current, "spawner")
    }

    func testCancelledOnEnterOpeningKeepsKeysForTheModeOnEnterEnters() async throws {
        let engine = ModeEngine(liveModifiers: { [] })
        let lens = testLensLifecycle(modeEngine: engine)
        var opener = Mode.zero; opener.onEnter = ["lens a", "mode other"]
        var seen: [String?] = []
        engine.execute = { commands in
            if commands.first?.args.description == "lens a" {
                let ticket = try XCTUnwrap(lens.begin("a", toggle: false))
                engine.whenLensReady { seen.append(engine.current) }
                lens.cancelOpening(ticket: ticket)
            } else {
                try await engine.enter("other", mode: .zero)
            }
        }
        try await engine.enter("opener", mode: opener)
        await engine.waitForInput()
        XCTAssertEqual(seen, ["other"])
    }

    func testLensCloseReturnDoesNotWaitForASlowInterrupt() async throws {
        let engine = ModeEngine(liveModifiers: { [] })
        engine.execute = { _ in }
        let lens = testLensLifecycle(modeEngine: engine)
        var browse = Mode.zero; browse.unbound = .consume
        _ = lens.begin("windows", toggle: false)
        engine.replace("browse", mode: browse)
        let started = expectation(description: "slow global binding")
        var resume: CheckedContinuation<Void, Never>?
        engine.interruptOpening {
            started.fulfill()
            await withCheckedContinuation { resume = $0 }
        }
        await fulfillment(of: [started], timeout: 2)
        lens.dismiss()
        for _ in 0 ..< 20 { await Task.yield() }
        XCTAssertEqual(engine.current, mainModeId)
        resume?.resume()
        await engine.waitForInput()
    }

    func testOnEnterReplacingAnAdoptedLensKeepsTheHold() async throws {
        let engine = ModeEngine(liveModifiers: { .command })
        let lens = testLensLifecycle(modeEngine: engine)
        _ = lens.begin("overview", toggle: false)
        var held = Mode.zero; held.lifetime = .held; held.onEnter = ["lens recent"]
        engine.execute = { _ in _ = lens.begin("recent", toggle: false) }
        try await engine.enter("cmd-tab", mode: held, invocation: .init(keyCode: 48, invoking: .command))
        await engine.waitForInput()
        XCTAssertEqual(engine.current, "cmd-tab")
        XCTAssertEqual(engine.entryModifiers, .command)
    }
}
