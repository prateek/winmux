@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor
final class ColumnPlacementTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    struct Case {
        let occupied: Bool
        let overflow: String
        var tabTarget = false
        var group = false
        var squeezed = false
        var alreadyHere = false
        var soleNested = false
    }

    private var cases: [Case] {
        [false, true].flatMap { occupied in
            ["tab-group", "split", "float", "squeeze"].map { Case(occupied: occupied, overflow: $0) }
        } + [Case(occupied: true, overflow: "squeeze", squeezed: true),
             Case(occupied: true, overflow: "tab-group", tabTarget: true),
             Case(occupied: true, overflow: "split", tabTarget: true),
             Case(occupied: false, overflow: "split", group: true),
             Case(occupied: true, overflow: "tab-group", group: true),
             Case(occupied: true, overflow: "split", group: true),
             Case(occupied: true, overflow: "squeeze", group: true),
             Case(occupied: true, overflow: "split", alreadyHere: true),
             Case(occupied: true, overflow: "float", alreadyHere: true, soleNested: true),
             Case(occupied: true, overflow: "squeeze", alreadyHere: true, soleNested: true),
             Case(occupied: true, overflow: "split", alreadyHere: true, soleNested: true)]
    }

    private func fixture(_ row: Case) async throws -> (Workspace, TreeNode, CGRect) {
        setUpWorkspacesForTests()
        config.enableNormalizationFlattenContainers = true
        config.enableNormalizationOppositeOrientationForNestedContainers = true
        config.workspaceSidebar.enabled = false
        config.gaps.inner.horizontal = .constant(20)
        config.gaps.inner.vertical = .constant(12)
        config.gaps.outer.left = .constant(0)
        config.gaps.outer.right = .constant(0)
        config.gaps.outer.top = .constant(0)
        config.gaps.outer.bottom = .constant(0)
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800)
        let monitor = TestMonitor(monitorAppKitNsScreenScreensId: 1, name: "Test", rect: rect, visibleRect: rect, isMain: true)
        setMonitorsForTests([monitor])
        let destination = Workspace.get(byName: "Destination")
        _ = monitor.setActiveWorkspace(destination)
        destination.columns = ColumnState(count: 3, widths: [0.2, 0.3, 0.5])
        let root = destination.rootTilingContainer
        let anchor = TestWindow.new(id: 1, parent: root)
        anchor.columnSlot = 1
        if row.occupied && !row.soleNested {
            if row.tabTarget {
                let group = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tabGroup, index: INDEX_BIND_LAST)
                group.columnSlot = 2
                TestWindow.new(id: 2, parent: group)
                TestWindow.new(id: 3, parent: group)
            } else {
                let window = TestWindow.new(id: 2, parent: root)
                window.columnSlot = 2
            }
        }
        if row.squeezed {
            destination.columns!.widths = [0.15, 0.225, 0.375, 0.25]
            let extra = TestWindow.new(id: 4, parent: root)
            extra.columnSlot = 4
        }
        let source = Workspace.get(byName: "Source")
        let incoming: TreeNode
        if row.soleNested {
            config.enableNormalizationFlattenContainers = false
            let column = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tiles, index: INDEX_BIND_LAST)
            column.columnSlot = 2
            incoming = TestWindow.new(id: 42, parent: column)
        } else if row.group {
            let group = TilingContainer(parent: source.rootTilingContainer, adaptiveWeight: 1, .h, .tabGroup, index: 0)
            TestWindow.new(id: 42, parent: group)
            TestWindow.new(id: 43, parent: group)
            incoming = group
        } else {
            incoming = TestWindow.new(id: 42, parent: row.alreadyHere ? root : source.rootTilingContainer)
            if row.alreadyHere { incoming.columnSlot = 3 }
        }
        destination.normalizeContainers()
        XCTAssertTrue(anchor.focusWindow())
        try await destination.layoutWorkspace()
        return (destination, incoming, root.lastAppliedLayoutPhysicalRect!.cgRect)
    }

    private func expected(_ row: Case) -> CGRect? {
        if row.occupied && row.overflow == "float" { return nil }
        if row.occupied && row.overflow == "squeeze" { return CGRect(x: 760, y: 0, width: 240, height: 799) }
        if row.occupied && !row.soleNested && row.overflow == "split" { return CGRect(x: 210, y: 405.5, width: 280, height: 393.5) }
        return CGRect(x: 210, y: 0, width: 280, height: 799)
    }

    private func region(_ row: Case, _ workspace: Workspace, _ incoming: TreeNode, window: Window) -> CGRect? {
        if incoming.parent === workspace { return nil }
        if row.occupied && row.overflow == "split" { return incoming.lastAppliedLayoutPhysicalRect?.cgRect }
        let column = window.parentsWithSelf.first { $0.parent === workspace.rootTilingContainer }
        return column?.lastAppliedLayoutPhysicalRect?.cgRect
    }

    func testActualPlacementRegionsForEveryOverflowAndGroups() async throws {
        for row in cases {
            let (workspace, incoming, _) = try await fixture(row)
            let window = incoming as? Window ?? incoming.allLeafWindowsRecursive.first!
            incoming.unbindFromParent()
            workspace.bindToColumn(incoming, slot: 2, overflow: OverflowPolicy(rawValue: row.overflow)!)
            workspace.normalizeContainers()
            try await workspace.layoutWorkspace()
            XCTAssertEqual(region(row, workspace, incoming, window: window), expected(row), String(describing: row))
            XCTAssertEqual(workspace.rootTilingContainer.allLeafWindowsRecursive.count + workspace.children.filterIsInstance(of: Window.self).count,
                           (row.occupied && !row.soleNested ? (row.tabTarget ? 3 : 2) : 1) + (row.group ? 2 : 1) + (row.squeezed ? 1 : 0))
        }
    }
    private func load(_ overflow: String) async throws {
        guard nickelHelperUrl() != nil else { throw XCTSkip("Run make helper") }
        let path = FileManager.default.temporaryDirectory.appending(path: "placement-\(UUID()).ncl")
        try ("let W = import \"winmux/winmux.ncl\" in { columns.place = fun w ctx cols => { column = 2, overflow = '\(overflow), run = [\"focus-column 3 --workspace Destination\"] } } | W.Config")
            .write(to: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: path) }
        let loaded = try await NickelSupervisor.shared.load(path).get()
        NickelSupervisor.shared.adopt(loaded)
        config.columns = ColumnsConfig(loaded.settings["columns"], workspaces: nil)
    }

    private func session(_ workspace: Workspace, window: Window, rect: CGRect) -> LensSession {
        var settings = LensConfig(); settings.presentation = "miniatures"
        let item = SwitcherPaletteItem(id: window.windowId, title: "Incoming", appName: "Test", icon: nil,
            workspaceName: "Source", isFocused: false,
            miniature: MiniatureWindow(workspace: "Source", frame: CGRect(x: 10, y: 10, width: 200, height: 200),
                                       tray: false, frozen: false, accessory: false, floating: false, window: window))
        let session = LensSession(name: "test", settings: settings, items: [item], search: "")
        session.miniatureWorkspaces = [MiniatureWorkspace(name: workspace.name, title: workspace.name, source: rect, current: true)]
        return session
    }

    private func treeSnapshot(_ node: TreeNode) -> [String] {
        let weights = node is Window && node.parent is Workspace ? "floating" : "\(node.hWeight),\(node.vWeight)"
        return ["\(ObjectIdentifier(node)) revision \(node.bindingRevision) slot \(String(describing: node.columnSlot)) weights \(weights)",
         "children \(node.children.map(ObjectIdentifier.init)) mru \(node.childrenByMostRecentUse.map(ObjectIdentifier.init))"]
            + node.children.flatMap(treeSnapshot)
    }

    func testResolvedHintMatchesActualLayoutIncludingGroups() async throws {
        for row in cases {
            let (workspace, incoming, rect) = try await fixture(row)
            let window = incoming as? Window ?? incoming.allLeafWindowsRecursive.first!
            let decision = PlacementDecision(slot: 2, target: "2", overflow: OverflowPolicy(rawValue: row.overflow)!, hook: nil)
            let placement = ColumnPlacement.resolve(decision, columns: workspace.columns!, children: workspace.rootTilingContainer.children, incoming: incoming)
            let hint = miniatureColumnLanding(placement, in: rect, horizontalGap: 20, verticalGap: 12,
                                              floatingFrame: CGRect(x: 10, y: 10, width: 200, height: 200), source: rect)
            incoming.unbindFromParent()
            workspace.bindToColumn(incoming, slot: decision.slot, overflow: decision.overflow)
            workspace.normalizeContainers()
            try await workspace.layoutWorkspace()
            let actual = region(row, workspace, incoming, window: window)
            XCTAssertEqual(actual, expected(row), String(describing: row))
            XCTAssertEqual(hint, actual ?? CGRect(x: 10, y: 10, width: 200, height: 200), String(describing: row))
        }
    }

    func testLensPreviewIsReadOnlyAndUnchangedSelectionDoesNoWork() async throws {
        for row in cases where !row.group {
            let (workspace, incoming, rect) = try await fixture(row)
            let window = incoming as! TestWindow
            try await load(row.overflow)
            let model = session(workspace, window: window, rect: rect)
            let before = Workspace.all.flatMap(treeSnapshot)
            let widths = workspace.columns!.widths
            let focusedSlot = workspace.columns!.focusedSlot
            let focusedWindow = focus.windowOrNil
            let focusedWorkspace = focus.workspace
            _ = columnsEventTracker.event(for: workspace)
            XCTAssertNil(columnsEventTracker.event(for: workspace))
            let tracker = String(reflecting: columnsEventTracker)
            var reads = 0
            window.beforeAxRecord = { reads += 1 }
            model.summonHeld = true
            await model.landingTask?.value
            let hint = model.miniatureLanding
            let initialReads = reads
            XCTAssertGreaterThan(initialReads, 0)
            for _ in 0..<10 { model.hover(window.windowId); model.updateMiniatureLanding() }
            await model.landingTask?.value
            XCTAssertEqual(reads, initialReads)
            XCTAssertEqual(model.miniatureLanding, hint)
            XCTAssertEqual(Workspace.all.flatMap(treeSnapshot), before)
            XCTAssertEqual(workspace.columns!.widths, widths)
            XCTAssertEqual(workspace.columns!.focusedSlot, focusedSlot, "The run list must not execute")
            XCTAssertTrue(focus.windowOrNil === focusedWindow)
            XCTAssertTrue(focus.workspace === focusedWorkspace)
            XCTAssertEqual(String(reflecting: columnsEventTracker), tracker)
            XCTAssertNil(columnsEventTracker.event(for: workspace), "No columns-changed event")
            model.cancelLanding()
            window.unbindFromParent()
            workspace.bindToColumn(window, slot: 2, overflow: OverflowPolicy(rawValue: row.overflow)!)
            workspace.normalizeContainers()
            try await workspace.layoutWorkspace()
            XCTAssertEqual(hint, region(row, workspace, window, window: window) ?? CGRect(x: 10, y: 10, width: 200, height: 200))
        }
    }

    func testPendingPreviewRejectsChangedDestinationAndColumnState() async throws {
        for change in ["destination", "columns"] {
            let (workspace, incoming, rect) = try await fixture(Case(occupied: true, overflow: "squeeze"))
            try await load("squeeze")
            let window = incoming as! TestWindow
            let started = expectation(description: "Preview collecting selected record")
            var release: CheckedContinuation<Void, Never>?
            window.beforeAxRecord = {
                window.beforeAxRecord = nil
                await withCheckedContinuation { release = $0; started.fulfill() }
            }
            let model = session(workspace, window: window, rect: rect)
            model.summonHeld = true
            await fulfillment(of: [started], timeout: 2)
            if change == "destination" { XCTAssertTrue(Workspace.get(byName: "Elsewhere").focusWorkspace()) }
            else { workspace.columns = ColumnState(count: 2) }
            release?.resume()
            await model.landingTask?.value
            XCTAssertNil(model.miniatureLanding, change)
            XCTAssertTrue(window.nodeWorkspace?.name == "Source")
            model.cancelLanding()
        }
    }

    func testCommitResolvesCurrentWidthsAndOccupancyAfterPreview() async throws {
        let (workspace, incoming, rect) = try await fixture(Case(occupied: true, overflow: "squeeze"))
        try await load("squeeze")
        let window = incoming as! TestWindow
        let model = session(workspace, window: window, rect: rect)
        model.summonHeld = true
        await model.landingTask?.value
        XCTAssertEqual(model.miniatureLanding, CGRect(x: 760, y: 0, width: 240, height: 799))
        workspace.columns!.widths = [0.4, 0.2, 0.4]
        let extra = TestWindow.new(id: 5, parent: workspace)
        workspace.bindToColumn(extra, slot: 2, overflow: .squeeze)
        let result = try await parseCommand("summon --window-id 42").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(result.exitCode, 0)
        for (actual, expected) in zip(workspace.columns!.widths, [0.3, 0.15, 0.3, 0.25]) { XCTAssertEqual(actual, expected, accuracy: 0.000001) }
        XCTAssertEqual(workspace.columnSlot(containing: window), 4)
        XCTAssertTrue(window.parent === extra.parent)
        model.cancelLanding()
    }

    func testPendingCommitRejectsMovedWindowAndReplacedColumns() async throws {
        for change in ["window", "columns"] {
            let (workspace, incoming, _) = try await fixture(Case(occupied: true, overflow: "squeeze"))
            try await load("squeeze")
            let window = incoming as! TestWindow
            let started = expectation(description: "Commit collecting selected record")
            var release: CheckedContinuation<Void, Never>?
            window.beforeAxRecord = {
                window.beforeAxRecord = nil
                await withCheckedContinuation { release = $0; started.fulfill() }
            }
            let commit = Task { @MainActor in try await ColumnPolicy.place(window, on: workspace) }
            await fulfillment(of: [started], timeout: 2)
            if change == "window" { window.bindAsFloatingWindow(to: Workspace.get(byName: "Elsewhere")) }
            else { workspace.columns = ColumnState(count: 2) }
            let before = Workspace.all.flatMap(treeSnapshot)
            let widths = workspace.columns!.widths
            let focusedSlot = workspace.columns!.focusedSlot
            release?.resume()
            let applied = try await commit.value
            XCTAssertFalse(applied, change)
            XCTAssertEqual(Workspace.all.flatMap(treeSnapshot), before, change)
            XCTAssertEqual(workspace.columns!.widths, widths, change)
            XCTAssertEqual(workspace.columns!.focusedSlot, focusedSlot, "No run commands after abandonment")
        }
    }

}
