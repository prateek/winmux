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
            testDisplayLayoutConfig(
                monitor: .sequenceNumber(1),
                defaultZone: "main",
                columns: [
                    ColumnConfig(id: "left", name: "Reference", width: 0.25),
                    ColumnConfig(id: "main", name: "Work", width: 0.50),
                    ColumnConfig(id: "right", name: "Comms", width: 0.25),
                ],
            ),
        ]
        let columnViewports = sortedMonitors
        XCTAssertEqual(columnViewports.compactMap(\.columnId), ["left", "main", "right"])
        XCTAssertEqual(Set(columnViewports.map { workspaceSidebarMonitorScopeId(for: $0) }).count, 1)

        let scopes = buildWorkspaceSidebarMonitorScopes(
            sortedMonitors: columnViewports,
            focusedMonitorScopeId: workspaceSidebarMonitorScopeId(for: columnViewports[1]),
        )

        XCTAssertEqual(scopes.map(\.id), [
            workspaceSidebarDefaultScopeId,
            workspaceSidebarMonitorScopeId(for: main),
        ])
        XCTAssertEqual(workspaceSidebarMonitor(forScopeId: workspaceSidebarMonitorScopeId(for: main))?.columnId, "main")
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

        let targets = buildWorkspaceSidebarColumnTargetViewModels(
            sortedMonitors: sortedMonitors,
            currentFocus: focus,
        )

        XCTAssertEqual(targets.map(\.columnId), ["left", "main", "right"])
        XCTAssertEqual(targets.map(\.displayName), ["Reference", "Work", "Comms"])
        XCTAssertEqual(targets.map(\.activeWorkspaceName), ["reference", "work", "comms"].map(Optional.some))
        XCTAssertEqual(targets.map(\.isEnabled), [true, true, true])
        XCTAssertEqual(Set(targets.map(\.monitorScopeId)).count, 1)
        XCTAssertEqual(targets.singleOrNil { $0.columnId == "main" }?.isFocused, true)
    }

    @MainActor
    func testSidebarZoneTargetsResolveWithinPhysicalMonitorScopeWhenColumnIdsRepeat() {
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

        let targets = buildWorkspaceSidebarColumnTargetViewModels(
            sortedMonitors: sortedMonitors,
            currentFocus: focus,
        )

        XCTAssertEqual(targets.filter { $0.monitorScopeId == mainScope }.map(\.columnId), ["left", "main", "right"])
        XCTAssertEqual(targets.filter { $0.monitorScopeId == secondaryScope }.map(\.columnId), ["left", "main", "right"])
        XCTAssertEqual(targets.filter { $0.columnId == "right" }.map(\.activeWorkspaceName), ["main-comms", "secondary-comms"].map(Optional.some))
        XCTAssertEqual(targets.filter { $0.columnId == "right" }.map(\.displayName), ["Main Comms", "Secondary Comms"])
        XCTAssertTrue(workspaceSidebarResolvedColumnTarget(monitorScopeId: mainScope, columnId: "right")?.activeWorkspace === mainRight)
        XCTAssertTrue(workspaceSidebarResolvedColumnTarget(monitorScopeId: secondaryScope, columnId: "right")?.activeWorkspace === secondaryRight)
        XCTAssertTrue(isActionableSidebarWorkspaceDropTarget(
            sourceWorkspaceName: "secondary-comms",
            targetKind: .column(monitorScopeId: mainScope, columnId: "right"),
        ))
        XCTAssertFalse(isActionableSidebarWorkspaceDropTarget(
            sourceWorkspaceName: "secondary-comms",
            targetKind: .column(monitorScopeId: secondaryScope, columnId: "right"),
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
            targetKind: .column(
                monitorScopeId: workspaceSidebarMonitorScopeId(for: zones["right"].orDie()),
                columnId: "right",
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
            targetKind: .column(
                monitorScopeId: workspaceSidebarMonitorScopeId(for: zones["right"].orDie()),
                columnId: "right",
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
            columnId: "right",
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
            columnId: "right",
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
        testDisplayLayoutConfig(
            monitor: .sequenceNumber(1),
            defaultZone: defaultZone,
            columns: [
                ColumnConfig(id: "left", name: "Reference", width: 0.25),
                ColumnConfig(id: "main", name: "Work", width: 0.50),
                ColumnConfig(id: "right", name: "Comms", width: 0.25),
            ],
        ),
    ]
    refreshColumnTopologySnapshot()
    return Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor in
        monitor.columnId.map { ($0, monitor) }
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
        testDisplayLayoutConfig(
            monitor: .sequenceNumber(1),
            layoutId: "main-layout",
            defaultZone: "main",
            columns: [
                ColumnConfig(id: "left", name: "Main Reference", width: 0.25),
                ColumnConfig(id: "main", name: "Main Work", width: 0.50),
                ColumnConfig(id: "right", name: "Main Comms", width: 0.25),
            ],
        ),
        testDisplayLayoutConfig(
            monitor: .sequenceNumber(2),
            layoutId: "secondary-layout",
            defaultZone: "main",
            columns: [
                ColumnConfig(id: "left", name: "Secondary Reference", width: 0.25),
                ColumnConfig(id: "main", name: "Secondary Work", width: 0.50),
                ColumnConfig(id: "right", name: "Secondary Comms", width: 0.25),
            ],
        ),
    ]
    refreshColumnTopologySnapshot()
    let mainScope = workspaceSidebarMonitorScopeId(for: main)
    let secondaryScope = workspaceSidebarMonitorScopeId(for: secondary)
    return (
        mainScope: mainScope,
        secondaryScope: secondaryScope,
        mainRight: workspaceSidebarResolvedColumnTarget(monitorScopeId: mainScope, columnId: "right").orDie().monitor,
        secondaryRight: workspaceSidebarResolvedColumnTarget(monitorScopeId: secondaryScope, columnId: "right").orDie().monitor,
    )
}
