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
             Case(occupied: true, overflow: "split", alreadyHere: true)]
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
        if row.occupied {
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
        if row.group {
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
        if row.occupied && row.overflow == "split" { return CGRect(x: 210, y: 405.5, width: 280, height: 393.5) }
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
            workspace.bindToColumn(incoming, slot: 2, overflow: row.overflow)
            workspace.normalizeContainers()
            try await workspace.layoutWorkspace()
            XCTAssertEqual(region(row, workspace, incoming, window: window), expected(row), String(describing: row))
            XCTAssertEqual(workspace.rootTilingContainer.allLeafWindowsRecursive.count + workspace.children.filterIsInstance(of: Window.self).count,
                           (row.occupied ? (row.tabTarget ? 3 : 2) : 1) + (row.group ? 2 : 1) + (row.squeezed ? 1 : 0))
        }
    }
}
