@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor
final class DefaultEventsTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        appForTests = TestApp.shared
    }
    private func json(_ event: ServerEvent) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any])
    }

    func testPayloadsHaveExactlyTheirDocumentedKeysIncludingNulls() throws {
        let success = try json(.configReloaded(ok: true, error: nil, configPath: "/demo/defaults.ncl"))
        XCTAssertEqual(Set(success.keys), ["_event", "ok", "error", "configPath"])
        XCTAssertEqual(success["ok"] as? Bool, true)
        XCTAssertTrue(success["error"] is NSNull)
        let failed = try json(.configReloaded(ok: false, error: "bad config", configPath: "/demo/config.ncl"))
        XCTAssertEqual(failed["error"] as? String, "bad config")
        for opened in [true, false] {
            let named = try json(.lensEvent(opened: opened, lens: "search", filter: nil))
            XCTAssertEqual(Set(named.keys), ["_event", "lens"])
            XCTAssertEqual(named["lens"] as? String, "search")
            let adhoc = try json(.lensEvent(opened: opened, lens: nil, filter: "w.class == 'floating"))
            XCTAssertEqual(Set(adhoc.keys), ["_event", "lens", "filter"])
            XCTAssertTrue(adhoc["lens"] is NSNull)
            XCTAssertEqual(adhoc["filter"] as? String, "w.class == 'floating")
        }
        let columns = try json(.columnsChanged(workspace: "Demo", count: 3, widths: [1.0 / 3, 1.0 / 3, 1.0 / 3], occupied: [1, 3]))
        XCTAssertEqual(Set(columns.keys), ["_event", "workspace", "count", "widths", "occupied"])
        XCTAssertEqual(columns["occupied"] as? [Int], [1, 3])
    }

    func testOriginalEventPayloadsKeepTheirKeysAndOptionalOmissions() throws {
        let cases: [(ServerEvent, Set<String>)] = [
            (.focusChanged(windowId: nil, workspace: "Demo"), ["_event", "workspace"]),
            (.focusedMonitorChanged(workspace: "Demo", monitorId_oneBased: 1), ["_event", "workspace", "monitorId"]),
            (.workspaceChanged(workspace: "Demo", prevWorkspace: "Other"), ["_event", "workspace", "prevWorkspace"]),
            (.modeChanged(mode: nil), ["_event"]),
            (.windowDetected(windowId: 42, workspace: "Demo", appBundleId: "org.example.Demo", appName: "Demo"),
             ["_event", "windowId", "workspace", "appBundleId", "appName"]),
            (.bindingTriggered(mode: "main", binding: "alt-slash"), ["_event", "mode", "binding"]),
        ]
        for (event, keys) in cases { XCTAssertEqual(Set(try json(event).keys), keys) }
    }

    func testAllIncludesTenEventsAndNewEventsParse() throws {
        let names = ["config-reloaded", "lens-opened", "lens-closed", "columns-changed"]
        for raw in [["--all"], names] {
            guard case .cmd(let args) = parseSubscribeCmdArgs(raw.slice) else { return XCTFail("Cannot subscribe") }
            XCTAssertTrue(Set(names).isSubset(of: Set(args.events.map(\.rawValue))))
            if raw == ["--all"] { XCTAssertEqual(args.events.count, 10) }
        }
    }

    func testOneLensPairAcrossSearchAndPresentationChangesAndRepeatedDismissal() throws {
        for presentation in ["list", "strip", "miniatures"] {
            var events: [ServerEvent] = []
            let lifecycle = LensLifecycle(emit: { events.append($0) })
            var settings = LensConfig(); settings.presentation = presentation
            let ticket = try XCTUnwrap(lifecycle.begin("recent", toggle: true))
            let session = LensSession(name: "recent", settings: settings, items: [], search: "")
            XCTAssertTrue(lifecycle.complete(session, ticket: ticket))
            lifecycle.presented(session)
            session.query = "Demo"
            session.changePresentation("list")
            XCTAssertEqual(events.count, 1)
            lifecycle.dismiss()
            lifecycle.dismiss()
            XCTAssertEqual(events.map(\.eventType), [.lensOpened, .lensClosed])
        }
        var events: [ServerEvent] = []
        let lifecycle = LensLifecycle(emit: { events.append($0) })
        let ticket = try XCTUnwrap(lifecycle.begin("bad", toggle: false))
        lifecycle.cancelOpening(ticket: ticket)
        let late = LensSession(name: "bad", settings: LensConfig(), items: [], search: "")
        XCTAssertFalse(lifecycle.complete(late, ticket: ticket))
        XCTAssertTrue(events.isEmpty)
        let adhocTicket = try XCTUnwrap(lifecycle.begin("<ad-hoc>", toggle: false))
        let adhoc = LensSession(name: "<ad-hoc>", settings: LensConfig(), items: [], search: "", eventFilter: "same-app")
        XCTAssertTrue(lifecycle.complete(adhoc, ticket: adhocTicket))
        lifecycle.presented(adhoc)
        lifecycle.dismiss()
        for event in events { XCTAssertEqual(try json(event)["filter"] as? String, "same-app") }
    }

    func testPanelDismissalRoutesEachEmitExactlyOnePair() async throws {
        setUpWorkspacesForTests()
        _ = NSApplication.shared
        for route in ["Escape", "click", "release", "global binding", "closeLens", "handoff"] {
            var events: [ServerEvent] = []
            let panel = SwitcherPalettePanel(emit: { events.append($0) })
            defer { panel.dismiss() }
            var settings = LensConfig()
            settings.presentation = ["release", "global binding", "handoff"].contains(route) ? "strip" : "list"
            let ticket = try XCTUnwrap(panel.beginLens("recent", toggle: false))
            await panel.openLens(name: "recent", settings: settings, entries: [], search: nil, banner: nil, context: .null, ticket: ticket)
            XCTAssertEqual(events.map(\.eventType), [.lensOpened], route)
            switch route {
                case "Escape":
                    let escape = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                        windowNumber: panel.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 53))
                    panel.sendEvent(escape)
                case "click":
                    let click = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0,
                        windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
                    panel.session?.onAction?(try XCTUnwrap(panel.session?.key(for: click, click: true)))
                case "release":
                    panel.session?.beginStrip(StripGesture(keyCode: 48, invoking: .command, openedAt: 0))
                    panel.stripFlagsChanged([])
                case "global binding":
                    panel.session?.beginStrip(StripGesture(keyCode: 48, invoking: .command, openedAt: 0))
                    XCTAssertFalse(panel.handleStripHotkey(keyCode: 37, modifiers: [.command, .control], characters: "l"))
                case "handoff":
                    panel.changePresentationToList()
                    panel.session?.query = "Demo"
                    XCTAssertEqual(events.map(\.eventType), [.lensOpened])
                    panel.dismiss()
                default: panel.dismiss()
            }
            panel.dismiss()
            XCTAssertEqual(events.map(\.eventType), [.lensOpened, .lensClosed], route)
            XCTAssertNil(panel.session, route)
        }
    }

    func testColumnsChangesIgnoreInitialRefreshAndWorkspaceSwitchButObserveOff() throws {
        setUpWorkspacesForTests()
        let ws = focus.workspace
        var tracker = ColumnsEventTracker()
        XCTAssertNil(tracker.event(for: ws))
        ws.columns = ColumnState(count: 3)
        XCTAssertEqual(try json(XCTUnwrap(tracker.event(for: ws)))["count"] as? Int, 3)
        XCTAssertNil(tracker.event(for: ws))
        let window = TestWindow.new(id: 1, parent: ws.rootTilingContainer)
        ws.normalizeContainers()
        XCTAssertEqual(try json(XCTUnwrap(tracker.event(for: ws)))["occupied"] as? [Int], [1])
        let drag = ColumnDividerResizeSession(workspace: ws, slot: 1, startX: 300)
        _ = drag.proposal(pointerX: 450)
        XCTAssertNil(tracker.event(for: ws), "divider previews do not mutate Columns")
        drag.commit(pointerX: 450)
        XCTAssertNotNil(tracker.event(for: ws))
        XCTAssertNil(tracker.event(for: ws))
        ws.columns?.widths = [0.5, 0.25, 0.25]
        XCTAssertNotNil(tracker.event(for: ws))
        XCTAssertNil(tracker.event(for: Workspace.get(byName: "Other")))
        XCTAssertNil(tracker.event(for: ws))
        window.unbindFromParent()
        ws.normalizeContainers()
        XCTAssertEqual(try json(XCTUnwrap(tracker.event(for: ws)))["occupied"] as? [Int], [])
        ws.columns = nil
        let off = try json(XCTUnwrap(tracker.event(for: ws)))
        XCTAssertEqual(off["count"] as? Int, 0)
        XCTAssertEqual(off["widths"] as? [Double], [])
        XCTAssertEqual(off["occupied"] as? [Int], [])
        XCTAssertNil(tracker.event(for: ws))
    }

    func testColumnFillAndFocusFollowUsesDestinationBaseline() async throws {
        setUpWorkspacesForTests()
        let source = focus.workspace
        let destination = Workspace.get(byName: "Destination")
        source.columns = ColumnState(count: 3)
        destination.columns = ColumnState(count: 3)
        let window = TestWindow.new(id: 42, parent: source.rootTilingContainer)
        source.normalizeContainers()
        _ = setFocus(to: window.toLiveFocusOrNil()!)
        var tracker = ColumnsEventTracker()
        XCTAssertNil(tracker.event(for: source))
        let result = try await parseCommand("move-node-to-workspace --focus-follows-window Destination --window-id 42").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        source.normalizeContainers(); destination.normalizeContainers()
        XCTAssertEqual(focus.workspace.name, "Destination")
        let event = try json(XCTUnwrap(tracker.event(for: destination)))
        XCTAssertEqual(event["workspace"] as? String, "Destination")
        XCTAssertEqual(event["occupied"] as? [Int], [1])
        XCTAssertNil(tracker.event(for: source))
        XCTAssertNil(tracker.event(for: destination))
    }

    func testNewWindowTakingFocusAndRemovedWorkspaceBaselines() throws {
        setUpWorkspacesForTests()
        let first = focus.workspace
        let other = Workspace.get(byName: "Other")
        other.columns = ColumnState(count: 2)
        var tracker = ColumnsEventTracker()
        XCTAssertNil(tracker.event(for: first))
        let window = TestWindow.new(id: 77, parent: other.rootTilingContainer)
        other.normalizeContainers()
        _ = setFocus(to: window.toLiveFocusOrNil()!)
        XCTAssertEqual(try json(XCTUnwrap(tracker.event(for: other)))["occupied"] as? [Int], [1])
        XCTAssertNil(tracker.event(for: first))
        XCTAssertNil(tracker.event(for: first, workspaces: [first]))
        other.columns?.widths = [0.75, 0.25]
        XCTAssertEqual(try json(XCTUnwrap(tracker.event(for: other)))["occupied"] as? [Int], [1])
    }

    func testWorkspaceCreatedByAFocusFollowingMoveEmitsItsFilledColumn() throws {
        setUpWorkspacesForTests()
        let source = focus.workspace
        var tracker = ColumnsEventTracker()
        XCTAssertNil(tracker.event(for: source, workspaces: [source]))
        let created = Workspace.get(byName: "Created")
        created.columns = ColumnState(count: 3)
        XCTAssertNil(tracker.event(for: created, workspaces: [source, created]))
        let filled = Workspace.get(byName: "Filled")
        filled.columns = ColumnState(count: 3)
        TestWindow.new(id: 91, parent: filled.rootTilingContainer)
        filled.normalizeContainers()
        let event = try json(XCTUnwrap(tracker.event(for: filled, workspaces: [source, created, filled])))
        XCTAssertEqual(event["workspace"] as? String, "Filled")
        XCTAssertEqual(event["occupied"] as? [Int], [1])
    }

    func testTrackingEmptyColumnsDoesNotCreateATilingRoot() {
        setUpWorkspacesForTests()
        let empty = Workspace.get(byName: "Empty")
        empty.columns = ColumnState(count: 3)
        XCTAssertTrue(empty.children.isEmpty)
        var tracker = ColumnsEventTracker()
        XCTAssertNil(tracker.event(for: empty))
        XCTAssertTrue(empty.children.isEmpty)
    }

    func testReloadResultFunctionSuccessFailureAndDryRun() throws {
        let success = try json(XCTUnwrap(configReloadEvent(dryRun: false, error: nil, configPath: "/demo/good.ncl")))
        XCTAssertEqual(success["ok"] as? Bool, true)
        XCTAssertTrue(success["error"] is NSNull)
        XCTAssertEqual(success["configPath"] as? String, "/demo/good.ncl")
        let failure = try json(XCTUnwrap(configReloadEvent(dryRun: false, error: "bad config", configPath: "/demo/bad.ncl")))
        XCTAssertEqual(failure["ok"] as? Bool, false)
        XCTAssertEqual(failure["error"] as? String, "bad config")
        XCTAssertEqual(failure["configPath"] as? String, "/demo/bad.ncl")
        XCTAssertNil(configReloadEvent(dryRun: true, error: nil, configPath: "/demo/dry.ncl"))
        XCTAssertNil(configReloadEvent(dryRun: true, error: "bad", configPath: "/demo/dry.ncl"))
    }

    func testStripReleasedBeforeDelayEmitsNeitherEvent() async throws {
        setUpWorkspacesForTests()
        _ = NSApplication.shared
        var events: [ServerEvent] = []
        let panel = SwitcherPalettePanel(emit: { events.append($0) })
        var settings = LensConfig(); settings.presentation = "strip"
        let invocation = StripGesture(keyCode: 48, invoking: .command, openedAt: ProcessInfo.processInfo.systemUptime)
        let ticket = try XCTUnwrap(panel.beginLens("recent", toggle: false, strip: invocation))
        panel.stripFlagsChanged([])
        await panel.openLens(name: "recent", settings: settings, entries: [], search: nil, banner: nil, context: .null, ticket: ticket, invocation: invocation)
        XCTAssertNil(panel.session)
        XCTAssertFalse(panel.isVisible)
        XCTAssertTrue(events.isEmpty)
        panel.dismiss()
        XCTAssertTrue(events.isEmpty)
    }
}
