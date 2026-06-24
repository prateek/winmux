import AppKit
import Common

struct ZoneTopologySnapshot: Sendable {
    static let empty = ZoneTopologySnapshot(
        zones: [],
        zoneLayouts: [],
        gaps: .zero,
        workspaceSidebar: WorkspaceSidebarConfig(),
        activeZoneLayoutSelections: [:],
    )

    let zones: [ZoneConfig]
    let zoneLayouts: [ZoneLayoutConfig]
    let gaps: Gaps
    let workspaceSidebar: WorkspaceSidebarConfig
    let activeZoneLayoutSelections: [String: String]

    init(
        _ config: Config,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        activeZoneLayoutSelections: [String: String] = activeZoneLayoutSelectionsSnapshot(),
    ) {
        self.init(
            zones: Self.effectiveZones(config.zones, environment: environment),
            zoneLayouts: config.zoneLayouts,
            gaps: config.gaps,
            workspaceSidebar: config.workspaceSidebar,
            activeZoneLayoutSelections: activeZoneLayoutSelections,
        )
    }

    init(
        zones: [ZoneConfig],
        zoneLayouts: [ZoneLayoutConfig],
        gaps: Gaps,
        workspaceSidebar: WorkspaceSidebarConfig,
        activeZoneLayoutSelections: [String: String],
    ) {
        self.zones = zones
        self.zoneLayouts = zoneLayouts
        self.gaps = gaps
        self.workspaceSidebar = workspaceSidebar
        self.activeZoneLayoutSelections = activeZoneLayoutSelections
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
        guard let zoneLayout = resolvedZoneLayout(for: physicalMonitor, zoneConfig: zoneConfig),
              zoneLayout.layout == .columns,
              !zoneLayout.columns.isEmpty
        else { return [physicalMonitor] }

        let baseRect = physicalWorkspaceRect(for: physicalMonitor, sortedPhysicalMonitors: sortedPhysicalMonitors)
        let defaultZoneId = zoneLayout.defaultZone ?? zoneLayout.columns.first?.id
        var nextLeft = baseRect.topLeftX

        return zoneLayout.columns.enumerated().map { index, column in
            let isLast = index == zoneLayout.columns.count - 1
            let width = isLast ? baseRect.maxX - nextLeft : baseRect.width * CGFloat(column.width)
            let rect = Rect(topLeftX: nextLeft, topLeftY: baseRect.topLeftY, width: width, height: baseRect.height)
            nextLeft += width
            return ZoneMonitor(
                physicalMonitor: physicalMonitor,
                zoneLayoutId: zoneLayout.id,
                zoneId: column.id,
                zoneName: column.name,
                rect: rect,
                visibleRect: rect,
                isDefaultZone: column.id == defaultZoneId,
            )
        }
    }

    private func resolvedZoneLayout(for physicalMonitor: Monitor, zoneConfig: ZoneConfig) -> ResolvedZoneLayout? {
        let physicalIdentity = zoneLayoutPhysicalIdentity(for: physicalMonitor)
        let candidateIds = [
            activeZoneLayoutSelections[physicalIdentity],
            zoneConfig.layoutPreset,
        ].compactMap { $0 }

        for id in candidateIds {
            if let layout = zoneLayouts.first(where: { $0.id == id }) {
                return ResolvedZoneLayout(
                    id: id,
                    layout: layout.layout,
                    defaultZone: layout.defaultZone,
                    columns: layout.columns,
                )
            }
        }

        return ResolvedZoneLayout(
            id: nil,
            layout: zoneConfig.layout,
            defaultZone: zoneConfig.defaultZone,
            columns: zoneConfig.columns,
        )
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
    let zoneLayoutId: String?
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

private struct ResolvedZoneLayout {
    let id: String?
    let layout: ZoneLayoutKind?
    let defaultZone: String?
    let columns: [ZoneColumnConfig]
}

nonisolated(unsafe) private var activeZoneLayoutSelectionsByPhysicalIdentity: [String: String] = [:]
nonisolated(unsafe) private var currentZoneTopologySnapshot: ZoneTopologySnapshot = .empty

func activeZoneLayoutSelectionsSnapshot() -> [String: String] {
    activeZoneLayoutSelectionsByPhysicalIdentity
}

@MainActor
func resetActiveZoneLayoutSelectionsForTests() {
    activeZoneLayoutSelectionsByPhysicalIdentity = [:]
    refreshZoneTopologySnapshot()
}

@MainActor
func refreshZoneTopologySnapshot() {
    setCurrentZoneTopologySnapshot(ZoneTopologySnapshot(config))
    invalidateMonitorCaches()
}

@MainActor
func setActiveZoneLayout(_ layoutId: String, for physicalMonitor: Monitor) -> Result<Void, String> {
    guard config.zoneLayouts.contains(where: { $0.id == layoutId }) else {
        return .failure("Unknown zone layout preset '\(layoutId)'")
    }

    let physicalCandidates = sortMonitorsBySpatialOrder(physicalMonitors)
    let targetPhysical = physicalMonitor.physicalMonitor
    let targetTopLeft = targetPhysical.rect.topLeftCorner
    let hasZoneConfig = config.zones.contains { zone in
        guard let monitorDescription = zone.monitor,
              let resolved = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: physicalCandidates)
        else { return false }
        return resolved.rect.topLeftCorner == targetTopLeft
    }
    guard hasZoneConfig else {
        return .failure("No zone config targets monitor \(targetPhysical.monitorId_oneBased ?? 0)")
    }

    activeZoneLayoutSelectionsByPhysicalIdentity[zoneLayoutPhysicalIdentity(for: targetPhysical)] = layoutId
    refreshZoneTopologySnapshot()
    Workspace.reconcileWorkspaceState()
    return .success(())
}

func zoneLayoutPhysicalIdentity(for monitor: Monitor) -> String {
    let topLeft = monitor.physicalMonitor.rect.topLeftCorner
    return "physical:\(topLeft.x),\(topLeft.y)"
}

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
