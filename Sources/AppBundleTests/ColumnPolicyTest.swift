@testable import AppBundle
import Common
import Combine
import XCTest

@MainActor
final class ColumnPolicyTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    private func load(_ body: String, shared: Bool = false) async throws -> NickelSupervisor {
        guard nickelHelperUrl() != nil else { throw XCTSkip("Run make helper") }
        let path = FileManager.default.temporaryDirectory.appending(path: "column-policy-\(UUID()).ncl")
        try ("let W = import \"winmux/winmux.ncl\" in { " + body + " } | W.Config").write(to: path, atomically: true, encoding: .utf8)
        let supervisor = shared ? NickelSupervisor.shared : NickelSupervisor()
        let loaded = try await supervisor.load(path).get()
        config.onFocusedMonitorChanged = []
        config.columns = ColumnsConfig(loaded.settings["columns"], workspaces: loaded.settings["workspace"])
        config.arrive = loaded.settings["arrive"]?.stringOrNil
        supervisor.adopt(loaded)
        addTeardownBlock { try? FileManager.default.removeItem(at: path) }
        return supervisor
    }

    private func demo(_ name: String = "Demo", count: Int = 3) -> Workspace {
        let ws = Workspace.get(byName: name)
        ws.columns = ColumnState(count: count)
        ws.enforceColumnInvariant()
        return ws
    }

    func testEachTargetAndOutOfRangeUsesBuiltInAndRecordsError() async throws {
        for (target, expected) in [("'focused", 2), ("'mru", 1), ("'nearest-empty", 2), ("'last", 3), ("3", 3), ("8", 2)] {
            let supervisor = try await load("columns.place = fun w ctx cols => { column = \(target), overflow = 'tab-group }")
            let ws = demo()
            let anchor = TestWindow.new(id: 1, parent: ws.rootTilingContainer)
            ws.enforceColumnInvariant()
            ws.columns?.focusedSlot = 2
            let window = TestWindow.new(id: 2, parent: ws)
            let before = ws.rootTilingContainer.children
            let decision = await ColumnPolicy.decision(window: window, workspace: ws, supervisor: supervisor)
            XCTAssertEqual(decision.slot, expected, target)
            XCTAssertEqual(ws.rootTilingContainer.children, before)
            if target == "8" { XCTAssertTrue(supervisor.status.lastError?.contains("exceeds count") == true) }
            anchor.unbindFromParent(); window.unbindFromParent()
        }
    }

    func testEveryOverflowAndSqueezeWidthAndRemoval() async throws {
        for action in ["tab-group", "split", "float", "squeeze"] {
            let supervisor = try await load("columns.place = fun w ctx cols => { column = 1, overflow = '\(action) }")
            let ws = demo()
            ws.columns = ColumnState(count: 3, widths: [0.2, 0.3, 0.5])
            let old = TestWindow.new(id: 1, parent: ws.rootTilingContainer)
            ws.enforceColumnInvariant()
            let new = TestWindow.new(id: 2, parent: ws)
            try await ColumnPolicy.place(new, on: ws, supervisor: supervisor)
            if action == "float" { XCTAssertTrue(new.isFloating) }
            else if action == "squeeze" {
                XCTAssertEqual(ws.columns?.slotCount, 4)
                XCTAssertEqual(ws.columnSlot(containing: new), 4)
                for (actual, expected) in zip(ws.columns!.widths, [0.15, 0.225, 0.375, 0.25]) { XCTAssertEqual(actual, expected, accuracy: 0.000001) }
                new.unbindFromParent(); ws.normalizeContainers()
                XCTAssertEqual(ws.columns?.widths, [0.2, 0.3, 0.5])
            } else {
                XCTAssertEqual(ws.columnSlot(containing: new), 1)
                XCTAssertEqual((new.parent as? TilingContainer)?.layout, action == "split" ? .tiles : .tabGroup)
                if action == "split" { XCTAssertEqual((new.parent as? TilingContainer)?.orientation, .v) }
            }
            old.unbindFromParent(); if new.isBound { new.unbindFromParent() }
        }
    }

    func testArriveColumnsRoutingFloatAndAccessoryOverride() async throws {
        let supervisor = try await load("arrive = fun w ctx cols => if w.id == 2 then { workspace = if std.array.length cols == 3 then \"Other\" else \"Wrong\" } else if w.id == 3 then { float = true } else { float = false, column = 2 }, workspace.Other.columns.place = fun w ctx cols => { column = 'last, overflow = 'tab-group }")
        let ws = demo()
        let other = demo("Other", count: 2)
        let routed = TestWindow.new(id: 2, parent: ws)
        try await ColumnPolicy.arrive(routed, on: ws, floatingDefault: false, supervisor: supervisor)
        XCTAssertTrue(routed.nodeWorkspace === other)
        XCTAssertEqual(other.columnSlot(containing: routed), 2)
        let floating = TestWindow.new(id: 3, parent: ws)
        try await ColumnPolicy.arrive(floating, on: ws, floatingDefault: false, supervisor: supervisor)
        XCTAssertTrue(floating.isFloating)
        let accessory = TestWindow.new(id: 4, parent: ws)
        try await ColumnPolicy.arrive(accessory, on: ws, floatingDefault: true, supervisor: supervisor)
        XCTAssertFalse(accessory.isFloating)
        XCTAssertEqual(ws.columnSlot(containing: accessory), 2)
    }

    func testArriveClassReflectsBindingDefaultBeforePlacement() async throws {
        let supervisor = try await load("arrive = fun w ctx cols => if w.class == 'tiled then { column = 2 } else { float = true }")
        let ws = demo()
        let tiled = TestWindow.new(id: 41, parent: ws)
        try await ColumnPolicy.arrive(tiled, on: ws, floatingDefault: false, supervisor: supervisor)
        XCTAssertEqual(ws.columnSlot(containing: tiled), 2)
        let accessory = TestWindow.new(id: 42, parent: ws)
        try await ColumnPolicy.arrive(accessory, on: ws, floatingDefault: true, supervisor: supervisor)
        XCTAssertTrue(accessory.isFloating)
    }

    func testArriveObservesPopupAndKeepsItsClassForAnEmptyResult() async throws {
        let supervisor = try await load("arrive = fun w ctx cols => if w.class == 'app-popup then { run = [\"focus-column 2 --workspace Demo\"] } else { float = true }")
        let ws = demo()
        let anchor = TestWindow.new(id: 98, parent: ws.rootTilingContainer)
        ws.normalizeContainers(); XCTAssertTrue(anchor.focusWindow())
        let popup = TestWindow.new(id: 99, parent: macosPopupWindowsContainer)
        try await ColumnPolicy.arrive(popup, on: ws, floatingDefault: false, supervisor: supervisor)
        XCTAssertTrue(popup.parent === macosPopupWindowsContainer)
        XCTAssertEqual(ws.columns!.focusedSlot, 2)
        XCTAssertNil(supervisor.status.lastError)
    }

    func testRunTargetsPlacedWindowAndDecisionNeverRunsIt() async throws {
        let supervisor = try await load("columns.place = fun w ctx cols => { column = 3, overflow = 'split, run = [\"layout floating\"] }")
        let ws = demo()
        let anchor = TestWindow.new(id: 1, parent: ws.rootTilingContainer)
        ws.enforceColumnInvariant(); XCTAssertTrue(anchor.focusWindow())
        let new = TestWindow.new(id: 2, parent: ws)
        let decision = await ColumnPolicy.decision(window: new, workspace: ws, supervisor: supervisor)
        XCTAssertEqual(decision.run, ["layout floating"])
        XCTAssertTrue(new.isFloating)
        try await ColumnPolicy.place(new, on: ws, supervisor: supervisor)
        XCTAssertTrue(new.isFloating)
        XCTAssertFalse(anchor.isFloating)
        XCTAssertEqual(ws.columns?.slotCount, 3)
    }

    func testWholeHookPrecedenceAndCountOff() async throws {
        let supervisor = try await load("arrive = fun w ctx cols => { float = std.array.length cols == 0 }, columns = { place = fun w ctx cols => { column = 1, overflow = 'float }, when.default.place = fun w ctx cols => { column = 2, overflow = 'split } }, workspace.Demo.columns = { place = fun w ctx cols => { column = 3, overflow = 'squeeze }, when.default.place = fun w ctx cols => { column = 'last, overflow = 'tab-group } }")
        let ws = demo()
        XCTAssertEqual(config.columns.hook("place", workspace: ws.name), "workspace.Demo.columns.when.default.place")
        let new = TestWindow.new(id: 2, parent: ws)
        let decision = await ColumnPolicy.decision(window: new, workspace: ws, supervisor: supervisor)
        XCTAssertEqual(decision.slot, 3); XCTAssertEqual(decision.overflow, "tab-group")
        let plain = Workspace.get(byName: "Plain")
        try await ColumnPolicy.arrive(new, on: plain, floatingDefault: false, supervisor: supervisor)
        XCTAssertTrue(new.isFloating); XCTAssertTrue(new.nodeWorkspace === plain)
    }

    func testRuntimeRaisedAndContractBreakingAndUnavailableKeepWindowPlaced() async throws {
        for expression in ["std.array.at 99 []", "{ column = 2, overflow = 'unknown }", "{ column = 99, overflow = 'float }"] {
            let supervisor = try await load("columns.place = fun w ctx cols => if w.id == 42 then \(expression) else { column = 1, overflow = 'tab-group }")
            let ws = demo(); ws.columns?.focusedSlot = 2
            let window = TestWindow.new(id: 42, parent: ws)
            try await ColumnPolicy.place(window, on: ws, supervisor: supervisor)
            XCTAssertEqual(ws.columnSlot(containing: window), 2)
            XCTAssertNotNil(supervisor.status.lastError)
            window.unbindFromParent()
        }
        let supervisor = NickelSupervisor(settings: .init(executable: { nil }))
        config.columns = ColumnsConfig(.object(["place": .string("columns.place")]), workspaces: nil)
        let ws = demo(); let new = TestWindow.new(id: 50, parent: ws)
        try await ColumnPolicy.place(new, on: ws, supervisor: supervisor)
        XCTAssertNotNil(ws.columnSlot(containing: new))
        XCTAssertNotNil(supervisor.status.lastError)
    }
    private func command(_ raw: String) async throws -> CmdResult {
        try await XCTUnwrap(parseCommand(raw).cmdOrNil).run(.defaultEnv, .emptyStdin)
    }

    func testBoundaryJoinSwapStopWrapNextWorkspaceAndEmptyBypass() async throws {
        for action in ["join", "swap", "stop", "wrap", "next-workspace"] {
            setUpWorkspacesForTests()
            _ = try await load("columns = { move-boundary = fun w ctx cols edge => { action = '\(action), overflow = 'split } }", shared: true)
            let ws = demo("Boundary", count: 2)
            let a = TestWindow.new(id: 1, parent: ws.rootTilingContainer)
            let b = TestWindow.new(id: 2, parent: ws.rootTilingContainer)
            ws.enforceColumnInvariant()
            XCTAssertTrue(a.focusWindow())
            if ["join", "swap"].contains(action) {
                let result = try await command("move right")
                XCTAssertEqual(result.exitCode, 0)
                XCTAssertEqual(ws.columnSlot(containing: a), 2)
                if action == "swap" { XCTAssertEqual(ws.columnSlot(containing: b), 1) }
                else { XCTAssertEqual((a.parent as? TilingContainer)?.layout, .tiles) }
            } else {
                let next = demo("Following")
                TestWindow.new(id: 3, parent: next.rootTilingContainer)
                XCTAssertTrue(b.focusWindow())
                let result = try await command("move right")
                XCTAssertEqual(result.exitCode, 0)
                if action == "stop" { XCTAssertEqual(ws.columnSlot(containing: b), 2) }
                if action == "wrap" { XCTAssertEqual(ws.columnSlot(containing: b), 1) }
                if action == "next-workspace" { XCTAssertFalse(b.nodeWorkspace === ws) }
            }
            for window in [a,b] { window.unbindFromParent() }
            ws.enforceColumnInvariant()
        }
        _ = try await load("columns.move-boundary = fun w ctx cols edge => if w.id == 42 then std.array.at 99 [] else { action = 'stop }", shared: true)
        let ws = demo("Empty", count: 2)
        let new = TestWindow.new(id: 42, parent: ws.rootTilingContainer)
        ws.enforceColumnInvariant(); XCTAssertTrue(new.focusWindow())
        let result = try await command("move right")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(ws.columnSlot(containing: new), 2)
        XCTAssertNil(NickelSupervisor.shared.status.lastError)
    }

    func testSummonPlacesEachMarkedWindowOnceNeverArrivesAndRunsAfterPlacement() async throws {
        _ = try await load("arrive = fun w ctx cols => if w.id == 42 || w.id == 43 then std.array.at 99 [] else {}, workspace.Destination.columns.place = fun w ctx cols => { column = 'last, overflow = 'split, run = [\"column-width next\"] }", shared: true)
        let source = demo("Source")
        let destination = demo("Destination")
        let a = TestWindow.new(id: 42, parent: source.rootTilingContainer)
        let b = TestWindow.new(id: 43, parent: source.rootTilingContainer)
        source.enforceColumnInvariant()
        XCTAssertTrue(destination.focusWorkspace())
        for id in [42,43] {
            let result = try await command("summon --window-id \(id)")
            XCTAssertEqual(result.exitCode, 0)
        }
        XCTAssertTrue(a.nodeWorkspace === destination); XCTAssertTrue(b.nodeWorkspace === destination)
        XCTAssertEqual(destination.columnSlot(containing: a), 3)
        XCTAssertEqual(destination.columnSlot(containing: b), 3)
        XCTAssertEqual(destination.columns!.widths[2], 2.0 / 3, accuracy: 0.000001)
        XCTAssertNil(NickelSupervisor.shared.status.lastError)
    }

    func testWorkspaceMoveRelayoutNativeRestoreAndClosedCacheRunPlaceNeverArrive() async throws {
        _ = try await load("arrive = fun w ctx cols => if w.id == 42 then std.array.at 99 [] else {}, columns.place = fun w ctx cols => { column = 3, overflow = 'tab-group }", shared: true)
        let source = demo("Source")
        let destination = demo("Destination")
        let window = TestWindow.new(id: 42, parent: source.rootTilingContainer)
        source.enforceColumnInvariant(); XCTAssertTrue(window.focusWindow())
        let result = try await command("move-node-to-workspace Destination")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(destination.columnSlot(containing: window), 3)
        window.bindAsFloatingWindow(to: destination)
        try await window.relayoutWindow(on: destination, forceTile: true)
        XCTAssertEqual(destination.columnSlot(containing: window), 3)
        for container: NonLeafTreeNodeObject in [macosMinimizedWindowsContainer, destination.macOsNativeFullscreenWindowsContainer] {
            window.bind(to: container, adaptiveWeight: 1, index: INDEX_BIND_LAST)
            try await exitMacOsNativeUnconventionalState(window: window, prevParentKind: .tilingContainer, prevWorkspaceName: nil, workspace: destination)
            XCTAssertEqual(destination.columnSlot(containing: window), 3)
        }
        syncClosedWindowsCacheToCurrentWorld()
        window.unbindFromParent()
        let restored = TestWindow.new(id: 42, parent: source)
        let didRestore = try await restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: restored)
        XCTAssertTrue(didRestore)
        XCTAssertEqual(destination.columnSlot(containing: restored), 3)
        XCTAssertNil(NickelSupervisor.shared.status.lastError)
    }

    func testSupervisorTimeoutKillAndBadResultRetainBuiltInPlacement() async throws {
        let path = FileManager.default.temporaryDirectory.appending(path: "column-stub-\(UUID())")
        try stubHelperScript.write(to: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
        defer { try? FileManager.default.removeItem(at: path) }
        var settings = NickelSupervisor.Settings()
        settings.executable = { path }
        settings.loadTimeout = .seconds(20)
        let supervisor = NickelSupervisor(settings: settings)
        supervisor.adopt(try await supervisor.load(URL(filePath: "/config/good.ncl")).get())
        config.columns = ColumnsConfig(.object(["place": .string("hang")]), workspaces: nil)
        let ws = demo()
        let timed = TestWindow.new(id: 42, parent: ws)
        try await ColumnPolicy.place(timed, on: ws, supervisor: supervisor)
        XCTAssertEqual(ws.columnSlot(containing: timed), 1)
        XCTAssertTrue(supervisor.status.lastError?.contains(NickelFailure.timedOut.message) == true)
        config.columns = ColumnsConfig(.object(["place": .string("columns.place")]), workspaces: nil)
        supervisor.adopt(try await supervisor.load(URL(filePath: "/config/good.ncl")).get())
        let pid = try XCTUnwrap(supervisor.status.pid)
        XCTAssertEqual(kill(pid, SIGKILL), 0)
        let killed = TestWindow.new(id: 43, parent: ws)
        try await ColumnPolicy.place(killed, on: ws, supervisor: supervisor)
        XCTAssertEqual(ws.columnSlot(containing: killed), 2)
        XCTAssertNotNil(supervisor.status.lastError)
    }

    func testBoundaryNextMonitorUsesTargetWorkspacePlace() async throws {
        _ = try await load("columns = { place = fun w ctx cols => { column = 'last, overflow = 'tab-group }, move-boundary = fun w ctx cols edge => { action = 'next-monitor } }", shared: true)
        let source = demo("First", count: 2), target = demo("Second", count: 3)
        let firstRect = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800)
        let secondRect = Rect(topLeftX: 1000, topLeftY: 0, width: 1000, height: 800)
        let first = TestMonitor(monitorAppKitNsScreenScreensId: 1, name: "First", rect: firstRect, visibleRect: firstRect, isMain: true)
        let second = TestMonitor(monitorAppKitNsScreenScreensId: 2, name: "Second", rect: secondRect, visibleRect: secondRect, isMain: false)
        setMonitorsForTests([first, second])
        _ = first.setActiveWorkspace(source); _ = second.setActiveWorkspace(target)
        let window = TestWindow.new(id: 42, parent: source.rootTilingContainer)
        window.columnSlot = 2; source.enforceColumnInvariant(); XCTAssertTrue(window.focusWindow())
        let result = try await command("move right")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(window.nodeWorkspace === target)
        XCTAssertEqual(target.columnSlot(containing: window), 3)
    }

    func testFloatingShakeAndGroupDropRunPlaceForEveryArrival() async throws {
        _ = try await load("columns.place = fun w ctx cols => { column = 'last, overflow = 'tab-group }", shared: true)
        let source = demo("Source"), destination = demo("Destination")
        let floating = TestWindow.new(id: 40, parent: source)
        try await WindowMouseInteractionDriver.shared.toggleFloatingForShakeWithPolicy(floating, on: source)
        XCTAssertEqual(source.columnSlot(containing: floating), 3)
        let a = TestWindow.new(id: 41, parent: source)
        let b = TestWindow.new(id: 42, parent: source)
        source.bindToColumn(a, slot: 1); source.bindToColumn(b, slot: 1)
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800)
        MousePointerTracker.shared.note(point: rect.center)
        defer { clearPendingWindowDragIntent(); MousePointerTracker.shared.reset() }
        XCTAssertTrue(setPendingWindowDragIntent(sourceWindowId: a.windowId, sourceSubject: .group, detachOrigin: .window,
            destination: WindowDragIntentDestination(kind: .moveToWorkspace(workspaceName: destination.name),
                previewRect: rect, interactionRect: rect, title: "Destination", subtitle: "", previewStyle: .workspaceMove,
                previewGeometry: .rounded, isGroup: true)))
        let applied = try await applyPendingWindowDragIntentWithPolicy()
        XCTAssertTrue(applied)
        XCTAssertTrue(a.nodeWorkspace === destination); XCTAssertTrue(b.nodeWorkspace === destination)
        XCTAssertEqual(destination.columnSlot(containing: a), 3)
        XCTAssertEqual(destination.columnSlot(containing: b), 3)
    }

    func testDryRunCommandDoesNotMoveOrExecuteAndReportsHookFailure() async throws {
        _ = try await load("columns.place = fun w ctx cols => { column = 3, overflow = 'split, run = [\"layout floating\"] }", shared: true)
        let ws = demo()
        let anchor = TestWindow.new(id: 1, parent: ws.rootTilingContainer)
        let window = TestWindow.new(id: 42, parent: ws.rootTilingContainer)
        ws.enforceColumnInvariant(); XCTAssertTrue(anchor.focusWindow())
        let parent = window.parent, widths = ws.columns!.widths
        for flag in ["", " --json"] {
            let result = try await command("place --dry-run --window-id 42" + flag)
            XCTAssertEqual(result.exitCode, 0)
            XCTAssertTrue(window.parent === parent); XCTAssertFalse(window.isFloating)
            XCTAssertEqual(ws.columns!.widths, widths)
            XCTAssertTrue(result.stdout.joined().contains("3"))
        }
        _ = try await load("columns.place = fun w ctx cols => if w.id == 42 then std.array.at 99 [] else { column = 1, overflow = 'tab-group }", shared: true)
        let result = try await command("place --dry-run --window-id 42")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.joined().contains("built-in"))
        XCTAssertTrue(result.stdout.joined().contains("hook failed"))
        let json = try await command("place --dry-run --json --window-id 42")
        XCTAssertEqual(json.exitCode, 0)
        XCTAssertTrue(json.stdout.joined().contains("failure"))
        XCTAssertTrue(json.stdout.joined().contains("nearest-empty"))
        XCTAssertTrue(window.parent === parent)
    }

    func testOffSkipsBothColumnHooksAndColumnRecordsMatchContract() async throws {
        let supervisor = try await load("columns = { place = fun w ctx cols => if w.id == 42 then std.array.at 99 [] else { column = 1, overflow = 'tab-group }, move-boundary = fun w ctx cols edge => if w.id == 42 then std.array.at 99 [] else { action = 'stop } }, arrive = fun w ctx cols => { float = std.array.length cols == 0 }", shared: true)
        let plain = Workspace.get(byName: "Plain")
        let window = TestWindow.new(id: 42, parent: plain.rootTilingContainer)
        let decision = await ColumnPolicy.decision(window: window, workspace: plain, supervisor: supervisor)
        XCTAssertNil(decision.hook); XCTAssertNil(supervisor.status.lastError)
        XCTAssertTrue(window.focusWindow())
        _ = try await command("move right")
        XCTAssertNil(supervisor.status.lastError)
        try await ColumnPolicy.arrive(window, on: plain, floatingDefault: false, supervisor: supervisor)
        XCTAssertTrue(window.isFloating)
        let ws = demo()
        ws.bindToColumn(window, slot: 2)
        let records = try await ws.columnRecords().arrayOrNil!
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[1]["index"], .int(2))
        XCTAssertEqual(records[1]["empty"], .bool(false))
        XCTAssertEqual(records[1]["windows"]?.arrayOrNil?.first?["id"], .int(42))
        XCTAssertEqual(records[0]["empty"], .bool(true))
    }

    func testMalformedHelperResultUsesBuiltInAndRecordsFailure() async throws {
        let path = FileManager.default.temporaryDirectory.appending(path: "column-bad-result-\(UUID())")
        try stubHelperScript.write(to: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
        defer { try? FileManager.default.removeItem(at: path) }
        var settings = NickelSupervisor.Settings(); settings.executable = { path }; settings.loadTimeout = .seconds(20)
        let supervisor = NickelSupervisor(settings: settings)
        supervisor.adopt(try await supervisor.load(URL(filePath: "/config/good.ncl")).get())
        config.columns = ColumnsConfig(.object(["place": .string("columns.place")]), workspaces: nil)
        let ws = demo()
        let window = TestWindow.new(id: 42, parent: ws)
        try await ColumnPolicy.place(window, on: ws, supervisor: supervisor)
        XCTAssertEqual(ws.columnSlot(containing: window), 1)
        XCTAssertTrue(supervisor.status.lastError?.contains("invalid hook result") == true)
        XCTAssertFalse(ColumnPolicy.accepts(.object(["column": .int(1), "overflow": .string("unknown")]), hook: "place"))
        XCTAssertFalse(ColumnPolicy.accepts(.object(["float": .int(1)]), hook: "arrive"))
        XCTAssertFalse(ColumnPolicy.accepts(.object(["action": .string("join"), "run": .array([.int(1)])]), hook: "move-boundary"))
    }

    func testDropAcrossColumnsRunsPlaceOnSameWorkspace() async throws {
        _ = try await load("columns.place = fun w ctx cols => { column = 3, overflow = 'tab-group }", shared: true)
        let ws = demo()
        let a = TestWindow.new(id: 42, parent: ws.rootTilingContainer)
        let b = TestWindow.new(id: 43, parent: ws.rootTilingContainer)
        ws.enforceColumnInvariant()
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800)
        MousePointerTracker.shared.note(point: rect.center)
        defer { clearPendingWindowDragIntent(); MousePointerTracker.shared.reset() }
        XCTAssertTrue(setPendingWindowDragIntent(sourceWindowId: a.windowId, sourceSubject: .window, detachOrigin: .window,
            destination: WindowDragIntentDestination(kind: .tabStack(targetWindowId: b.windowId),
                previewRect: rect, interactionRect: rect, title: "Column", subtitle: "", previewStyle: .tabInsert,
                previewGeometry: .rounded, isGroup: false)))
        let applied = try await applyPendingWindowDragIntentWithPolicy()
        XCTAssertTrue(applied)
        XCTAssertEqual(ws.columnSlot(containing: a), 3)
        XCTAssertEqual(ws.columnSlot(containing: b), 2)
    }

    func testMiniatureLandingPreservesFloatingAndSameWorkspaceGeometry() async throws {
        _ = try await load("columns.place = fun w ctx cols => { column = 3, overflow = 'tab-group }", shared: true)
        let destination = demo("Destination"), source = demo("Source")
        XCTAssertTrue(destination.focusWorkspace())
        let rect = CGRect(x: 0, y: 0, width: 900, height: 600)
        for floating in [true, false] {
            let window = TestWindow.new(id: 42, parent: floating ? source : destination.rootTilingContainer)
            destination.enforceColumnInvariant()
            let frame = CGRect(x: 10, y: 10, width: 200, height: 200)
            let item = SwitcherPaletteItem(id: 42, title: "Guest", appName: "Demo", icon: nil,
                workspaceName: floating ? source.name : destination.name, isFocused: false,
                miniature: MiniatureWindow(workspace: floating ? source.name : destination.name,
                    frame: frame, tray: false, frozen: false, accessory: false, floating: floating, window: window))
            var settings = LensConfig(); settings.presentation = "miniatures"
            let session = LensSession(name: "demo", settings: settings, items: [item], search: "")
            session.miniatureWorkspaces = [MiniatureWorkspace(name: destination.name, title: "Destination", source: rect, current: true)]
            session.summonHeld = true
            XCTAssertEqual(session.miniatureLanding, frame)
            XCTAssertNil(session.landingTask)
            XCTAssertEqual(window.isFloating, floating)
            window.unbindFromParent()
        }
    }

    func testWorkspaceTransferChoosesFocusedColumnBeforeFocusFollows() async throws {
        _ = try await load("workspace.Destination.columns.place = fun w ctx cols => { column = 'focused, overflow = 'tab-group }", shared: true)
        let destination = demo("Destination")
        let anchor = TestWindow.new(id: 1, parent: destination.rootTilingContainer)
        destination.normalizeContainers(); XCTAssertTrue(anchor.focusWindow())
        let source = demo("Source")
        let moved = TestWindow.new(id: 2, parent: source.rootTilingContainer)
        source.normalizeContainers(); XCTAssertTrue(moved.focusWindow())
        let command = try XCTUnwrap(parseCommand("move-node-to-workspace Destination --focus-follows-window --window-id 2").cmdOrNil)
        let result = try await command.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(destination.columnSlot(containing: moved), 1)
        XCTAssertTrue(focus.windowOrNil === moved)
    }

    func testEachPrecedenceLevelReplacesWholePlaceFunction() async throws {
        let definitions = [
            "columns.place = fun w ctx cols => { column = 1, overflow = 'float }",
            "columns.when.default.place = fun w ctx cols => { column = 2, overflow = 'split }",
            "workspace.Demo.columns.place = fun w ctx cols => { column = 3, overflow = 'squeeze }",
            "workspace.Demo.columns.when.default.place = fun w ctx cols => { column = 2, overflow = 'tab-group }",
        ]
        for index in definitions.indices {
            let supervisor = try await load(definitions.prefix(index + 1).joined(separator: ", "))
            let ws = demo()
            let window = TestWindow.new(id: 42, parent: ws)
            let result = await ColumnPolicy.decision(window: window, workspace: ws, supervisor: supervisor)
            XCTAssertEqual(result.slot, [1, 2, 3, 2][index])
            XCTAssertEqual(result.overflow, ["float", "split", "squeeze", "tab-group"][index])
            window.unbindFromParent()
        }
    }

    func testArriveRunFollowsPlaceRunAndTargetsArrival() async throws {
        let supervisor = try await load("arrive = fun w ctx cols => { run = [\"column-width 0.7\"] }, columns.place = fun w ctx cols => { column = 2, overflow = 'tab-group, run = [\"column-width 0.5\"] }")
        let ws = demo()
        let anchor = TestWindow.new(id: 1, parent: ws.rootTilingContainer)
        ws.enforceColumnInvariant(); XCTAssertTrue(anchor.focusWindow())
        let window = TestWindow.new(id: 42, parent: ws)
        try await ColumnPolicy.arrive(window, on: ws, floatingDefault: false, supervisor: supervisor)
        XCTAssertEqual(ws.columnSlot(containing: window), 2)
        XCTAssertEqual(ws.columns!.widths[1], 0.7, accuracy: 0.000001)
        XCTAssertTrue(focus.windowOrNil === anchor)
        XCTAssertNil(supervisor.status.lastError)
    }

    func testPopupPlacementFieldsAreIgnoredButRunExecutes() async throws {
        let supervisor = try await load("arrive = fun w ctx cols => { workspace = \"Other\", float = true, column = 2, run = [\"column-count 2 --workspace Demo\"] }")
        let ws = demo()
        XCTAssertTrue(ws.focusWorkspace())
        let popup = TestWindow.new(id: 42, parent: macosPopupWindowsContainer)
        try await ColumnPolicy.arrive(popup, on: ws, floatingDefault: false, supervisor: supervisor)
        XCTAssertTrue(popup.parent === macosPopupWindowsContainer)
        XCTAssertEqual(ws.columns?.count, 2)
        XCTAssertNil(Workspace.existing(byName: "Other"))
    }

    func testPlaceAcceptsAnUnboundArrivalWithoutEmptyWrappers() async throws {
        for hooked in [false, true] {
            let supervisor = try await load(hooked ? "columns.place = fun w ctx cols => { column = 3, overflow = 'tab-group }" : "")
            let ws = demo()
            let window = TestWindow.new(id: 42, parent: macosPopupWindowsContainer)
            window.unbindFromParent()
            try await ColumnPolicy.place(window, on: ws, supervisor: supervisor)
            XCTAssertEqual(ws.columnSlot(containing: window), hooked ? 3 : 1)
            XCTAssertEqual(ws.rootTilingContainer.children.count, 1)
            if window.isBound { window.unbindFromParent() }; ws.normalizeContainers()
        }
    }

    func testGlobalPlaceLeavesColumnsOffTransferAtRootAppend() async throws {
        _ = try await load("columns.place = fun w ctx cols => { column = 1, overflow = 'float }", shared: true)
        let ws = Workspace.get(byName: "Plain")
        let first = TestWindow.new(id: 1, parent: ws.rootTilingContainer)
        _ = TestWindow.new(id: 2, parent: ws.rootTilingContainer)
        XCTAssertTrue(first.focusWindow())
        let source = demo("Source")
        _ = TestWindow.new(id: 42, parent: source.rootTilingContainer)
        let result = try await command("move-node-to-workspace Plain --window-id 42")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(ws.rootTilingContainer.children.map { ($0 as? Window)?.windowId }, [1, 2, 42])
        XCTAssertNil(NickelSupervisor.shared.status.lastError)
    }

    func testUnboundDuringRecordAwaitDoesNotMutatePlaceArriveOrMove() async throws {
        for action in ["place", "arrive", "move"] {
            let supervisor = try await load("arrive = fun w ctx cols => { float = true }, columns = { place = fun w ctx cols => { column = 2, overflow = 'tab-group }, move-boundary = fun w ctx cols edge => { action = 'join } }", shared: true)
            let ws = demo()
            let window = TestWindow.new(id: 42, parent: ws.rootTilingContainer)
            _ = TestWindow.new(id: 43, parent: ws.rootTilingContainer)
            ws.enforceColumnInvariant(); XCTAssertTrue(window.focusWindow())
            window.beforeAxRecord = { window.beforeAxRecord = nil; if window.isBound { window.unbindFromParent() } }
            switch action {
                case "place": try await ColumnPolicy.place(window, on: ws, supervisor: supervisor)
                case "arrive": try await ColumnPolicy.arrive(window, on: ws, floatingDefault: false, supervisor: supervisor)
                default:
                    let move = MoveCommand(args: MoveCmdArgs(rawArgs: [], .right))
                    _ = try await move.run(.defaultEnv.copy(\.windowId, 42), CmdIo(stdin: .emptyStdin))
            }
            XCTAssertFalse(window.isBound, action)
        }
    }

    func testDirectMoveRunConsultsBoundaryHook() async throws {
        _ = try await load("columns.move-boundary = fun w ctx cols edge => { action = 'swap }", shared: true)
        let ws = demo()
        let a = TestWindow.new(id: 42, parent: ws.rootTilingContainer)
        let b = TestWindow.new(id: 43, parent: ws.rootTilingContainer)
        ws.enforceColumnInvariant(); XCTAssertTrue(a.focusWindow())
        _ = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.defaultEnv, CmdIo(stdin: .emptyStdin))
        XCTAssertEqual(ws.columnSlot(containing: a), 2)
        XCTAssertEqual(ws.columnSlot(containing: b), 1)
    }

    func testSummonPreservesFloatingAndDoesNotReplaceSameWorkspaceWindow() async throws {
        _ = try await load("columns.place = fun w ctx cols => { column = 3, overflow = 'tab-group }", shared: true)
        let target = demo("Target"), source = demo("Source")
        let anchor = TestWindow.new(id: 1, parent: target.rootTilingContainer)
        target.enforceColumnInvariant(); XCTAssertTrue(anchor.focusWindow())
        let floating = TestWindow.new(id: 42, parent: source)
        _ = try await command("summon --window-id 42")
        XCTAssertTrue(floating.isFloating); XCTAssertTrue(floating.nodeWorkspace === target)
        _ = try await command("summon --window-id 1")
        XCTAssertEqual(target.columnSlot(containing: anchor), 1)
    }

    func testLastTargetsConfiguredCountWithSqueezePresent() async throws {
        let supervisor = try await load("columns.place = fun w ctx cols => { column = 'last, overflow = 'tab-group }")
        let ws = demo()
        let anchor = TestWindow.new(id: 1, parent: ws)
        ws.bindToColumn(anchor, slot: 1)
        let squeezed = TestWindow.new(id: 2, parent: ws)
        ws.bindToColumn(squeezed, slot: 1, overflow: "squeeze")
        let window = TestWindow.new(id: 42, parent: ws)
        let result = await ColumnPolicy.decision(window: window, workspace: ws, supervisor: supervisor)
        XCTAssertEqual(ws.columns?.slotCount, 4)
        XCTAssertEqual(result.slot, 3)
    }

    func testPopupPromotionRunsArriveAgainWithRealClassBeforePlace() async throws {
        _ = try await load("arrive = fun w ctx cols => if w.class == 'tiled then { workspace = \"Promoted\" } else { workspace = \"Wrong\", float = true, column = 2 }, workspace.Promoted.columns.place = fun w ctx cols => { column = 3, overflow = 'tab-group }", shared: true)
        let detected = demo(), destination = demo("Promoted")
        XCTAssertTrue(detected.focusWorkspace())
        let popup = TestWindow.new(id: 42, parent: macosPopupWindowsContainer)
        popup.testNativeWindowType = .popup
        try await ColumnPolicy.arrive(popup, on: detected, floatingDefault: false)
        XCTAssertTrue(popup.parent === macosPopupWindowsContainer)
        popup.testNativeWindowType = .window
        try await validateStillPopups()
        XCTAssertTrue(popup.nodeWorkspace === destination)
        XCTAssertEqual(destination.columnSlot(containing: popup), 3)
        let parent = popup.parent
        try await validateStillPopups()
        XCTAssertTrue(popup.parent === parent)
    }

    func testRelayoutClassificationOnAllThreeRestorationPaths() async throws {
        for hooked in [false, true] {
            _ = try await load(hooked ? "columns.place = fun w ctx cols => { column = 3, overflow = 'tab-group }" : "", shared: true)
            let ws = demo()
            XCTAssertTrue(ws.focusWorkspace())
            for path in ["promotion", "fullscreen-command", "native-state"] {
                let window = TestWindow.new(id: 42, parent: macosPopupWindowsContainer)
                window.testNativeWindowType = .window
                if path == "promotion" {
                    try await validateStillPopups()
                } else {
                    window.bind(to: ws.macOsNativeFullscreenWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
                    if path == "fullscreen-command" {
                        window.nativeIsMacosFullscreen = true
                        _ = try await command("macos-native-fullscreen off --window-id 42")
                    } else {
                        try await exitMacOsNativeUnconventionalState(window: window, prevParentKind: .macosPopupWindowsContainer, prevWorkspaceName: nil, workspace: ws)
                    }
                }
                XCTAssertEqual(ws.columnSlot(containing: window), hooked ? 3 : 1, path)
                XCTAssertEqual(ws.rootTilingContainer.children.count, 1, path)
                window.unbindFromParent(); ws.normalizeContainers()
            }
        }
    }

    func testNestedRunPlacesWindowButTerminatesPingPong() async throws {
        _ = try await load("workspace.Ping.columns.place = fun w ctx cols => { column = 2, overflow = 'tab-group, run = [\"move-node-to-workspace Pong\"] }, workspace.Pong.columns.place = fun w ctx cols => { column = 3, overflow = 'tab-group, run = [\"move-node-to-workspace Ping\"] }", shared: true)
        let ping = demo("Ping"), pong = demo("Pong")
        let window = TestWindow.new(id: 42, parent: ping)
        try await ColumnPolicy.place(window, on: ping)
        XCTAssertTrue(window.nodeWorkspace === pong)
        XCTAssertEqual(pong.columnSlot(containing: window), 3)
        XCTAssertTrue(NickelSupervisor.shared.status.lastError?.contains("nested run list suppressed") == true)
    }

    func testGlobalPlacePreservesColumnsOffDropAndFrozenRestore() async throws {
        _ = try await load("columns.place = fun w ctx cols => { column = 1, overflow = 'float }", shared: true)
        let ws = Workspace.get(byName: "Plain")
        let a = TestWindow.new(id: 1, parent: ws.rootTilingContainer)
        let b = TestWindow.new(id: 2, parent: ws.rootTilingContainer)
        let source = demo("Source")
        let window = TestWindow.new(id: 42, parent: source.rootTilingContainer)
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800)
        MousePointerTracker.shared.note(point: rect.center)
        defer { clearPendingWindowDragIntent(); MousePointerTracker.shared.reset() }
        XCTAssertTrue(setPendingWindowDragIntent(sourceWindowId: 42, sourceSubject: .window, detachOrigin: .window,
            destination: WindowDragIntentDestination(kind: .tabStack(targetWindowId: b.windowId), previewRect: rect, interactionRect: rect, title: "Target", subtitle: "", previewStyle: .tabInsert, previewGeometry: .rounded, isGroup: false)))
        let applied = try await applyPendingWindowDragIntentWithPolicy()
        XCTAssertTrue(applied)
        XCTAssertTrue(window.parent === b.parent)
        XCTAssertFalse(window.parent === a.parent)
        XCTAssertFalse(window.isFloating)
        syncClosedWindowsCacheToCurrentWorld()
        window.unbindFromParent()
        // Unit-test lookup walks live trees; keep the other windows discoverable while the frozen root is rebuilt.
        a.bindAsFloatingWindow(to: source); b.bindAsFloatingWindow(to: source)
        let restored = TestWindow.new(id: 42, parent: source)
        let didRestore = try await restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: restored)
        XCTAssertTrue(didRestore)
        XCTAssertTrue(restored.parent === b.parent)
        XCTAssertFalse(restored.parent === a.parent)
        XCTAssertFalse(restored.isFloating)
        XCTAssertNil(NickelSupervisor.shared.status.lastError)
    }

    func testStackWithMovePathConsultsBoundaryHook() async throws {
        _ = try await load("columns.move-boundary = fun w ctx cols edge => { action = 'swap }", shared: true)
        let ws = demo()
        let a = TestWindow.new(id: 42, parent: ws)
        let b = TestWindow.new(id: 43, parent: ws)
        let c = TestWindow.new(id: 44, parent: ws)
        ws.bindToColumn(a, slot: 1); ws.bindToColumn(b, slot: 1); ws.bindToColumn(c, slot: 2)
        XCTAssertTrue(b.focusWindow())
        let result = try await command("stack-with left")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(ws.columnSlot(containing: c), 3)
        XCTAssertEqual(ws.columnSlot(containing: b), 2)
    }

    func testColumnRecordsOverlapAccessibilityReads() async throws {
        let ws = demo()
        let allStarted = expectation(description: "Ten overlapping native record reads")
        allStarted.expectedFulfillmentCount = 10
        var continuations: [CheckedContinuation<Void, Never>] = []
        var released = false
        for id in 1...10 {
            let window = TestWindow.new(id: UInt32(id), parent: ws.rootTilingContainer)
            window.beforeAxRecord = {
                window.beforeAxRecord = nil
                allStarted.fulfill()
                if !released { await withCheckedContinuation { continuations.append($0) } }
            }
        }
        ws.normalizeContainers()
        let read = Task { @MainActor in try await ws.columnRecords() }
        await fulfillment(of: [allStarted], timeout: 2)
        released = true
        for continuation in continuations { continuation.resume() }
        let records = try await read.value
        XCTAssertEqual(records.arrayOrNil?.flatMap { $0["windows"]?.arrayOrNil ?? [] }.count, 10)
    }

    func testLandingCancelsOldSelectionAndReadsColumnsOncePerSession() async throws {
        _ = try await load("columns.place = fun w ctx cols => { column = if w.id == 42 then 2 else 3, overflow = 'tab-group }", shared: true)
        let destination = demo("Destination"), source = demo("Source")
        XCTAssertTrue(destination.focusWorkspace())
        var columnReads = 0
        let anchor = TestWindow.new(id: 1, parent: destination.rootTilingContainer)
        let unrelated = TestWindow.new(id: 2, parent: destination.rootTilingContainer)
        unrelated.beforeAxRecord = { columnReads += 1 }
        destination.enforceColumnInvariant()
        XCTAssertTrue(anchor.focusWindow())
        let a = TestWindow.new(id: 42, parent: source.rootTilingContainer)
        let b = TestWindow.new(id: 43, parent: source.rootTilingContainer)
        source.enforceColumnInvariant()
        let started = expectation(description: "First selection record pending")
        var pending: CheckedContinuation<Void, Never>?
        a.beforeAxRecord = {
            a.beforeAxRecord = nil
            started.fulfill()
            await withCheckedContinuation { pending = $0 }
        }
        var settings = LensConfig(); settings.presentation = "miniatures"
        let rect = CGRect(x: 0, y: 0, width: 900, height: 600)
        let items = [a,b].map { window in
            SwitcherPaletteItem(id: window.windowId, title: "Guest", appName: "Demo", icon: nil, workspaceName: source.name, isFocused: false,
                miniature: MiniatureWindow(workspace: source.name, frame: rect, tray: false, frozen: false, accessory: false, floating: false, window: window))
        }
        let session = LensSession(name: "demo", settings: settings, items: items, search: "")
        session.miniatureWorkspaces = [MiniatureWorkspace(name: destination.name, title: "Destination", source: rect, current: true)]
        session.selection = 0; session.summonHeld = true
        await fulfillment(of: [started], timeout: 2)
        let oldTask = session.landingTask
        session.selection = 1
        XCTAssertTrue(oldTask?.isCancelled == true)
        XCTAssertNil(session.miniatureLanding)
        pending?.resume()
        await oldTask?.value
        await session.landingTask?.value
        XCTAssertEqual(session.miniatureLanding?.maxX, 900)
        session.selection = 0
        await session.landingTask?.value
        XCTAssertEqual(columnReads, 1)
        session.cancelLanding()
    }

    func testMouseUpWaitsForPendingShakePlacement() async throws {
        let driver = WindowMouseInteractionDriver.shared
        let started = expectation(description: "Shake placement pending")
        var resume: CheckedContinuation<Void, Never>?
        driver.shakePlacementTask = Task { @MainActor in
            started.fulfill()
            await withCheckedContinuation { resume = $0 }
        }
        await fulfillment(of: [started], timeout: 2)
        var flushed = false
        let flush = Task { @MainActor in await driver.flushBeforeMouseUp(); flushed = true }
        await Task.yield()
        XCTAssertFalse(flushed)
        resume?.resume()
        await flush.value
        XCTAssertTrue(flushed)
        driver.shakePlacementTask = nil
    }

    func testWindowUnboundWhileHelperReplyIsSuspended() async throws {
        for action in ["place", "arrive", "move-join", "move-wrap"] {
            let directory = FileManager.default.temporaryDirectory.appending(path: "policy-reply-\(UUID())")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let marker = directory.appending(path: "requested"), release = directory.appending(path: "release")
            try Data().write(to: marker)
            let hookBody = """
                elif op == "hook":
                    open("\(marker.path)", "w").write("requested")
                    while not os.path.exists("\(release.path)"):
                        time.sleep(0.001)
                    if request["hook"] == "arrive":
                        result = {"float": True}
                    elif request["hook"].endswith("move-boundary"):
                        result = {"action": "\(action == "move-wrap" ? "wrap" : "join")"}
                    else:
                        result = {"column": 2, "overflow": "split"}
                """
            let helper = directory.appending(path: "helper")
            let start = stubHelperScript.range(of: "elif op == \"hook\":")!.lowerBound
            let end = stubHelperScript.range(of: "    reply =")!.lowerBound
            let script = String(stubHelperScript[..<start]) + hookBody.replacingOccurrences(of: "\n", with: "\n    ") + "\n" + String(stubHelperScript[end...])
            try script.write(to: helper, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
            var settings = NickelSupervisor.Settings(); settings.executable = { helper }
            let supervisor = action.hasPrefix("move") ? NickelSupervisor.shared : NickelSupervisor(settings: settings)
            if action.hasPrefix("move") {
                let loader = NickelSupervisor(settings: settings)
                supervisor.adopt(try await loader.load(URL(filePath: "/config/good.ncl")).get())
            } else { supervisor.adopt(try await supervisor.load(URL(filePath: "/config/good.ncl")).get()) }
            config.arrive = "arrive"
            config.columns = ColumnsConfig(.object(["place": .string("columns.place"), "move-boundary": .string("columns.move-boundary")]), workspaces: nil)
            let ws = demo()
            let window = TestWindow.new(id: 42, parent: ws.rootTilingContainer)
            window.columnSlot = action == "move-wrap" ? 3 : 1
            _ = TestWindow.new(id: 43, parent: ws.rootTilingContainer)
            ws.enforceColumnInvariant(); XCTAssertTrue(window.focusWindow())
            let requested = expectation(description: "Helper is awaiting its reply release")
            let descriptor = open(marker.path, O_EVTONLY)
            XCTAssertGreaterThanOrEqual(descriptor, 0)
            let watcher = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
            watcher.setEventHandler { requested.fulfill(); watcher.cancel() }
            watcher.setCancelHandler { close(descriptor) }
            watcher.resume()
            let task = Task { @MainActor in
                switch action {
                    case "place": try await ColumnPolicy.place(window, on: ws, supervisor: supervisor)
                    case "arrive": try await ColumnPolicy.arrive(window, on: ws, floatingDefault: false, supervisor: supervisor)
                    default: _ = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.defaultEnv, CmdIo(stdin: .emptyStdin))
                }
            }
            await fulfillment(of: [requested], timeout: 2)
            if window.isBound { window.unbindFromParent() }
            try Data().write(to: release)
            try await task.value
            XCTAssertFalse(window.isBound, action)
            watcher.cancel()
        }
    }

    func testArriveSkipsRunWhenDestinationPlaceWasAbandoned() async throws {
        let supervisor = try await load("arrive = fun w ctx cols => { run = [\"column-count 2 --workspace Demo\"] }, columns.place = fun w ctx cols => { column = 3, overflow = 'tab-group }", shared: true)
        let ws = demo()
        let other = Workspace.get(byName: "Other")
        let anchor = TestWindow.new(id: 1, parent: ws.rootTilingContainer)
        ws.enforceColumnInvariant()
        XCTAssertTrue(anchor.focusWindow())
        let window = TestWindow.new(id: 42, parent: ws)
        let placing = expectation(description: "Arrival is collecting Place arguments")
        var reads = 0
        var release: CheckedContinuation<Void, Never>?
        window.beforeAxRecord = {
            reads += 1
            if reads == 2 {
                await withCheckedContinuation { continuation in release = continuation; placing.fulfill() }
            }
        }
        let arrival = Task { @MainActor in try await ColumnPolicy.arrive(window, on: ws, floatingDefault: false, supervisor: supervisor) }
        await fulfillment(of: [placing], timeout: 2)
        window.bindAsFloatingWindow(to: other)
        release?.resume()
        try await arrival.value
        XCTAssertTrue(window.nodeWorkspace === other)
        XCTAssertEqual(ws.columns?.count, 3)
        XCTAssertNil(supervisor.status.lastError)
    }

}
