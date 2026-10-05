@testable import AppBundle
import AppKit
import Clocks
import Common
import XCTest

private struct CancellationInsensitiveClock: Clock {
    let base: TestClock<Duration>
    var now: TestClock<Duration>.Instant { base.now }
    var minimumResolution: Duration { base.minimumResolution }
    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        try await Task.detached { try await base.sleep(until: deadline, tolerance: tolerance) }.value
    }
}

@MainActor
final class LensEffectLifetimeTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    private func model(_ name: String = "recent", presentation: String = "strip", id: UInt32 = 1, search: String = "") -> LensSession {
        var settings = LensConfig(); settings.presentation = presentation
        let window = TestWindow.new(id: id, parent: focus.workspace.rootTilingContainer)
        let item = SwitcherPaletteItem(id: id, title: "Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false,
            miniature: MiniatureWindow(workspace: "1", frame: .zero, tray: false, frozen: false, accessory: false, floating: false, window: window))
        return LensSession(name: name, settings: settings, items: [item], search: search)
    }

    func testStripReadyIsSilentUntilExactGestureDeadlineAndQuickTapIsSilent() async throws {
        let clock = TestClock()
        var events: [ServerEvent] = []
        var shown = 0
        let owner = testLensLifecycle(clock: clock, emit: { events.append($0) }, show: { _ in shown += 1 })
        let gesture = StripGesture(keyCode: 48, invoking: .command, clock: clock)
        let ticket = owner.begin("recent", toggle: false, strip: gesture)!
        // Readiness uses up most of the delay; it does not restart it.
        await clock.advance(by: .milliseconds(80))
        owner.complete(model(), ticket: ticket)
        guard case .ready = owner.state else { return XCTFail("Expected ready") }
        XCTAssertTrue(events.isEmpty)
        await clock.advance(by: .milliseconds(20) - .nanoseconds(1))
        XCTAssertEqual(shown, 0)
        await clock.advance(by: .nanoseconds(1))
        XCTAssertEqual(shown, 1)
        XCTAssertEqual(events.map(\.eventType), [.lensOpened])
        owner.dismiss()
        XCTAssertEqual(events.map(\.eventType), [.lensOpened, .lensClosed])
        events = []; shown = 0
        let quick = owner.begin("recent", toggle: false, strip: StripGesture(keyCode: 48, invoking: .command, clock: clock))!
        owner.complete(model(), ticket: quick)
        owner.session?.send(.modifiersChanged([]))
        await clock.advance(by: .seconds(2))
        XCTAssertEqual(shown, 0)
        XCTAssertTrue(events.isEmpty)
        XCTAssertTrue(owner.ownedEffects.isEmpty)
        try await clock.checkSuspension()
    }

    func testDismissalRejectsLateStripSleeperAndOvertakenOpeningStartsNoEffects() async throws {
        let base = TestClock()
        let clock = CancellationInsensitiveClock(base: base)
        var shown: [String] = []
        let owner = testLensLifecycle(clock: clock, show: { shown.append($0.name) })
        let old = owner.begin("old", toggle: false, strip: StripGesture(keyCode: 48, invoking: .command, clock: clock))!
        let newer = owner.begin("recent", toggle: false, strip: StripGesture(keyCode: 48, invoking: .command, clock: clock))!
        XCTAssertFalse(owner.complete(model("old"), ticket: old))
        XCTAssertTrue(owner.ownedEffects.isEmpty)
        owner.complete(model(), ticket: newer)
        await base.advance(by: .milliseconds(99))
        owner.dismiss()
        let replacement = owner.begin("list", toggle: false)!
        owner.complete(model("list", presentation: "list", id: 2), ticket: replacement)
        await base.advance(by: .seconds(3))
        XCTAssertEqual(shown, ["list"])
        XCTAssertEqual(owner.session?.name, "list")
        owner.dismiss()
        try await base.checkSuspension()
    }

    func testStripToListCancelsDelayAndRefreshAndRetainsOneEventPair() async throws {
        for ready in [true, false] {
            let clock = TestClock()
            var events: [ServerEvent] = []
            var requests = 0
            var closed = 0
            let dependencies = LensLifecycle.Dependencies(evaluate: { _, _, _ in .success([true]) },
                requestThumbnail: { _, _ in requests += 1 }, closeThumbnails: { _ in closed += 1 }, flags: { .command })
            let owner = LensLifecycle(clock: clock, dependencies: dependencies, emit: { events.append($0) }, show: { _ in }, hide: {})
            let ticket = owner.begin("recent", toggle: false, strip: StripGesture(keyCode: 48, invoking: .command, clock: clock))!
            let session = model()
            owner.complete(session, ticket: ticket)
            if !ready { await clock.advance(by: .milliseconds(100)) }
            session.send(.presentationChanged("list"))
            session.send(.searchChanged("= true"))
            XCTAssertTrue(owner.ownedEffects.contains(.search))
            await clock.advance(by: .seconds(3))
            XCTAssertEqual(requests, ready ? 0 : 1)
            XCTAssertEqual(closed, ready ? 0 : 1)
            XCTAssertEqual(events.map(\.eventType), [.lensOpened])
            owner.dismiss()
            XCTAssertEqual(events.map(\.eventType), [.lensOpened, .lensClosed])
            XCTAssertTrue(owner.ownedEffects.isEmpty)
            try await clock.checkSuspension()
        }
    }

    func testDismissedSearchCannotPublishOrClearReplacementWork() async throws {
        let clock = TestClock()
        let started = LensEffectSignal()
        var finishes: [CheckedContinuation<Result<[Bool], NickelFailure>, Never>] = []
        let dependencies = LensLifecycle.Dependencies(evaluate: { _, _, _ in
            await withCheckedContinuation { finishes.append($0); started.send() }
        }, requestThumbnail: { _, _ in XCTFail("List must not poll") }, closeThumbnails: { _ in }, flags: { [] })
        let owner = LensLifecycle(clock: clock, dependencies: dependencies, emit: { _ in }, show: { _ in }, hide: {})
        let first = model("old", presentation: "list", search: "= true")
        owner.complete(first, ticket: owner.begin("old", toggle: false)!)
        await clock.advance(by: .milliseconds(150))
        await started.wait()
        let oldTask = owner.searchTask
        owner.dismiss()
        XCTAssertTrue(owner.ownedEffects.isEmpty)
        let second = model("new", presentation: "list", id: 2, search: "= false")
        owner.complete(second, ticket: owner.begin("new", toggle: false)!)
        await clock.advance(by: .milliseconds(150))
        await started.wait(2)
        let newTask = owner.searchTask
        // A stale event from the old model is rejected as well as the old reply.
        first.send(.dismissed)
        finishes[0].resume(returning: .failure(.diagnostic("old error")))
        await oldTask?.value
        XCTAssertEqual(owner.searchTask, newTask)
        XCTAssertNil(first.searchError)
        XCTAssertNil(second.searchError)
        owner.dismiss()
        owner.dismiss()
        finishes[1].resume(returning: .success([false]))
        await newTask?.value
        XCTAssertEqual(second.results.map(\.id), [2])
        XCTAssertTrue(owner.ownedEffects.isEmpty)
        try await clock.checkSuspension()
    }

    func testPresentationChangeKeepsSuspendedSessionSearchAndOneEventPair() async throws {
        let clock = TestClock()
        let reached = LensEffectSignal()
        var finish: CheckedContinuation<Result<[Bool], NickelFailure>, Never>?
        var events: [ServerEvent] = []
        let dependencies = LensLifecycle.Dependencies(evaluate: { _, _, _ in
            await withCheckedContinuation { finish = $0; reached.send() }
        }, requestThumbnail: { _, _ in }, closeThumbnails: { _ in }, flags: { [] })
        let owner = LensLifecycle(clock: clock, dependencies: dependencies, emit: { events.append($0) }, show: { _ in }, hide: {})
        let session = model("overview", presentation: "miniatures", search: "= true")
        owner.complete(session, ticket: owner.begin("overview", toggle: false)!, ids: [1])
        await clock.advance(by: .milliseconds(150))
        await reached.wait()
        let search = owner.searchTask
        session.send(.presentationChanged("list"))
        XCTAssertEqual(owner.searchTask, search)
        finish?.resume(returning: .success([true]))
        await search?.value
        XCTAssertEqual(session.results.map(\.id), [1])
        owner.dismiss()
        XCTAssertEqual(events.map(\.eventType), [.lensOpened, .lensClosed])
        try await clock.checkSuspension()
    }

    func testUnchangedModifiersDoNotPublishAndIdenticalSelectionStillPublishesOnce() {
        let owner = testLensLifecycle()
        let session = model("overview", presentation: "miniatures")
        session.miniatureWorkspaces = [MiniatureWorkspace(name: "1", title: "Demo", source: .zero, current: true)]
        owner.complete(session, ticket: owner.begin("overview", toggle: false)!)
        var changes = 0
        let observation = session.objectWillChange.sink { changes += 1 }
        session.send(.modifiersChanged([]))
        XCTAssertEqual(changes, 0)
        session.send(.summonChanged(true))
        changes = 0
        session.send(.selectionChanged(session.selection))
        XCTAssertEqual(changes, 1, "The base assigns selection unconditionally, but dedupes landing")
        owner.dismiss()
        withExtendedLifetime(observation) {}
    }

    func testStripDeadlineChecksReleaseWithoutUpdatingSummon() async throws {
        let clock = TestClock()
        var flags: NSEvent.ModifierFlags = .command
        let dependencies = LensLifecycle.Dependencies(evaluate: { _, _, _ in .success([]) },
            requestThumbnail: { _, _ in }, closeThumbnails: { _ in }, flags: { flags })
        let owner = LensLifecycle(clock: clock, dependencies: dependencies, emit: { _ in }, show: { _ in }, hide: {})
        var settings = LensConfig(); settings.presentation = "strip"; settings.keys["alt-enter"] = ["summon"]
        let session = LensSession(name: "recent", settings: settings, items: [], search: "")
        owner.complete(session, ticket: owner.begin("recent", toggle: false, strip: StripGesture(keyCode: 48, invoking: .command, clock: clock))!)
        XCTAssertFalse(session.summonHeld)
        flags = [.command, .option]
        await clock.advance(by: .milliseconds(100))
        XCTAssertFalse(session.summonHeld, "The display deadline only rechecks the release key")
        owner.dismiss()
        try await clock.checkSuspension()
    }

    func testPollingStopsAfterReplacementAndRepeatedDismissalCancelsOnlyOwnedToken() async throws {
        let base = TestClock()
        let clock = CancellationInsensitiveClock(base: base)
        var requests: [UInt32] = []
        var closed: [Int] = []
        let dependencies = LensLifecycle.Dependencies(evaluate: { _, _, _ in .success([]) },
            requestThumbnail: { window, _ in requests.append(window.windowId) }, closeThumbnails: { closed.append($0) }, flags: { .command })
        let owner = LensLifecycle(clock: clock, dependencies: dependencies, emit: { _ in }, show: { _ in }, hide: {})
        owner.complete(model("old", presentation: "miniatures"), ticket: owner.begin("old", toggle: false)!)
        owner.session?.miniatureWorkspaces = [MiniatureWorkspace(name: "1", title: "Demo", source: CGRect(x: 0, y: 0, width: 1000, height: 700), current: true)]
        await base.advance()
        XCTAssertEqual(requests, [1])
        owner.dismiss()
        owner.dismiss()
        XCTAssertEqual(closed, [1])
        let replacement = model("new", presentation: "miniatures", id: 2)
        replacement.miniatureWorkspaces = [MiniatureWorkspace(name: "1", title: "Demo", source: CGRect(x: 0, y: 0, width: 1000, height: 700), current: true)]
        owner.complete(replacement, ticket: owner.begin("new", toggle: false)!)
        await base.advance(by: .seconds(2))
        XCTAssertEqual(requests.filter { $0 == 1 }, [1])
        XCTAssertGreaterThan(requests.filter { $0 == 2 }.count, 1)
        owner.dismiss()
        let final = requests
        await base.advance(by: .seconds(3))
        XCTAssertEqual(requests, final)
        XCTAssertEqual(closed, [1, 2])
        XCTAssertTrue(owner.ownedEffects.isEmpty)
        try await base.checkSuspension()
    }
}
