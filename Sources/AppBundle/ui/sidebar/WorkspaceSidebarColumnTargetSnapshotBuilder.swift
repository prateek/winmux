import CoreGraphics
import Foundation

@MainActor
func buildWorkspaceSidebarColumnTargetViewModels(
    sortedMonitors: [Monitor],
    currentFocus: LiveFocus,
) -> [WorkspaceSidebarColumnTargetViewModel] {
    let physicalMonitors = workspaceSidebarPhysicalMonitors(from: sortedMonitors)
    let activeColumnMonitors = sortedMonitors.filter { $0.columnId != nil }
    return getCurrentColumnTopologySnapshot()
        .configuredColumns(for: physicalMonitors)
        .map { zone in
            let monitorScopeId = workspaceSidebarMonitorScopeId(for: zone.physicalMonitor)
            let activeWorkspace = activeColumnMonitors
                .first {
                    $0.columnId == zone.columnId &&
                        $0.physicalMonitor.rect.topLeftCorner == zone.physicalMonitor.rect.topLeftCorner
                }?
                .activeWorkspace
            return WorkspaceSidebarColumnTargetViewModel(
                id: "\(monitorScopeId):\(zone.columnId)",
                monitorScopeId: monitorScopeId,
                columnId: zone.columnId,
                displayName: zone.displayName,
                activeWorkspaceName: activeWorkspace?.name,
                activeWorkspaceDisplayName: activeWorkspace
                    .map { workspaceDisplayName($0.name) }
                    ?? "Hidden",
                isFocused: activeWorkspace.map { currentFocus.workspace === $0 } ?? false,
                isDefaultColumn: zone.isDefaultColumn,
                isEnabled: zone.isEnabled,
                styleId: zone.zoneStyleId,
                styleColorHex: zone.columnColorHex,
            )
        }
}

/// The scenes declared for each display, in declared order, tagged with which one is active. The
/// non-active scenes are the sidebar's cross-scene card drop targets; an implicit display declares
/// no scenes and contributes none.
@MainActor
func buildWorkspaceSidebarSceneSwitchTargetViewModels(
    sortedMonitors: [Monitor],
) -> [WorkspaceSidebarSceneTargetViewModel] {
    workspaceSidebarPhysicalMonitors(from: sortedMonitors).flatMap { physicalMonitor -> [WorkspaceSidebarSceneTargetViewModel] in
        let monitorScopeId = workspaceSidebarMonitorScopeId(for: physicalMonitor)
        let activeId = activeSceneId(for: physicalMonitor)
        return scenes(on: physicalMonitor).map { scene in
            WorkspaceSidebarSceneTargetViewModel(
                id: "\(monitorScopeId):scene:\(scene.id)",
                monitorScopeId: monitorScopeId,
                sceneId: scene.id,
                displayName: scene.id,
                isActive: scene.id == activeId,
            )
        }
    }
}

private func workspaceSidebarPhysicalMonitors(from monitors: [Monitor]) -> [Monitor] {
    var seenTopLeftCorners = Set<CGPoint>()
    return sortMonitorsBySpatialOrder(monitors.map(\.physicalMonitor))
        .filter { seenTopLeftCorners.insert($0.rect.topLeftCorner).inserted }
}

func workspaceSidebarColumnDisplayName(_ monitor: Monitor) -> String {
    monitor.columnName?.takeIf { !$0.isEmpty } ?? monitor.columnId ?? "Zone"
}

/// The sidebar's grouping: one section per column of each display's active scene, in spatial
/// order, each carrying its column's deck (cards in deck order) and the card currently showing.
/// A display with no configured scene runs its implicit one-column scene and yields a single
/// headerless section holding all its cards, so the flat pre-scenes list is unchanged.
@MainActor
func buildWorkspaceSidebarColumnSectionViewModels(
    sortedMonitors: [Monitor],
    currentFocus: LiveFocus,
) -> [WorkspaceSidebarColumnSectionViewModel] {
    let physicalMonitors = workspaceSidebarPhysicalMonitors(from: sortedMonitors)
    let activeColumnViewports = sortedMonitors.filter { $0.columnId != nil }
    let configuredColumnsByDisplay = Dictionary(
        grouping: getCurrentColumnTopologySnapshot().configuredColumns(for: physicalMonitors),
        by: { $0.physicalMonitor.rect.topLeftCorner },
    )
    return physicalMonitors.flatMap { physicalMonitor -> [WorkspaceSidebarColumnSectionViewModel] in
        let monitorScopeId = workspaceSidebarMonitorScopeId(for: physicalMonitor)
        let configuredColumns = configuredColumnsByDisplay[physicalMonitor.rect.topLeftCorner] ?? []
        guard !configuredColumns.isEmpty else {
            return [workspaceSidebarImplicitColumnSection(
                physicalMonitor: physicalMonitor,
                monitorScopeId: monitorScopeId,
                currentFocus: currentFocus,
            )]
        }
        return configuredColumns.map { column in
            workspaceSidebarConfiguredColumnSection(
                column: column,
                physicalMonitor: physicalMonitor,
                monitorScopeId: monitorScopeId,
                activeColumnViewports: activeColumnViewports,
                currentFocus: currentFocus,
            )
        }
    }
}

@MainActor
private func workspaceSidebarConfiguredColumnSection(
    column: ConfiguredColumnSummary,
    physicalMonitor: Monitor,
    monitorScopeId: String,
    activeColumnViewports: [Monitor],
    currentFocus: LiveFocus,
) -> WorkspaceSidebarColumnSectionViewModel {
    let viewport = activeColumnViewports.first {
        $0.columnId == column.columnId &&
            $0.physicalMonitor.rect.topLeftCorner == physicalMonitor.rect.topLeftCorner
    }
    // A disabled column has no live viewport, but its deck survives; key it by scene + column id.
    let columnKey = viewport.map { columnDeckKey(for: $0) }
        ?? columnDeckKey(sceneKey: activeSceneDeckKeyComponent(for: physicalMonitor), columnId: column.columnId)
    let showingCard = viewport?.activeWorkspace
    return WorkspaceSidebarColumnSectionViewModel(
        id: "\(monitorScopeId):\(column.columnId)",
        monitorScopeId: monitorScopeId,
        columnId: column.columnId,
        title: column.displayName,
        colorHex: column.columnColorHex,
        isDefaultColumn: column.isDefaultColumn,
        isEnabled: column.isEnabled,
        isFocusedColumn: showingCard.map { currentFocus.workspace === $0 } ?? false,
        cardNames: orderedDeckWorkspaces(inColumn: columnKey).map(\.name),
        showingCardName: showingCard?.name,
    )
}

@MainActor
private func workspaceSidebarImplicitColumnSection(
    physicalMonitor: Monitor,
    monitorScopeId: String,
    currentFocus: LiveFocus,
) -> WorkspaceSidebarColumnSectionViewModel {
    let viewport = physicalMonitor.defaultWorkspaceViewport
    let showingCard = viewport.activeWorkspace
    return WorkspaceSidebarColumnSectionViewModel(
        id: "\(monitorScopeId):\(implicitColumnDeckColumnId)",
        monitorScopeId: monitorScopeId,
        columnId: implicitColumnDeckColumnId,
        title: nil,
        colorHex: nil,
        isDefaultColumn: true,
        isEnabled: true,
        isFocusedColumn: currentFocus.workspace === showingCard,
        cardNames: orderedDeckWorkspaces(inColumn: columnDeckKey(for: viewport)).map(\.name),
        showingCardName: showingCard.name,
    )
}
