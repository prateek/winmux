import AppKit
import Common

struct ZoneTopologySnapshot: Sendable {
    static let empty = ZoneTopologySnapshot(
        zones: [],
        zoneStyles: [],
        zoneLayouts: [],
        gaps: .zero,
        workspaceSidebar: WorkspaceSidebarConfig(),
        runtimeOverlaysByPhysicalIdentity: [:],
    )

    let zones: [ZoneConfig]
    let zoneStyles: [ZoneStyleConfig]
    let zoneLayouts: [ZoneLayoutConfig]
    let gaps: Gaps
    let workspaceSidebar: WorkspaceSidebarConfig
    let runtimeOverlaysByPhysicalIdentity: [String: ZoneRuntimeOverlay]

    init(
        _ config: Config,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        runtimeOverlaysByPhysicalIdentity: [String: ZoneRuntimeOverlay] = zoneRuntimeOverlaysSnapshot(),
    ) {
        self.init(
            zones: Self.effectiveZones(config.zones, environment: environment),
            zoneStyles: config.zoneStyles,
            zoneLayouts: config.zoneLayouts,
            gaps: config.gaps,
            workspaceSidebar: config.workspaceSidebar,
            runtimeOverlaysByPhysicalIdentity: runtimeOverlaysByPhysicalIdentity,
        )
    }

    init(
        zones: [ZoneConfig],
        zoneStyles: [ZoneStyleConfig],
        zoneLayouts: [ZoneLayoutConfig],
        gaps: Gaps,
        workspaceSidebar: WorkspaceSidebarConfig,
        runtimeOverlaysByPhysicalIdentity: [String: ZoneRuntimeOverlay],
    ) {
        self.zones = zones
        self.zoneStyles = zoneStyles
        self.zoneLayouts = zoneLayouts
        self.gaps = gaps
        self.workspaceSidebar = workspaceSidebar
        self.runtimeOverlaysByPhysicalIdentity = runtimeOverlaysByPhysicalIdentity
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

        let effectiveColumns = resolvedEffectiveColumns(for: physicalMonitor, zoneLayout: zoneLayout)
        let disabledZoneIds = disabledZoneIds(for: physicalMonitor)
        let enabledColumns = effectiveColumns.filter { !disabledZoneIds.contains($0.column.id) }
        guard !enabledColumns.isEmpty else { return [physicalMonitor] }

        let baseRect = physicalWorkspaceRect(for: physicalMonitor, sortedPhysicalMonitors: sortedPhysicalMonitors)
        let configuredDefaultZoneId = zoneLayout.defaultZone
        let defaultZoneId = configuredDefaultZoneId.flatMap { defaultZoneId in
            enabledColumns.contains { $0.column.id == defaultZoneId } ? defaultZoneId : nil
        } ?? enabledColumns.first?.column.id
        let enabledWidthTotal = enabledColumns.reduce(0.0) { $0 + $1.effectiveWidth }
        var nextLeft = baseRect.topLeftX

        return enabledColumns.enumerated().map { index, effectiveColumn in
            let column = effectiveColumn.column
            let isLast = index == enabledColumns.count - 1
            let width = isLast ? baseRect.maxX - nextLeft : baseRect.width * CGFloat(effectiveColumn.effectiveWidth / enabledWidthTotal)
            let rect = Rect(topLeftX: nextLeft, topLeftY: baseRect.topLeftY, width: width, height: baseRect.height)
            let style = style(for: physicalMonitor, zoneId: column.id)
            nextLeft += width
            return ZoneMonitor(
                physicalMonitor: physicalMonitor,
                zoneLayoutId: zoneLayout.id,
                zoneId: column.id,
                zoneName: column.name,
                zoneStyleId: style?.id,
                zoneStyleColorHex: style?.color,
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
            let effectiveColumns = resolvedEffectiveColumns(for: physicalMonitor, zoneLayout: zoneLayout)
            let activeZoneMonitors = zoneMonitors(for: physicalMonitor, zoneConfig: zoneConfig, sortedPhysicalMonitors: sortedPhysicalMonitors)
            let defaultZoneId = zoneLayout.defaultZone ?? zoneLayout.columns.first?.id
            return effectiveColumns.map { effectiveColumn in
                let column = effectiveColumn.column
                let activeZoneMonitor = activeZoneMonitors.first { $0.zoneId == column.id }
                let style = style(for: physicalMonitor, zoneId: column.id)
                return ConfiguredZoneSummary(
                    physicalMonitor: physicalMonitor,
                    zoneLayoutId: zoneLayout.id,
                    zoneId: column.id,
                    zoneName: column.name,
                    zoneStyleId: style?.id,
                    zoneStyleColorHex: style?.color,
                    configuredWidth: column.width,
                    effectiveWidth: effectiveColumn.effectiveWidth,
                    runtimeWidthOverride: effectiveColumn.runtimeWidthOverride,
                    left: activeZoneMonitor?.rect.topLeftX,
                    top: activeZoneMonitor?.rect.topLeftY,
                    pixelWidth: activeZoneMonitor?.rect.width,
                    pixelHeight: activeZoneMonitor?.rect.height,
                    isDefaultZone: column.id == defaultZoneId,
                    isEnabled: !disabledZoneIds.contains(column.id),
                )
            }
        }
    }

    private func style(for physicalMonitor: Monitor, zoneId: String) -> ZoneStyleConfig? {
        guard let styleId = runtimeOverlay(for: physicalMonitor).styleOverridesByZoneId[zoneId] else { return nil }
        return zoneStyles.first { $0.id == styleId }
    }

    private func disabledZoneIds(for physicalMonitor: Monitor) -> Set<String> {
        runtimeOverlay(for: physicalMonitor).disabledZoneIds
    }

    private func runtimeOverlay(for physicalMonitor: Monitor) -> ZoneRuntimeOverlay {
        runtimeOverlaysByPhysicalIdentity[zoneLayoutPhysicalIdentity(for: physicalMonitor)] ?? ZoneRuntimeOverlay()
    }

    private func resolvedZoneLayout(for physicalMonitor: Monitor, zoneConfig: ZoneConfig) -> ResolvedZoneLayout? {
        let physicalIdentity = zoneLayoutPhysicalIdentity(for: physicalMonitor)
        let runtimeOverlay = runtimeOverlaysByPhysicalIdentity[physicalIdentity]
        let candidateIds = [
            runtimeOverlay?.activeLayoutId,
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

    private func resolvedEffectiveColumns(
        for physicalMonitor: Monitor,
        zoneLayout: ResolvedZoneLayout,
    ) -> [EffectiveZoneColumn] {
        let physicalIdentity = zoneLayoutPhysicalIdentity(for: physicalMonitor)
        let layoutIdentity = zoneRuntimeLayoutIdentity(zoneLayout.id)
        let overrides = runtimeOverlaysByPhysicalIdentity[physicalIdentity]?
            .widthOverridesByLayoutIdentity[layoutIdentity] ?? [:]
        return zoneLayout.columns.map { column in
            let runtimeWidthOverride = overrides[column.id]
            return EffectiveZoneColumn(
                column: column,
                effectiveWidth: runtimeWidthOverride ?? column.width,
                runtimeWidthOverride: runtimeWidthOverride,
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
    let zoneLayoutId: String?
    let zoneId: String?
    let zoneName: String?
    let zoneStyleId: String?
    let zoneStyleColorHex: String?
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

private struct EffectiveZoneColumn {
    let column: ZoneColumnConfig
    let effectiveWidth: Double
    let runtimeWidthOverride: Double?
}

struct ConfiguredZoneSummary {
    let physicalMonitor: Monitor
    let zoneLayoutId: String?
    let zoneId: String
    let zoneName: String?
    let zoneStyleId: String?
    let zoneStyleColorHex: String?
    let configuredWidth: Double
    let effectiveWidth: Double
    let runtimeWidthOverride: Double?
    let left: CGFloat?
    let top: CGFloat?
    let pixelWidth: CGFloat?
    let pixelHeight: CGFloat?
    let isDefaultZone: Bool
    let isEnabled: Bool

    var runtimeWidthOverrideState: String {
        runtimeWidthOverride == nil ? "configured" : "runtime"
    }

    var displayName: String { zoneName ?? zoneId }
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

struct ZoneRuntimeOverlay: Sendable, Equatable {
    var activeLayoutId: String?
    var disabledZoneIds: Set<String> = []
    var parkedWorkspaceByZoneId: [String: WorkspaceId] = [:]
    var widthOverridesByLayoutIdentity: [String: [String: Double]] = [:]
    var styleOverridesByZoneId: [String: String] = [:]
}

nonisolated(unsafe) private var zoneRuntimeOverlaysByPhysicalIdentity: [String: ZoneRuntimeOverlay] = [:]
nonisolated(unsafe) private var currentZoneTopologySnapshot: ZoneTopologySnapshot = .empty

func zoneRuntimeOverlaysSnapshot() -> [String: ZoneRuntimeOverlay] {
    zoneRuntimeOverlaysByPhysicalIdentity
}

func activeZoneLayoutSelectionsSnapshot() -> [String: String] {
    zoneRuntimeOverlaysByPhysicalIdentity.compactMapValues(\.activeLayoutId)
}

func activeZoneDisabledSelectionsSnapshot() -> [String: Set<String>] {
    zoneRuntimeOverlaysByPhysicalIdentity
        .mapValues(\.disabledZoneIds)
        .filter { !$0.value.isEmpty }
}

func zoneRuntimeLayoutIdentity(_ layoutId: String?) -> String {
    layoutId ?? "__inline__"
}

@MainActor
func resetActiveZoneLayoutSelectionsForTests() {
    zoneRuntimeOverlaysByPhysicalIdentity = [:]
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

    let physicalIdentity = zoneLayoutPhysicalIdentity(for: targetPhysical)
    var runtimeOverlay = zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] ?? ZoneRuntimeOverlay()
    runtimeOverlay.activeLayoutId = layoutId
    zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
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

struct ZoneWidthChangeResult {
    let physicalMonitor: Monitor
    let layoutId: String?
    let zoneId: String?
    let zoneName: String?
    let widths: [ConfiguredZoneSummary]
}

struct ZoneStyleChangeResult {
    let physicalMonitor: Monitor
    let zoneId: String
    let zoneName: String?
    let styleId: String
    let styleColorHex: String
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
    var runtimeOverlay = zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] ?? ZoneRuntimeOverlay()

    if shouldEnable {
        runtimeOverlay.disabledZoneIds.remove(resolved.zoneId)
        zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
        refreshZoneTopologySnapshot()
        Workspace.reconcileWorkspaceState()
        restoreParkedWorkspace(physicalIdentity: physicalIdentity, resolved: resolved)
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
        if let parkedWorkspaceId = parkWorkspace(for: resolved) {
            runtimeOverlay.parkedWorkspaceByZoneId[resolved.zoneId] = parkedWorkspaceId
        }
        runtimeOverlay.disabledZoneIds.insert(resolved.zoneId)
        zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
        refreshZoneTopologySnapshot()
        Workspace.reconcileWorkspaceState()
        if let parkedWorkspaceId = runtimeOverlay.parkedWorkspaceByZoneId[resolved.zoneId],
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
func setZoneStyle(
    selector: ZoneSelector,
    styleId: String,
    monitorDescription: MonitorDescription? = nil,
) -> Result<ZoneStyleChangeResult, String> {
    guard let style = config.zoneStyles.first(where: { $0.id == styleId }) else {
        return .failure("Unknown zone style '\(styleId)'")
    }

    let resolved: ResolvedConfiguredZoneSelector
    switch resolveConfiguredZoneSelector(selector, monitorDescription: monitorDescription) {
        case .success(let zone):
            resolved = zone
        case .failure(let message):
            return .failure(message)
    }

    guard resolved.isEnabled else {
        return .failure("Zone '\(resolved.displayName)' is disabled. Use enable-zone \(selector.raw) before styling it.")
    }

    let physicalIdentity = zoneLayoutPhysicalIdentity(for: resolved.physicalMonitor)
    var runtimeOverlay = zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] ?? ZoneRuntimeOverlay()
    runtimeOverlay.styleOverridesByZoneId[resolved.zoneId] = style.id
    zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
    refreshZoneTopologySnapshot()
    Workspace.reconcileWorkspaceState()

    return .success(ZoneStyleChangeResult(
        physicalMonitor: resolved.physicalMonitor,
        zoneId: resolved.zoneId,
        zoneName: resolved.zoneName,
        styleId: style.id,
        styleColorHex: style.color,
    ))
}

@MainActor
func resizeZoneWidth(
    selector: ZoneSelector,
    amount: ZoneWidthAmount,
    monitorDescription: MonitorDescription? = nil,
) -> Result<ZoneWidthChangeResult, String> {
    let resolved: ResolvedConfiguredZoneSelector
    switch resolveConfiguredZoneSelector(selector, monitorDescription: monitorDescription) {
        case .success(let zone):
            resolved = zone
        case .failure(let message):
            return .failure(message)
    }

    guard resolved.isEnabled else {
        return .failure("Zone '\(resolved.displayName)' is disabled. Use enable-zone \(selector.raw) before resizing it.")
    }

    return updateZoneWidths(
        on: resolved.physicalMonitor,
        targetZoneId: resolved.zoneId,
        targetZoneName: resolved.zoneName,
        operation: .resize(amount),
    )
}

@MainActor
func balanceZoneWidths(monitorDescription: MonitorDescription? = nil) -> Result<ZoneWidthChangeResult, String> {
    let targetPhysicalMonitor: Monitor
    if let monitorDescription {
        guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
            return .failure("Can't resolve monitor selector for balance-zones")
        }
        targetPhysicalMonitor = monitor
    } else {
        targetPhysicalMonitor = focus.workspace.workspaceMonitor.physicalMonitor
    }

    return updateZoneWidths(
        on: targetPhysicalMonitor,
        targetZoneId: nil,
        targetZoneName: nil,
        operation: .balance,
    )
}

@MainActor
func cycleZoneLayout(_ layoutIds: [String], for physicalMonitor: Monitor) -> Result<String, String> {
    guard !layoutIds.isEmpty else {
        return .failure("cycle-zone-layout requires at least one layout id")
    }
    for layoutId in layoutIds {
        guard config.zoneLayouts.contains(where: { $0.id == layoutId }) else {
            return .failure("Unknown zone layout preset '\(layoutId)'")
        }
    }

    let physicalIdentity = zoneLayoutPhysicalIdentity(for: physicalMonitor)
    let currentLayoutId = getCurrentZoneTopologySnapshot()
        .configuredZones(for: sortedPhysicalMonitors)
        .first { $0.physicalMonitor.rect.topLeftCorner == physicalMonitor.physicalMonitor.rect.topLeftCorner }?
        .zoneLayoutId
        ?? zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity]?.activeLayoutId
    let selectedLayoutId: String
    if let currentLayoutId,
       let currentIndex = layoutIds.firstIndex(of: currentLayoutId)
    {
        selectedLayoutId = layoutIds[(currentIndex + 1) % layoutIds.count]
    } else {
        selectedLayoutId = layoutIds[0]
    }

    return setActiveZoneLayout(selectedLayoutId, for: physicalMonitor).map { selectedLayoutId }
}

private enum ZoneWidthOperation {
    case resize(ZoneWidthAmount)
    case balance
}

@MainActor
private func updateZoneWidths(
    on physicalMonitor: Monitor,
    targetZoneId: String?,
    targetZoneName: String?,
    operation: ZoneWidthOperation,
) -> Result<ZoneWidthChangeResult, String> {
    let targetPhysicalMonitor = physicalMonitor.physicalMonitor
    let physicalIdentity = zoneLayoutPhysicalIdentity(for: targetPhysicalMonitor)
    let configuredZones = getCurrentZoneTopologySnapshot()
        .configuredZones(for: sortedPhysicalMonitors)
        .filter { $0.physicalMonitor.rect.topLeftCorner == targetPhysicalMonitor.rect.topLeftCorner }
    guard !configuredZones.isEmpty else {
        return .failure("No zone config targets monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
    }
    let enabledZones = configuredZones.filter(\.isEnabled)
    guard enabledZones.count > 1 else {
        return .failure("Cannot resize zones on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0); at least two zones must be enabled")
    }

    let layoutId = configuredZones.first?.zoneLayoutId
    let layoutIdentity = zoneRuntimeLayoutIdentity(layoutId)
    let enabledTotal = enabledZones.reduce(0.0) { $0 + $1.effectiveWidth }
    guard enabledTotal > 0 else {
        return .failure("Cannot resize zones on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0); enabled zone widths must be positive")
    }

    let nextEnabledShares: [String: Double]
    switch operation {
        case .balance:
            let balancedShare = 1.0 / Double(enabledZones.count)
            nextEnabledShares = Dictionary(uniqueKeysWithValues: enabledZones.map { ($0.zoneId, balancedShare) })
        case .resize(let amount):
            guard let targetZoneId,
                  let target = enabledZones.first(where: { $0.zoneId == targetZoneId })
            else {
                return .failure("No enabled zone matches resize target")
            }
            let oldTargetShare = target.effectiveWidth / enabledTotal
            let nextTargetShare = switch amount {
                case .set(let percent): percent
                case .add(let percent): oldTargetShare + percent
                case .subtract(let percent): oldTargetShare - percent
            }
            let minShare = 0.05
            guard nextTargetShare >= minShare else {
                return .failure("Cannot resize zone '\(target.displayName)' below 5%")
            }
            guard nextTargetShare <= 1.0 - (Double(enabledZones.count - 1) * minShare) else {
                return .failure("Cannot resize zone '\(target.displayName)'; sibling zones would fall below 5%")
            }
            let oldSiblingTotalShare = 1.0 - oldTargetShare
            let nextSiblingTotalShare = 1.0 - nextTargetShare
            nextEnabledShares = Dictionary(uniqueKeysWithValues: enabledZones.map { zone in
                if zone.zoneId == target.zoneId {
                    return (zone.zoneId, nextTargetShare)
                }
                let oldShare = zone.effectiveWidth / enabledTotal
                let nextShare = oldSiblingTotalShare > 0
                    ? oldShare / oldSiblingTotalShare * nextSiblingTotalShare
                    : nextSiblingTotalShare / Double(enabledZones.count - 1)
                return (zone.zoneId, nextShare)
            })
    }

    for zone in enabledZones {
        guard (nextEnabledShares[zone.zoneId] ?? 0) >= 0.05 else {
            return .failure("Cannot resize zones on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0); zone '\(zone.displayName)' would fall below 5%")
        }
    }

    var runtimeOverlay = zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] ?? ZoneRuntimeOverlay()
    var overrides = runtimeOverlay.widthOverridesByLayoutIdentity[layoutIdentity] ?? [:]
    for zone in enabledZones {
        if let nextShare = nextEnabledShares[zone.zoneId] {
            overrides[zone.zoneId] = nextShare * enabledTotal
        }
    }
    runtimeOverlay.widthOverridesByLayoutIdentity[layoutIdentity] = overrides
    zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay

    refreshZoneTopologySnapshot()
    Workspace.reconcileWorkspaceState()

    let nextSummaries = getCurrentZoneTopologySnapshot()
        .configuredZones(for: sortedPhysicalMonitors)
        .filter { $0.physicalMonitor.rect.topLeftCorner == targetPhysicalMonitor.rect.topLeftCorner }
    return .success(ZoneWidthChangeResult(
        physicalMonitor: targetPhysicalMonitor,
        layoutId: layoutId,
        zoneId: targetZoneId,
        zoneName: targetZoneName,
        widths: nextSummaries,
    ))
}

@MainActor
private func parkWorkspace(for resolved: ResolvedConfiguredZoneSelector) -> WorkspaceId? {
    guard let activeMonitor = sortedMonitors.first(where: {
        $0.zoneId == resolved.zoneId &&
            $0.physicalMonitor.rect.topLeftCorner == resolved.physicalMonitor.rect.topLeftCorner
    }) else { return nil }
    let viewportId = MonitorViewportId(activeMonitor)
    guard var viewport = winMuxWorkspaceState.monitorViewportsById[viewportId],
          let activeWorkspaceId = viewport.activeWorkspaceId
    else { return nil }
    viewport.activeWorkspaceId = nil
    winMuxWorkspaceState.monitorViewportsById[viewportId] = viewport
    return activeWorkspaceId
}

@MainActor
private func restoreParkedWorkspace(physicalIdentity: String, resolved: ResolvedConfiguredZoneSelector) {
    guard let parkedWorkspaceId = zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity]?
        .parkedWorkspaceByZoneId[resolved.zoneId],
          let workspace = winMuxWorkspaceState.workspaceById[parkedWorkspaceId],
          let restoredMonitor = sortedMonitors.first(where: {
              $0.zoneId == resolved.zoneId &&
                  $0.physicalMonitor.rect.topLeftCorner == resolved.physicalMonitor.rect.topLeftCorner
          })
    else { return }
    let restoredViewportId = MonitorViewportId(restoredMonitor)
    guard !winMuxWorkspaceState.isWorkspaceActive(parkedWorkspaceId, outside: restoredViewportId) else { return }
    _ = restoredMonitor.setActiveWorkspace(workspace)
    var runtimeOverlay = zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] ?? ZoneRuntimeOverlay()
    runtimeOverlay.parkedWorkspaceByZoneId.removeValue(forKey: resolved.zoneId)
    zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
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
