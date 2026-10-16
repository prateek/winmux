@testable import AppBundle
import AppKit
import Clocks
import Common
import XCTest

@MainActor
final class LandingPlacementEdgeCasesTest: SerialClockTestCase {
    private func reset() {
        setUpWorkspacesForTests()
        config.onFocusedMonitorChanged = []
        setScheduledRefreshOverrideForTests { _, _ in }
    }

    override func setUp() async throws {
        reset()
        config.workspaceSidebar.enabled = false
        PolicyHooks.setOverrideForTests(ControlledPolicyHooks())
    }

    override func tearDown() async throws {
        config.enableNormalizationFlattenContainers = true
        PolicyHooks.setOverrideForTests(nil)
        setScheduledRefreshOverrideForTests(nil)
    }

    private func columns(_ overflow: OverflowPolicy) -> ControlledPolicyHooks {
        let hooks = ControlledPolicyHooks()
        hooks.answers["columns.place"] = .success(.object(["column": .int(2), "overflow": .string(overflow.rawValue)]))
        PolicyHooks.setOverrideForTests(hooks)
        config.columns = ColumnsConfig(.object(["count": .int(3), "place": .string("columns.place")]), workspaces: nil)
        return hooks
    }

    private func lens(_ window: Window, source: Workspace, destination: Workspace, frame: CGRect, floating: Bool = false) -> LensSession {
        var settings = LensConfig(); settings.presentation = "miniatures"
        let item = SwitcherPaletteItem(id: window.windowId, title: "Incoming", appName: "Test", icon: nil,
            workspaceName: source.name, isFocused: false,
            miniature: MiniatureWindow(workspace: source.name, frame: frame, tray: false, frozen: false,
                                       accessory: false, floating: floating, window: window))
        let model = LensSession(name: "overview", settings: settings, items: [item], search: "")
        model.miniatureWorkspaces = [source, destination].map {
            MiniatureWorkspace(name: $0.name, title: $0.name, source: $0.workspaceMonitor.visibleRect.cgRect, current: $0 === destination)
        }
        return model
    }

    func testPlaceSoleNestedWindowAttachesAtTopLevelUnderEveryOverflow() async throws {
        for overflow in OverflowPolicy.allCases {
            for layout: Layout in [.tiles, .tabGroup] {
                reset()
                defer { config.enableNormalizationFlattenContainers = true }
                config.enableNormalizationFlattenContainers = false
                let hooks = columns(overflow)
                let workspace = focus.workspace
                workspace.columns = ColumnState(count: 3, widths: [0.2, 0.3, 0.5])
                let root = workspace.rootTilingContainer
                let anchor = TestWindow.new(id: 1, parent: root); anchor.columnSlot = 1
                let wrapper = TilingContainer(parent: root, adaptiveWeight: 1, .v, layout, index: INDEX_BIND_LAST)
                wrapper.columnSlot = 2
                let nested = TilingContainer(parent: wrapper, adaptiveWeight: 1, .h, .tiles, index: 0)
                let incoming = TestWindow.new(id: 42, parent: nested)
                XCTAssertTrue(anchor.focusWindow())
                workspace.normalizeContainers()
                XCTAssertEqual(workspace.columnPlacementSlot(excluding: incoming), 2)
                XCTAssertEqual(workspace.mruColumnSlot(excluding: incoming), 1)
                let records = try await workspace.columnRecords(excluding: incoming)
                XCTAssertEqual(records.arrayOrNil?[1]["empty"], .bool(true))
                let preview = ColumnPlacement.resolve(slot: 2, overflow: overflow, columns: workspace.columns!, children: root.children, incoming: incoming)
                if case .attach = preview.effect {} else { XCTFail("Expected attach for \(overflow), \(layout)") }
                XCTAssertEqual(preview.widths, [0.2, 0.3, 0.5])
                XCTAssertEqual(preview.verticalRange, 0...1)
                let placed = try await ColumnPolicy.place(incoming, on: workspace)
                XCTAssertTrue(placed)
                XCTAssertTrue(incoming.parent === root, "\(overflow), \(layout): no empty wrapper or tab beside it")
                XCTAssertEqual(incoming.columnSlot, 2)
                XCTAssertEqual(workspace.columns?.widths, [0.2, 0.3, 0.5])
                XCTAssertEqual(root.children.count, 2)
                XCTAssertFalse(wrapper.isBound)
                XCTAssertEqual(hooks.calls.last?.args.last?.arrayOrNil?[1]["empty"], .bool(true))
            }
        }
    }

    func testEmptySlotContainerAndIncomingGroupUseTheSameOccupancy() async throws {
        for overflow in OverflowPolicy.allCases {
            reset()
            defer { config.enableNormalizationFlattenContainers = true }
            let workspace = focus.workspace
            workspace.columns = ColumnState(count: 3)
            let root = workspace.rootTilingContainer
            let empty = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tiles, index: 0); empty.columnSlot = 2
            let group = TilingContainer(parent: empty, adaptiveWeight: 1, .h, .tabGroup, index: 0)
            let first = TestWindow.new(id: 1, parent: group)
            TestWindow.new(id: 2, parent: group)
            let resolved = ColumnPlacement.resolve(slot: 2, overflow: overflow, columns: workspace.columns!, children: root.children, incoming: group)
            if case .attach = resolved.effect {} else { XCTFail("Incoming group's own leaves do not occupy its Column") }
            group.unbindFromParent()
            workspace.bindToColumn(group, slot: 2, overflow: overflow)
            XCTAssertTrue(group.parent === root)
            XCTAssertEqual(group.columnSlot, 2)
            XCTAssertTrue(first.parent === group)
            XCTAssertFalse(empty.isBound)
        }
    }

    func testNoHooksSelectionRecordsAndExtraSlotReleaseIgnoreEmptyContainers() async throws {
        config.columns = ColumnsConfig()
        let workspace = focus.workspace
        workspace.columns = ColumnState(count: 2)
        let root = workspace.rootTilingContainer
        let anchor = TestWindow.new(id: 1, parent: root); anchor.columnSlot = 1
        let empty = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tabGroup, index: 1); empty.columnSlot = 2
        XCTAssertTrue(anchor.focusWindow())
        XCTAssertEqual(workspace.columnPlacementSlot(), 2)
        XCTAssertEqual(workspace.mruColumnSlot(excluding: nil), 1)
        let records = try await workspace.columnRecords()
        XCTAssertEqual(records.arrayOrNil?[1]["empty"], .bool(true))
        workspace.columns!.widths = [0.3, 0.3, 0.4]
        empty.columnSlot = 3
        workspace.enforceColumnInvariant()
        XCTAssertEqual(workspace.columns!.widths, [0.5, 0.5])
    }

    func testNoHooksNewWindowBindingReleasesEmptySlotContainer() {
        for layout: Layout in [.tiles, .tabGroup] {
            reset()
            defer { config.enableNormalizationFlattenContainers = true }
            config.columns = ColumnsConfig()
            let workspace = focus.workspace
            workspace.columns = ColumnState(count: 2)
            let root = workspace.rootTilingContainer
            let anchor = TestWindow.new(id: 1, parent: root); anchor.columnSlot = 1
            let empty = TilingContainer(parent: root, adaptiveWeight: 1, .v, layout, index: 1); empty.columnSlot = 2
            let incoming = TestWindow.new(id: 42, parent: workspace)
            let binding = bindingDataForNewTilingWindow(workspace, window: incoming)
            incoming.bind(to: binding.parent, adaptiveWeight: binding.adaptiveWeight, index: binding.index)
            XCTAssertFalse(empty.isBound)
            XCTAssertFalse(incoming.parent === empty)
            XCTAssertEqual(workspace.columnSlot(containing: incoming), 2)
            XCTAssertEqual(root.allLeafWindowsRecursive.count, 2)
            XCTAssertEqual(incoming.parent?.children, [incoming])
        }
    }

    func testEmptyContainerHintRecordsAndPlaceAgreeUnderEveryOverflow() async throws {
        for overflow in OverflowPolicy.allCases {
            reset()
            config.workspaceSidebar.enabled = false
            config.enableNormalizationFlattenContainers = false
            defer { config.enableNormalizationFlattenContainers = true }
            let hooks = columns(overflow)
            let destination = focus.workspace
            let source = Workspace.get(byName: "Source")
            destination.columns = ColumnState(count: 3)
            let root = destination.rootTilingContainer
            let anchor = TestWindow.new(id: 1, parent: root); anchor.columnSlot = 1
            let incoming = TestWindow.new(id: 42, parent: source.rootTilingContainer)
            XCTAssertTrue(anchor.focusWindow())
            destination.normalizeContainers()
            try await destination.layoutWorkspace()
            let empty = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tabGroup, index: 1); empty.columnSlot = 2
            _ = TilingContainer(parent: empty, adaptiveWeight: 1, .h, .tiles, index: 0)
            XCTAssertTrue(empty.isBound)
            XCTAssertTrue(root.children.first { $0.columnSlot == 2 } === empty)
            let model = lens(incoming, source: source, destination: destination, frame: CGRect(x: 10, y: 10, width: 200, height: 200))
            let owner = ownLens(model)
            model.send(.modifiersChanged(.option))
            await owner.landingTask?.value
            let hint = try XCTUnwrap(model.miniatureLanding)
            XCTAssertEqual(hooks.calls.last?.args.last?.arrayOrNil?[1]["empty"], .bool(true))
            let placed = try await ColumnPolicy.place(incoming, on: destination)
            XCTAssertTrue(placed)
            try await destination.layoutWorkspace()
            XCTAssertTrue(incoming.parent === root)
            XCTAssertEqual(hint, incoming.lastAppliedLayoutPhysicalRect?.cgRect)
            XCTAssertEqual(destination.columnSlot(containing: incoming), 2)
            owner.dismiss()
        }
    }

    func testFloatHintEqualsSummonAcrossSyntheticDisplays() async throws {
        for destinationSize in [CGSize(width: 1000, height: 800), CGSize(width: 1400, height: 1000)] {
            for alreadyFloating in [false, true] {
                reset()
                config.enableNormalizationFlattenContainers = true
                config.workspaceSidebar.enabled = false
                _ = columns(.float)
                config.gaps.outer.left = .constant(37)
                config.gaps.outer.top = .constant(23)
                let sourceRect = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800)
                let destinationRect = Rect(topLeftX: 1000, topLeftY: 0, width: destinationSize.width, height: destinationSize.height)
                let left = TestMonitor(monitorAppKitNsScreenScreensId: 1, name: "Left", rect: sourceRect,
                    visibleRect: Rect(topLeftX: 20, topLeftY: 30, width: 960, height: 710), isMain: true)
                let right = TestMonitor(monitorAppKitNsScreenScreensId: 2, name: "Right", rect: destinationRect,
                    visibleRect: Rect(topLeftX: 1040, topLeftY: 45, width: destinationSize.width - 80,
                                      height: destinationSize.height - 120), isMain: false)
                setMonitorsForTests([left, right])
                let source = Workspace.get(byName: "Source")
                let destination = Workspace.get(byName: "Destination")
                _ = left.setActiveWorkspace(source); _ = right.setActiveWorkspace(destination)
                source.seedMonitorIfNeeded(left); destination.seedMonitorIfNeeded(right)
                destination.columns = ColumnState(count: 3)
                let anchor = TestWindow.new(id: 1, parent: destination.rootTilingContainer); anchor.columnSlot = 2
                destination.normalizeContainers()
                XCTAssertTrue(anchor.focusWindow())
                try await destination.layoutWorkspace()
                let frame = Rect(topLeftX: 120, topLeftY: 150, width: 240, height: 180)
                let window = TestWindow.new(id: 42, parent: alreadyFloating ? source : source.rootTilingContainer, rect: frame)
                let model = lens(window, source: source, destination: destination, frame: frame.cgRect, floating: alreadyFloating)
                let owner = ownLens(model)
                model.send(.modifiersChanged(.option))
                await owner.landingTask?.value
                let hint = try XCTUnwrap(model.miniatureLanding)
                let result = try await parseCommand("summon --window-id 42").cmdOrDie.run(.defaultEnv, .emptyStdin)
                XCTAssertEqual(result.exitCode, 0)
                try await destination.layoutWorkspace()
                let actual = try await window.getAxRect()
                XCTAssertEqual(hint, actual?.cgRect, "\(destinationSize), already floating: \(alreadyFloating)")
                XCTAssertTrue(window.isFloating)
                XCTAssertTrue(window.nodeWorkspace === destination)
                owner.dismiss()
            }
        }
    }
    func testHiddenFloatingHintMatchesUnhideRestoreOnOneAndTwoMonitors() async throws {
        for displayCount in [1, 2] {
            for destinationSize in [CGSize(width: 1000, height: 800), CGSize(width: 1400, height: 1000)] {
                for alreadyFloating in [false, true] {
                    reset()
                    _ = columns(.float)
                    config.workspaceSidebar.enabled = false
                    let sourceRect = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800)
                    let destinationRect = Rect(topLeftX: displayCount == 1 ? 0 : 1000, topLeftY: 0,
                                               width: destinationSize.width, height: destinationSize.height)
                    let left = TestMonitor(monitorAppKitNsScreenScreensId: 1, name: "Left", rect: sourceRect,
                        visibleRect: Rect(topLeftX: 20, topLeftY: 30, width: 960, height: 710), isMain: true)
                    let right = TestMonitor(monitorAppKitNsScreenScreensId: 2, name: "Right", rect: destinationRect,
                        visibleRect: Rect(topLeftX: destinationRect.minX + 40, topLeftY: 45,
                                          width: destinationSize.width - 80, height: destinationSize.height - 120), isMain: false)
                    setMonitorsForTests(displayCount == 1 ? [right] : [left, right])
                    let source = Workspace.get(byName: "Source")
                    let destination = Workspace.get(byName: "Destination")
                    _ = right.setActiveWorkspace(destination)
                    source.seedMonitorIfNeeded(displayCount == 1 ? right : left)
                    destination.seedMonitorIfNeeded(right)
                    XCTAssertFalse(source.isVisible)
                    destination.columns = ColumnState(count: 3)
                    let anchor = TestWindow.new(id: 1, parent: destination.rootTilingContainer); anchor.columnSlot = 2
                    destination.normalizeContainers()
                    XCTAssertTrue(anchor.focusWindow())
                    try await destination.layoutWorkspace()
                    let saved = CGPoint(x: displayCount == 1 ? -0.06 : 0.12, y: 0.125)
                    let frame = Rect(topLeftX: displayCount == 1 ? -60 : 120, topLeftY: 100, width: 240, height: 180)
                    let window = TestWindow.new(id: 42, parent: alreadyFloating ? source : source.rootTilingContainer, rect: frame)
                    window.testSavedProportionalPosition = saved
                    let model = lens(window, source: source, destination: destination, frame: frame.cgRect, floating: alreadyFloating)
                    let owner = ownLens(model)
                    model.send(.modifiersChanged(.option))
                    await owner.landingTask?.value
                    let hint = try XCTUnwrap(model.miniatureLanding)
                    let expected = CGRect(x: destinationRect.minX + max(0, saved.x) * destinationRect.width,
                                          y: saved.y * destinationRect.height, width: 240, height: 180)
                    // TestWindow cannot call MacWindow.unhideFromCorner; compare with its shared restore function.
                    let restored = restoredFloatingWindowFrame(proportion: saved, size: frame.size, in: destinationRect.cgRect)
                    XCTAssertEqual(restored, expected)
                    XCTAssertEqual(hint, restored, "\(displayCount) monitors, \(destinationSize), floating: \(alreadyFloating)")
                    owner.dismiss()
                }
            }
        }
    }

    func testVisibleFloatingHintUsesMonitorUnderWindowCenter() async throws {
        for alreadyFloating in [false, true] {
            reset()
            _ = columns(.float)
            let a = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800)
            let b = Rect(topLeftX: 1000, topLeftY: 0, width: 1400, height: 1000)
            let left = TestMonitor(monitorAppKitNsScreenScreensId: 1, name: "Left", rect: a, visibleRect: a, isMain: true)
            let right = TestMonitor(monitorAppKitNsScreenScreensId: 2, name: "Right", rect: b, visibleRect: b, isMain: false)
            setMonitorsForTests([left, right])
            let source = Workspace.get(byName: "Source")
            let destination = Workspace.get(byName: "Destination")
            _ = left.setActiveWorkspace(source); _ = right.setActiveWorkspace(destination)
            source.seedMonitorIfNeeded(left); destination.seedMonitorIfNeeded(right)
            destination.columns = ColumnState(count: 3)
            let anchor = TestWindow.new(id: 1, parent: destination.rootTilingContainer); anchor.columnSlot = 2
            destination.normalizeContainers()
            XCTAssertTrue(anchor.focusWindow())
            try await destination.layoutWorkspace()
            let frame = Rect(topLeftX: 1200, topLeftY: 150, width: 240, height: 180)
            let window = TestWindow.new(id: 42, parent: alreadyFloating ? source : source.rootTilingContainer, rect: frame)
            let model = lens(window, source: source, destination: destination, frame: frame.cgRect, floating: alreadyFloating)
            let owner = ownLens(model)
            model.send(.modifiersChanged(.option))
            await owner.landingTask?.value
            let hint = try XCTUnwrap(model.miniatureLanding)
            let result = try await parseCommand("summon --window-id 42").cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(result.exitCode, 0)
            try await destination.layoutWorkspace()
            let actual = try await window.getAxRect()
            XCTAssertEqual(hint, actual?.cgRect)
            XCTAssertEqual(hint, frame.cgRect)
            owner.dismiss()
        }
    }

    func testColumnCountOffReevaluatesHintThroughCommand() async throws {
        _ = columns(.squeeze)
        let destination = focus.workspace
        let source = Workspace.get(byName: "Source")
        destination.columns = ColumnState(count: 3)
        let anchor = TestWindow.new(id: 1, parent: destination.rootTilingContainer); anchor.columnSlot = 2
        let incoming = TestWindow.new(id: 42, parent: source.rootTilingContainer)
        destination.normalizeContainers()
        XCTAssertTrue(anchor.focusWindow())
        try await destination.layoutWorkspace()
        let model = lens(incoming, source: source, destination: destination, frame: CGRect(x: 10, y: 10, width: 200, height: 200))
        let owner = ownLens(model)
        defer { owner.dismiss() }
        model.send(.modifiersChanged(.option))
        await owner.landingTask?.value
        let hint = try XCTUnwrap(model.miniatureLanding)
        let selection = model.selectedId
        let result = try await parseCommand("column-count off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertNil(destination.columns)
        XCTAssertNotEqual(model.miniatureLanding, hint)
        XCTAssertNotNil(model.miniatureLanding)
        XCTAssertEqual(model.selectedId, selection)
        XCTAssertTrue(model.summonHintsShown)
    }

    func testHiddenFloatingHintWithNoReadSizeKeepsTheWindowsSize() async throws {
        _ = columns(.float)
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800)
        let monitor = TestMonitor(monitorAppKitNsScreenScreensId: 1, name: "Only", rect: rect, visibleRect: rect, isMain: true)
        setMonitorsForTests([monitor])
        let destination = Workspace.get(byName: "Destination")
        let source = Workspace.get(byName: "Source")
        _ = monitor.setActiveWorkspace(destination)
        destination.columns = ColumnState(count: 3)
        let anchor = TestWindow.new(id: 1, parent: destination.rootTilingContainer); anchor.columnSlot = 2
        destination.normalizeContainers()
        XCTAssertTrue(anchor.focusWindow())
        try await destination.layoutWorkspace()
        let window = TestWindow.new(id: 42, parent: source)
        XCTAssertNil(window.lastKnownActualRect)
        XCTAssertNil(window.lastFloatingSize)
        window.testSavedProportionalPosition = CGPoint(x: 0.1, y: 0.1)
        let model = lens(window, source: source, destination: destination, frame: CGRect(x: 5, y: 5, width: 240, height: 180), floating: true)
        let owner = ownLens(model)
        defer { owner.dismiss() }
        model.send(.modifiersChanged(.option))
        await owner.landingTask?.value
        XCTAssertEqual(model.miniatureLanding, CGRect(x: 100, y: 80, width: 240, height: 180))
    }

    func testUnchangedColumnsKeepTheHintOnScreen() async throws {
        _ = columns(.squeeze)
        let destination = focus.workspace
        let source = Workspace.get(byName: "Source")
        destination.columns = ColumnState(count: 3)
        let anchor = TestWindow.new(id: 1, parent: destination.rootTilingContainer); anchor.columnSlot = 2
        let incoming = TestWindow.new(id: 42, parent: source.rootTilingContainer)
        destination.normalizeContainers()
        XCTAssertTrue(anchor.focusWindow())
        try await destination.layoutWorkspace()
        let model = lens(incoming, source: source, destination: destination, frame: CGRect(x: 10, y: 10, width: 200, height: 200))
        let owner = ownLens(model)
        defer { owner.dismiss() }
        model.send(.modifiersChanged(.option))
        await owner.landingTask?.value
        let hint = try XCTUnwrap(model.miniatureLanding)
        destination.applyColumns(ColumnsConfig(.object(["count": .int(3)]), workspaces: nil))
        XCTAssertEqual(model.miniatureLanding, hint)
        XCTAssertNil(owner.landingTask)
    }

    func testCachedColumnRecordsKeepEmptyConsistentWithSnapshotWindows() async throws {
        let hooks = columns(.squeeze)
        let destination = focus.workspace
        let source = Workspace.get(byName: "Source")
        destination.columns = ColumnState(count: 3)
        let anchor = TestWindow.new(id: 1, parent: destination.rootTilingContainer); anchor.columnSlot = 2
        let incoming = TestWindow.new(id: 42, parent: source.rootTilingContainer)
        destination.normalizeContainers()
        XCTAssertTrue(anchor.focusWindow())
        try await destination.layoutWorkspace()
        let model = lens(incoming, source: source, destination: destination, frame: CGRect(x: 10, y: 10, width: 200, height: 200))
        let owner = ownLens(model)
        defer { owner.dismiss() }
        model.send(.modifiersChanged(.option))
        await owner.landingTask?.value
        let first = try XCTUnwrap(hooks.calls.last?.args.last?.arrayOrNil)
        XCTAssertEqual(first[1]["empty"], .bool(false))
        XCTAssertEqual(first[2]["empty"], .bool(true))
        anchor.columnSlot = 3
        model.send(.modifiersChanged([]))
        model.send(.modifiersChanged(.option))
        await owner.landingTask?.value
        let records = try XCTUnwrap(hooks.calls.last?.args.last?.arrayOrNil)
        XCTAssertEqual(records[1]["windows"], first[1]["windows"])
        XCTAssertEqual(records[2]["windows"], first[2]["windows"])
        for record in records {
            XCTAssertEqual(record["empty"], .bool(record["windows"]?.arrayOrNil?.isEmpty == true))
        }
    }

    func testConfigSaveReevaluatesLandingWithSameSelectionAndHeldModifier() async throws {
        let clock = TestClock<Duration>()
        let workspace = focus.workspace
        let source = Workspace.get(byName: "Source")
        _ = columns(.squeeze)
        workspace.columns = ColumnState(count: 3)
        let anchor = TestWindow.new(id: 1, parent: workspace.rootTilingContainer); anchor.columnSlot = 2
        let incoming = TestWindow.new(id: 42, parent: source.rootTilingContainer)
        XCTAssertTrue(anchor.focusWindow())
        workspace.normalizeContainers()
        try await workspace.layoutWorkspace()
        let model = lens(incoming, source: source, destination: workspace, frame: CGRect(x: 10, y: 10, width: 200, height: 200))
        let owner = testLensLifecycle(clock: clock)
        owner.complete(model, ticket: owner.begin(model.name, toggle: false)!)
        defer { owner.dismiss() }
        model.send(.modifiersChanged(.option))
        await owner.landingTask?.value
        let columnHint = try XCTUnwrap(model.miniatureLanding)
        let selection = model.selectedId
        let probe = ReloadProbe()
        probe.duringApply = { _ in
            config.columns = ColumnsConfig()
            for workspace in Workspace.all { workspace.applyColumns(config.columns) }
        }
        let reloader = probe.owner()
        let scheduler = ConfigReloadScheduler(delay: .milliseconds(300), clock: clock) { await reloader.fileChanged() }
        scheduler.fileChanged()
        await clock.advance(by: .milliseconds(300) - .nanoseconds(1))
        XCTAssertEqual(model.miniatureLanding, columnHint)
        await clock.advance(by: .nanoseconds(1))
        await probe.completions.wait()
        XCTAssertNil(workspace.columns)
        XCTAssertEqual(model.selectedId, selection)
        XCTAssertTrue(model.summonHintsShown)
        let ordinary = try XCTUnwrap(model.miniatureLanding)
        XCTAssertNotEqual(ordinary, columnHint)
        let rect = try XCTUnwrap(workspace.rootTilingContainer.lastAppliedLayoutPhysicalRect?.cgRect)
        let gap = CGFloat(ResolvedGaps(gaps: config.gaps, monitor: workspace.workspaceMonitor).inner.get(.h).toDouble()) / 2
        XCTAssertEqual(ordinary, CGRect(x: rect.midX + gap, y: rect.minY, width: rect.width / 2 - gap, height: rect.height))
        probe.duringApply = { _ in
            config.columns = ColumnsConfig(.object(["count": .int(3)]), workspaces: nil)
            for workspace in Workspace.all { workspace.applyColumns(config.columns) }
        }
        scheduler.fileChanged()
        await clock.advance(by: .milliseconds(300))
        await probe.completions.wait(for: 2)
        await owner.landingTask?.value
        XCTAssertNotNil(workspace.columns)
        XCTAssertNotEqual(model.miniatureLanding, ordinary)
        XCTAssertEqual(model.selectedId, selection)
        XCTAssertTrue(model.summonHintsShown)
    }

}
