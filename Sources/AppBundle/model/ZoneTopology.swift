import AppKit
import Common

struct ZoneTopologySnapshot: Sendable {
    static let empty = ZoneTopologySnapshot(
        zones: [],
        zoneLayouts: [],
        gaps: .zero,
        workspaceSidebar: WorkspaceSidebarConfig(),
        activeZoneLayoutSelections: [:],
        disabledZoneIdsByPhysicalIdentity: [:],
    )

    let zones: [ZoneConfig]
    let zoneLayouts: [ZoneLayoutConfig]
    let gaps: Gaps
    let workspaceSidebar: WorkspaceSidebarConfig
    let activeZoneLayoutSelections: [String: String]
    let disabledZoneIdsByPhysicalIdentity: [String: Set<String>]

    init(
        _ config: Config,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        activeZoneLayoutSelections: [String: String] = activeZoneLayoutSelectionsSnapshot(),
        disabledZoneIdsByPhysicalIdentity: [String: Set<String>] = activeZoneDisabledSelectionsSnapshot(),
    ) {
        self.init(
            zones: Self.effectiveZones(config.zones, environment: environment),
            zoneLayouts: config.zoneLayouts,
            gaps: config.gaps,
            workspaceSidebar: config.workspaceSidebar,
            activeZoneLayoutSelections: activeZoneLayoutSelections,
            disabledZoneIdsByPhysicalIdentity: disabledZoneIdsByPhysicalIdentity,
        )
    }

    init(
        zones: [ZoneConfig],
        zoneLayouts: [ZoneLayoutConfig],
        gaps: Gaps,
        workspaceSidebar: WorkspaceSidebarConfig,
        activeZoneLayoutSelections: [String: String],
        disabledZoneIdsByPhysicalIdentity: [String: Set<String>],
    ) {
        self.zones = zones
        self.zoneLayouts = zoneLayouts
        self.gaps = gaps
        self.workspaceSidebar = workspaceSidebar
        self.activeZoneLayoutSelections = activeZoneLayoutSelections
        self.disabledZoneIdsByPhysicalIdentity = disabledZoneIdsByPhysicalIdentity
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

        let disabledZoneIds = disabledZoneIds(for: physicalMonitor)
        let enabledColumns = zoneLayout.columns.filter { !disabledZoneIds.contains($0.id) }
        guard !enabledColumns.isEmpty else { return [physicalMonitor] }

        let baseRect = physicalWorkspaceRect(for: physicalMonitor, sortedPhysicalMonitors: sortedPhysicalMonitors)
        let configuredDefaultZoneId = zoneLayout.defaultZone
        let defaultZoneId = configuredDefaultZoneId.flatMap { defaultZoneId in
            enabledColumns.contains { $0.id == defaultZoneId } ? defaultZoneId : nil
        } ?? enabledColumns.first?.id
        let enabledWidthTotal = enabledColumns.reduce(0.0) { $0 + $1.width }
        var nextLeft = baseRect.topLeftX

        return enabledColumns.enumerated().map { index, column in
            let isLast = index == enabledColumns.count - 1
            let width = isLast ? baseRect.maxX - nextLeft : baseRect.width * CGFloat(column.width / enabledWidthTotal)
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

    func configuredZones(for physicalMonitors: [Monitor]) -> [ConfiguredZoneSummary] {
        guard !zones.isEmpty else { return [] }
        let sortedPhysicalMonitors = sortMonitorsBySpatialOrder(physicalMonitors)
        return physicalMonitors.flatMap { physicalMonitor -> [ConfiguredZoneSummary] in
            guard let zoneConfig = zones.first(where: { zone in
                guard let monitorDescription = zone.monitor else { return false }
                return resolvePhysicalMonitor(monitorDescription, sortedPhysicalMonitors: sortedPhysicalMonitors)?.rect.topLeftCorner == physicalMonitor.rect.topLeftCorner
            }),
                  let zoneLayout = resolvedZoneLayout(for: physicalMonitor, zoneConfig: zoneConfig),
                  zoneLayout.layout == .columns
            else { return [] }

            let disabledZoneIds = disabledZoneIds(for: physicalMonitor)
            let defaultZoneId = zoneLayout.defaultZone ?? zoneLayout.columns.first?.id
            return zoneLayout.columns.map { column in
                ConfiguredZoneSummary(
                    physicalMonitor: physicalMonitor,
                    zoneLayoutId: zoneLayout.id,
                    zoneId: column.id,
                    zoneName: column.name,
                    width: column.width,
                    isDefaultZone: column.id == defaultZoneId,
                    isEnabled: !disabledZoneIds.contains(column.id),
                )
            }
        }
    }

    private func disabledZoneIds(for physicalMonitor: Monitor) -> Set<String> {
        disabledZoneIdsByPhysicalIdentity[zoneLayoutPhysicalIdentity(for: physicalMonitor)] ?? []
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

struct ConfiguredZoneSummary {
    let physicalMonitor: Monitor
    let zoneLayoutId: String?
    let zoneId: String
    let zoneName: String?
    let width: Double
    let isDefaultZone: Bool
    let isEnabled: Bool
}

struct ResolvedConfiguredZoneSelector {
    let physicalMonitor: Monitor
    let zoneLayoutId: String?
    let zoneId: String
    let zoneName: String?
    let isDefaultZone: Bool
    let isEnabled: Bool

    var displayName: String { zoneName ?? zoneId }
}

nonisolated(unsafe) private var activeZoneLayoutSelectionsByPhysicalIdentity: [String: String] = [:]
nonisolated(unsafe) private var activeZoneDisabledSelectionsByPhysicalIdentity: [String: Set<String>] = [:]
nonisolated(unsafe) private var parkedWorkspaceByZoneAvailabilityKey: [String: WorkspaceId] = [:]
nonisolated(unsafe) private var currentZoneTopologySnapshot: ZoneTopologySnapshot = .empty

func activeZoneLayoutSelectionsSnapshot() -> [String: String] {
    activeZoneLayoutSelectionsByPhysicalIdentity
}

func activeZoneDisabledSelectionsSnapshot() -> [String: Set<String>] {
    activeZoneDisabledSelectionsByPhysicalIdentity
}

@MainActor
func resetActiveZoneLayoutSelectionsForTests() {
    activeZoneLayoutSelectionsByPhysicalIdentity = [:]
    activeZoneDisabledSelectionsByPhysicalIdentity = [:]
    parkedWorkspaceByZoneAvailabilityKey = [:]
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

enum ZoneAvailabilityOperation {
    case enable
    case disable
    case toggle
}

struct ZoneAvailabilityChange {
    let zoneId: String
    let zoneName: String?
    let physicalMonitor: Monitor
    let isEnabled: Bool
    let changed: Bool
}

@MainActor
func setZoneAvailability(
    _ operation: ZoneAvailabilityOperation,
    selector: ZoneSelector,
    monitorDescription: MonitorDescription? = nil,
) -> Result<ZoneAvailabilityChange, String> {
    let resolved: ResolvedConfiguredZoneSelector
    switch resolveConfiguredZoneSelector(selector, monitorDescription: monitorDescription) {
        case .success(let zone):
            resolved = zone
        case .failure(let message):
            return .failure(message)
    }

    let shouldEnable = switch operation {
        case .enable: true
        case .disable: false
        case .toggle: !resolved.isEnabled
    }
    if shouldEnable == resolved.isEnabled {
        return .success(ZoneAvailabilityChange(
            zoneId: resolved.zoneId,
            zoneName: resolved.zoneName,
            physicalMonitor: resolved.physicalMonitor,
            isEnabled: resolved.isEnabled,
            changed: false,
        ))
    }

    let physicalIdentity = zoneLayoutPhysicalIdentity(for: resolved.physicalMonitor)
    let availabilityKey = zoneAvailabilityKey(physicalIdentity: physicalIdentity, zoneId: resolved.zoneId)
    var disabledZoneIds = activeZoneDisabledSelectionsByPhysicalIdentity[physicalIdentity] ?? []

    if shouldEnable {
        disabledZoneIds.remove(resolved.zoneId)
        activeZoneDisabledSelectionsByPhysicalIdentity[physicalIdentity] = disabledZoneIds
        refreshZoneTopologySnapshot()
        Workspace.reconcileWorkspaceState()
        restoreParkedWorkspace(availabilityKey: availabilityKey, resolved: resolved)
    } else {
        let enabledZonesOnMonitor = getCurrentZoneTopologySnapshot()
            .configuredZones(for: sortedPhysicalMonitors)
            .filter {
                $0.physicalMonitor.rect.topLeftCorner == resolved.physicalMonitor.rect.topLeftCorner &&
                    $0.isEnabled
            }
        guard enabledZonesOnMonitor.count > 1 else {
            return .failure("Cannot disable zone '\(resolved.displayName)'; at least one zone must stay enabled on monitor \(resolved.physicalMonitor.monitorId_oneBased ?? 0)")
        }
        parkWorkspace(for: resolved, availabilityKey: availabilityKey)
        disabledZoneIds.insert(resolved.zoneId)
        activeZoneDisabledSelectionsByPhysicalIdentity[physicalIdentity] = disabledZoneIds
        refreshZoneTopologySnapshot()
        Workspace.reconcileWorkspaceState()
        if let parkedWorkspaceId = parkedWorkspaceByZoneAvailabilityKey[availabilityKey],
           focus.workspace.id == parkedWorkspaceId
        {
            _ = resolved.physicalMonitor.activeWorkspace.focusWorkspace()
        }
    }

    return .success(ZoneAvailabilityChange(
        zoneId: resolved.zoneId,
        zoneName: resolved.zoneName,
        physicalMonitor: resolved.physicalMonitor,
        isEnabled: shouldEnable,
        changed: true,
    ))
}

@MainActor
private func parkWorkspace(for resolved: ResolvedConfiguredZoneSelector, availabilityKey: String) {
    guard let activeMonitor = sortedMonitors.first(where: {
        $0.zoneId == resolved.zoneId &&
            $0.physicalMonitor.rect.topLeftCorner == resolved.physicalMonitor.rect.topLeftCorner
    }) else { return }
    let viewportId = MonitorViewportId(activeMonitor)
    guard var viewport = winMuxWorkspaceState.monitorViewportsById[viewportId],
          let activeWorkspaceId = viewport.activeWorkspaceId
    else { return }
    parkedWorkspaceByZoneAvailabilityKey[availabilityKey] = activeWorkspaceId
    viewport.activeWorkspaceId = nil
    winMuxWorkspaceState.monitorViewportsById[viewportId] = viewport
}

@MainActor
private func restoreParkedWorkspace(availabilityKey: String, resolved: ResolvedConfiguredZoneSelector) {
    guard let parkedWorkspaceId = parkedWorkspaceByZoneAvailabilityKey[availabilityKey],
          let workspace = winMuxWorkspaceState.workspaceById[parkedWorkspaceId],
          let restoredMonitor = sortedMonitors.first(where: {
              $0.zoneId == resolved.zoneId &&
                  $0.physicalMonitor.rect.topLeftCorner == resolved.physicalMonitor.rect.topLeftCorner
          })
    else { return }
    let restoredViewportId = MonitorViewportId(restoredMonitor)
    guard !winMuxWorkspaceState.isWorkspaceActive(parkedWorkspaceId, outside: restoredViewportId) else { return }
    _ = restoredMonitor.setActiveWorkspace(workspace)
    parkedWorkspaceByZoneAvailabilityKey.removeValue(forKey: availabilityKey)
}

private func zoneAvailabilityKey(physicalIdentity: String, zoneId: String) -> String {
    "\(physicalIdentity):\(zoneId)"
}

struct ZoneSceneActivationResult {
    let sceneId: String
    let layoutId: String
    let bindings: [(zone: String, workspace: String)]
}

@MainActor
func setActiveZoneScene(_ sceneId: String, for physicalMonitor: Monitor) -> Result<ZoneSceneActivationResult, String> {
    guard let scene = config.zoneScenes.first(where: { $0.id == sceneId }) else {
        return .failure("Unknown zone scene '\(sceneId)'")
    }
    guard let layoutId = scene.layoutPreset else {
        return .failure("Zone scene '\(sceneId)' is missing layout-preset")
    }

    switch setActiveZoneLayout(layoutId, for: physicalMonitor) {
        case .success:
            break
        case .failure(let message):
            return .failure(message)
    }

    let targetPhysicalMonitor = physicalMonitor.physicalMonitor
    let targetTopLeft = targetPhysicalMonitor.rect.topLeftCorner
    let zoneMonitors = sortMonitorsBySpatialOrder(monitors.filter {
        $0.zoneId != nil && $0.physicalMonitor.rect.topLeftCorner == targetTopLeft
    })

    var appliedBindings: [(zone: String, workspace: String)] = []
    for binding in scene.workspaces {
        guard let workspaceName = binding.workspace?.raw else {
            return .failure("Zone scene '\(sceneId)' has a workspace binding without a workspace name")
        }
        guard let zoneMonitor = zoneMonitors.first(where: { $0.zoneId == binding.zone }) else {
            return .failure("Zone scene '\(sceneId)' references zone '\(binding.zone)' that is not active on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
        }

        let workspace = Workspace.get(byName: workspaceName)
        guard overrideWorkspaceOnMonitorBySwappingActiveViewports(workspace, targetMonitor: zoneMonitor) else {
            return .failure("Can't activate workspace '\(workspaceName)' in zone '\(binding.zone)'")
        }
        appliedBindings.append((zone: binding.zone, workspace: workspaceName))
    }

    Workspace.reconcileWorkspaceState()
    return .success(ZoneSceneActivationResult(sceneId: sceneId, layoutId: layoutId, bindings: appliedBindings))
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
