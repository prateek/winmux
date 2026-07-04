import CoreGraphics
import Foundation

@MainActor
func buildWorkspaceSidebarZoneTargetViewModels(
    sortedMonitors: [Monitor],
    currentFocus: LiveFocus,
) -> [WorkspaceSidebarZoneTargetViewModel] {
    let physicalMonitors = workspaceSidebarPhysicalMonitors(from: sortedMonitors)
    let activeColumnMonitors = sortedMonitors.filter { $0.zoneId != nil }
    return getCurrentColumnTopologySnapshot()
        .configuredZones(for: physicalMonitors)
        .map { zone in
            let monitorScopeId = workspaceSidebarMonitorScopeId(for: zone.physicalMonitor)
            let activeWorkspace = activeColumnMonitors
                .first {
                    $0.zoneId == zone.zoneId &&
                        $0.physicalMonitor.rect.topLeftCorner == zone.physicalMonitor.rect.topLeftCorner
                }?
                .activeWorkspace
            return WorkspaceSidebarZoneTargetViewModel(
                id: "\(monitorScopeId):\(zone.zoneId)",
                monitorScopeId: monitorScopeId,
                zoneId: zone.zoneId,
                displayName: zone.displayName,
                activeWorkspaceName: activeWorkspace?.name,
                activeWorkspaceDisplayName: activeWorkspace
                    .map { workspaceDisplayName($0.name) }
                    ?? "Hidden",
                isFocused: activeWorkspace.map { currentFocus.workspace === $0 } ?? false,
                isDefaultZone: zone.isDefaultZone,
                isEnabled: zone.isEnabled,
                availabilitySetId: zone.zoneAvailabilitySetId,
                styleId: zone.zoneStyleId,
                styleColorHex: zone.zoneStyleColorHex,
            )
        }
}

private func workspaceSidebarPhysicalMonitors(from monitors: [Monitor]) -> [Monitor] {
    var seenTopLeftCorners = Set<CGPoint>()
    return sortMonitorsBySpatialOrder(monitors.map(\.physicalMonitor))
        .filter { seenTopLeftCorners.insert($0.rect.topLeftCorner).inserted }
}

func workspaceSidebarZoneDisplayName(_ monitor: Monitor) -> String {
    monitor.zoneName?.takeIf { !$0.isEmpty } ?? monitor.zoneId ?? "Zone"
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
    let activeColumnViewports = sortedMonitors.filter { $0.zoneId != nil }
    let configuredColumnsByDisplay = Dictionary(
        grouping: getCurrentColumnTopologySnapshot().configuredZones(for: physicalMonitors),
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
    column: ConfiguredZoneSummary,
    physicalMonitor: Monitor,
    monitorScopeId: String,
    activeColumnViewports: [Monitor],
    currentFocus: LiveFocus,
) -> WorkspaceSidebarColumnSectionViewModel {
    let viewport = activeColumnViewports.first {
        $0.zoneId == column.zoneId &&
            $0.physicalMonitor.rect.topLeftCorner == physicalMonitor.rect.topLeftCorner
    }
    // A disabled column has no live viewport, but its deck survives; key it by scene + column id.
    let columnKey = viewport.map { columnDeckKey(for: $0) }
        ?? columnDeckKey(sceneKey: activeSceneDeckKeyComponent(for: physicalMonitor), columnId: column.zoneId)
    let showingCard = viewport?.activeWorkspace
    return WorkspaceSidebarColumnSectionViewModel(
        id: "\(monitorScopeId):\(column.zoneId)",
        monitorScopeId: monitorScopeId,
        columnId: column.zoneId,
        title: column.displayName,
        colorHex: column.zoneStyleColorHex,
        isDefaultColumn: column.isDefaultZone,
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
