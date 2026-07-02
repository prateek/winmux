import CoreGraphics
import Foundation

@MainActor
func buildWorkspaceSidebarZoneTargetViewModels(
    sortedMonitors: [Monitor],
    currentFocus: LiveFocus,
) -> [WorkspaceSidebarZoneTargetViewModel] {
    let physicalMonitors = workspaceSidebarPhysicalMonitors(from: sortedMonitors)
    let activeZoneMonitors = sortedMonitors.filter { $0.zoneId != nil }
    return getCurrentZoneTopologySnapshot()
        .configuredZones(for: physicalMonitors)
        .map { zone in
            let monitorScopeId = workspaceSidebarMonitorScopeId(for: zone.physicalMonitor)
            let activeWorkspace = activeZoneMonitors
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
