import AppKit
import Common
@testable import AppBundle
import XCTest

final class WorkspaceSidebarTreeTest: XCTestCase {
    @MainActor
    func testLayoutCommandWithoutSidebarArrangementPreservesNestedTabsAndCascade() async throws {
        setUpWorkspacesForTests()
        config.enableNormalizationOppositeOrientationForNestedContainers = true
        let root = Workspace.get(byName: "1").rootTilingContainer
        let split = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
        let nested = TilingContainer(parent: split, adaptiveWeight: WEIGHT_AUTO, .h, .tiles, index: 0)
        let window = TestWindow.new(id: 601, parent: nested)
        _ = TestWindow.new(id: 602, parent: split)
        let orientation = LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.vertical]))
        let oriented = try await orientation.run(.defaultEnv.copy(\.windowId, window.windowId), .emptyStdin)
        XCTAssertEqual(oriented.exitCode, 0)
        XCTAssertEqual(nested.orientation, .v)
        XCTAssertEqual(split.orientation, .h)
        XCTAssertEqual(root.orientation, .v)
        let tabs = LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.tabGroup]))
        let tabbed = try await tabs.run(.defaultEnv.copy(\.windowId, UInt32(602)), .emptyStdin)
        XCTAssertEqual(tabbed.exitCode, 0)
        XCTAssertEqual(split.layout, .tabGroup)
        XCTAssertTrue(split.children[0] === nested, "The command preserves nested containers")
    }

    @MainActor
    func testPlainSiblingDropWithoutOptionPreservesBothHalves() async throws {
        for after in [false, true] {
            setUpWorkspacesForTests()
            clearActiveWorkspaceSidebarDrag()
            let root = Workspace.get(byName: "1").rootTilingContainer
            let source = TestWindow.new(id: 601, parent: root)
            let target = TestWindow.new(id: 602, parent: root)
            let row = WorkspaceSidebarDropTarget(kind: .tree(.window(602, after: false)), rect: Rect(topLeftX: 0, topLeftY: 0, width: 300, height: 24))
            let resolved = try XCTUnwrap(resolveWorkspaceSidebarDropTarget(at: CGPoint(x: 125, y: after ? 20 : 4), targets: [row]))
            XCTAssertEqual(resolved.kind, .tree(.window(602, after: after)))
            try await checkDrop(source, .window(target.windowId, after: after))
            XCTAssertEqual(root.children.map { ($0 as! Window).windowId }, after ? [602, 601] : [601, 602])
        }
    }

    func testZoneResolutionUsesSixFixedSegmentsAndWholeRow() {
        let row = Rect(topLeftX: 30, topLeftY: 40, width: 300, height: 24)
        let zones: [WindowDropZone] = [.tab, .left, .right, .top, .bottom, .middle]
        for (index, zone) in zones.enumerated() {
            let point = CGPoint(x: 55 + index * 50, y: 54)
            XCTAssertEqual(workspaceSidebarDropZone(at: point, row: row, offered: zones), zone)
            XCTAssertNil(workspaceSidebarDropZone(at: point, row: row, offered: zones.filter { $0 != zone }))
            let target = WorkspaceSidebarDropTarget(kind: .tree(.tab(602, after: false)), rect: Rect(topLeftX: 30, topLeftY: 50, width: 300, height: 14), rowRect: row)
            XCTAssertEqual(resolveWorkspaceSidebarDropTarget(at: point, targets: [target], windowZones: { $0 == 602 ? zones : [] })?.kind, .tree(.windowZone(602, zone: zone)))
        }
        XCTAssertNil(workspaceSidebarDropZone(at: CGPoint(x: 29, y: 54), row: row, offered: zones))
    }

    @MainActor
    func testOfferedZonesForEverySourceAndTargetWithTabsOnAndOff() {
        for enabled in [false, true] {
            for layout: Layout in [.tiles, .tabGroup] {
                setUpWorkspacesForTests()
                config.windowTabs.enabled = enabled
                let root = Workspace.get(byName: "1").rootTilingContainer
                let window = TestWindow.new(id: 601, parent: root)
                let group = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, layout, index: 1)
                _ = TestWindow.new(id: 602, parent: group)
                let other = Workspace.get(byName: "2")
                let tiled = TestWindow.new(id: 603, parent: other.rootTilingContainer)
                let tabs = TilingContainer(parent: other.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .v, .tabGroup, index: 1)
                let tab = TestWindow.new(id: 604, parent: tabs)
                let sibling = TestWindow.new(id: 605, parent: tabs)
                let floating = TestWindow.new(id: 606, parent: other)
                XCTAssertEqual(workspaceSidebarOfferedZones(source: window, target: tiled), enabled ? [.tab, .left, .right, .top, .bottom, .middle] : [.left, .right, .top, .bottom, .middle])
                XCTAssertEqual(workspaceSidebarOfferedZones(source: group, target: tiled), [.left, .right, .top, .bottom, .middle])
                XCTAssertEqual(workspaceSidebarOfferedZones(source: window, target: tab), enabled ? [.tab, .middle] : [.middle])
                XCTAssertEqual(workspaceSidebarOfferedZones(source: group, target: tab), [])
                XCTAssertEqual(workspaceSidebarOfferedZones(source: sibling, target: tab), [])
                XCTAssertEqual(workspaceSidebarOfferedZones(source: window, target: floating), [])
                XCTAssertEqual(workspaceSidebarOfferedZones(source: floating, target: window), enabled ? [.tab, .left, .right, .top, .bottom] : [.left, .right, .top, .bottom])
                XCTAssertEqual(workspaceSidebarOfferedZones(source: floating, target: tab), enabled ? [.tab] : [])
            }
        }
    }

    @MainActor
    func testOptionEventsChangeResolvedTargetAndClearBetweenDrags() {
        setUpWorkspacesForTests()
        let root = Workspace.get(byName: "1").rootTilingContainer
        let source = TestWindow.new(id: 601, parent: root)
        let target = TestWindow.new(id: 602, parent: root)
        let row = WorkspaceSidebarDropTarget(kind: .tree(.window(602, after: false)), rect: Rect(topLeftX: 0, topLeftY: 0, width: 300, height: 24))
        beginActiveWorkspaceSidebarDrag(windowId: 601, subject: .window)
        defer { clearActiveWorkspaceSidebarDrag() }
        for flags: NSEvent.ModifierFlags in [[], .option, [], .option] {
            noteWorkspaceSidebarDragModifiers(flags)
            let zones = workspaceSidebarDragWindowZones(source: source)
            XCTAssertEqual(resolveWorkspaceSidebarDropTarget(at: CGPoint(x: 75, y: 20), targets: [row], windowZones: zones)?.kind,
                           flags.contains(.option) ? .tree(.windowZone(602, zone: .left)) : .tree(.window(602, after: true)))
        }
        clearActiveWorkspaceSidebarDrag()
        beginActiveWorkspaceSidebarDrag(windowId: 601, subject: .window)
        XCTAssertTrue(workspaceSidebarDragWindowZones(source: source)(602).isEmpty)
        XCTAssertTrue(target.parent === root)
    }

    @MainActor
    func testEveryZoneActsOnPointedWindowInSameOppositeAndColumnParents() async throws {
        for context in ["horizontal", "vertical", "column"] {
            for zone: WindowDropZone in [.tab, .left, .right, .top, .bottom, .middle] {
                for sameParent in [false, true] {
                    setUpWorkspacesForTests()
                    let workspace = Workspace.get(byName: "1")
                    let root = workspace.rootTilingContainer
                    if context == "column" { workspace.columns = ColumnState(count: 3, widths: [0.28, 0.44, 0.28]) }
                    let parent = context == "column" ? root : TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, context == "horizontal" ? .h : .v, .tiles, index: 0)
                    let sourceParent = sameParent ? parent : Workspace.get(byName: "2").rootTilingContainer
                    let source = TestWindow.new(id: 601, parent: sourceParent)
                    let target = TestWindow.new(id: 602, parent: parent)
                    if context == "column" { target.columnSlot = 2; if sameParent { source.columnSlot = 1 } }
                    target.setWeight(parent.orientation, 400)
                    try await checkDrop(source, .windowZone(602, zone: zone))
                    if sameParent, context != "column", let position = zone.stackSplitPosition, position.orientation != parent.orientation {
                        // The source leaves the pointed window alone in its split: what counts is the tree the shipped normalization leaves.
                        config.enableNormalizationFlattenContainers = true
                        config.enableNormalizationOppositeOrientationForNestedContainers = true
                        workspace.normalizeContainers()
                        let pair = try XCTUnwrap(target.parent as? TilingContainer)
                        XCTAssertTrue(source.parent === pair)
                        XCTAssertEqual(pair.orientation, position.orientation)
                        XCTAssertEqual(pair.children.map { ($0 as! Window).windowId }, position.isPositive ? [602, 601] : [601, 602])
                        continue
                    }
                    if zone == .middle {
                        XCTAssertTrue(source.parent === parent)
                        XCTAssertTrue(target.parent === sourceParent)
                        if context == "column" { XCTAssertEqual(source.columnSlot, 2); XCTAssertEqual(target.columnSlot, sameParent ? 1 : nil) }
                    } else {
                        let result = try XCTUnwrap(target.parent as? TilingContainer)
                        XCTAssertTrue(source.parent === result)
                        XCTAssertEqual(result.layout, zone == .tab ? .tabGroup : .tiles)
                        if let position = zone.stackSplitPosition {
                            XCTAssertEqual(result.orientation, position.orientation)
                            XCTAssertEqual(result.children.map { ($0 as! Window).windowId }, position.isPositive ? [602, 601] : [601, 602])
                            if result === parent { XCTAssertEqual(source.getWeight(result.orientation), 200); XCTAssertEqual(target.getWeight(result.orientation), 200) }
                        } else { XCTAssertEqual(result.children.map { ($0 as! Window).windowId }, [602, 601]) }
                        if context == "column" { XCTAssertEqual(result.columnSlot, 2); XCTAssertTrue(result.parent === root) }
                    }
                    if context == "column" { XCTAssertEqual(workspace.columns?.widths, [0.28, 0.44, 0.28]) }
                }
            }
        }
    }

    @MainActor
    func testTabZonesAppendAndSwapPointedTabAndNeverSplitItsGroup() async throws {
        for zone: WindowDropZone in [.tab, .left, .right, .top, .bottom, .middle] {
            setUpWorkspacesForTests()
            let root = Workspace.get(byName: "1").rootTilingContainer
            let tabs = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tabGroup, index: 0)
            let target = TestWindow.new(id: 602, parent: tabs)
            let sibling = TestWindow.new(id: 603, parent: tabs)
            let source = TestWindow.new(id: 601, parent: root)
            let offered = zone == .tab || zone == .middle
            try await checkDrop(source, .windowZone(602, zone: zone), accepted: offered)
            XCTAssertTrue(sibling.parent === tabs)
            if zone == .tab { XCTAssertEqual(tabs.children.map { ($0 as! Window).windowId }, [602, 601, 603]) }
            if zone == .middle { XCTAssertTrue(source.parent === tabs); XCTAssertTrue(target.parent === root) }
            if !offered { XCTAssertTrue(source.parent === root); XCTAssertTrue(target.parent === tabs) }
        }
    }

    @MainActor
    func testFloatingZoneRecordsSizeAndStaleOrContainedTargetsRefuse() async throws {
        for zone: WindowDropZone in [.tab, .left, .right, .top, .bottom, .middle] {
            setUpWorkspacesForTests()
            let workspace = Workspace.get(byName: "1")
            let source = TestWindow.new(id: 601, parent: workspace, rect: Rect(topLeftX: 0, topLeftY: 0, width: 320, height: 240))
            let target = TestWindow.new(id: 602, parent: workspace.rootTilingContainer)
            if zone == .middle {
                try await checkDrop(source, .windowZone(602, zone: zone), accepted: false)
                XCTAssertTrue(source.isFloating, "A floating source is not offered swap")
                XCTAssertFalse(target.isFloating, "Swap would have floated the pointed window")
                continue
            }
            try await checkDrop(source, .windowZone(602, zone: zone))
            XCTAssertFalse(source.isFloating)
            XCTAssertEqual(source.lastFloatingSize, CGSize(width: 320, height: 240))
            try await checkDrop(source, .windowZone(601, zone: zone), accepted: false)
            try await checkDrop(source, .windowZone(9999, zone: zone), accepted: false)
            if let parent = target.parent as? TilingContainer { try await checkDrop(parent, .windowZone(602, zone: zone), accepted: false) }
        }
    }

    @MainActor
    func testContainerMenuItemsAndNestedFlattening() {
        for original: Layout in [.tiles, .tabGroup] {
            for nested in [false, true] {
                for action in WorkspaceSidebarContainerAction.allCases {
                    setUpWorkspacesForTests()
                    let workspace = Workspace.get(byName: "1")
                    let root = workspace.rootTilingContainer
                    _ = TestWindow.new(id: 600, parent: root)
                    let container = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, original, index: 1)
                    let child = nested ? TilingContainer(parent: container, adaptiveWeight: WEIGHT_AUTO, .h, .tiles, index: 0) : container
                    _ = TestWindow.new(id: 601, parent: child)
                    _ = TestWindow.new(id: 602, parent: child)
                    _ = TestWindow.new(id: 603, parent: container)
                    let unchanged = workspaceSidebarContainerActionIsCurrent(action, container: container)
                    XCTAssertTrue(applyWorkspaceSidebarContainerAction(action, identity: container.stableId, workspaceName: "1"))
                    if action == .ungroup {
                        XCTAssertTrue(container.isBound, "Normalization removes the emptied container")
                        XCTAssertTrue(container.allLeafWindowsRecursive.isEmpty)
                        workspace.normalizeContainers()
                        XCTAssertFalse(container.isBound)
                        XCTAssertEqual(root.allLeafWindowsRecursive.map(\.windowId), [600, 601, 602, 603])
                        // The nested split runs the root's way, so Ungroup splices its windows in rather than letting normalization turn it.
                        XCTAssertFalse(child.isBound && nested)
                        XCTAssertEqual(root.children.count, 4)
                    } else {
                        XCTAssertEqual(container.layout, action == .tabs ? .tabGroup : .tiles)
                        if action == .tabs && !unchanged { XCTAssertTrue(container.children.allSatisfy { $0 is Window }) }
                        if action == .sideBySide { XCTAssertEqual(container.orientation, .h) }
                        if action == .stacked { XCTAssertEqual(container.orientation, .v) }
                    }
                }
            }
        }
    }

    @MainActor
    func testContainerRootAndColumnChildRefusalsAndTabsDisabled() {
        for column in [false, true] {
            setUpWorkspacesForTests()
            let workspace = Workspace.get(byName: "1")
            let root = workspace.rootTilingContainer
            if column { workspace.columns = ColumnState(count: 2) }
            let container = column ? TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0) : root
            if column { container.columnSlot = 1 }
            _ = TestWindow.new(id: 601, parent: container)
            _ = TestWindow.new(id: 602, parent: container)
            XCTAssertNotNil(workspaceSidebarUngroupRefusal(container))
            XCTAssertFalse(applyWorkspaceSidebarContainerAction(.ungroup, identity: container.stableId, workspaceName: "1"))
            for action: WorkspaceSidebarContainerAction in [.tabs, .sideBySide, .stacked] {
                XCTAssertTrue(applyWorkspaceSidebarContainerAction(action, identity: container.stableId, workspaceName: "1"))
            }
            config.windowTabs.enabled = false
            XCTAssertFalse(applyWorkspaceSidebarContainerAction(.tabs, identity: container.stableId, workspaceName: "1"))
            XCTAssertTrue(container.isBound)
        }
    }

    @MainActor
    func testGlyphFlipCascadesAncestorsAndPreservesColumnsAfterNormalization() {
        for column in [false, true] {
            setUpWorkspacesForTests()
            config.enableNormalizationOppositeOrientationForNestedContainers = true
            let workspace = Workspace.get(byName: "1")
            let root = workspace.rootTilingContainer
            if column { workspace.columns = ColumnState(count: 2, widths: [0.4, 0.6]) }
            let parent = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
            if column { parent.columnSlot = 1 }
            let split = TilingContainer(parent: parent, adaptiveWeight: WEIGHT_AUTO, .h, .tiles, index: 0)
            _ = TestWindow.new(id: 601, parent: split)
            _ = TestWindow.new(id: 602, parent: split)
            _ = TestWindow.new(id: 603, parent: parent)
            let other = TestWindow.new(id: 604, parent: root)
            if column { other.columnSlot = 2 }
            XCTAssertTrue(flipWorkspaceSidebarSplit(identity: split.stableId, workspaceName: "1"))
            XCTAssertEqual(split.orientation, .v)
            XCTAssertEqual(parent.orientation, .h)
            XCTAssertEqual(root.orientation, .v)
            let expectedChildren: [LayoutDescription] = [
                .h_tiles([.v_tiles([.window(601), .window(602)]), .window(603)]), .window(604),
            ]
            assertEquals(root.layoutDescription, .v_tiles(expectedChildren))
            workspace.normalizeContainers()
            assertEquals(root.layoutDescription, column ? .h_tiles(expectedChildren) : .v_tiles(expectedChildren))
            XCTAssertEqual(root.orientation, column ? .h : .v)
            XCTAssertEqual(root.layout, .tiles)
            XCTAssertEqual(root.allLeafWindowsRecursive.map(\.windowId), [601, 602, 603, 604])
            if column { XCTAssertEqual(parent.columnSlot, 1); XCTAssertEqual(other.columnSlot, 2); XCTAssertEqual(workspace.columns?.widths, [0.4, 0.6]) }
        }
    }

    @MainActor
    func testSwapAcrossColumnsKeepsTheSlotsAndWidthsAtTheirPositions() async throws {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        workspace.columns = ColumnState(count: 2, widths: [0.4, 0.6])
        let root = workspace.rootTilingContainer
        let first = TestWindow.new(id: 601, parent: root)
        let second = TestWindow.new(id: 602, parent: root)
        first.columnSlot = 1
        second.columnSlot = 2
        try await checkDrop(first, .windowZone(602, zone: .middle))
        workspace.normalizeContainers()
        XCTAssertEqual(root.children.map { ($0 as! Window).windowId }, [602, 601])
        XCTAssertEqual(second.columnSlot, 1)
        XCTAssertEqual(first.columnSlot, 2)
        XCTAssertEqual(workspace.columns?.widths, [0.4, 0.6])
    }

    @MainActor
    func testGroupSplitAndSwapMoveTheWholeSourceWithoutClimbingTargetAncestors() async throws {
        for sourceLayout: Layout in [.tiles, .tabGroup] {
            for zone: WindowDropZone in [.left, .right, .top, .bottom, .middle] {
                setUpWorkspacesForTests()
                let root = Workspace.get(byName: "1").rootTilingContainer
                let source = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, sourceLayout, index: 0)
                _ = TestWindow.new(id: 601, parent: source)
                _ = TestWindow.new(id: 602, parent: source)
                let parent = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 1)
                let target = TestWindow.new(id: 603, parent: parent)
                let sibling = TestWindow.new(id: 604, parent: parent)
                try await checkDrop(source, .windowZone(603, zone: zone))
                XCTAssertEqual(source.allLeafWindowsRecursive.map(\.windowId), [601, 602])
                XCTAssertTrue(sibling.parent === parent)
                if zone == .middle { XCTAssertTrue(source.parent === parent); XCTAssertTrue(target.parent === root) }
                if zone == .left || zone == .right {
                    XCTAssertTrue(source.parent === target.parent)
                    XCTAssertFalse(source.parent === root, "Do not climb to the matching horizontal ancestor")
                    XCTAssertFalse(source.parent === parent)
                }
            }
        }
    }

    @MainActor
    func testZoneRevalidatesPointedWindowAndOfferAfterFloatingAXRead() async throws {
        for disappears in [false, true] {
            setUpWorkspacesForTests()
            let workspace = Workspace.get(byName: "1")
            let source = TestWindow.new(id: 601, parent: workspace)
            let target = TestWindow.new(id: 602, parent: workspace.rootTilingContainer)
            source.beforeAxSize = {
                if disappears { target.unbindFromParent() } else { config.windowTabs.enabled = false }
            }
            try await checkDrop(source, .windowZone(602, zone: .tab), accepted: false)
            XCTAssertTrue(source.parent === workspace)
        }
    }

    @MainActor
    func testUngroupIntoTabsJoinsOnlyOrderedLeavesAndNormalizesSingleParent() {
        setUpWorkspacesForTests()
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: "1")
        let root = workspace.rootTilingContainer
        root.layout = .tabGroup
        _ = TestWindow.new(id: 600, parent: root)
        let split = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 1)
        let nested = TilingContainer(parent: split, adaptiveWeight: WEIGHT_AUTO, .h, .tiles, index: 0)
        _ = TestWindow.new(id: 601, parent: nested)
        _ = TestWindow.new(id: 602, parent: nested)
        _ = TestWindow.new(id: 603, parent: split)
        XCTAssertTrue(applyWorkspaceSidebarContainerAction(.ungroup, identity: split.stableId, workspaceName: "1"))
        workspace.normalizeContainers()
        XCTAssertEqual(root.children.map { ($0 as! Window).windowId }, [600, 601, 602, 603])
        XCTAssertFalse(split.isBound)
    }

    @MainActor
    func testContainerCurrentItemsDoNothingAndStaleIdentitiesDoNotMutate() {
        setUpWorkspacesForTests()
        let root = Workspace.get(byName: "1").rootTilingContainer
        let split = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .h, .tiles, index: 0)
        let child = TilingContainer(parent: split, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
        _ = TestWindow.new(id: 601, parent: child)
        _ = TestWindow.new(id: 602, parent: split)
        XCTAssertTrue(applyWorkspaceSidebarContainerAction(.sideBySide, identity: split.stableId, workspaceName: "1"))
        XCTAssertTrue(split.children[0] === child)
        split.layout = .tabGroup
        XCTAssertTrue(applyWorkspaceSidebarContainerAction(.tabs, identity: split.stableId, workspaceName: "1"))
        XCTAssertTrue(split.children[0] === child, "A checked item does nothing, even for legacy nested tabs")
        split.unbindFromParent()
        for action in WorkspaceSidebarContainerAction.allCases {
            XCTAssertFalse(applyWorkspaceSidebarContainerAction(action, identity: split.stableId, workspaceName: "1"))
        }
        XCTAssertFalse(flipWorkspaceSidebarSplit(identity: split.stableId, workspaceName: "1"))
    }

    @MainActor
    func testDirectColumnSplitGlyphPreservesOneItemPerSlot() {
        setUpWorkspacesForTests()
        config.enableNormalizationOppositeOrientationForNestedContainers = true
        let workspace = Workspace.get(byName: "1")
        workspace.columns = ColumnState(count: 2, widths: [0.4, 0.6])
        let root = workspace.rootTilingContainer
        let split = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
        split.columnSlot = 1
        _ = TestWindow.new(id: 601, parent: split)
        _ = TestWindow.new(id: 602, parent: split)
        let other = TestWindow.new(id: 603, parent: root)
        other.columnSlot = 2
        XCTAssertTrue(flipWorkspaceSidebarSplit(identity: split.stableId, workspaceName: "1"))
        workspace.normalizeContainers()
        XCTAssertEqual(split.orientation, .h)
        XCTAssertEqual(root.orientation, .h)
        XCTAssertEqual(root.children.count, 2)
        XCTAssertEqual(split.columnSlot, 1)
        XCTAssertEqual(other.columnSlot, 2)
        XCTAssertEqual(workspace.columns?.widths, [0.4, 0.6])
    }

    @MainActor
    func testZonePreviewNamesPointedWindowAndShowsRefusal() {
        setUpWorkspacesForTests()
        let root = Workspace.get(byName: "1").rootTilingContainer
        let source = TestWindow.new(id: 601, parent: root)
        let target = TestWindow.new(id: 602, parent: root)
        defer { clearWorkspaceSidebarDropPreview(); clearActiveWorkspaceSidebarDrag() }
        for zone in WindowDropZone.allCases {
            previewWorkspaceSidebarDrop(source.windowId, subject: .window, target: .tree(.windowZone(target.windowId, zone: zone)))
            XCTAssertEqual(TrayMenuModel.shared.workspaceSidebarDropPreview?.destinationDescription, "\(zone.sidebarIntent) \(sidebarDisplayLabel(for: target))")
        }
        previewWorkspaceSidebarDrop(source.windowId, subject: .window, target: .tree(.windowZone(601, zone: .middle)))
        XCTAssertEqual(TrayMenuModel.shared.workspaceSidebarDropPreview?.refusalReason, "Cannot drop an item on itself or its descendants")
    }
    @MainActor
    func testUnassignedColumnChildrenRemainListedAndSearchable() async {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "2")
        workspace.columns = ColumnState(count: 2)
        let first = TestWindow.new(id: 701, parent: workspace.rootTilingContainer)
        let second = TestWindow.new(id: 702, parent: workspace.rootTilingContainer)
        second.columnSlot = 9
        let tree = await buildWorkspaceSidebarLayoutTree(for: workspace, currentFocus: focus)
        XCTAssertEqual(tree.count, 4)
        let flat = workspaceSidebarProjectItems(tree, splits: false, columns: false)
        XCTAssertEqual(flat.map(\.identity), [.window(first.windowId), .window(second.windowId)])
        XCTAssertEqual(flat.map(\.indexInParent), [0, 1])
        XCTAssertTrue(flat.allSatisfy { $0.realParent == .container(workspace.rootTilingContainer.stableId) })
    }

    @MainActor
    func testFloatingDropRestoresRememberedSizeAndPreservesUnknownSize() async throws {
        for remembered in [false, true] {
            setUpWorkspacesForTests()
            let workspace = Workspace.get(byName: "1")
            let window = TestWindow.new(id: 703, parent: workspace.rootTilingContainer, rect: Rect(topLeftX: 20, topLeftY: 30, width: 900, height: 700))
            window.lastFloatingSize = remembered ? CGSize(width: 320, height: 240) : nil
            try await checkDrop(window, .floatingGroup("1"))
            XCTAssertTrue(window.parent === workspace)
            let rect = try await window.getAxRect()
            XCTAssertEqual(rect?.size, remembered ? CGSize(width: 320, height: 240) : CGSize(width: 900, height: 700))
            XCTAssertEqual(rect?.topLeftCorner, CGPoint(x: 20, y: 30))
        }
    }

    @MainActor
    func testColumnsRootCannotBeAStaleSplitOrTabTarget() async throws {
        for layout: Layout in [.tiles, .tabGroup] {
            setUpWorkspacesForTests()
            let workspace = Workspace.get(byName: "1")
            let root = workspace.rootTilingContainer
            root.layout = layout
            let target: WorkspaceSidebarTreeDropTarget = layout == .tiles ? .split(root.stableId, workspace: "1") : .tabGroup(root.stableId, workspace: "1")
            workspace.columns = ColumnState(count: 2)
            let sourceParent = Workspace.get(byName: "2").rootTilingContainer
            let source = TestWindow.new(id: 704, parent: sourceParent)
            XCTAssertNil(workspaceSidebarTreeDestination(target))
            try await checkDrop(source, target, accepted: false)
            XCTAssertTrue(source.parent === sourceParent)
            XCTAssertTrue(root.children.isEmpty)
        }
    }

    @MainActor
    func testColumnsRootIsRecheckedAfterSuspendedFloatingSizeRead() async throws {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        let root = workspace.rootTilingContainer
        let sourceWorkspace = Workspace.get(byName: "2")
        let source = TestWindow.new(id: 709, parent: sourceWorkspace)
        let target = WorkspaceSidebarTreeDropTarget.split(root.stableId, workspace: "1")
        XCTAssertNotNil(workspaceSidebarTreeDestination(target))
        source.beforeAxSize = { workspace.columns = ColumnState(count: 2) }
        try await checkDrop(source, target, accepted: false)
        XCTAssertTrue(source.parent === sourceWorkspace)
        XCTAssertTrue(root.children.isEmpty)
        previewWorkspaceSidebarDrop(source.windowId, subject: .window, target: .tree(target))
        XCTAssertEqual(TrayMenuModel.shared.workspaceSidebarDropPreview?.refusalReason, "Destination no longer exists")
        clearWorkspaceSidebarDropPreview()
    }

    func testVisibleControlsBeatTreeFramesUnderTheHeader() {
        let row = WorkspaceSidebarDropTarget(kind: .tree(.window(1, after: false)), rect: Rect(topLeftX: 10, topLeftY: 10, width: 100, height: 24))
        for kind: WorkspaceSidebarDropTargetKind in [.monitor("display"), .newWorkspace(projectId: workspaceProjectDefaultId, monitorScopeId: "display")] {
            let control = WorkspaceSidebarDropTarget(kind: kind, rect: Rect(topLeftX: 0, topLeftY: 0, width: 300, height: 50))
            XCTAssertEqual(resolveWorkspaceSidebarDropTarget(at: CGPoint(x: 20, y: 20), targets: [control, row])?.kind, kind)
        }
    }

    func testSearchRestoresBundleTermsGroupTitlesAndEmptyWorkspaceMatches() {
        let window = WorkspaceSidebarWindowViewModel(windowId: 705, workspaceName: "work", appName: "Editor", appBundleId: "org.example.editor", appBundlePath: "/Apps/Editor.app", title: "Draft", isFocused: false)
        let group = WorkspaceSidebarTabGroupViewModel(representativeWindowId: 705, workspaceName: "work", title: "Special group", windowCount: 1, isFocused: false, tabs: [window])
        let model = WorkspaceSidebarWorkspaceViewModel(name: "work", projectId: workspaceProjectDefaultId, displayName: "Work", sidebarLabel: "Label", isGeneratedName: false, monitorScopeId: "display", monitorName: "Studio", isFocused: false, isVisible: true, items: [.init(kind: .tabGroup(group))])
        for query in ["org.example", "/apps/", "draft editor", "editor work"] {
            let results = workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [model]], projects: [], query: query)[workspaceProjectDefaultId]!
            XCTAssertEqual(workspaceSidebarSearchSelections(workspaces: results), [.window(705)], query)
        }
        let groups = workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [model]], projects: [], query: "special group")[workspaceProjectDefaultId]!
        XCTAssertEqual(groups.count, 1)
        if case .tabGroup(let result) = groups.first?.items.first?.kind { XCTAssertEqual(result.searchVisibleTabs, []) }
        XCTAssertEqual(groups.first?.items.first?.isSearchAncestor, false, "A group whose own title matches is a match, not a dimmed ancestor")
        var empty = model
        empty.items = []
        for query in ["label", "studio", "work"] {
            let results = workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [empty]], projects: [], query: query)[workspaceProjectDefaultId]!
            XCTAssertEqual(workspaceSidebarSearchSelections(workspaces: results), [.workspace("work")])
        }
        let projects = [WorkspaceSidebarProjectViewModel(id: workspaceProjectDefaultId, displayName: "Build project", colorHex: nil)]
        let projectResults = workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [model]], projects: projects, query: "editor build")[workspaceProjectDefaultId]!
        XCTAssertEqual(workspaceSidebarSearchSelections(workspaces: projectResults), [.window(705)])
        XCTAssertTrue(workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [model]], projects: [], query: "draft absent")[workspaceProjectDefaultId]!.isEmpty)
    }
    @MainActor
    func testSidebarMonitorPreviewKeepsItsExistingActiveWorkspaceDestination() {
        setUpWorkspacesForTests()
        let monitor = WorkspaceSidebarDragTestMonitor(monitorAppKitNsScreenScreensId: 1, name: "Test", rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080), visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080), isMain: true)
        setMonitorsForTests([monitor])
        defer { setMonitorsForTests(nil); clearWorkspaceSidebarDropPreview() }
        let destination = Workspace.get(byName: "2")
        XCTAssertTrue(monitor.setActiveWorkspace(destination))
        let window = TestWindow.new(id: 796, parent: Workspace.get(byName: "1").rootTilingContainer)
        previewWorkspaceSidebarDrop(window.windowId, subject: .window, target: .monitor(workspaceSidebarMonitorScopeId(for: monitor)))
        XCTAssertEqual(TrayMenuModel.shared.workspaceSidebarDropPreview?.targetWorkspaceName, "2")
    }
    @MainActor
    func testHiddenEmptyColumnsKeepTheExistingOtherDisplayEmptySectionHeight() {
        let workspace = WorkspaceSidebarWorkspaceViewModel(name: "2", projectId: workspaceProjectDefaultId, displayName: "2", sidebarLabel: "", isGeneratedName: false, monitorScopeId: "", monitorName: nil, isFocused: false, isVisible: true, items: [.init(kind: .column(workspace: "2", slot: 1, fraction: 1))])
        let section = WorkspaceSidebarWorkspaceSection(
            workspace: workspace, dragPreview: nil, expansionProgress: 1, layout: .empty,
            emitsDropTarget: false, isFromOtherDisplay: true, isInUseOnOtherDisplay: true,
            isOnFocusedMonitor: false, allowsWorkspaceActivation: true, isPinnedActiveWorkspace: false,
            isActiveOnTargetMonitor: false, projectContextLabel: nil, projectContextColor: nil,
            renamingWorkspaceName: .constant(nil), renamingWorkspaceText: .constant(""),
            onBeginRenameWorkspace: {}, onCommitRenameWorkspace: {}, onCancelRenameWorkspace: {},
            selectedSearchTarget: nil, isSearchFiltering: false,
            activeInUseOverrideWorkspaceName: .constant(nil), actions: .init()
        )
        XCTAssertEqual(section.sectionMinHeight, workspaceSidebarInUseOverrideEmptySectionMinHeight)
    }
    @MainActor
    func testOnScreenFeedbackStillClearsPreviewWithoutSidebarSource() {
        setUpWorkspacesForTests()
        let window = TestWindow.new(id: 797, parent: Workspace.get(byName: "1").rootTilingContainer)
        clearActiveWorkspaceSidebarDrag()
        previewWorkspaceSidebarDrop(window.windowId, subject: .window, target: .tree(.window(window.windowId, after: false)))
        XCTAssertNotNil(TrayMenuModel.shared.workspaceSidebarDropPreview)
        updateSidebarDragFeedback(sourceWindow: window, subject: .window, destination: nil)
        XCTAssertNil(TrayMenuModel.shared.workspaceSidebarDropPreview)
    }

    @MainActor
    func testNativeFeedbackProtectsTreeOnlyOverSidebarAndClearsItOutside() {
        setUpWorkspacesForTests()
        let window = TestWindow.new(id: 798, parent: Workspace.get(byName: "1").rootTilingContainer)
        beginActiveWorkspaceSidebarDrag(windowId: window.windowId, subject: .window)
        defer { clearActiveWorkspaceSidebarDrag(); clearWorkspaceSidebarDropPreview() }
        previewWorkspaceSidebarDrop(window.windowId, subject: .window, target: .tree(.window(window.windowId, after: false)))
        let preview = TrayMenuModel.shared.workspaceSidebarDropPreview
        XCTAssertNotNil(preview?.refusalReason)
        XCTAssertTrue(preservesWorkspaceSidebarTreePreview(isOverSidebar: true))
        XCTAssertFalse(preservesWorkspaceSidebarTreePreview(isOverSidebar: false))
        MousePointerTracker.shared.note(point: CGPoint(x: 10000, y: 10000))
        updateSidebarDragFeedback(sourceWindow: window, subject: .window, destination: nil)
        XCTAssertNil(TrayMenuModel.shared.workspaceSidebarDropPreview)
    }

    @MainActor
    func testSplitSidebarDragNeverOffersScreenOrMonitorAndKeepsWholeSource() async throws {
        setUpWorkspacesForTests()
        let root = Workspace.get(byName: "1").rootTilingContainer
        let split = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .h, .tiles, index: 0)
        let first = TestWindow.new(id: 706, parent: split)
        _ = TestWindow.new(id: 707, parent: split)
        let targetWorkspace = Workspace.get(byName: "2")
        let monitor = WorkspaceSidebarDragTestMonitor(monitorAppKitNsScreenScreensId: 1, name: "Test", rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080), visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080), isMain: true)
        setMonitorsForTests([monitor])
        defer { setMonitorsForTests(nil) }
        XCTAssertTrue(monitor.setActiveWorkspace(targetWorkspace))
        let target = TestWindow.new(id: 708, parent: targetWorkspace.rootTilingContainer)
        beginActiveWorkspaceSidebarDrag(windowId: first.windowId, subject: .group(split.stableId), sidebarOnly: true)
        defer { clearActiveWorkspaceSidebarDrag(); clearPendingWindowDragIntent() }
        XCTAssertTrue(workspaceSidebarDragSource(first, subject: .group(split.stableId)) === split)
        XCTAssertNil(currentWindowDragIntentDestination(sourceWindow: first, mouseLocation: CGPoint(x: 500, y: 500), subject: .group(split.stableId), detachOrigin: .window))
        XCTAssertFalse(workspaceSidebarTreeAcceptsTarget(sourceWorkspaceName: "1", target: .monitor("display")))
        XCTAssertFalse(workspaceSidebarTreeAcceptsTarget(sourceWorkspaceName: "1", target: .newWorkspace(projectId: workspaceProjectDefaultId, monitorScopeId: "display")))
        XCTAssertTrue(workspaceSidebarTreeAcceptsTarget(sourceWorkspaceName: "1", target: .tree(.window(target.windowId, after: true))))
        _ = setPendingWindowDragIntent(sourceWindowId: first.windowId, sourceSubject: .group(split.stableId), detachOrigin: .window,
                                       destination: WindowDragIntentDestination(kind: .moveToWorkspace(workspaceName: "2"), previewRect: monitor.rect,
                                           interactionRect: monitor.rect, title: "Move", subtitle: "", previewStyle: .workspaceMove,
                                           previewGeometry: .rounded, isGroup: true))
        finishSidebarWindowDrag(pointer: CGPoint(x: 10000, y: 10000))
        XCTAssertNil(pendingWindowDragIntent)
        XCTAssertTrue(split.parent === root)
        XCTAssertEqual(split.allLeafWindowsRecursive.map(\.windowId), [706, 707])
        XCTAssertNil(currentActiveWorkspaceSidebarDrag())
        beginActiveWorkspaceSidebarDrag(windowId: first.windowId, subject: .group(split.stableId), sidebarOnly: true)
        let source = try XCTUnwrap(workspaceSidebarDragSource(first, subject: .group(split.stableId)))
        try await checkDrop(source, .window(target.windowId, after: true))
        XCTAssertTrue(split.parent === targetWorkspace.rootTilingContainer)
        XCTAssertEqual(split.allLeafWindowsRecursive.map(\.windowId), [706, 707])
    }

    @MainActor
    func testFreedContainerIdentityCannotResolveReplacementOrInheritDisclosure() async {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        var old: TilingContainer? = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
        let identity = old!.stableId
        weak var freed = old
        old!.unbindFromParent()
        old = nil
        XCTAssertNil(freed)
        let replacement = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
        XCTAssertGreaterThan(replacement.stableId, identity)
        XCTAssertNil(workspaceSidebarLiveContainer(identity, workspaceName: "1"))
        XCTAssertTrue(workspaceSidebarLiveContainer(replacement.stableId, workspaceName: "1") === replacement)
        var state = WorkspaceSidebarTreeState()
        state.collapsedNodes = [.container(identity)]
        let models = await buildWorkspaceSidebarWorkspaceViewModels(currentFocus: focus, workspaceLabels: [:], availableMonitors: [])
        state.prune(workspaces: models)
        XCTAssertFalse(state.collapsedNodes.contains(.container(replacement.stableId)))
        XCTAssertTrue(state.collapsedNodes.isEmpty)
    }

    func testViewportDropsScrolledAndPartlyClippedTreeFrames() {
        let viewport = CGRect(x: 0, y: 50, width: 320, height: 300)
        let hidden = WorkspaceSidebarDropTargetFrame(kind: .tree(.window(1, after: false)), frame: CGRect(x: 10, y: 20, width: 100, height: 24))
        let partial = WorkspaceSidebarDropTargetFrame(kind: .tree(.window(2, after: false)), frame: CGRect(x: 10, y: 40, width: 100, height: 24))
        let visible = WorkspaceSidebarDropTargetFrame(kind: .tree(.window(3, after: false)), frame: CGRect(x: 10, y: 60, width: 100, height: 24))
        let clipped = WorkspaceSidebarDropTargetFrame(kind: partial.kind, frame: CGRect(x: 10, y: 50, width: 100, height: 14), rowFrame: partial.frame, viewport: viewport)
        let boundedVisible = WorkspaceSidebarDropTargetFrame(kind: visible.kind, frame: visible.frame, viewport: viewport)
        XCTAssertEqual(workspaceSidebarVisibleTargets([hidden, partial, visible], viewport: viewport), [clipped, boundedVisible])
        let section = WorkspaceSidebarDropTargetFrame(kind: .workspace("1"), frame: CGRect(x: 0, y: 20, width: 320, height: 360))
        let create = WorkspaceSidebarDropTargetFrame(kind: .newWorkspace(projectId: workspaceProjectDefaultId, monitorScopeId: "display"), frame: section.frame)
        for target in [section, create] {
            XCTAssertEqual(workspaceSidebarVisibleTargets([target], viewport: viewport), [.init(kind: target.kind, frame: viewport, viewport: viewport)])
        }
    }

    func testAPartlyHiddenRowTakesDropsOnlyWhereItShowsAndKeepsItsHalves() {
        // The row spans 40-64, centre 52; the header covers everything above 50.
        let row = WorkspaceSidebarDropTarget(kind: .tree(.window(2, after: false)), rect: Rect(topLeftX: 10, topLeftY: 50, width: 100, height: 14),
                                             rowRect: Rect(topLeftX: 10, topLeftY: 40, width: 100, height: 24))
        let section = WorkspaceSidebarDropTarget(kind: .workspace("1"), rect: Rect(topLeftX: 0, topLeftY: 0, width: 320, height: 400))
        let targets = [section, row]
        XCTAssertEqual(resolveWorkspaceSidebarDropTarget(at: CGPoint(x: 50, y: 45), targets: targets)?.kind, .workspace("1"), "The row's hidden part is not the row: the point falls to the enclosing section, as it did before tree rows existed")
        XCTAssertEqual(resolveWorkspaceSidebarDropTarget(at: CGPoint(x: 50, y: 51), targets: targets)?.kind, .tree(.window(2, after: false)))
        XCTAssertEqual(resolveWorkspaceSidebarDropTarget(at: CGPoint(x: 50, y: 54), targets: targets)?.kind, .tree(.window(2, after: true)), "Halves follow the whole row")
    }

    @MainActor
    func testFloatingTargetDoesNotResizeAFullscreenLeaf() async throws {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        let target = Workspace.get(byName: "2")
        let window = TestWindow.new(id: 725, parent: workspace.macOsNativeFullscreenWindowsContainer, rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080))
        window.lastFloatingSize = CGSize(width: 320, height: 240)
        try await checkDrop(window, .floatingGroup("2"))
        XCTAssertTrue(window.parent === target)
        let rect = try await window.getAxRect()
        XCTAssertEqual(rect?.size, CGSize(width: 1920, height: 1080))
    }

    @MainActor
    func testFloatingReorderKeepsTheSizeOfAnAlreadyFloatingWindow() async throws {
        setUpWorkspacesForTests()
        let source = Workspace.get(byName: "1")
        let target = Workspace.get(byName: "2")
        let window = TestWindow.new(id: 723, parent: source, rect: Rect(topLeftX: 20, topLeftY: 30, width: 900, height: 700))
        window.lastFloatingSize = CGSize(width: 320, height: 240)
        try await checkDrop(window, .floatingGroup("2"))
        XCTAssertTrue(window.parent === target)
        let rect = try await window.getAxRect()
        XCTAssertEqual(rect?.size, CGSize(width: 900, height: 700))
    }

    func testWorkspaceNameMatchKeepsTheWholeWorkspaceUndimmed() {
        let window = WorkspaceSidebarWindowViewModel(windowId: 724, workspaceName: "coding", appName: "Editor", appBundleId: nil, appBundlePath: nil, title: "Draft", isFocused: false)
        let occupied = WorkspaceSidebarItemViewModel(kind: .column(workspace: "coding", slot: 1, fraction: 0.5), children: [.init(kind: .window(window), columnSlot: 1)], columnSlot: 1)
        let empty = WorkspaceSidebarItemViewModel(kind: .column(workspace: "coding", slot: 2, fraction: 0.5), columnSlot: 2)
        let model = WorkspaceSidebarWorkspaceViewModel(name: "coding", projectId: workspaceProjectDefaultId, displayName: "coding", sidebarLabel: "", isGeneratedName: false, monitorScopeId: "", monitorName: nil, isFocused: false, isVisible: true, items: [occupied, empty])
        let results = workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [model]], projects: [], query: "coding")[workspaceProjectDefaultId]!
        XCTAssertEqual(results.first?.items.map(\.identity), [.column("coding", 1), .column("coding", 2)])
        XCTAssertEqual(results.first?.items.map(\.isSearchAncestor), [false, false])
        XCTAssertEqual(results.first?.items.map(\.isSearchRevealed), [true, false], "A workspace match opens collapsed nodes, as a window match does")
    }

    func testRenderReadsReuseProjectionStorageAndModelChangesRebuildIt() {
        let window = WorkspaceSidebarWindowViewModel(windowId: 710, workspaceName: "1", appName: "Editor", appBundleId: nil, appBundlePath: nil, title: "Draft", isFocused: false)
        let child = WorkspaceSidebarItemViewModel(kind: .window(window), columnSlot: 1)
        let column = WorkspaceSidebarItemViewModel(kind: .column(workspace: "1", slot: 1, fraction: 1), children: [child])
        var model = WorkspaceSidebarWorkspaceViewModel(name: "1", projectId: workspaceProjectDefaultId, displayName: "1", sidebarLabel: "", isGeneratedName: false, monitorScopeId: "", monitorName: nil, isFocused: false, isVisible: true, items: [column])
        let first = model.projectedItems
        let second = model.projectedItems
        first.withUnsafeBufferPointer { firstBuffer in
            second.withUnsafeBufferPointer { secondBuffer in
                XCTAssertEqual(firstBuffer.baseAddress, secondBuffer.baseAddress, "Repeated render reads must not allocate another projection")
            }
        }
        XCTAssertEqual(model.columnSlot(for: 710), 1)
        XCTAssertEqual(first.map(\.identity), [.window(710)])
        model.showsColumns = true
        XCTAssertEqual(model.projectedItems.map(\.identity), [.column("1", 1)])
        model.items = []
        XCTAssertTrue(model.projectedItems.isEmpty)
        XCTAssertNil(model.columnSlot(for: 710))
    }
    @MainActor
    func testStructuralHeadingDragsPublishRefusalWithoutMovingWindows() {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        let window = TestWindow.new(id: 799, parent: workspace.rootTilingContainer)
        let targets: [WorkspaceSidebarTreeDropTarget?] = [nil, .column("1", slot: 1)]
        for target in targets {
            handleWorkspaceSidebarAction(.refuseStructuralDrag("1", target: target))
            XCTAssertEqual(TrayMenuModel.shared.workspaceSidebarDropPreview?.refusalReason, "Workspaces and Columns are not windows")
            XCTAssertEqual(TrayMenuModel.shared.workspaceSidebarDropPreview?.treeTarget, target)
            XCTAssertTrue(window.parent === workspace.rootTilingContainer)
        }
        handleWorkspaceSidebarAction(.clearDropPreview)
        XCTAssertNil(TrayMenuModel.shared.workspaceSidebarDropPreview)
    }
    @MainActor
    private func checkDrop(_ source: TreeNode, _ target: WorkspaceSidebarTreeDropTarget, accepted: Bool = true, file: StaticString = #filePath, line: UInt = #line) async throws {
        let result = try await applyWorkspaceSidebarTreeDrop(source: source, target: target)
        XCTAssertEqual(result, accepted, file: file, line: line)
    }
    @MainActor
    func testTreeSameWorkspaceTargetIsAcceptedButScreenDragGuardIsUnchanged() {
        XCTAssertTrue(workspaceSidebarTreeAcceptsTarget(sourceWorkspaceName: "2", target: .workspace("2")))
        XCTAssertFalse(isActionableSidebarWorkspaceDropTarget(sourceWorkspaceName: "2", targetKind: .workspace("2")))
    }

    @MainActor
    func testSiblingInsertAcrossParentsAndWorkspaces() {
        for crossWorkspace in [false, true] {
            for after in [false, true] {
                setUpWorkspacesForTests()
                let sourceWorkspace = Workspace.get(byName: "1")
                let targetWorkspace = Workspace.get(byName: crossWorkspace ? "2" : "1")
                let sourceParent = TilingContainer(parent: sourceWorkspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
                let source = TestWindow.new(id: 901, parent: sourceParent)
                let target = TestWindow.new(id: 902, parent: targetWorkspace.rootTilingContainer)
                let binding = siblingBindingData(source: source, target: target, after: after)!
                source.bind(to: binding.parent, adaptiveWeight: binding.adaptiveWeight, index: binding.index)
                XCTAssertTrue(source.parent === target.parent)
                XCTAssertEqual(source.ownIndex, target.ownIndex! + (after ? 1 : -1))
            }
        }
    }

    @MainActor
    func testDirectColumnSiblingFormsVerticalSplitWithoutChangingWidths() async throws {
        for after in [false, true] {
            setUpWorkspacesForTests()
            let workspace = Workspace.get(byName: "2")
            workspace.columns = ColumnState(count: 3, widths: [0.28, 0.44, 0.28])
            let target = TestWindow.new(id: 921, parent: workspace.rootTilingContainer)
            target.columnSlot = 2
            let source = TestWindow.new(id: 922, parent: Workspace.get(byName: "1").rootTilingContainer)
            try await checkDrop(source, .window(target.windowId, after: after))
            let wrapper = try XCTUnwrap(target.parent as? TilingContainer)
            XCTAssertEqual(wrapper.orientation, .v)
            XCTAssertEqual(wrapper.columnSlot, 2)
            XCTAssertTrue(source.parent === wrapper)
            XCTAssertEqual(source.ownIndex, after ? 1 : 0)
            XCTAssertEqual(workspace.columns?.widths, [0.28, 0.44, 0.28])
        }
    }

    @MainActor
    func testGroupJoinsTabsAsOrderedLeavesAndFloatingTargetFloatsLeaves() async throws {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "2")
        let tabs = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .h, .tabGroup, index: 0)
        _ = TestWindow.new(id: 931, parent: tabs)
        _ = TestWindow.new(id: 932, parent: tabs)
        let source = TilingContainer(parent: Workspace.get(byName: "1").rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
        _ = TestWindow.new(id: 933, parent: source)
        _ = TestWindow.new(id: 934, parent: source)
        try await checkDrop(source, .tabGroup(tabs.stableId, workspace: "2"))
        XCTAssertEqual(tabs.allLeafWindowsRecursive.map(\.windowId), [931, 932, 933, 934])
        XCTAssertFalse(source.isBound)
        try await checkDrop(tabs, .floatingGroup("2"))
        XCTAssertEqual(workspace.floatingWindows.map(\.windowId), [931, 932, 933, 934])
        XCTAssertFalse(tabs.isBound)
    }

    @MainActor
    func testNestedGroupJoinsSiblingTabAtBothHalves() async throws {
        for after in [false, true] {
            setUpWorkspacesForTests()
            let root = Workspace.get(byName: "1").rootTilingContainer
            root.layout = .tabGroup
            let source = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
            _ = TestWindow.new(id: 961, parent: source)
            _ = TestWindow.new(id: 962, parent: source)
            let target = TestWindow.new(id: 963, parent: root)
            try await checkDrop(source, .tab(target.windowId, after: after))
            XCTAssertEqual(root.allLeafWindowsRecursive.map(\.windowId), after ? [963, 961, 962] : [961, 962, 963])
        }
    }

    @MainActor
    func testFloatingSourceTilesDirectlyAndStaleOrCyclicTargetsDoNotMutate() async throws {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        let tabs = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .h, .tabGroup, index: 0)
        let first = TestWindow.new(id: 941, parent: tabs)
        _ = TestWindow.new(id: 942, parent: tabs)
        let floating = TestWindow.new(id: 943, parent: workspace)
        try await checkDrop(tabs, .tab(first.windowId, after: true), accepted: false)
        XCTAssertEqual(tabs.children.count, 2)
        try await checkDrop(floating, .tab(first.windowId, after: true))
        XCTAssertTrue(floating.parent === tabs)
        XCTAssertEqual(tabs.allLeafWindowsRecursive.map(\.windowId), [941, 943, 942])
        let identity = tabs.stableId
        tabs.unbindFromParent()
        try await checkDrop(TestWindow.new(id: 944, parent: workspace.rootTilingContainer), .split(identity, workspace: "1"), accepted: false)
    }

    @MainActor
    func testChangedContainerLayoutCancelsAStaleSplitTarget() async throws {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        let split = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
        _ = TestWindow.new(id: 971, parent: split)
        _ = TestWindow.new(id: 972, parent: split)
        let sourceParent = Workspace.get(byName: "2").rootTilingContainer
        let source = TestWindow.new(id: 973, parent: sourceParent)
        let target = WorkspaceSidebarTreeDropTarget.split(split.stableId, workspace: "1")
        split.layout = .tabGroup
        try await checkDrop(source, target, accepted: false)
        XCTAssertTrue(source.parent === sourceParent)
    }

    @MainActor
    func testExplicitColumnTargetsMergeOccupiedAndPreserveGroupInEmptySlot() async throws {
        for occupied in [false, true] {
            setUpWorkspacesForTests()
            let workspace = Workspace.get(byName: "2")
            workspace.columns = ColumnState(count: 3)
            if occupied {
                let existing = TestWindow.new(id: 951, parent: workspace.rootTilingContainer)
                existing.columnSlot = 2
            }
            let source = TilingContainer(parent: Workspace.get(byName: "1").rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
            _ = TestWindow.new(id: 952, parent: source)
            _ = TestWindow.new(id: 953, parent: source)
            try await checkDrop(source, .column("2", slot: 2))
            let column = try XCTUnwrap(workspace.rootTilingContainer.children.first { $0.columnSlot == 2 })
            XCTAssertEqual(column.allLeafWindowsRecursive.map(\.windowId), occupied ? [951, 952, 953] : [952, 953])
            XCTAssertEqual(source.isBound, !occupied)
        }
    }
    func testReloadClearsOnlyOverridesWhoseDefaultChanged() {
        for splits in [false, true] {
            for columns in [false, true] {
                var state = WorkspaceSidebarTreeState()
                state.splitOverrides = ["1": true]
                state.columnOverrides = ["2": true]
                state.reload(defaults: WorkspaceSidebarTreeConfig(splits: splits, columns: columns))
                XCTAssertEqual(state.splitOverrides.isEmpty, splits)
                XCTAssertEqual(state.columnOverrides.isEmpty, columns)
            }
        }
    }

    @MainActor
    func testSearchRevealsAncestorsAndRestoresDisclosureWithoutDuplicateWindows() async {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "2")
        workspace.columns = ColumnState(count: 3, widths: [0.28, 0.44, 0.28])
        let tabs = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .h, .tabGroup, index: 0)
        tabs.columnSlot = 2
        _ = TestWindow.new(id: 981, parent: tabs)
        _ = TestWindow.new(id: 982, parent: tabs)
        let models = await buildWorkspaceSidebarWorkspaceViewModels(currentFocus: focus, workspaceLabels: [:], availableMonitors: [])
        var model = models.first { $0.name == "2" }!
        XCTAssertEqual(model.columnWidths, [0.28, 0.44, 0.28])
        XCTAssertEqual(model.columnSlot(for: 981), 2)
        model.collapsedNodes = [.container(tabs.stableId), .column("2", 2)]
        let original = model
        let title = model.items.flatMap(\.descendantItems).compactMap { item -> WorkspaceSidebarWindowViewModel? in
            if case .window(let window) = item.kind { return window }; return nil
        }.first!.appName
        let filtered = workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [model]], projects: [], query: title.lowercased())[workspaceProjectDefaultId]!
        XCTAssertEqual(Set(workspaceSidebarSearchSelections(workspaces: filtered)), [.window(981), .window(982)])
        XCTAssertEqual(filtered.first?.collapsedNodes, original.collapsedNodes)
        XCTAssertTrue(filtered.first!.items[0].isSearchRevealed)
        let cleared = workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [model]], projects: [], query: "")[workspaceProjectDefaultId]!
        XCTAssertEqual(cleared, [original])
        XCTAssertTrue(workspaceSidebarFilteredWorkspacesByProject([workspaceProjectDefaultId: [model]], projects: [], query: "qzxnomatch")[workspaceProjectDefaultId]!.isEmpty)
    }

    func testDisclosurePrunesRemovedIdentitiesAndKeepsSurvivingChoices() {
        var state = WorkspaceSidebarTreeState()
        let live = WorkspaceSidebarWorkspaceViewModel(name: "2", projectId: workspaceProjectDefaultId, displayName: "2", sidebarLabel: "", isGeneratedName: false, monitorScopeId: "", monitorName: nil, isFocused: false, isVisible: false, items: [.init(kind: .column(workspace: "2", slot: 1, fraction: 1))])
        state.collapsedNodes = [.workspace("2"), .column("2", 1), .column("2", 3), .workspace("removed")]
        state.prune(workspaces: [live])
        XCTAssertEqual(state.collapsedNodes, [.workspace("2"), .column("2", 1)])
    }

    @MainActor
    func testSiblingBindingUsesRealParentAndAdjustsSameParentRemoval() {
        for sourceIndex in 0...2 {
            for targetIndex in 0...2 where sourceIndex != targetIndex {
                for after in [false, true] {
                    setUpWorkspacesForTests()
                    let root = Workspace.get(byName: "1").rootTilingContainer
                    let windows = (0...2).map { TestWindow.new(id: UInt32(850 + $0), parent: root) }
                    let source = windows[sourceIndex]
                    let target = windows[targetIndex]
                    let binding = siblingBindingData(source: source, target: target, after: after)!
                    source.bind(to: binding.parent, adaptiveWeight: binding.adaptiveWeight, index: binding.index)
                    var expected = windows.filter { $0 !== source }
                    let index = expected.firstIndex { $0 === target }! + (after ? 1 : 0)
                    expected.insert(source, at: index)
                    XCTAssertEqual(root.children.map { ($0 as! Window).windowId }, expected.map(\.windowId))
                }
            }
        }
    }

    @MainActor
    func testTreeCarriesEmptyColumnsWidthsAndRealParents() async {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "2")
        workspace.columns = ColumnState(count: 3, widths: [0.28, 0.44, 0.28])
        workspace.columns?.focusedSlot = 2
        let window = TestWindow.new(id: 890, parent: workspace.rootTilingContainer)
        window.columnSlot = 2
        let tree = await buildWorkspaceSidebarLayoutTree(for: workspace, currentFocus: focus)
        XCTAssertEqual(tree.count, 3)
        XCTAssertEqual(tree[1].children.first?.realParent, .container(workspace.rootTilingContainer.stableId))
        XCTAssertEqual(tree[1].children.first?.indexInParent, 0)
        XCTAssertEqual(workspaceSidebarProjectItems(tree, splits: false, columns: false).map(\.id), ["window:890"])
    }

    @MainActor
    func testFlatTabProjectionRetainsNativeRepresentativeTabsAndRevealsRealSplitOnDemand() async {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        let root = workspace.rootTilingContainer
        root.layout = .tabGroup
        let split = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
        _ = TestWindow.new(id: 991, parent: split)
        _ = TestWindow.new(id: 992, parent: split)
        _ = TestWindow.new(id: 993, parent: root)
        let tree = await buildWorkspaceSidebarLayoutTree(for: workspace, currentFocus: focus)
        let flat = workspaceSidebarProjectItems(tree, splits: false, columns: false)
        guard case .tabGroup(let group) = flat[0].kind else { return XCTFail("Native tab group") }
        XCTAssertEqual(flat[0].children.map(\.identity), group.tabs.map { .window($0.windowId) })
        let revealed = workspaceSidebarProjectItems(tree, splits: true, columns: false)
        guard case .split = revealed[0].children[0].kind else { return XCTFail("Real nested split") }
        XCTAssertEqual(revealed[0].children[0].children.count, 2)
    }
    @MainActor
    func testFlatProjectionPreservesNativeItemsAndFloatingWindows() async {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        let root = workspace.rootTilingContainer
        let split = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: INDEX_BIND_LAST)
        let first = TestWindow.new(id: 801, parent: split)
        let tabs = TilingContainer(parent: split, adaptiveWeight: WEIGHT_AUTO, .h, .tabGroup, index: INDEX_BIND_LAST)
        _ = TestWindow.new(id: 802, parent: tabs)
        _ = TestWindow.new(id: 803, parent: tabs)
        _ = TestWindow.new(id: 804, parent: workspace)
        let tree = await buildWorkspaceSidebarLayoutTree(for: workspace, currentFocus: focus)
        let items = workspaceSidebarProjectItems(tree, splits: false, columns: false)
        XCTAssertEqual(items.count, 3)
        guard case .window(let window) = items[0].kind,
              case .tabGroup(let group) = items[1].kind,
              case .window(let floating) = items[2].kind else { return XCTFail("Flat windows, tab group, then floating") }
        XCTAssertEqual(window.windowId, first.windowId)
        XCTAssertEqual(group.tabs.map(\.windowId), [802, 803])
        XCTAssertEqual(floating.windowId, 804)
    }

    @MainActor
    func testExistingWorkspaceRowMovePreservesFloatingAndAppendsTiledNode() {
        setUpWorkspacesForTests()
        let source = Workspace.get(byName: "1")
        let destination = Workspace.get(byName: "2")
        let existing = TestWindow.new(id: 811, parent: destination.rootTilingContainer)
        let tiled = TestWindow.new(id: 812, parent: source.rootTilingContainer)
        let floating = TestWindow.new(id: 813, parent: source)
        applySidebarWorkspaceMove(sourceNode: tiled, sourceWindow: tiled, targetWorkspace: destination)
        applySidebarWorkspaceMove(sourceNode: floating, sourceWindow: floating, targetWorkspace: destination)
        XCTAssertEqual(destination.rootTilingContainer.children.map { ($0 as? Window)?.windowId }, [existing.windowId, tiled.windowId])
        XCTAssertTrue(floating.parent === destination)
        XCTAssertFalse(isActionableSidebarWorkspaceDropTarget(sourceWorkspaceName: "2", targetKind: .workspace("2")))
    }

    @MainActor
    func testTabsAndUngroupKeepTheActiveWindowAndRememberedFocus() {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        let root = workspace.rootTilingContainer
        let other = TestWindow.new(id: 600, parent: root)
        let split = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .h, .tiles, index: 1)
        let active = TestWindow.new(id: 601, parent: split)
        let nested = TilingContainer(parent: split, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 1)
        _ = TestWindow.new(id: 602, parent: nested)
        _ = TestWindow.new(id: 603, parent: nested)
        active.markAsMostRecentChild()
        other.markAsMostRecentChild()
        XCTAssertTrue(applyWorkspaceSidebarContainerAction(.tabs, identity: split.stableId, workspaceName: "1"))
        XCTAssertEqual(split.children.map { ($0 as! Window).windowId }, [601, 602, 603])
        XCTAssertTrue(split.mostRecentChild === active, "The tab that was showing stays showing")
        XCTAssertTrue(root.mostRecentChild === other, "The workspace's remembered focus is unchanged")

        root.layout = .tabGroup
        XCTAssertTrue(applyWorkspaceSidebarContainerAction(.ungroup, identity: split.stableId, workspaceName: "1"))
        XCTAssertEqual(root.children.map { ($0 as! Window).windowId }, [600, 601, 602, 603])
        XCTAssertTrue(root.mostRecentChild === other, "Ungrouping into tabs keeps the visible tab")

        setUpWorkspacesForTests()
        let tiles = Workspace.get(byName: "1").rootTilingContainer
        let first = TestWindow.new(id: 610, parent: tiles)
        let group = TilingContainer(parent: tiles, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 1)
        let inner = TestWindow.new(id: 611, parent: group)
        _ = TestWindow.new(id: 612, parent: group)
        inner.markAsMostRecentChild()
        first.markAsMostRecentChild()
        XCTAssertTrue(applyWorkspaceSidebarContainerAction(.ungroup, identity: group.stableId, workspaceName: "1"))
        XCTAssertTrue(tiles.mostRecentChild === first, "Ungrouping into a split keeps the remembered focus")
        XCTAssertTrue(tiles.childrenByMostRecentUse[1] === inner)
    }

    @MainActor
    func testUngroupKeepsTheContainersShareOfItsParent() {
        for along in [true, false] {
            setUpWorkspacesForTests()
            let root = Workspace.get(byName: "1").rootTilingContainer
            root.changeOrientation(.h)
            let other = TestWindow.new(id: 600, parent: root, adaptiveWeight: 300)
            let group = TilingContainer(parent: root, adaptiveWeight: 700, along ? .h : .v, .tiles, index: 1)
            let a = TestWindow.new(id: 601, parent: group, adaptiveWeight: 600)
            let b = TestWindow.new(id: 602, parent: group, adaptiveWeight: 100)
            XCTAssertTrue(applyWorkspaceSidebarContainerAction(.ungroup, identity: group.stableId, workspaceName: "1"))
            XCTAssertEqual(other.getWeight(.h), 300)
            XCTAssertEqual(a.getWeight(.h), along ? 600 : 350, accuracy: 0.001)
            XCTAssertEqual(b.getWeight(.h), along ? 100 : 350, accuracy: 0.001)
        }
    }

    @MainActor
    func testSplitWithTheTargetsOnlySiblingKeepsTheAskedOrientationAfterNormalization() async throws {
        for position: WindowDropZone in [.left, .right, .top, .bottom] {
            setUpWorkspacesForTests()
            config.enableNormalizationFlattenContainers = true
            config.enableNormalizationOppositeOrientationForNestedContainers = true
            let workspace = Workspace.get(byName: "1")
            let root = workspace.rootTilingContainer
            root.changeOrientation(.h)
            _ = TestWindow.new(id: 600, parent: root)
            let stack = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 1)
            let source = TestWindow.new(id: 601, parent: stack)
            let target = TestWindow.new(id: 602, parent: stack)
            try await checkDrop(source, .windowZone(602, zone: position))
            workspace.normalizeContainers()
            let orientation = position.stackSplitPosition.orDie().orientation
            let pair = try XCTUnwrap(source.parent as? TilingContainer)
            XCTAssertTrue(target.parent === pair, "\(position)")
            XCTAssertEqual(pair.orientation, orientation, "\(position): the split is the one the zone named; root \(root.orientation) \(root.children.map { ($0 as? Window).map { "w\($0.windowId)" } ?? "c\(($0 as! TilingContainer).orientation)\($0.children.count)" })")
            let order = pair.children.compactMap { ($0 as? Window)?.windowId }.filter { [601, 602].contains($0) }
            XCTAssertEqual(order, position == .left || position == .top ? [601, 602] : [602, 601], "\(position)")
        }
    }

    @MainActor
    func testUngroupSplicesASplitThatRunsTheParentsWaySoItsWindowsKeepTheirDirection() {
        setUpWorkspacesForTests()
        config.enableNormalizationFlattenContainers = true
        config.enableNormalizationOppositeOrientationForNestedContainers = true
        let workspace = Workspace.get(byName: "1")
        let root = workspace.rootTilingContainer
        root.changeOrientation(.h)
        _ = TestWindow.new(id: 600, parent: root, adaptiveWeight: 400)
        let stack = TilingContainer(parent: root, adaptiveWeight: 600, .v, .tiles, index: 1)
        _ = TestWindow.new(id: 601, parent: stack)
        let pair = TilingContainer(parent: stack, adaptiveWeight: WEIGHT_AUTO, .h, .tiles, index: 1)
        let left = TestWindow.new(id: 602, parent: pair, adaptiveWeight: 3)
        let right = TestWindow.new(id: 603, parent: pair, adaptiveWeight: 1)
        workspace.normalizeContainers()
        XCTAssertEqual(pair.orientation, .h)
        XCTAssertTrue(applyWorkspaceSidebarContainerAction(.ungroup, identity: stack.stableId, workspaceName: "1"))
        workspace.normalizeContainers()
        XCTAssertTrue(left.parent === right.parent)
        XCTAssertEqual((left.parent as? TilingContainer)?.orientation, .h, "602 and 603 stay side by side")
        XCTAssertEqual(root.children.compactMap { ($0 as? Window)?.windowId }, [600, 601, 602, 603])
        XCTAssertEqual(left.getWeight(.h), 225, accuracy: 0.001, "The pair's half of the stack's 600 keeps its 3:1 split")
        XCTAssertEqual(right.getWeight(.h), 75, accuracy: 0.001)
    }

    @MainActor
    func testSplitIsChosenAfterTheSourcesOwnSplitIsNormalizedAway() async throws {
        for position: WindowDropZone in [.left, .right, .top, .bottom] {
            setUpWorkspacesForTests()
            config.enableNormalizationFlattenContainers = true
            config.enableNormalizationOppositeOrientationForNestedContainers = true
            let workspace = Workspace.get(byName: "1")
            let root = workspace.rootTilingContainer
            root.changeOrientation(.h)
            let outer = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 0)
            let source = TestWindow.new(id: 601, parent: outer)
            let inner = TilingContainer(parent: outer, adaptiveWeight: WEIGHT_AUTO, .h, .tiles, index: 1)
            let target = TestWindow.new(id: 602, parent: inner)
            _ = TestWindow.new(id: 603, parent: inner)
            _ = TestWindow.new(id: 604, parent: root)
            workspace.normalizeContainers()
            try await checkDrop(source, .windowZone(602, zone: position))
            workspace.normalizeContainers()
            let pair = try XCTUnwrap(source.parent as? TilingContainer)
            XCTAssertTrue(target.parent === pair, "\(position)")
            XCTAssertEqual(pair.orientation, position.stackSplitPosition.orDie().orientation, "\(position): the split is the one the zone named")
            let order = pair.children.compactMap { ($0 as? Window)?.windowId }.filter { [601, 602].contains($0) }
            XCTAssertEqual(order, position == .left || position == .top ? [601, 602] : [602, 601], "\(position)")
        }
    }

    @MainActor
    func testWindowsOfASplitThatIsATabTakeOnlySwap() {
        setUpWorkspacesForTests()
        let root = Workspace.get(byName: "1").rootTilingContainer
        let tabs = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tabGroup, index: 0)
        let split = TilingContainer(parent: tabs, adaptiveWeight: WEIGHT_AUTO, .h, .tiles, index: 0)
        let first = TestWindow.new(id: 601, parent: split)
        let target = TestWindow.new(id: 602, parent: split)
        _ = TestWindow.new(id: 604, parent: tabs)
        let outside = TestWindow.new(id: 605, parent: root)
        XCTAssertEqual(workspaceSidebarOfferedZones(source: outside, target: target), [.middle])
        XCTAssertEqual(workspaceSidebarOfferedZones(source: first, target: target), [.middle])
    }

    @MainActor
    func testARefusedZoneSkipsTheFloatingSizeRead() async throws {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "1")
        let source = TestWindow.new(id: 601, parent: workspace, rect: Rect(topLeftX: 0, topLeftY: 0, width: 320, height: 240))
        _ = TestWindow.new(id: 602, parent: workspace.rootTilingContainer)
        source.lastFloatingSize = CGSize(width: 100, height: 100)
        try await checkDrop(source, .windowZone(602, zone: .middle), accepted: false)
        XCTAssertEqual(source.lastFloatingSize, CGSize(width: 100, height: 100), "A zone the source is not offered is refused before the AX read")
    }

    @MainActor
    func testSplitMidDropNormalizationKeepsColumnSlotsAndIgnoresAnotherWorkspace() async throws {
        for crossWorkspace in [false, true] {
            setUpWorkspacesForTests()
            config.enableNormalizationFlattenContainers = true
            config.enableNormalizationOppositeOrientationForNestedContainers = true
            let workspace = Workspace.get(byName: "1")
            workspace.columns = ColumnState(count: 3, widths: [0.28, 0.44, 0.28])
            let root = workspace.rootTilingContainer
            let first = TestWindow.new(id: 600, parent: root)
            first.columnSlot = 1
            let column = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tiles, index: 1)
            column.columnSlot = 2
            let other = Workspace.get(byName: "2").rootTilingContainer
            let source = TestWindow.new(id: 601, parent: crossWorkspace ? other : column)
            let target = TestWindow.new(id: 602, parent: column)
            if crossWorkspace { _ = TestWindow.new(id: 603, parent: column) }
            workspace.normalizeContainers()
            try await checkDrop(source, .windowZone(602, zone: .left))
            workspace.normalizeContainers()
            let pair = try XCTUnwrap(target.parent as? TilingContainer)
            XCTAssertTrue(source.parent === pair)
            XCTAssertEqual(pair.orientation, .h)
            XCTAssertEqual(pair.children.compactMap { ($0 as? Window)?.windowId }, [601, 602])
            let slotNode: TreeNode = crossWorkspace ? column : pair
            XCTAssertEqual(slotNode.columnSlot, 2, "The Column keeps one item in slot 2")
            XCTAssertEqual(root.children.compactMap(\.columnSlot).sorted(), [1, 2])
            XCTAssertEqual(workspace.columns?.widths, [0.28, 0.44, 0.28])
        }
    }
}
