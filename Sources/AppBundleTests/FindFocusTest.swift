@testable import AppBundle
import AppKit
import Clocks
import Common
import XCTest

@MainActor
final class FindFocusTest: SerialClockTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    override func tearDown() async throws {
        FindFocusHighlight.shared.dismiss()
        TrayMenuModel.shared.isEnabled = true
        MissionControlState.shared.receive("AXExposeExit")
    }

    private func install(_ clock: TestClock<Duration> = TestClock(), show: @escaping (Rect) -> Void = { _ in }, fade: @escaping () -> Void = {}, hide: @escaping () -> Void = {}) -> FindFocusHighlight {
        FindFocusHighlight.shared.dismiss()
        let owner = FindFocusHighlight(clock: clock, show: show, fade: fade, hide: hide, monitorInput: { _ in {} })
        FindFocusHighlight.shared = owner
        TrayMenuModel.shared.isEnabled = true
        return owner
    }

    private func window(_ id: UInt32 = 1, floating: Bool = false) -> TestWindow {
        let workspace = focus.workspace
        let rect = Rect(topLeftX: CGFloat(id) * 100, topLeftY: 100, width: 400, height: 300)
        let window = TestWindow.new(id: id, parent: floating ? workspace : workspace.rootTilingContainer, rect: rect)
        XCTAssertTrue(window.focusWindow())
        return window
    }

    @discardableResult
    private func mark() async throws -> CmdResult {
        try await parseCommand("find-focus").cmdOrDie.run(.defaultEnv, .emptyStdin)
    }

    func testTiledActiveTabFloatingAndFullscreenUseTheLiveWindowFrame() async throws {
        var shown: [Rect] = []
        let owner = install(show: { shown.append($0) })
        let first = window()
        let second = window(2)
        XCTAssertTrue(first.focusWindow())
        let tiled = try await mark()
        XCTAssertEqual(tiled.exitCode, 0)
        XCTAssertEqual(tiled.stdout, [])
        let firstRect = try await first.getAxRect()
        XCTAssertEqual(shown.last, firstRect)
        owner.dismiss()
        config.windowTabs.enabled = true
        focus.workspace.rootTilingContainer.layout = .tabGroup
        let next = try await runLightSession(.hotkeyBinding, .checkServerIsEnabledOrDie(), shouldSchedulePostRefresh: false) {
            try await parseCommand("focus tab-next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        }
        XCTAssertEqual(next.exitCode, 0)
        XCTAssertEqual(focus.windowOrNil, second)
        try await mark()
        let secondRect = try await second.getAxRect()
        XCTAssertEqual(shown.last, secondRect)
        XCTAssertNotEqual(shown.last, shown.first)
        let inactiveRect = try await first.getAxRect()
        XCTAssertNotEqual(shown.last, inactiveRect)
        XCTAssertNotEqual(shown.last, focus.workspace.rootTilingContainer.lastAppliedLayoutPhysicalRect)
        owner.dismiss()
        let floating = window(3, floating: true)
        try await mark()
        let floatingRect = try await floating.getAxRect()
        XCTAssertEqual(shown.last, floatingRect)
        owner.dismiss()
        floating.isFullscreen = true
        try await mark()
        let fullscreenRect = try await floating.getAxRect()
        XCTAssertEqual(shown.last, fullscreenRect)
    }

    func testMissingAXFrameFallsBackToActualThenAppliedLayout() async throws {
        var shown: [Rect] = []
        _ = install(show: { shown.append($0) })
        let target = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        XCTAssertTrue(target.focusWindow())
        let actual = Rect(topLeftX: 20, topLeftY: 30, width: 500, height: 400)
        let applied = Rect(topLeftX: 40, topLeftY: 50, width: 600, height: 500)
        target.recordAuthoritativeActualRect(actual)
        target.lastAppliedLayoutPhysicalRect = applied
        try await mark()
        XCTAssertEqual(shown.last, actual)
        target.invalidateLastKnownNativeState()
        try await mark()
        XCTAssertEqual(shown.last, applied)
        target.lastAppliedLayoutPhysicalRect = nil
        let unavailable = try await mark()
        XCTAssertEqual(unavailable.exitCode, 1)
        XCTAssertFalse(FindFocusHighlight.shared.isShowing)
    }

    func testMissingAXFramePrefersAnActualFrameUpdatedDuringTheRead() async throws {
        var shown: [Rect] = []
        _ = install(show: { shown.append($0) })
        let target = window()
        let newer = Rect(topLeftX: 40, topLeftY: 50, width: 600, height: 500)
        target.testAxRectUnavailable = true
        target.beforeAxRect = { [weak target] in target?.recordAuthoritativeActualRect(newer) }
        try await mark()
        XCTAssertEqual(shown.last, newer)
    }

    func testEmptyWorkspaceFailsButDisabledAndMissionControlSucceedWithoutDrawing() async throws {
        var shows = 0
        _ = install(show: { _ in shows += 1 })
        let empty = try await mark()
        XCTAssertEqual(empty.exitCode, 1)
        XCTAssertEqual(empty.stderr, ["find-focus: no window is focused"])
        TrayMenuModel.shared.isEnabled = false
        let disabled = try await mark()
        XCTAssertEqual(disabled.exitCode, 0)
        TrayMenuModel.shared.isEnabled = true
        MissionControlState.shared.receive("AXExposeShowAllWindows")
        let overview = try await mark()
        XCTAssertEqual(overview.exitCode, 0)
        XCTAssertEqual(shows, 0)
    }

    func testDisabledSocketCommandIsRefusedLikeEveryOtherCommand() async {
        var shows = 0
        _ = install(show: { _ in shows += 1 })
        let target = window()
        let applied = Rect(topLeftX: 1, topLeftY: 2, width: 3, height: 4)
        target.lastAppliedLayoutPhysicalRect = applied
        TrayMenuModel.shared.isEnabled = false
        let marked = await executeExternalCommand(["find-focus"], stdin: "", windowId: nil, workspace: nil, traceOrigin: .internalNow())
        XCTAssertEqual(marked.exitCode, 1)
        XCTAssertTrue(marked.stderr.contains("server is disabled"))
        XCTAssertEqual(target.lastAppliedLayoutPhysicalRect, applied, "a disabled WinMux runs no layout for find-focus")
        XCTAssertEqual(shows, 0)
    }

    func testCommandAndFileReloadEndMarkEvenOnFailureButDryRunKeepsIt() async throws {
        let owner = install()
        _ = window()
        let probe = ReloadProbe()
        probe.failures["bad"] = "invalid config"
        let reloader = probe.owner(willReload: { owner.dismiss() })
        let file = URL(filePath: "/config/bad.ncl")
        try await mark()
        _ = await reloader.request(forceConfigUrl: file, dryRun: true)
        XCTAssertTrue(owner.isShowing)
        for trigger: ConfigReloadTrigger in [.command, .fileChange] {
            try await mark()
            let result = await reloader.request(forceConfigUrl: file, trigger: trigger)
            XCTAssertFalse(try result.result.get())
            XCTAssertFalse(owner.isShowing)
        }
    }

    func testShowsImmediatelyFadesAtPointEightAndHidesAtOnePointTwo() async throws {
        let clock = TestClock<Duration>()
        var events: [String] = []
        _ = install(clock, show: { _ in events.append("show") }, fade: { events.append("fade") }, hide: { events.append("hide") })
        _ = window()
        try await mark()
        XCTAssertEqual(events, ["show"])
        await clock.advance(by: .milliseconds(799))
        XCTAssertEqual(events, ["show"])
        await clock.advance(by: .milliseconds(1))
        XCTAssertEqual(events, ["show", "fade"])
        await clock.advance(by: .milliseconds(399))
        XCTAssertEqual(events, ["show", "fade"])
        await clock.advance(by: .milliseconds(1))
        XCTAssertEqual(events, ["show", "fade", "hide"])
        try await clock.checkSuspension()
    }

    func testRestartAtPointFiveResetsOpacityAndDeadline() async throws {
        let clock = TestClock<Duration>()
        var events: [String] = []
        _ = install(clock, show: { _ in events.append("show") }, fade: { events.append("fade") }, hide: { events.append("hide") })
        _ = window()
        try await mark()
        await clock.advance(by: .milliseconds(500))
        try await mark()
        await clock.advance(by: .milliseconds(700))
        XCTAssertEqual(events, ["show", "show"])
        await clock.advance(by: .milliseconds(100))
        XCTAssertEqual(events, ["show", "show", "fade"])
        await clock.advance(by: .milliseconds(400))
        XCTAssertEqual(events, ["show", "show", "fade", "hide"])
        try await clock.checkSuspension()
    }

    func testInputEndsImmediatelyExceptModifierChangesAndRemovesMonitors() async throws {
        let clock = TestClock<Duration>()
        var hides = 0, starts = 0, stops = 0
        let owner = FindFocusHighlight(clock: clock, show: { _ in }, fade: { XCTFail("early dismissal must not fade") }, hide: { hides += 1 }, monitorInput: { receive in
            starts += 1
            receive(.flagsChanged)
            return { stops += 1 }
        })
        FindFocusHighlight.shared = owner
        _ = window()
        for type: NSEvent.EventType in [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown] {
            try await mark()
            owner.receiveInput(.flagsChanged)
            XCTAssertTrue(owner.isShowing)
            owner.receiveInput(type)
            XCTAssertFalse(owner.isShowing)
        }
        await clock.advance(by: .seconds(2))
        XCTAssertEqual([starts, stops, hides], [4, 4, 4])
        try await clock.checkSuspension()
    }

    func testFocusCommandWorkspaceChangeLayoutDisableReloadAndMissionControlEndImmediately() async throws {
        var hides = 0
        let owner = install(hide: { hides += 1 })
        let first = window()
        let second = window(2)
        XCTAssertTrue(first.focusWindow())
        try await mark()
        _ = try await parseCommand("focus --window-id 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(focus.windowOrNil, second)
        XCTAssertEqual(hides, 1)
        try await mark()
        XCTAssertTrue(Workspace.get(byName: "empty").focusWorkspace())
        XCTAssertEqual(hides, 2)
        XCTAssertTrue(first.focusWindow())
        try await runLightSession(.hotkeyBinding, .checkServerIsEnabledOrDie(), shouldSchedulePostRefresh: false) {}
        try await mark()
        try await runLightSession(.hotkeyBinding, .checkServerIsEnabledOrDie(), shouldSchedulePostRefresh: false) {}
        XCTAssertTrue(owner.isShowing, "an unchanged refresh must retain the mark despite AX/layout rounding")
        let oldRect = first.lastAppliedLayoutPhysicalRect
        try await runLightSession(.hotkeyBinding, .checkServerIsEnabledOrDie(), shouldSchedulePostRefresh: false) {
            let resized = try await parseCommand("resize width +100").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(resized.exitCode, 0)
        }
        XCTAssertNotEqual(first.lastAppliedLayoutPhysicalRect, oldRect)
        XCTAssertEqual(hides, 3)
        try await mark()
        _ = try await parseCommand("enable off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(hides, 4)
        TrayMenuModel.shared.isEnabled = true
        try await mark()
        resetHotKeys()
        XCTAssertEqual(hides, 5)
        try await mark()
        MissionControlState.shared.receive("AXExposeShowAllWindows")
        XCTAssertEqual(hides, 6)
        let floating = window(3, floating: true)
        MissionControlState.shared.receive("AXExposeExit")
        try await mark()
        floating.lastAppliedLayoutPhysicalRect = nil
        owner.refresh()
        XCTAssertTrue(owner.isShowing)
    }

    func testBindingDispatchWithAndWithoutAMarkKeepsItsCommandsAndCanRestart() async throws {
        let clock = TestClock<Duration>()
        var shows = 0, hides = 0
        _ = install(clock, show: { _ in shows += 1 }, hide: { hides += 1 })
        _ = window()
        config.modes = ["main": .zero, "window": .zero]
        activeMode = "window"
        triggerBinding("esc", [parseCommand("mode main").cmdOrDie])
        await clock.advance()
        XCTAssertEqual(activeMode, "main", "feature off: binding still executes")
        XCTAssertEqual(hides, 0)
        activeMode = "window"
        try await mark()
        triggerBinding("esc", [parseCommand("mode main").cmdOrDie])
        XCTAssertEqual(hides, 1, "Carbon dispatch hides synchronously before its task runs")
        await clock.advance()
        XCTAssertEqual(activeMode, "main")
        activeMode = "window"
        try await mark()
        triggerBinding("c", [parseCommand("find-focus").cmdOrDie])
        XCTAssertEqual(hides, 2)
        await clock.advance()
        XCTAssertEqual(shows, 3)
        XCTAssertTrue(FindFocusHighlight.shared.isShowing)
        FindFocusHighlight.shared.dismiss()
    }

    func testFocusLayoutAndDisableKeepTheirBehaviorWithNoMark() async throws {
        var hides = 0
        _ = install(hide: { hides += 1 })
        let a = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        let b = TestWindow.new(id: 2, parent: focus.workspace.rootTilingContainer)
        XCTAssertTrue(a.focusWindow())
        let result = try await parseCommand("focus --window-id 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(focus.windowOrNil, b)
        try await runLightSession(.hotkeyBinding, .checkServerIsEnabledOrDie(), shouldSchedulePostRefresh: false) {}
        XCTAssertNotNil(b.lastAppliedLayoutPhysicalRect)
        let disabled = try await parseCommand("enable off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(disabled.exitCode, 0)
        XCTAssertFalse(TrayMenuModel.shared.isEnabled)
        TrayMenuModel.shared.isEnabled = true
        XCTAssertEqual(hides, 0, "with no mark, the end hooks hide nothing")
    }

    func testCommandParsesWithoutArgumentsAndIsAllowedInConfigAndURL() throws {
        let command = try XCTUnwrap(parseCommand("find-focus").cmdOrNil)
        XCTAssertTrue(command.info.allowInConfig)
        XCTAssertNil(parseCommand("find-focus extra").cmdOrNil)
        XCTAssertNil(parseCommand("find-focus --window-id 1").cmdOrNil)
        let words = try parseCommandURL(URL(string: "winmux://run/find-focus")!).get()
        XCTAssertEqual(words, ["find-focus"])
        XCTAssertNil(urlCommandRefusal(kind: command.info.kind, args: command.args))
        XCTAssertTrue(command.canSkipPostCommandRefresh)
    }

    func testPanelsAreNonactivatingAndDrawingClipsAcrossScreenOrigins() throws {
        let screen = NSRect(x: -800, y: 100, width: 800, height: 600)
        let window = NSRect(x: -200, y: 200, width: 400, height: 300)
        let panel = FindFocusPanel()
        panel.show(window: window, screen: screen, scale: 2)
        defer { panel.orderOut(nil) }
        XCTAssertEqual(panel.frame, screen)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertFalse(panel.hasShadow)
        XCTAssertEqual(panel.animationBehavior, .none)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertEqual(panel.level, WinMuxPanelLayer.overlay.level)
        let paths = findFocusPaths(window: window, screen: screen)
        XCTAssertFalse(paths.dim.contains(CGPoint(x: 700, y: 200), using: .evenOdd))
        XCTAssertTrue(paths.dim.contains(CGPoint(x: 100, y: 200), using: .evenOdd))
        XCTAssertTrue(paths.border.contains(CGPoint(x: 602, y: 200), using: .evenOdd))
        XCTAssertFalse(paths.border.contains(CGPoint(x: 610, y: 200), using: .evenOdd))
        let other = findFocusPaths(window: window, screen: NSRect(x: 1000, y: 0, width: 800, height: 600))
        XCTAssertTrue(other.dim.contains(CGPoint(x: 400, y: 300), using: .evenOdd))
        let fullscreen = findFocusPaths(window: screen, screen: screen)
        XCTAssertTrue(fullscreen.border.contains(CGPoint(x: 2, y: 300), using: .evenOdd))
        XCTAssertFalse(fullscreen.border.contains(CGPoint(x: 5, y: 300), using: .evenOdd))
    }

    func testDefaultCMarksFocusAndKeepsWindowModeWithNoMainChord() async throws {
        _ = install()
        _ = window()
        let commands = try XCTUnwrap(defaultConfig.modes["window"]?.bindings["c"]?.commands)
        XCTAssertEqual(commands.count, 1)
        XCTAssertTrue(commands[0].equals(parseCommand("find-focus").cmdOrDie))
        XCTAssertFalse(defaultConfig.modes["main"]!.bindings.values.contains { binding in
            binding.commands.contains { $0 is FindFocusCommand }
        })
        config.modes = ["main": .zero, "window": .zero]
        try await activateMode("window")
        let result = try await commands.runCmdSeq(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(activeMode, "window")
        XCTAssertTrue(FindFocusHighlight.shared.isShowing)
    }

    func testFocusChangeDuringTheFrameReadRejectsTheOldTarget() async throws {
        var shown: [Rect] = []
        _ = install(show: { shown.append($0) })
        let first = window()
        let second = window(2)
        XCTAssertTrue(first.focusWindow())
        let gate = ReloadGate()
        first.beforeAxRect = { await gate.hold() }
        let request = Task { try await self.mark() }
        await gate.entered.wait()
        XCTAssertTrue(second.focusWindow())
        gate.release()
        let result = try await request.value
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(shown.isEmpty)
    }

    func testInputDuringARestartFrameReadDoesNotResurrectTheMark() async throws {
        var shows = 0
        let owner = install(show: { _ in shows += 1 })
        let target = window()
        try await mark()
        let gate = ReloadGate()
        target.beforeAxRect = { await gate.hold() }
        let request = Task { try await self.mark() }
        await gate.entered.wait()
        owner.receiveInput(.keyDown)
        gate.release()
        let result = try await request.value
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(shows, 1)
        XCTAssertFalse(owner.isShowing)
    }

    func testFocusResolutionAfterTheMarkedWindowLeavesItsWorkspaceEndsTheMark() async throws {
        let owner = install()
        let first = window(floating: true)
        let second = window(2)
        XCTAssertTrue(first.focusWindow())
        try await mark()
        first.unbindFromParent()
        XCTAssertTrue(second.focusWindow())
        XCTAssertEqual(focus.windowOrNil, second)
        XCTAssertFalse(owner.isShowing)
    }

    func testRestartSentAsTheOldMarkExpiresStillDraws() async throws {
        let clock = TestClock<Duration>()
        var shows = 0
        _ = install(clock, show: { _ in shows += 1 })
        let target = window()
        try await mark()
        await clock.advance(by: .milliseconds(1199))
        let gate = ReloadGate()
        target.beforeAxRect = { await gate.hold() }
        let request = Task { try await self.mark() }
        await gate.entered.wait()
        target.beforeAxRect = nil
        await clock.advance(by: .milliseconds(1))
        XCTAssertFalse(FindFocusHighlight.shared.isShowing)
        gate.release()
        let result = try await request.value
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(shows, 2)
        XCTAssertTrue(FindFocusHighlight.shared.isShowing)
        FindFocusHighlight.shared.dismiss()
    }

    func testAFailedAXReadFallsBackToTheCachedFrame() async throws {
        var shown: [Rect] = []
        _ = install(show: { shown.append($0) })
        let target = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        XCTAssertTrue(target.focusWindow())
        let actual = Rect(topLeftX: 20, topLeftY: 30, width: 500, height: 400)
        target.recordAuthoritativeActualRect(actual)
        target.testAxRectError = FindFocusTestError()
        let result = try await mark()
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(shown.last, actual)
    }

    func testALayoutDuringTheReadReadsTheFrameAgain() async throws {
        var shown: [Rect] = []
        let owner = install(show: { shown.append($0) })
        let target = window()
        let moved = Rect(topLeftX: 700, topLeftY: 40, width: 300, height: 200)
        var reads = 0
        target.beforeAxRect = { [weak target] in
            reads += 1
            // AX answers with the old frame, then the layout lands; the second read sees the move.
            if reads == 1 { target?.lastAppliedLayoutPhysicalRect = moved }
            if reads == 2 { target?.setAxFrame(moved.topLeftCorner, moved.size) }
        }
        try await mark()
        XCTAssertEqual(reads, 2)
        XCTAssertEqual(shown.last, moved)
        owner.refresh()
        XCTAssertTrue(owner.isShowing, "the new layout is the mark's baseline")
    }

    func testARestartDuringALayoutThatEndsTheOldMarkStillDraws() async throws {
        var shows = 0
        let owner = install(show: { _ in shows += 1 })
        let target = window()
        try await mark()
        let gate = ReloadGate()
        target.beforeAxRect = { [weak target] in
            target?.beforeAxRect = nil
            await gate.hold()
        }
        let request = Task { try await self.mark() }
        await gate.entered.wait()
        target.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 700, topLeftY: 40, width: 300, height: 200)
        owner.refresh()
        XCTAssertFalse(owner.isShowing)
        gate.release()
        let result = try await request.value
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(shows, 2)
        XCTAssertTrue(owner.isShowing)
    }

    func testACancelledReadDrawsNothing() async throws {
        var shows = 0
        _ = install(show: { _ in shows += 1 })
        let target = window()
        target.recordAuthoritativeActualRect(Rect(topLeftX: 20, topLeftY: 30, width: 500, height: 400))
        target.testAxRectError = CancellationError()
        do {
            try await mark()
            XCTFail("a cancelled read ends the command")
        } catch is CancellationError {}
        XCTAssertEqual(shows, 0)
    }

    func testAFloatingWindowTiledAgainEndsTheMark() async throws {
        let owner = install()
        let floating = window(3, floating: true)
        try await mark()
        XCTAssertNil(floating.lastAppliedLayoutPhysicalRect)
        owner.refresh()
        XCTAssertTrue(owner.isShowing)
        floating.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 600, height: 400)
        owner.refresh()
        XCTAssertFalse(owner.isShowing)
    }

    func testTriggerBindingCommandEndsTheMarkBeforeItsCommandsRun() async throws {
        var shows = 0, hides = 0
        _ = install(show: { _ in shows += 1 }, hide: { hides += 1 })
        _ = window()
        config.modes["window"] = defaultConfig.modes["window"]
        try await mark()
        let result = try await parseCommand("trigger-binding --mode window c").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual([shows, hides], [2, 1])
        XCTAssertTrue(FindFocusHighlight.shared.isShowing)
    }

    func testFocusResolvingToAnotherWindowDuringTheReadDrawsNothing() async throws {
        var shows = 0
        _ = install(show: { _ in shows += 1 })
        let first = window(floating: true)
        _ = window(2)
        XCTAssertTrue(first.focusWindow())
        let gate = ReloadGate()
        first.beforeAxRect = { await gate.hold() }
        let request = Task { try await self.mark() }
        await gate.entered.wait()
        _ = first.unbindFromParent()
        XCTAssertNotEqual(focus.windowOrNil, first)
        gate.release()
        let result = try await request.value
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(shows, 0)
    }

    func testRestartDuringFadeShowsAtFullOpacityAndCancelsTheOldHide() async throws {
        let clock = TestClock<Duration>()
        var events: [String] = []
        _ = install(clock, show: { _ in events.append("show") }, fade: { events.append("fade") }, hide: { events.append("hide") })
        _ = window()
        try await mark()
        await clock.advance(by: .milliseconds(900))
        XCTAssertEqual(events, ["show", "fade"])
        try await mark()
        await clock.advance(by: .milliseconds(300))
        XCTAssertEqual(events, ["show", "fade", "show"])
        await clock.advance(by: .milliseconds(900))
        XCTAssertEqual(events, ["show", "fade", "show", "fade", "hide"])
        try await clock.checkSuspension()
    }
}

private struct FindFocusTestError: Error {}
