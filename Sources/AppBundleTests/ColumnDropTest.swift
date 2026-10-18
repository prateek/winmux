@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor
final class ColumnDropTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        config.workspaceSidebar.enabled = false
        PolicyHooks.setOverrideForTests(ControlledPolicyHooks())
    }

    override func tearDown() async throws {
        clearPendingWindowDragIntent()
        cancelManipulatedWithMouseState()
        MousePointerTracker.shared.reset()
        PolicyHooks.setOverrideForTests(nil)
    }

    private func fixture(columns: Bool = true) async throws -> (Workspace, TestWindow, TestWindow, CGRect) {
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800)
        let monitor = TestMonitor(monitorAppKitNsScreenScreensId: 1, name: "Test", rect: rect, visibleRect: rect, isMain: true)
        setMonitorsForTests([monitor])
        config.gaps.inner.horizontal = .constant(20)
        config.gaps.inner.vertical = .constant(12)
        config.gaps.outer.left = .constant(0)
        config.gaps.outer.right = .constant(0)
        config.gaps.outer.top = .constant(0)
        config.gaps.outer.bottom = .constant(0)
        let workspace = Workspace.get(byName: "Drop")
        _ = monitor.setActiveWorkspace(workspace)
        if columns { workspace.columns = ColumnState(count: 3) }
        let a = TestWindow.new(id: 41, parent: workspace.rootTilingContainer)
        let b = TestWindow.new(id: 42, parent: workspace.rootTilingContainer)
        if columns { a.columnSlot = 1; b.columnSlot = 2 }
        workspace.normalizeContainers()
        XCTAssertTrue(a.focusWindow())
        try await workspace.layoutWorkspace()
        return (workspace, a, b, workspace.rootTilingContainer.lastAppliedLayoutPhysicalRect!.cgRect)
    }

    private func lookup(_ window: Window, _ point: CGPoint, subject: WindowDragSubject = .window,
                        origin: TabDetachOrigin = .window) -> WindowDragIntentDestination? {
        currentWindowDragIntentDestination(sourceWindow: window, mouseLocation: point, subject: subject, detachOrigin: origin)
    }

    func testEmptyOccupiedOwnAndGapLookup() async throws {
        let (workspace, a, _, rect) = try await fixture()
        for (x, slot) in [(600.0, 2), (1000, 3), (395, 1), (405, 2), (795, 2), (805, 3)] {
            let point = CGPoint(x: x, y: rect.midY)
            let destination = lookup(a, point)
            if slot == 1 {
                XCTAssertNil(destination, "Own Column keeps the existing self-window behavior")
            } else {
                XCTAssertEqual(destination.map { debugDescribe($0.kind) }, "column(\(workspace.name), \(slot))")
                let frame = ColumnState.frame(slot: slot, widths: workspace.columns!.widths, in: rect, gap: 20)
                XCTAssertEqual(destination?.previewRect.cgRect, frame)
                XCTAssertEqual(destination?.dropIntentOverlay?.targetFrame.cgRect, frame)
                XCTAssertEqual(destination?.interactionRect.cgRect, rect)
            }
        }
        XCTAssertNil(lookup(a, CGPoint(x: 600, y: rect.maxY + 10)))
    }

    func testColumnsOffWindowSurfaceAndFloatingSourceKeepExistingPaths() async throws {
        let (_, a, b, _) = try await fixture(columns: false)
        let point = b.lastAppliedLayoutPhysicalRect!.center
        let expected = currentWindowSurfaceDestination(sourceWindow: a, mouseLocation: point, subject: .window, detachOrigin: .window)
        XCTAssertNotNil(expected)
        XCTAssertEqual(lookup(a, point)?.kind, expected?.kind)
        XCTAssertEqual(lookup(a, point)?.previewRect, expected?.previewRect)
        let workspace = a.nodeWorkspace!
        workspace.columns = ColumnState(count: 3)
        workspace.enforceColumnInvariant()
        a.unbindFromParent(); a.bindAsFloatingWindow(to: workspace)
        let floatingExpected = currentWindowSurfaceDestination(sourceWindow: a, mouseLocation: point, subject: .window, detachOrigin: .window)
        XCTAssertEqual(lookup(a, point)?.kind, floatingExpected?.kind)
    }

    func testDropDecisionNoHookFocusedFixedAndFailure() async throws {
        let (workspace, a, _, _) = try await fixture()
        let noHook = await ColumnPolicy.dropDecision(window: a, workspace: workspace, slot: 2)
        XCTAssertEqual(noHook, PlacementDecision(slot: 2, target: "2", overflow: .tabGroup, hook: nil))
        let helper = ControlledPolicyHooks()
        PolicyHooks.setOverrideForTests(helper)
        config.columns = ColumnsConfig(.object(["place": .string("columns.place")]), workspaces: nil)
        workspace.columns!.focusedSlot = 1
        for (answer, expected) in [(JSONValue.string("focused"), 2), (.int(3), 3), (.string("nearest-empty"), 1)] {
            helper.answers["columns.place"] = .success(.object(["column": answer, "overflow": .string("split")]))
            let decision = await ColumnPolicy.dropDecision(window: a, workspace: workspace, slot: 2)
            XCTAssertEqual(decision.slot, expected)
            XCTAssertEqual(decision.overflow, .split)
            XCTAssertEqual(workspace.columns!.focusedSlot, 1, "Preview must not change focus")
            let records = helper.calls.last!.args[2].arrayOrNil!
            XCTAssertEqual(records[0]["empty"], .bool(true))
        }
        helper.answers["columns.place"] = .failure(.unavailable("Broken hook"))
        let failed = await ColumnPolicy.dropDecision(window: a, workspace: workspace, slot: 2)
        XCTAssertEqual(failed.slot, 1, "Nearest empty breaks the tie toward the lower Column")
        XCTAssertNotNil(failed.failure)
        XCTAssertEqual(helper.failures.count, 1)
    }

    func testNoHookDropsJoinPointedOccupiedColumnAndFillPointedEmptyColumn() async throws {
        for slot in [2, 3] {
            setUpWorkspacesForTests()
            config.workspaceSidebar.enabled = false
            let (workspace, a, b, rect) = try await fixture()
            let helper = ControlledPolicyHooks()
            PolicyHooks.setOverrideForTests(helper)
            let frame = ColumnState.frame(slot: slot, widths: workspace.columns!.widths, in: rect, gap: 20)
            let point = CGPoint(x: frame.midX, y: frame.midY)
            let destination = try XCTUnwrap(lookup(a, point))
            MousePointerTracker.shared.note(point: point)
            _ = setPendingWindowDragIntent(sourceWindowId: a.windowId, sourceSubject: .window,
                                           detachOrigin: .window, destination: destination)
            let applied = try await applyPendingWindowDragIntentWithPolicy()
            XCTAssertTrue(applied)
            XCTAssertEqual(workspace.columnSlot(containing: a), slot)
            if slot == 2 {
                XCTAssertTrue(a.parent === b.parent)
                XCTAssertEqual((a.parent as? TilingContainer)?.layout, .tabGroup)
                XCTAssertEqual(destination.title, "Column 2 · tab group")
            } else {
                XCTAssertEqual(destination.title, "Column 3")
            }
            XCTAssertTrue(helper.calls.isEmpty)
            XCTAssertNil(pendingWindowDragIntent)
        }
    }

    func testLookupIntoOtherWorkspaceReplacesZoneIntents() async throws {
        let (source, a, _, rect) = try await fixture()
        let target = Workspace.get(byName: "Other")
        target.columns = ColumnState(count: 3)
        let monitor = source.workspaceMonitor
        _ = monitor.setActiveWorkspace(target)
        try await target.layoutWorkspace()
        for (x, slot) in [(100.0, 1), (600, 2), (1100, 3)] {
            XCTAssertEqual(lookup(a, CGPoint(x: x, y: rect.midY))?.kind, .column(workspaceName: target.name, slot: slot))
        }
    }

    func testOverlayAndDropAgreeForEveryOverflowAndHookRunsOnce() async throws {
        for overflow in OverflowPolicy.allCases {
            setUpWorkspacesForTests(); config.workspaceSidebar.enabled = false
            let (workspace, a, b, rect) = try await fixture()
            let helper = ControlledPolicyHooks()
            PolicyHooks.setOverrideForTests(helper)
            config.columns = ColumnsConfig(.object(["place": .string("columns.place")]), workspaces: nil)
            helper.answers["columns.place"] = .success(.object(["column": .string("focused"), "overflow": .string(overflow.rawValue)]))
            let point = CGPoint(x: 600, y: rect.midY)
            _ = lookup(a, point)
            _ = await ColumnDropDecisionCache.shared.decision(window: a, workspace: workspace, slot: 2, incoming: a)
            let destination = try XCTUnwrap(lookup(a, point))
            let expected = ColumnPlacement.resolve(slot: 2, overflow: overflow, columns: workspace.columns!,
                                                   children: workspace.rootTilingContainer.children, incoming: a)
            if overflow == .float {
                XCTAssertEqual(destination.title, "Float")
                XCTAssertNil(destination.dropIntentOverlay)
            } else {
                let frame = ColumnPlacement.frame(expected, in: rect, horizontalGap: 20, verticalGap: 12)
                XCTAssertEqual(destination.previewRect.cgRect, frame)
                XCTAssertEqual(destination.dropIntentOverlay?.targetFrame.cgRect, frame)
            }
            MousePointerTracker.shared.note(point: point)
            XCTAssertTrue(setPendingWindowDragIntent(sourceWindowId: a.windowId, sourceSubject: .window,
                                                     detachOrigin: .window, destination: destination))
            let applied = try await applyPendingWindowDragIntentWithPolicy()
            XCTAssertTrue(applied)
            XCTAssertEqual(helper.calls.count, 1, "Drop reuses the preview's hook answer")
            if overflow == .float { XCTAssertTrue(a.isFloating) }
            else {
                try await workspace.layoutWorkspace()
                XCTAssertEqual(workspace.columnSlot(containing: a), expected.slot)
                if overflow == .split {
                    XCTAssertEqual(a.lastAppliedLayoutPhysicalRect!.cgRect, destination.previewRect.cgRect)
                    XCTAssertTrue(a.parent === b.parent)
                } else {
                    let column = a.parentsWithSelf.first { $0.parent === workspace.rootTilingContainer }!
                    XCTAssertEqual(column.lastAppliedLayoutPhysicalRect!.cgRect, destination.previewRect.cgRect)
                }
            }
        }
    }

    func testCacheCoalescesSamplesAndRejectsAnswersAfterClearOrStateReplacement() async throws {
        let (workspace, a, b, _) = try await fixture()
        for change in ["clear", "columns", "window", "workspace"] {
            let gate = ReloadGate()
            var evaluations = 0, redraws = 0
            let cache = ColumnDropDecisionCache { _, _, slot, _, _ in
                evaluations += 1
                await gate.hold()
                return PlacementDecision(slot: slot, target: "focused", overflow: .split, hook: "columns.place")
            }
            let completion = Task { @MainActor in
                await cache.decision(window: a, workspace: workspace, slot: 2, incoming: a)
            }
            await gate.entered.wait()
            for _ in 0..<10 {
                let provisional = cache.preview(window: a, workspace: workspace, slot: 2, incoming: a) { redraws += 1 }
                XCTAssertEqual(provisional.overflow, .tabGroup)
            }
            XCTAssertEqual(evaluations, 1)
            switch change {
                case "columns": workspace.columns = ColumnState(count: 3)
                case "window": cache.track(window: b, workspace: workspace)
                case "workspace": cache.track(window: a, workspace: Workspace.get(byName: "ColumnsOff"))
                default: cache.clear()
            }
            gate.release()
            let result = await completion.value
            XCTAssertNil(result)
            XCTAssertEqual(redraws, 0)
        }
    }

    func testDropAbandonsHookAnswerWhenColumnsAreReplacedDuringEvaluation() async throws {
        try await checkAbandonedDrop { $0.columns = ColumnState(count: 3) }
    }

    func testCacheReusesWorkspaceKeysWithoutPublishingAnOldContext() async throws {
        let (workspace, a, _, _) = try await fixture()
        let other = Workspace.get(byName: "Other")
        other.columns = ColumnState(count: 3)
        let gate = ReloadGate()
        var evaluations = 0, oldRedraws = 0
        let cache = ColumnDropDecisionCache { _, destination, slot, _, _ in
            evaluations += 1
            if destination === workspace, evaluations == 1 { await gate.hold() }
            return PlacementDecision(slot: slot, target: "focused", overflow: .split, hook: "columns.place")
        }
        let oldResult = Task { @MainActor in
            await cache.decision(window: a, workspace: workspace, slot: 2, incoming: a)
        }
        await gate.entered.wait()
        _ = cache.preview(window: a, workspace: workspace, slot: 2, incoming: a) { oldRedraws += 1 }
        _ = cache.preview(window: a, workspace: other, slot: 2, incoming: a) {}
        _ = await cache.decision(window: a, workspace: other, slot: 2, incoming: a)
        gate.release()
        let abandoned = await oldResult.value
        XCTAssertNil(abandoned)
        XCTAssertEqual(oldRedraws, 0)
        let reused = cache.preview(window: a, workspace: workspace, slot: 2, incoming: a) {}
        XCTAssertEqual(reused.overflow, .split)
        let completed = await cache.decision(window: a, workspace: workspace, slot: 2, incoming: a)
        XCTAssertEqual(completed?.overflow, .split)
        XCTAssertEqual(evaluations, 2, "Returning to a key within one drag reuses its first evaluation")
    }

    func testDropAbandonsHookAnswerWhenTheDragIsCancelledDuringEvaluation() async throws {
        try await checkAbandonedDrop { _ in cancelManipulatedWithMouseState() }
    }

    private func checkAbandonedDrop(change: (Workspace) -> Void) async throws {
        let (workspace, a, _, rect) = try await fixture()
        let helper = ControlledPolicyHooks()
        PolicyHooks.setOverrideForTests(helper)
        config.columns = ColumnsConfig(.object(["place": .string("columns.place")]), workspaces: nil)
        helper.answers["columns.place"] = .success(.object(["column": .int(2), "overflow": .string("split")]))
        let gate = ReloadGate()
        helper.gates["columns.place"] = gate
        let provisional = PlacementDecision(slot: 2, target: "2", overflow: .tabGroup, hook: nil)
        let destination = columnDragDestination(workspace: workspace, slot: 2, decision: provisional,
                                               incoming: a, rect: Rect(topLeftX: rect.minX, topLeftY: rect.minY,
                                               width: rect.width, height: rect.height), subject: .window)
        MousePointerTracker.shared.note(point: CGPoint(x: 600, y: rect.midY))
        _ = setPendingWindowDragIntent(sourceWindowId: a.windowId, sourceSubject: .window,
                                       detachOrigin: .window, destination: destination)
        let drop = Task { @MainActor in try await applyPendingWindowDragIntentWithPolicy() }
        await gate.entered.wait()
        change(workspace)
        gate.release()
        let applied = try await drop.value
        XCTAssertFalse(applied)
        XCTAssertEqual(workspace.columnSlot(containing: a), 1)
        XCTAssertNil(pendingWindowDragIntent)
    }

    func testFixedHookOutranksPointerAndRunsCommandsOnlyAfterDrop() async throws {
        let (workspace, a, _, rect) = try await fixture()
        let helper = ControlledPolicyHooks()
        PolicyHooks.setOverrideForTests(helper)
        config.columns = ColumnsConfig(.object(["place": .string("columns.place")]), workspaces: nil)
        helper.answers["columns.place"] = .success(.object(["column": .int(3), "overflow": .string("tab-group"),
            "run": .array([.string("focus-column 2 --workspace Drop")])]))
        _ = await ColumnDropDecisionCache.shared.decision(window: a, workspace: workspace, slot: 2, incoming: a)
        let destination = try XCTUnwrap(lookup(a, CGPoint(x: 600, y: rect.midY)))
        XCTAssertEqual(destination.title, "Column 3")
        XCTAssertEqual(destination.previewRect.cgRect, ColumnState.frame(slot: 3, widths: workspace.columns!.widths, in: rect, gap: 20))
        XCTAssertEqual(workspace.columns!.focusedSlot, 1)
        MousePointerTracker.shared.note(point: CGPoint(x: 600, y: rect.midY))
        _ = setPendingWindowDragIntent(sourceWindowId: a.windowId, sourceSubject: .window, detachOrigin: .window, destination: destination)
        let applied = try await applyPendingWindowDragIntentWithPolicy()
        XCTAssertTrue(applied)
        XCTAssertEqual(workspace.columnSlot(containing: a), 3)
        XCTAssertEqual(workspace.columns!.focusedSlot, 2, "The run list executes after binding")
        XCTAssertEqual(helper.calls.count, 1)
    }

    func testLateDragSampleAfterMouseUpKeepsColumnDecisionUntilApply() async throws {
        let (workspace, a, _, rect) = try await fixture()
        let helper = ControlledPolicyHooks()
        PolicyHooks.setOverrideForTests(helper)
        config.columns = ColumnsConfig(.object(["place": .string("columns.place")]), workspaces: nil)
        helper.answers["columns.place"] = .success(.object(["column": .string("focused"), "overflow": .string("split")]))
        _ = await ColumnDropDecisionCache.shared.decision(window: a, workspace: workspace, slot: 2, incoming: a)
        let point = CGPoint(x: 600, y: rect.midY)
        let destination = try XCTUnwrap(lookup(a, point))
        MousePointerTracker.shared.note(point: point)
        _ = setPendingWindowDragIntent(sourceWindowId: a.windowId, sourceSubject: .window,
                                       detachOrigin: .window, destination: destination)
        currentlyManipulatedWithMouseWindowId = a.windowId
        setCurrentMouseManipulationKind(.move)
        XCTAssertFalse(isLeftMouseButtonDown)
        refreshPendingWindowDragIntentFromGlobalMouseDrag()
        XCTAssertEqual(pendingWindowDragIntent?.kind, .column(workspaceName: workspace.name, slot: 2))
        let applied = try await applyPendingWindowDragIntentWithPolicy()
        XCTAssertTrue(applied)
        XCTAssertEqual(workspace.columnSlot(containing: a), 2)
        XCTAssertEqual(helper.calls.count, 1)
    }

    func testSqueezeSlotAndOwnColumnSplitAndTabStripKeepTheirPaths() async throws {
        let (workspace, a, b, _) = try await fixture()
        workspace.columns!.widths = [0.25, 0.25, 0.25, 0.25]
        let c = TestWindow.new(id: 43, parent: workspace.rootTilingContainer)
        c.columnSlot = 4
        try await workspace.layoutWorkspace()
        XCTAssertEqual(lookup(a, CGPoint(x: 1100, y: 400))?.kind, .column(workspaceName: workspace.name, slot: 4))
        c.unbindFromParent()
        workspace.bindToColumn(c, slot: 1, overflow: .split)
        workspace.normalizeContainers()
        try await workspace.layoutWorkspace()
        let point = c.lastAppliedLayoutPhysicalRect!.center
        let expected = currentWindowSurfaceDestination(sourceWindow: a, mouseLocation: point, subject: .window, detachOrigin: .window)
        XCTAssertNotNil(expected)
        XCTAssertEqual(lookup(a, point)?.kind, expected?.kind)
        config.windowTabs.enabled = true
        c.unbindFromParent(); workspace.bindToColumn(c, slot: 2)
        workspace.normalizeContainers(); try await workspace.layoutWorkspace()
        let group = try XCTUnwrap(b.parent as? TilingContainer)
        let tabPoint = try XCTUnwrap(group.windowTabDropZoneRect).center
        let tabExpected = currentWindowSurfaceDestination(sourceWindow: a, mouseLocation: tabPoint, subject: .window, detachOrigin: .window)
        XCTAssertNotNil(tabExpected)
        XCTAssertEqual(lookup(a, tabPoint)?.kind, tabExpected?.kind)
        let stripExpected = currentWindowSurfaceDestination(sourceWindow: b, mouseLocation: point, subject: .window, detachOrigin: .tabStrip)
        XCTAssertEqual(lookup(b, point, origin: .tabStrip)?.kind, stripExpected?.kind)
    }

    func testGroupDropMovesEveryLeafInOrderAcrossWorkspacesAndExcludesGroupRecords() async throws {
        let (source, a, _, _) = try await fixture()
        let c = TestWindow.new(id: 43, parent: source)
        source.bindToColumn(c, slot: 1)
        let incoming = dragSubjectNode(for: c, subject: .group)
        XCTAssertEqual(incoming.allLeafWindowsRecursive.map(\.windowId), [41, 43])
        let destination = Workspace.get(byName: "Other")
        destination.columns = ColumnState(count: 3)
        let target = TestWindow.new(id: 44, parent: destination.rootTilingContainer)
        target.columnSlot = 2
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800)
        MousePointerTracker.shared.note(point: rect.center)
        let helper = ControlledPolicyHooks()
        PolicyHooks.setOverrideForTests(helper)
        config.columns = ColumnsConfig(.object(["place": .string("columns.place")]), workspaces: nil)
        helper.answers["columns.place"] = .success(.object(["column": .string("focused"), "overflow": .string("tab-group")]))
        let records = try await source.columnRecords(excluding: incoming).arrayOrNil!
        XCTAssertEqual(records[0]["empty"], .bool(true))
        let answer = await ColumnDropDecisionCache.shared.decision(window: c, workspace: destination, slot: 2, incoming: incoming)
        let decision = try XCTUnwrap(answer)
        let preview = columnDragDestination(workspace: destination, slot: 2, decision: decision, incoming: incoming, rect: rect, subject: .group)
        _ = setPendingWindowDragIntent(sourceWindowId: c.windowId, sourceSubject: .group, detachOrigin: .window, destination: preview)
        let applied = try await applyPendingWindowDragIntentWithPolicy()
        XCTAssertTrue(applied)
        XCTAssertTrue(a.nodeWorkspace === destination)
        XCTAssertTrue(c.nodeWorkspace === destination)
        XCTAssertEqual(destination.columnSlot(containing: a), 2)
        XCTAssertEqual(destination.columnSlot(containing: c), 2)
        XCTAssertEqual(a.parent?.allLeafWindowsRecursive.map(\.windowId), [44, 41, 43])
        XCTAssertEqual(helper.calls.count, 2)
        XCTAssertEqual(helper.calls.map { $0.args[0]["id"] }, [.int(43), .int(41)])
        for call in helper.calls {
            let ids = call.args[2].arrayOrNil!.flatMap { $0["windows"]!.arrayOrNil! }.map { $0["id"] }
            XCTAssertEqual(ids, [.int(44)], "All dragged leaves stay excluded after the first leaf moves")
        }
    }
}
