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
final class LensEffectLifetimeTest: SerialClockTestCase {
    override func setUp() async throws { setUpWorkspacesForTests(); enterModeForTests("browse") }

    private func model(_ name: String = "recent", presentation: String = "strip", id: UInt32 = 1, search: String = "") -> LensSession {
        var settings = LensConfig(); settings.presentation = presentation
        if !search.isEmpty { enterModeForTests("search") }
        let window = TestWindow.new(id: id, parent: focus.workspace.rootTilingContainer)
        let item = SwitcherPaletteItem(id: id, title: "Demo", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false,
            miniature: MiniatureWindow(workspace: "1", frame: .zero, tray: false, frozen: false, accessory: false, floating: false, window: window))
        return LensSession(name: name, settings: settings, items: [item], search: search)
    }




    func testDismissedSearchCannotPublishOrClearReplacementWork() async throws {
        let clock = TestClock()
        let started = LensEffectSignal()
        var finishes: [CheckedContinuation<Result<[Bool], NickelFailure>, Never>] = []
        let dependencies = LensLifecycle.Dependencies(evaluate: { _, _, _ in
            await withCheckedContinuation { finishes.append($0); started.send() }
        }, requestThumbnail: { _, _, _ in XCTFail("List must not poll") }, closeThumbnails: { _ in }, flags: { [] })
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
        }, requestThumbnail: { _, _, _ in }, closeThumbnails: { _ in }, flags: { [] })
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
        session.send(.modifiersChanged(.option))
        changes = 0
        session.send(.modifiersChanged(.option))
        session.send(.modifiersChanged([.option, .capsLock]))
        XCTAssertEqual(changes, 0)
        session.send(.selectionChanged(session.selection))
        XCTAssertEqual(changes, 1, "The base assigns selection unconditionally, but dedupes landing")
        owner.dismiss()
        withExtendedLifetime(observation) {}
    }


    func testPollingStopsAfterReplacementAndRepeatedDismissalCancelsOnlyOwnedToken() async throws {
        let base = TestClock()
        let clock = CancellationInsensitiveClock(base: base)
        var requests: [UInt32] = []
        var closed: [Int] = []
        let dependencies = LensLifecycle.Dependencies(evaluate: { _, _, _ in .success([]) },
            requestThumbnail: { window, _, _ in requests.append(window.windowId) }, closeThumbnails: { closed.append($0) }, flags: { .command })
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



    func testListAskedToBecomeAListIsPresentedAgainWithoutActivationOrEvents() {
        var events: [ServerEvent] = []
        var shown = 0
        var instructions: [LensLifecycle.ShowInstruction] = []
        let owner = testLensLifecycle(emit: { events.append($0) }, show: { _ in shown += 1 })
        owner.finishShow = { _, instruction in instructions.append(instruction) }
        var settings = LensConfig(); enterModeForTests("browse")
        let session = LensSession(name: "search", settings: settings, items: [], search: "")
        owner.complete(session, ticket: owner.begin("search", toggle: false)!)
        owner.changePresentationToList(session)
        XCTAssertEqual(shown, 2)
        XCTAssertEqual(activeMode, "browse")
        XCTAssertEqual(instructions.last, .init(activate: false, focusSearch: false))
        XCTAssertEqual(events.map(\.eventType), [.lensOpened])
        owner.dismiss()
    }
}
