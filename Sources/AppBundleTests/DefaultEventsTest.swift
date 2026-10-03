@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor
final class DefaultEventsTest: XCTestCase {
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

    func testOneLensPairAcrossSearchAndPresentationChangesAndEveryDismissal() throws {
        for presentation in ["list", "strip", "miniatures"] {
            for reason in ["Escape", "click", "release", "global binding", "closeLens"] {
                var events: [ServerEvent] = []
                let lifecycle = LensLifecycle(emit: { events.append($0) })
                var settings = LensConfig(); settings.presentation = presentation
                let ticket = try XCTUnwrap(lifecycle.begin("recent", toggle: true))
                let session = LensSession(name: "recent", settings: settings, items: [], search: "")
                XCTAssertTrue(lifecycle.complete(session, ticket: ticket))
                session.query = "Demo"
                session.changePresentation("list")
                XCTAssertEqual(events.count, 1, reason)
                lifecycle.dismiss()
                lifecycle.dismiss()
                XCTAssertEqual(events.map(\.eventType), [.lensOpened, .lensClosed], reason)
            }
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
        lifecycle.dismiss()
        for event in events { XCTAssertEqual(try json(event)["filter"] as? String, "same-app") }
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

    func testReloadResultsEmitOnlyForCompletedAttempts() throws {
        var events: [ServerEvent] = []
        let emit: (ServerEvent) -> Void = { events.append($0) }
        for trigger in [ConfigReloadTrigger.command, .fileChange] {
            var result = ConfigReloadEvent(configPath: "/demo/config.ncl", emit: emit)
            result.finish(error: nil, dryRun: false, superseded: false)
            result.finish(error: "ignored duplicate", dryRun: false, superseded: false)
            var failed = ConfigReloadEvent(configPath: "/demo/config.ncl", emit: emit)
            failed.finish(error: "bad config", dryRun: false, superseded: false)
            XCTAssertEqual(events.count, trigger == .command ? 2 : 4)
        }
        for (dry, superseded) in [(true, false), (false, true)] {
            var result = ConfigReloadEvent(configPath: "/demo/config.ncl", emit: emit)
            result.finish(error: nil, dryRun: dry, superseded: superseded)
        }
        XCTAssertEqual(events.count, 4)
    }
}
