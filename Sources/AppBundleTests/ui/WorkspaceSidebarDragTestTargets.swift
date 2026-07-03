import AppKit
@testable import AppBundle
import XCTest

extension WorkspaceSidebarDragTest {
    @MainActor
    func testSameWorkspaceSidebarDropTargetIsNotActionable() {
        XCTAssertFalse(
            isActionableSidebarWorkspaceDropTarget(
                sourceWorkspaceName: "1",
                targetKind: .workspace("1"),
            ),
        )
    }

    @MainActor
    func testDifferentWorkspaceSidebarDropTargetIsActionable() {
        XCTAssertTrue(
            isActionableSidebarWorkspaceDropTarget(
                sourceWorkspaceName: "1",
                targetKind: .workspace("2"),
            ),
        )
    }

    @MainActor
    func testNewWorkspaceSidebarDropTargetIsActionable() {
        XCTAssertTrue(
            isActionableSidebarWorkspaceDropTarget(
                sourceWorkspaceName: "1",
                targetKind: .newWorkspace(projectId: workspaceProjectDefaultId, monitorScopeId: workspaceSidebarDefaultScopeId),
            ),
        )
    }

    @MainActor
    func testBlankSidebarAreaIsNotActionable() {
        XCTAssertFalse(
            isActionableSidebarWorkspaceDropTarget(
                sourceWorkspaceName: "1",
                targetKind: nil,
            ),
        )
    }

    @MainActor
    func testMonitorSidebarDropTargetIsActionable() {
        XCTAssertTrue(
            isActionableSidebarWorkspaceDropTarget(
                sourceWorkspaceName: "1",
                targetKind: .monitor("monitor:1920.0,0.0"),
            ),
        )
    }

    @MainActor
    func testSidebarNewWorkspaceTargetUsesDropPointMonitorBeforeSourceMonitor() {
        let main = WorkspaceSidebarDragTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            isMain: true,
        )
        let secondary = WorkspaceSidebarDragTestMonitor(
            monitorAppKitNsScreenScreensId: 2,
            name: "Secondary",
            rect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            isMain: false,
        )
        setMonitorsForTests([main, secondary])
        defer { setMonitorsForTests(nil) }

        let target = workspaceSidebarTargetMonitor(
            selectedMonitor: nil,
            fallbackPoint: CGPoint(x: 2000, y: 20),
            fallbackWindowMonitor: main,
            focusedMonitor: main,
        )

        XCTAssertEqual(target.rect.topLeftCorner, secondary.rect.topLeftCorner)
    }

    @MainActor
    func testSidebarNewWorkspaceTargetHonorsExplicitMonitorSelection() {
        let main = WorkspaceSidebarDragTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            isMain: true,
        )
        let secondary = WorkspaceSidebarDragTestMonitor(
            monitorAppKitNsScreenScreensId: 2,
            name: "Secondary",
            rect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            isMain: false,
        )
        setMonitorsForTests([main, secondary])
        defer { setMonitorsForTests(nil) }

        let target = workspaceSidebarTargetMonitor(
            selectedMonitor: main,
            fallbackPoint: CGPoint(x: 2000, y: 20),
            fallbackWindowMonitor: secondary,
            focusedMonitor: secondary,
        )

        XCTAssertEqual(target.rect.topLeftCorner, main.rect.topLeftCorner)
    }

    @MainActor
    func testMonitorScopeResolvesMonitorPoint() {
        let secondary = WorkspaceSidebarDragTestMonitor(
            monitorAppKitNsScreenScreensId: 2,
            name: "Secondary",
            rect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            isMain: false,
        )
        setMonitorsForTests([secondary])
        defer { setMonitorsForTests(nil) }

        let scopeId = workspaceSidebarMonitorScopeId(for: secondary)

        XCTAssertEqual(workspaceSidebarMonitorScopePoint(scopeId), secondary.rect.topLeftCorner)
        XCTAssertEqual(workspaceSidebarMonitor(forScopeId: scopeId)?.rect.topLeftCorner, secondary.rect.topLeftCorner)
    }

    @MainActor
    func testSidebarWorkspaceClickDoesNotFocusWorkspaceVisibleOnOtherMonitor() {
        let main = WorkspaceSidebarDragTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            isMain: true,
        )
        let secondary = WorkspaceSidebarDragTestMonitor(
            monitorAppKitNsScreenScreensId: 2,
            name: "Secondary",
            rect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            isMain: false,
        )
        setMonitorsForTests([main, secondary])
        defer { setMonitorsForTests(nil) }

        let mainWorkspace = Workspace.get(byName: "main")
        let secondaryWorkspace = Workspace.get(byName: "secondary")
        XCTAssertTrue(main.setActiveWorkspace(mainWorkspace))
        XCTAssertTrue(secondary.setActiveWorkspace(secondaryWorkspace))
        XCTAssertTrue(mainWorkspace.focusWorkspace())

        XCTAssertFalse(focusWorkspaceFromSidebar(
            secondaryWorkspace,
            targetMonitorScopeId: workspaceSidebarMonitorScopeId(for: main),
        ))
        XCTAssertEqual(main.activeWorkspace, mainWorkspace)
        XCTAssertEqual(secondary.activeWorkspace, secondaryWorkspace)
        XCTAssertEqual(focus.workspace, mainWorkspace)
    }

    @MainActor
    func testSidebarWorkspaceClickActivatesHiddenWorkspaceOnOwningPanelMonitor() {
        let main = WorkspaceSidebarDragTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            isMain: true,
        )
        let secondary = WorkspaceSidebarDragTestMonitor(
            monitorAppKitNsScreenScreensId: 2,
            name: "Secondary",
            rect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            isMain: false,
        )
        setMonitorsForTests([main, secondary])
        defer { setMonitorsForTests(nil) }

        let mainWorkspace = Workspace.get(byName: "main")
        let secondaryWorkspace = Workspace.get(byName: "secondary")
        let hiddenWorkspace = Workspace.get(byName: "hidden")
        XCTAssertTrue(main.setActiveWorkspace(mainWorkspace))
        XCTAssertTrue(secondary.setActiveWorkspace(secondaryWorkspace))
        XCTAssertTrue(mainWorkspace.focusWorkspace())

        XCTAssertTrue(focusWorkspaceFromSidebar(
            hiddenWorkspace,
            targetMonitorScopeId: workspaceSidebarMonitorScopeId(for: secondary),
        ))
        XCTAssertEqual(main.activeWorkspace, mainWorkspace)
        XCTAssertEqual(secondary.activeWorkspace, hiddenWorkspace)
        XCTAssertEqual(focus.workspace, hiddenWorkspace)
    }

    @MainActor
    func testMonitorScopeSelectionIsPanelLocal() {
        let previousSharedScope = TrayMenuModel.shared.workspaceSidebarSelectedMonitorScopeId
        TrayMenuModel.shared.workspaceSidebarSelectedMonitorScopeId = workspaceSidebarDefaultScopeId
        defer { TrayMenuModel.shared.workspaceSidebarSelectedMonitorScopeId = previousSharedScope }

        let mainModel = TrayMenuModel()
        let secondaryModel = TrayMenuModel()
        mainModel.workspaceSidebarMonitorScopes = [
            WorkspaceSidebarMonitorScopeViewModel(
                id: workspaceSidebarDefaultScopeId,
                displayName: "Default",
                subtitle: nil,
                systemImageName: "display",
                isFocusedMonitor: false,
            ),
            WorkspaceSidebarMonitorScopeViewModel(
                id: "monitor:1440.0,0.0",
                displayName: "Secondary",
                subtitle: nil,
                systemImageName: "display",
                isFocusedMonitor: false,
            ),
        ]
        secondaryModel.workspaceSidebarMonitorScopes = mainModel.workspaceSidebarMonitorScopes

        selectWorkspaceSidebarMonitorScope("monitor:1440.0,0.0", viewModel: mainModel)

        XCTAssertEqual(mainModel.workspaceSidebarSelectedMonitorScopeId, "monitor:1440.0,0.0")
        XCTAssertEqual(secondaryModel.workspaceSidebarSelectedMonitorScopeId, workspaceSidebarDefaultScopeId)
        XCTAssertEqual(TrayMenuModel.shared.workspaceSidebarSelectedMonitorScopeId, workspaceSidebarDefaultScopeId)
    }

    @MainActor
    func testMonitorScopesOmitDisabledFocusAndAllFilters() {
        let main = WorkspaceSidebarDragTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            isMain: true,
        )
        let secondary = WorkspaceSidebarDragTestMonitor(
            monitorAppKitNsScreenScreensId: 2,
            name: "Secondary",
            rect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            isMain: false,
        )

        let scopes = buildWorkspaceSidebarMonitorScopes(
            sortedMonitors: [main, secondary],
            focusedMonitorScopeId: workspaceSidebarMonitorScopeId(for: main),
        )

        XCTAssertEqual(scopes.map(\.id), [
            workspaceSidebarDefaultScopeId,
            workspaceSidebarMonitorScopeId(for: main),
            workspaceSidebarMonitorScopeId(for: secondary),
        ])
    }

    @MainActor
    func testMonitorScopesDedupeZoneViewportsByPhysicalMonitor() {
        setUpWorkspacesForTests()
        defer { setUpWorkspacesForTests() }
        let main = WorkspaceSidebarDragTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
            isMain: true,
        )
        setMonitorsForTests([main])
        config.gaps = .zero
        config.workspaceSidebar.enabled = true
        config.workspaceSidebar.enableFocus = false
        config.zones = [
            ZoneConfig(
                monitor: .sequenceNumber(1),
                layout: .columns,
                defaultZone: "main",
                columns: [
                    ZoneColumnConfig(id: "left", name: "Reference", width: 0.25),
                    ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
                    ZoneColumnConfig(id: "right", name: "Comms", width: 0.25),
                ],
            ),
        ]
        let zoneViewports = sortedMonitors
        XCTAssertEqual(zoneViewports.compactMap(\.zoneId), ["left", "main", "right"])
        XCTAssertEqual(Set(zoneViewports.map { workspaceSidebarMonitorScopeId(for: $0) }).count, 1)

        let scopes = buildWorkspaceSidebarMonitorScopes(
            sortedMonitors: zoneViewports,
            focusedMonitorScopeId: workspaceSidebarMonitorScopeId(for: zoneViewports[1]),
        )

        XCTAssertEqual(scopes.map(\.id), [
            workspaceSidebarDefaultScopeId,
            workspaceSidebarMonitorScopeId(for: main),
        ])
        XCTAssertEqual(workspaceSidebarMonitor(forScopeId: workspaceSidebarMonitorScopeId(for: main))?.zoneId, "main")
    }

    @MainActor
    func testWorkspaceSidebarBuildsZoneTargetsForPhysicalMonitorScope() {
        setUpWorkspacesForTests()
        defer { setUpWorkspacesForTests() }
        let zones = configureWorkspaceSidebarThreeZones()
        let reference = Workspace.get(byName: "reference")
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["left"].orDie().setActiveWorkspace(reference))
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        XCTAssertTrue(work.focusWorkspace())

        let targets = buildWorkspaceSidebarZoneTargetViewModels(
            sortedMonitors: sortedMonitors,
            currentFocus: focus,
        )

        XCTAssertEqual(targets.map(\.zoneId), ["left", "main", "right"])
        XCTAssertEqual(targets.map(\.displayName), ["Reference", "Work", "Comms"])
        XCTAssertEqual(targets.map(\.activeWorkspaceName), ["reference", "work", "comms"].map(Optional.some))
        XCTAssertEqual(targets.map(\.isEnabled), [true, true, true])
        XCTAssertEqual(Set(targets.map(\.monitorScopeId)).count, 1)
        XCTAssertEqual(targets.singleOrNil { $0.zoneId == "main" }?.isFocused, true)
    }

    @MainActor
    func testSidebarZoneTargetsResolveWithinPhysicalMonitorScopeWhenZoneIdsRepeat() {
        setUpWorkspacesForTests()
        defer { setUpWorkspacesForTests() }
        let zones = configureWorkspaceSidebarDuplicateZonesByScope()
        let mainScope = zones.mainScope
        let secondaryScope = zones.secondaryScope
        let mainRight = Workspace.get(byName: "main-comms")
        let secondaryRight = Workspace.get(byName: "secondary-comms")
        XCTAssertTrue(zones.mainRight.setActiveWorkspace(mainRight))
        XCTAssertTrue(zones.secondaryRight.setActiveWorkspace(secondaryRight))
        XCTAssertTrue(mainRight.focusWorkspace())

        let targets = buildWorkspaceSidebarZoneTargetViewModels(
            sortedMonitors: sortedMonitors,
            currentFocus: focus,
        )

        XCTAssertEqual(targets.filter { $0.monitorScopeId == mainScope }.map(\.zoneId), ["left", "main", "right"])
        XCTAssertEqual(targets.filter { $0.monitorScopeId == secondaryScope }.map(\.zoneId), ["left", "main", "right"])
        XCTAssertEqual(targets.filter { $0.zoneId == "right" }.map(\.activeWorkspaceName), ["main-comms", "secondary-comms"].map(Optional.some))
        XCTAssertEqual(targets.filter { $0.zoneId == "right" }.map(\.displayName), ["Main Comms", "Secondary Comms"])
        XCTAssertTrue(workspaceSidebarResolvedZoneTarget(monitorScopeId: mainScope, zoneId: "right")?.activeWorkspace === mainRight)
        XCTAssertTrue(workspaceSidebarResolvedZoneTarget(monitorScopeId: secondaryScope, zoneId: "right")?.activeWorkspace === secondaryRight)
        XCTAssertTrue(isActionableSidebarWorkspaceDropTarget(
            sourceWorkspaceName: "secondary-comms",
            targetKind: .zone(monitorScopeId: mainScope, zoneId: "right"),
        ))
        XCTAssertFalse(isActionableSidebarWorkspaceDropTarget(
            sourceWorkspaceName: "secondary-comms",
            targetKind: .zone(monitorScopeId: secondaryScope, zoneId: "right"),
        ))
    }

    @MainActor
    func testSameZoneSidebarDropTargetIsNotActionable() {
        setUpWorkspacesForTests()
        defer { setUpWorkspacesForTests() }
        let zones = configureWorkspaceSidebarThreeZones()
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))

        XCTAssertFalse(isActionableSidebarWorkspaceDropTarget(
            sourceWorkspaceName: "comms",
            targetKind: .zone(
                monitorScopeId: workspaceSidebarMonitorScopeId(for: zones["right"].orDie()),
                zoneId: "right",
            ),
        ))
    }

    @MainActor
    func testDifferentZoneSidebarDropTargetIsActionable() {
        setUpWorkspacesForTests()
        defer { setUpWorkspacesForTests() }
        let zones = configureWorkspaceSidebarThreeZones()
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))

        XCTAssertTrue(isActionableSidebarWorkspaceDropTarget(
            sourceWorkspaceName: "work",
            targetKind: .zone(
                monitorScopeId: workspaceSidebarMonitorScopeId(for: zones["right"].orDie()),
                zoneId: "right",
            ),
        ))
    }

    @MainActor
    func testMoveWindowFromSidebarToZoneMovesToZoneActiveWorkspace() {
        setUpWorkspacesForTests()
        defer { setUpWorkspacesForTests() }
        let zones = configureWorkspaceSidebarThreeZones()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let window = TestWindow.new(id: 801, parent: work.rootTilingContainer)

        XCTAssertTrue(moveSidebarSourceToZoneNow(
            window.windowId,
            subject: .window,
            monitorScopeId: workspaceSidebarMonitorScopeId(for: zones["right"].orDie()),
            zoneId: "right",
        ))

        XCTAssertTrue(window.nodeWorkspace === comms)
        XCTAssertFalse(work.rootTilingContainer.allLeafWindowsRecursive.contains(window))
    }

    @MainActor
    func testMoveTabGroupFromSidebarToZoneMovesWholeGroup() {
        setUpWorkspacesForTests()
        defer { setUpWorkspacesForTests() }
        let zones = configureWorkspaceSidebarThreeZones()
        let work = Workspace.get(byName: "work")
        let comms = Workspace.get(byName: "comms")
        XCTAssertTrue(zones["main"].orDie().setActiveWorkspace(work))
        XCTAssertTrue(zones["right"].orDie().setActiveWorkspace(comms))
        let tabGroup = TilingContainer(parent: work.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, .h, .tabGroup, index: INDEX_BIND_LAST)
        let first = TestWindow.new(id: 811, parent: tabGroup)
        let second = TestWindow.new(id: 812, parent: tabGroup)

        XCTAssertTrue(moveSidebarSourceToZoneNow(
            first.windowId,
            subject: .group,
            monitorScopeId: workspaceSidebarMonitorScopeId(for: zones["right"].orDie()),
            zoneId: "right",
        ))

        XCTAssertTrue(tabGroup.nodeWorkspace === comms)
        XCTAssertTrue(first.nodeWorkspace === comms)
        XCTAssertTrue(second.nodeWorkspace === comms)
        XCTAssertFalse(work.rootTilingContainer.allLeafWindowsRecursive.contains(first))
    }

    @MainActor
    func testWorkspaceSidebarFocusFilterDefaultsOff() {
        XCTAssertFalse(defaultConfig.workspaceSidebar.enableFocus)
    }

    @MainActor
    func testMonitorScopesIncludeFocusFilterWhenEnabled() {
        let previous = config.workspaceSidebar.enableFocus
        config.workspaceSidebar.enableFocus = true
        defer { config.workspaceSidebar.enableFocus = previous }
        let main = WorkspaceSidebarDragTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            isMain: true,
        )

        let scopes = buildWorkspaceSidebarMonitorScopes(
            sortedMonitors: [main],
            focusedMonitorScopeId: workspaceSidebarMonitorScopeId(for: main),
        )

        XCTAssertEqual(scopes.map(\.id), [
            workspaceSidebarDefaultScopeId,
            workspaceSidebarFocusedScopeId,
            workspaceSidebarMonitorScopeId(for: main),
        ])
    }

    func testVisibleWorkspacesAreGroupedByProjectAndScope() {
        let focusedScope = "monitor:0.0"
        let otherScope = "monitor:1920.0"
        let workspaces = [
            WorkspaceSidebarWorkspaceViewModel(
                name: "1",
                projectId: "default",
                displayName: "1",
                sidebarLabel: "",
                isGeneratedName: false,
                monitorScopeId: focusedScope,
                monitorName: nil,
                isFocused: true,
                isVisible: true,
                items: [],
            ),
            WorkspaceSidebarWorkspaceViewModel(
                name: "2",
                projectId: "project-b",
                displayName: "2",
                sidebarLabel: "",
                isGeneratedName: false,
                monitorScopeId: otherScope,
                monitorName: nil,
                isFocused: false,
                isVisible: true,
                items: [],
            ),
        ]

        let grouped = workspaceSidebarVisibleWorkspacesByProject(
            workspaces: workspaces,
            selectedScopeId: workspaceSidebarFocusedScopeId,
            focusedMonitorScopeId: focusedScope,
        )

        XCTAssertEqual(grouped["default"]?.map(\.name), ["1"])
        XCTAssertNil(grouped["project-b"])
    }

    func testProjectPagerRendersOnlyCurrentAndSwipeTargetPages() {
        XCTAssertTrue(shouldRenderWorkspaceSidebarProjectPage(index: 1, displayIndex: 1, swipeDirection: nil, projectCount: 4))
        XCTAssertFalse(shouldRenderWorkspaceSidebarProjectPage(index: 0, displayIndex: 1, swipeDirection: nil, projectCount: 4))
        XCTAssertTrue(shouldRenderWorkspaceSidebarProjectPage(index: 2, displayIndex: 1, swipeDirection: 1, projectCount: 4))
        XCTAssertFalse(shouldRenderWorkspaceSidebarProjectPage(index: 3, displayIndex: 1, swipeDirection: 1, projectCount: 4))
    }
}

@MainActor
private func configureWorkspaceSidebarThreeZones(defaultZone: String = "main") -> [String: Monitor] {
    let main = WorkspaceSidebarDragTestMonitor(
        monitorAppKitNsScreenScreensId: 1,
        name: "Main",
        rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        isMain: true,
    )
    setMonitorsForTests([main])
    config.gaps = .zero
    config.workspaceSidebar.enabled = true
    config.workspaceSidebar.enableFocus = false
    config.zones = [
        ZoneConfig(
            monitor: .sequenceNumber(1),
            layout: .columns,
            defaultZone: defaultZone,
            columns: [
                ZoneColumnConfig(id: "left", name: "Reference", width: 0.25),
                ZoneColumnConfig(id: "main", name: "Work", width: 0.50),
                ZoneColumnConfig(id: "right", name: "Comms", width: 0.25),
            ],
        ),
    ]
    refreshZoneTopologySnapshot()
    return Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.zoneId.map { ($0, monitor) }
    })
}

@MainActor
private func configureWorkspaceSidebarDuplicateZonesByScope() -> (
    mainScope: String,
    secondaryScope: String,
    mainRight: Monitor,
    secondaryRight: Monitor
) {
    let main = WorkspaceSidebarDragTestMonitor(
        monitorAppKitNsScreenScreensId: 1,
        name: "Main",
        rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 800),
        isMain: true,
    )
    let secondary = WorkspaceSidebarDragTestMonitor(
        monitorAppKitNsScreenScreensId: 2,
        name: "Secondary",
        rect: Rect(topLeftX: 1200, topLeftY: 0, width: 1200, height: 800),
        visibleRect: Rect(topLeftX: 1200, topLeftY: 0, width: 1200, height: 800),
        isMain: false,
    )
    setMonitorsForTests([main, secondary])
    config.gaps = .zero
    config.workspaceSidebar.enabled = true
    config.workspaceSidebar.enableFocus = false
    config.zones = [
        ZoneConfig(
            monitor: .sequenceNumber(1),
            layout: .columns,
            defaultZone: "main",
            columns: [
                ZoneColumnConfig(id: "left", name: "Main Reference", width: 0.25),
                ZoneColumnConfig(id: "main", name: "Main Work", width: 0.50),
                ZoneColumnConfig(id: "right", name: "Main Comms", width: 0.25),
            ],
        ),
        ZoneConfig(
            monitor: .sequenceNumber(2),
            layout: .columns,
            defaultZone: "main",
            columns: [
                ZoneColumnConfig(id: "left", name: "Secondary Reference", width: 0.25),
                ZoneColumnConfig(id: "main", name: "Secondary Work", width: 0.50),
                ZoneColumnConfig(id: "right", name: "Secondary Comms", width: 0.25),
            ],
        ),
    ]
    refreshZoneTopologySnapshot()
    let mainScope = workspaceSidebarMonitorScopeId(for: main)
    let secondaryScope = workspaceSidebarMonitorScopeId(for: secondary)
    return (
        mainScope: mainScope,
        secondaryScope: secondaryScope,
        mainRight: workspaceSidebarResolvedZoneTarget(monitorScopeId: mainScope, zoneId: "right").orDie().monitor,
        secondaryRight: workspaceSidebarResolvedZoneTarget(monitorScopeId: secondaryScope, zoneId: "right").orDie().monitor,
    )
}
