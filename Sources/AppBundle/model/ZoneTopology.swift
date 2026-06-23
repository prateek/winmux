import AppKit
import Common

struct ZoneTopologySnapshot: Sendable {
    static let empty = ZoneTopologySnapshot(zones: [], gaps: .zero, workspaceSidebar: WorkspaceSidebarConfig())

    let zones: [ZoneConfig]
    let gaps: Gaps
    let workspaceSidebar: WorkspaceSidebarConfig

    init(_ config: Config, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.init(
            zones: Self.effectiveZones(config.zones, environment: environment),
            gaps: config.gaps,
            workspaceSidebar: config.workspaceSidebar,
        )
    }

    init(zones: [ZoneConfig], gaps: Gaps, workspaceSidebar: WorkspaceSidebarConfig) {
        self.zones = zones
        self.gaps = gaps
        self.workspaceSidebar = workspaceSidebar
    }

    var isEmpty: Bool { zones.isEmpty }

    private static func effectiveZones(_ configuredZones: [ZoneConfig], environment: [String: String]) -> [ZoneConfig] {
        guard isSpikeEnabled(environment) else { return configuredZones }
        return [
            ZoneConfig(
                monitor: .main,
                layout: .columns,
                defaultZone: "main",
                columns: [
                    ZoneColumnConfig(id: "left", name: "Left", width: 1.0 / 3.0),
                    ZoneColumnConfig(id: "main", name: "Main", width: 1.0 / 3.0),
                    ZoneColumnConfig(id: "right", name: "Right", width: 1.0 / 3.0),
                ],
            ),
        ]
    }

    private static func isSpikeEnabled(_ environment: [String: String]) -> Bool {
        switch environment["WINMUX_ZONES_SPIKE"]?.lowercased() {
            case "1", "true", "yes", "on": return true
            default: return false
        }
    }

    func workspaceViewports(for physicalMonitors: [Monitor]) -> [Monitor] {
        guard !zones.isEmpty else { return physicalMonitors }

        let sortedPhysicalMonitors = sortMonitorsBySpatialOrder(physicalMonitors)
        return physicalMonitors.flatMap { physicalMonitor -> [Monitor] in
            guard let zoneConfig = zones.first(where: { zone in
                guard let monitorDescription = zone.monitor else { return false }
                return resolvePhysicalMonitor(monitorDescription, sortedPhysicalMonitors: sortedPhysicalMonitors)?.rect.topLeftCorner == physicalMonitor.rect.topLeftCorner
            }) else {
                return [physicalMonitor]
            }
            return zoneMonitors(for: physicalMonitor, zoneConfig: zoneConfig, sortedPhysicalMonitors: sortedPhysicalMonitors)
        }
    }

    private func zoneMonitors(
        for physicalMonitor: Monitor,
        zoneConfig: ZoneConfig,
        sortedPhysicalMonitors: [Monitor],
    ) -> [Monitor] {
        guard zoneConfig.layout == .columns, !zoneConfig.columns.isEmpty else { return [physicalMonitor] }

        let baseRect = physicalWorkspaceRect(for: physicalMonitor, sortedPhysicalMonitors: sortedPhysicalMonitors)
        let defaultZoneId = zoneConfig.defaultZone ?? zoneConfig.columns.first?.id
        var nextLeft = baseRect.topLeftX

        return zoneConfig.columns.enumerated().map { index, column in
            let isLast = index == zoneConfig.columns.count - 1
            let width = isLast ? baseRect.maxX - nextLeft : baseRect.width * CGFloat(column.width)
            let rect = Rect(topLeftX: nextLeft, topLeftY: baseRect.topLeftY, width: width, height: baseRect.height)
            nextLeft += width
            return ZoneMonitor(
                physicalMonitor: physicalMonitor,
                zoneId: column.id,
                zoneName: column.name,
                rect: rect,
                visibleRect: rect,
                isDefaultZone: column.id == defaultZoneId,
            )
        }
    }

    private func physicalWorkspaceRect(
        for physicalMonitor: Monitor,
        sortedPhysicalMonitors: [Monitor],
    ) -> Rect {
        let visibleRect = physicalMonitor.visibleRect
        let gaps = resolvedOuterGaps(for: physicalMonitor, sortedPhysicalMonitors: sortedPhysicalMonitors)
        let sidebarInset = workspaceSidebarInset(for: physicalMonitor, sortedPhysicalMonitors: sortedPhysicalMonitors)
        let leftInset = CGFloat(gaps.left + sidebarInset)
        return Rect(
            topLeftX: visibleRect.topLeftX + leftInset,
            topLeftY: visibleRect.topLeftY + CGFloat(gaps.top),
            width: visibleRect.width - leftInset - CGFloat(gaps.right),
            height: visibleRect.height - CGFloat(gaps.top) - CGFloat(gaps.bottom),
        )
    }

    private func resolvedOuterGaps(
        for physicalMonitor: Monitor,
        sortedPhysicalMonitors: [Monitor],
    ) -> (left: Int, bottom: Int, top: Int, right: Int) {
        (
            left: resolvedDynamicValue(gaps.outer.left, for: physicalMonitor, sortedPhysicalMonitors: sortedPhysicalMonitors),
            bottom: resolvedDynamicValue(gaps.outer.bottom, for: physicalMonitor, sortedPhysicalMonitors: sortedPhysicalMonitors),
            top: resolvedDynamicValue(gaps.outer.top, for: physicalMonitor, sortedPhysicalMonitors: sortedPhysicalMonitors),
            right: resolvedDynamicValue(gaps.outer.right, for: physicalMonitor, sortedPhysicalMonitors: sortedPhysicalMonitors),
        )
    }

    private func resolvedDynamicValue<Value: Equatable>(
        _ dynamicValue: DynamicConfigValue<Value>,
        for physicalMonitor: Monitor,
        sortedPhysicalMonitors: [Monitor],
    ) -> Value {
        switch dynamicValue {
            case .constant(let value):
                return value
            case .perMonitor(let rules, let defaultValue):
                return rules.lazy.compactMap { rule -> Value? in
                    let resolvedMonitor = resolvePhysicalMonitor(rule.description, sortedPhysicalMonitors: sortedPhysicalMonitors)
                    return resolvedMonitor?.rect.topLeftCorner == physicalMonitor.rect.topLeftCorner ? rule.value : nil
                }.first ?? defaultValue
        }
    }

    private func workspaceSidebarInset(
        for physicalMonitor: Monitor,
        sortedPhysicalMonitors: [Monitor],
    ) -> Int {
        guard workspaceSidebar.enabled else { return 0 }
        let panelMonitors = resolvedWorkspaceSidebarPanelMonitors(sortedPhysicalMonitors: sortedPhysicalMonitors)
        return panelMonitors.contains { $0.rect.topLeftCorner == physicalMonitor.rect.topLeftCorner }
            ? workspaceSidebar.collapsedWidth
            : 0
    }

    private func resolvedWorkspaceSidebarPanelMonitors(sortedPhysicalMonitors: [Monitor]) -> [Monitor] {
        guard !workspaceSidebar.monitor.isEmpty else { return sortedPhysicalMonitors }
        if workspaceSidebar.monitor == [.main] {
            return sortedPhysicalMonitors
        }
        var seenTopLeftCorners = Set<CGPoint>()
        return workspaceSidebar.monitor
            .compactMap { resolvePhysicalMonitor($0, sortedPhysicalMonitors: sortedPhysicalMonitors) }
            .filter { seenTopLeftCorners.insert($0.rect.topLeftCorner).inserted }
    }

    private func resolvePhysicalMonitor(
        _ description: MonitorDescription,
        sortedPhysicalMonitors: [Monitor],
    ) -> Monitor? {
        switch description {
            case .sequenceNumber(let number):
                sortedPhysicalMonitors.getOrNil(atIndex: number - 1)
            case .main:
                sortedPhysicalMonitors.first(where: \.isMain) ?? sortedPhysicalMonitors.first
            case .pattern(_, let regex):
                sortedPhysicalMonitors.first { $0.name.contains(regex.val) }
            case .secondary:
                sortedPhysicalMonitors.takeIf { $0.count == 2 }?
                    .first { !$0.isMain }
        }
    }
}

private struct ZoneMonitor: Monitor {
    let physicalMonitor: Monitor
    let zoneId: String?
    let zoneName: String?
    let rect: Rect
    let visibleRect: Rect
    let isDefaultZone: Bool

    var monitorAppKitNsScreenScreensId: Int { physicalMonitor.monitorAppKitNsScreenScreensId }
    var name: String { "\(physicalMonitor.name) / \(zoneName ?? zoneId ?? "Zone")" }
    var width: CGFloat { rect.width }
    var height: CGFloat { rect.height }
    var isMain: Bool { physicalMonitor.isMain && isDefaultZone }
}

nonisolated(unsafe) private var currentZoneTopologySnapshot: ZoneTopologySnapshot = .empty

func setCurrentZoneTopologySnapshot(_ snapshot: ZoneTopologySnapshot) {
    currentZoneTopologySnapshot = snapshot
}

func getCurrentZoneTopologySnapshot() -> ZoneTopologySnapshot {
    currentZoneTopologySnapshot
}

func sortMonitorsBySpatialOrder(_ monitors: [Monitor]) -> [Monitor] {
    monitors.sorted {
        if $0.rect.minX != $1.rect.minX {
            return $0.rect.minX < $1.rect.minX
        }
        if $0.rect.minY != $1.rect.minY {
            return $0.rect.minY < $1.rect.minY
        }
        return $0.monitorAppKitNsScreenScreensId < $1.monitorAppKitNsScreenScreensId
    }
}
