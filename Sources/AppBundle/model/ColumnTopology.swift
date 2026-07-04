import AppKit
import Common

struct ColumnTopologySnapshot: Sendable {
    static let empty = ColumnTopologySnapshot(
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
        runtimeOverlaysByPhysicalIdentity: [String: ZoneRuntimeOverlay] = zoneRuntimeOverlaysSnapshot(),
    ) {
        self.init(
            zones: config.zones,
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
            return columnMonitors(for: physicalMonitor, zoneConfig: zoneConfig, sortedPhysicalMonitors: sortedPhysicalMonitors)
        }
    }

    private func columnMonitors(
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
        let defaultZoneId = effectiveDefaultZoneId(zoneLayout: zoneLayout, enabledColumns: enabledColumns)
        let enabledWidthTotal = enabledColumns.reduce(0.0) { $0 + $1.effectiveWidth }
        let activeAvailabilitySetId = runtimeOverlay(for: physicalMonitor).activeAvailabilitySetId
        var nextLeft = baseRect.topLeftX

        return enabledColumns.enumerated().map { index, effectiveColumn in
            let column = effectiveColumn.column
            let isLast = index == enabledColumns.count - 1
            let width = isLast ? baseRect.maxX - nextLeft : baseRect.width * CGFloat(effectiveColumn.effectiveWidth / enabledWidthTotal)
            let rect = Rect(topLeftX: nextLeft, topLeftY: baseRect.topLeftY, width: width, height: baseRect.height)
            let colorHex = columnColorHex(for: physicalMonitor, column: column)
            nextLeft += width
            return ColumnMonitor(
                physicalMonitor: physicalMonitor,
                zoneLayoutId: zoneLayout.id,
                zoneAvailabilitySetId: activeAvailabilitySetId,
                zoneId: column.id,
                zoneName: column.name,
                zoneStyleId: nil,
                zoneStyleColorHex: colorHex,
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
            let activeAvailabilitySetId = runtimeOverlay(for: physicalMonitor).activeAvailabilitySetId
            let effectiveColumns = resolvedEffectiveColumns(for: physicalMonitor, zoneLayout: zoneLayout)
            let enabledColumns = effectiveColumns.filter { !disabledZoneIds.contains($0.column.id) }
            let activeColumnMonitors = columnMonitors(for: physicalMonitor, zoneConfig: zoneConfig, sortedPhysicalMonitors: sortedPhysicalMonitors)
            let defaultZoneId = effectiveDefaultZoneId(zoneLayout: zoneLayout, enabledColumns: enabledColumns)
            return effectiveColumns.map { effectiveColumn in
                let column = effectiveColumn.column
                let activeColumnMonitor = activeColumnMonitors.first { $0.zoneId == column.id }
                let colorHex = columnColorHex(for: physicalMonitor, column: column)
                return ConfiguredZoneSummary(
                    physicalMonitor: physicalMonitor,
                    zoneLayoutId: zoneLayout.id,
                    zoneAvailabilitySetId: activeAvailabilitySetId,
                    zoneId: column.id,
                    zoneName: column.name,
                    zoneStyleId: nil,
                    zoneStyleColorHex: colorHex,
                    configuredWidth: column.width,
                    effectiveWidth: effectiveColumn.effectiveWidth,
                    runtimeWidthOverride: effectiveColumn.runtimeWidthOverride,
                    left: activeColumnMonitor?.rect.topLeftX,
                    top: activeColumnMonitor?.rect.topLeftY,
                    pixelWidth: activeColumnMonitor?.rect.width,
                    pixelHeight: activeColumnMonitor?.rect.height,
                    isDefaultZone: column.id == defaultZoneId,
                    isEnabled: !disabledZoneIds.contains(column.id),
                )
            }
        }
    }

    private func effectiveDefaultZoneId(
        zoneLayout: ResolvedZoneLayout,
        enabledColumns: [EffectiveZoneColumn],
    ) -> String? {
        zoneLayout.defaultZone.flatMap { defaultZoneId in
            enabledColumns.contains { $0.column.id == defaultZoneId } ? defaultZoneId : nil
        } ?? enabledColumns.first?.column.id
    }

    /// Resolves a column's chrome tint: a `column color` runtime override wins, otherwise the
    /// scene column's declared `color`. Zone-styles are dead at config v3, so the color is a plain
    /// hex string, not a style-id lookup.
    private func columnColorHex(for physicalMonitor: Monitor, column: ZoneColumnConfig) -> String? {
        runtimeOverlay(for: physicalMonitor).styleOverridesByZoneId[column.id] ?? column.color
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

private struct ColumnMonitor: Monitor {
    let physicalMonitor: Monitor
    let zoneLayoutId: String?
    let zoneAvailabilitySetId: String?
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
    let zoneAvailabilitySetId: String?
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
    var activeSceneId: String?
    var activeAvailabilitySetId: String?
    var zoneSnapPolicyOverride: ZoneSnapPolicy?
    var disabledZoneIds: Set<String> = []
    var widthOverridesByLayoutIdentity: [String: [String: Double]] = [:]
    var styleOverridesByZoneId: [String: String] = [:]
    var currentToggleRestoreZoneId: String?
}

nonisolated(unsafe) private var zoneRuntimeOverlaysByPhysicalIdentity: [String: ZoneRuntimeOverlay] = [:]
nonisolated(unsafe) private var currentColumnTopologySnapshot: ColumnTopologySnapshot = .empty

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

func activeZoneAvailabilitySelectionsSnapshot() -> [String: String] {
    zoneRuntimeOverlaysByPhysicalIdentity.compactMapValues(\.activeAvailabilitySetId)
}

func activeZoneSceneSelectionsSnapshot() -> [String: String] {
    zoneRuntimeOverlaysByPhysicalIdentity.compactMapValues(\.activeSceneId)
}

/// The named scene currently active on a display, the authoritative scene selector that also
/// scopes the display's column decks. `nil` means the display runs its implicit scene.
func activeSceneId(for physicalMonitor: Monitor) -> String? {
    zoneRuntimeOverlaysByPhysicalIdentity[zoneLayoutPhysicalIdentity(for: physicalMonitor.physicalMonitor)]?.activeSceneId
}

/// Points a display at a scene's backing layout and marks the scene active in one step, so the
/// column viewports and the deck-key scene namespace change together.
@MainActor
func applySceneRuntimeOverlay(sceneId: String, layoutId: String, for physicalMonitor: Monitor) {
    let physicalIdentity = zoneLayoutPhysicalIdentity(for: physicalMonitor.physicalMonitor)
    var runtimeOverlay = zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] ?? ZoneRuntimeOverlay()
    runtimeOverlay.activeLayoutId = layoutId
    runtimeOverlay.activeSceneId = sceneId
    zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
    refreshColumnTopologySnapshot()
}

/// Drops a display back to its implicit scene: clears the active scene and its backing layout so
/// deck keys revert to display identity. Used when the last scene on a display is removed.
@MainActor
func clearActiveSceneOverlay(for physicalMonitor: Monitor) {
    let physicalIdentity = zoneLayoutPhysicalIdentity(for: physicalMonitor.physicalMonitor)
    guard var runtimeOverlay = zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] else { return }
    runtimeOverlay.activeSceneId = nil
    runtimeOverlay.activeLayoutId = nil
    zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
    refreshColumnTopologySnapshot()
}

@MainActor
func restoreZoneRuntimeOverlaysAfterRollback(_ snapshot: [String: ZoneRuntimeOverlay]) {
    zoneRuntimeOverlaysByPhysicalIdentity = snapshot
    refreshColumnTopologySnapshot()
}

func activeZoneSnapPolicyOverridesSnapshot() -> [String: ZoneSnapPolicy] {
    zoneRuntimeOverlaysByPhysicalIdentity.compactMapValues(\.zoneSnapPolicyOverride)
}

@MainActor
func effectiveZoneSnapConfig(for monitor: Monitor) -> ZoneSnapConfig {
    var snapConfig = config.mouse.zoneSnap
    let physicalIdentity = zoneLayoutPhysicalIdentity(for: monitor.physicalMonitor)
    if let runtimePolicy = zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity]?.zoneSnapPolicyOverride {
        snapConfig.policy = runtimePolicy
    }
    return snapConfig
}

func zoneRuntimeLayoutIdentity(_ layoutId: String?) -> String {
    layoutId ?? "__inline__"
}

@MainActor
func resetActiveZoneLayoutSelectionsForTests() {
    zoneRuntimeOverlaysByPhysicalIdentity = [:]
    refreshColumnTopologySnapshot()
}

@MainActor
func refreshColumnTopologySnapshot() {
    setCurrentColumnTopologySnapshot(ColumnTopologySnapshot(config))
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
    runtimeOverlay.activeSceneId = nil
    zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
    refreshColumnTopologySnapshot()
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

struct ZoneDividerChangeResult {
    let physicalMonitor: Monitor
    let layoutId: String?
    let leftZoneId: String
    let leftZoneName: String?
    let rightZoneId: String
    let rightZoneName: String?
    let requestedDeltaPixels: CGFloat
    let appliedDeltaPixels: CGFloat
    let oldBoundaryX: CGFloat
    let newBoundaryX: CGFloat
    let widths: [ConfiguredZoneSummary]
}

struct ZoneDividerWidthPreview {
    let leftZoneId: String
    let leftZoneName: String?
    let rightZoneId: String
    let rightZoneName: String?
    let requestedDeltaPixels: CGFloat
    let appliedDeltaPixels: CGFloat
    let oldBoundaryX: CGFloat
    let newBoundaryX: CGFloat
    let leftBeforeShare: Double
    let leftAfterShare: Double
    let rightBeforeShare: Double
    let rightAfterShare: Double
}

struct ZoneDividerHandle {
    let physicalMonitor: Monitor
    let layoutId: String?
    let leftZoneId: String
    let leftZoneName: String?
    let rightZoneId: String
    let rightZoneName: String?
    let boundaryX: CGFloat
    let workspaceRect: Rect
    let leftZoneRect: Rect
    let rightZoneRect: Rect

    func hitRect(hitSlop: CGFloat) -> Rect {
        Rect(
            topLeftX: boundaryX - hitSlop,
            topLeftY: workspaceRect.topLeftY,
            width: hitSlop * 2,
            height: workspaceRect.height,
        )
    }
}

struct ColumnColorChange {
    let physicalMonitor: Monitor
    let zoneId: String
    let zoneName: String?
    let colorHex: String
}

struct ZoneSnapPolicyChangeResult {
    let physicalMonitor: Monitor
    let policy: ZoneSnapPolicy
}

@MainActor
func setZoneAvailability(
    _ operation: ZoneAvailabilityOperation,
    selector: ZoneSelector,
    monitorDescription: MonitorDescription? = nil,
) -> Result<ZoneAvailabilityChange, String> {
    let resolved: ResolvedConfiguredZoneSelector
    let isCurrentToggle = operation == .toggle && selector.isBareCurrentZoneSelector
    let currentToggleRestoreZone = isCurrentToggle
        ? resolveCurrentToggleRestoreZone(selector, monitorDescription: monitorDescription)
        : nil
    switch currentToggleRestoreZone ?? resolveConfiguredZoneSelector(selector, monitorDescription: monitorDescription) {
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
    if !isCurrentToggle {
        runtimeOverlay.currentToggleRestoreZoneId = nil
    }

    if shouldEnable {
        runtimeOverlay.disabledZoneIds.remove(resolved.zoneId)
        if runtimeOverlay.currentToggleRestoreZoneId == resolved.zoneId {
            runtimeOverlay.currentToggleRestoreZoneId = nil
        }
        runtimeOverlay.activeAvailabilitySetId = nil
        zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
        refreshColumnTopologySnapshot()
        restoreDeckWorkspace(for: resolved)
        Workspace.reconcileWorkspaceState()
    } else {
        let enabledZonesOnMonitor = getCurrentColumnTopologySnapshot()
            .configuredZones(for: sortedPhysicalMonitors)
            .filter {
                $0.physicalMonitor.rect.topLeftCorner == resolved.physicalMonitor.rect.topLeftCorner &&
                    $0.isEnabled
            }
        guard enabledZonesOnMonitor.count > 1 else {
            return .failure("Cannot disable zone '\(resolved.displayName)'; at least one zone must stay enabled on monitor \(resolved.physicalMonitor.monitorId_oneBased ?? 0)")
        }
        let hiddenWorkspaceId = hideActiveWorkspaceForDisabledZone(for: resolved)
        runtimeOverlay.disabledZoneIds.insert(resolved.zoneId)
        if isCurrentToggle {
            runtimeOverlay.currentToggleRestoreZoneId = resolved.zoneId
        }
        runtimeOverlay.activeAvailabilitySetId = nil
        zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
        refreshColumnTopologySnapshot()
        Workspace.reconcileWorkspaceState()
        if let hiddenWorkspaceId, focus.workspace.id == hiddenWorkspaceId {
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

/// `column color <hex>` — stores the hex tint directly on the column runtime overlay. Zone-styles
/// are dead at config v3, so there is no style-id lookup: the color synthesis reads this hex.
@MainActor
func setColumnColor(
    selector: ZoneSelector,
    colorHex: String,
    monitorDescription: MonitorDescription? = nil,
) -> Result<ColumnColorChange, String> {
    let resolved: ResolvedConfiguredZoneSelector
    switch resolveConfiguredZoneSelector(selector, monitorDescription: monitorDescription) {
        case .success(let zone):
            resolved = zone
        case .failure(let message):
            return .failure(message)
    }

    guard resolved.isEnabled else {
        return .failure("Column '\(resolved.displayName)' is collapsed. Use column expand \(selector.raw) before coloring it.")
    }

    let physicalIdentity = zoneLayoutPhysicalIdentity(for: resolved.physicalMonitor)
    var runtimeOverlay = zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] ?? ZoneRuntimeOverlay()
    runtimeOverlay.styleOverridesByZoneId[resolved.zoneId] = colorHex
    zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
    refreshColumnTopologySnapshot()
    Workspace.reconcileWorkspaceState()

    return .success(ColumnColorChange(
        physicalMonitor: resolved.physicalMonitor,
        zoneId: resolved.zoneId,
        zoneName: resolved.zoneName,
        colorHex: colorHex,
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
func setZoneSnapPolicy(_ policyId: String, for physicalMonitor: Monitor) -> Result<ZoneSnapPolicyChangeResult, String> {
    guard let policy = ZoneSnapPolicy(rawValue: policyId) else {
        return .failure("Unknown zone snap policy '\(policyId)'. Expected one of: \(ZoneSnapPolicy.unionLiteral)")
    }
    return setZoneSnapPolicy(policy, for: physicalMonitor)
}

@MainActor
func setZoneSnapPolicy(_ policy: ZoneSnapPolicy, for physicalMonitor: Monitor) -> Result<ZoneSnapPolicyChangeResult, String> {
    let targetPhysicalMonitor = physicalMonitor.physicalMonitor
    guard !configuredZones(on: targetPhysicalMonitor).isEmpty else {
        return .failure("No zone config targets monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
    }

    let physicalIdentity = zoneLayoutPhysicalIdentity(for: targetPhysicalMonitor)
    var runtimeOverlay = zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] ?? ZoneRuntimeOverlay()
    runtimeOverlay.zoneSnapPolicyOverride = policy
    zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
    refreshColumnTopologySnapshot()

    return .success(ZoneSnapPolicyChangeResult(
        physicalMonitor: targetPhysicalMonitor,
        policy: policy,
    ))
}

@MainActor
func cycleZoneSnapPolicy(_ policyIds: [String], for physicalMonitor: Monitor) -> Result<ZoneSnapPolicyChangeResult, String> {
    guard !policyIds.isEmpty else {
        return .failure("cycle-column-snap-policy requires at least one policy")
    }
    let duplicatedIds = policyIds.grouped { $0 }
        .filter { id, ids in !id.isEmpty && ids.count > 1 }
        .keys
        .sorted()
    guard duplicatedIds.isEmpty else {
        return .failure("cycle-column-snap-policy requires unique policies: \(duplicatedIds.joined(separator: ", "))")
    }

    var policies: [ZoneSnapPolicy] = []
    for policyId in policyIds {
        guard let policy = ZoneSnapPolicy(rawValue: policyId) else {
            return .failure("Unknown zone snap policy '\(policyId)'. Expected one of: \(ZoneSnapPolicy.unionLiteral)")
        }
        policies.append(policy)
    }

    let currentPolicy = effectiveZoneSnapConfig(for: physicalMonitor).policy
    let selectedPolicy: ZoneSnapPolicy
    if let currentIndex = policies.firstIndex(of: currentPolicy) {
        selectedPolicy = policies[(currentIndex + 1) % policies.count]
    } else {
        selectedPolicy = policies[0]
    }

    return setZoneSnapPolicy(selectedPolicy, for: physicalMonitor)
}

private enum ZoneWidthOperation {
    case resize(ZoneWidthAmount)
    case balance
}

private let zoneMinimumShare = 0.05
nonisolated(unsafe) private var zoneDividerHandlesCache: [ZoneDividerHandle]? = nil

func invalidateZoneDividerHandlesCache() {
    zoneDividerHandlesCache = nil
}

@MainActor
private func configuredZones(on physicalMonitor: Monitor) -> [ConfiguredZoneSummary] {
    let targetTopLeft = physicalMonitor.physicalMonitor.rect.topLeftCorner
    return getCurrentColumnTopologySnapshot()
        .configuredZones(for: sortedPhysicalMonitors)
        .filter { $0.physicalMonitor.rect.topLeftCorner == targetTopLeft }
}

private func resolvedConfiguredZone(from summary: ConfiguredZoneSummary) -> ResolvedConfiguredZoneSelector {
    ResolvedConfiguredZoneSelector(
        physicalMonitor: summary.physicalMonitor,
        zoneLayoutId: summary.zoneLayoutId,
        zoneId: summary.zoneId,
        zoneName: summary.zoneName,
        isDefaultZone: summary.isDefaultZone,
        isEnabled: summary.isEnabled,
    )
}

@MainActor
func zoneDividerHandles(hitSlop _: CGFloat = 10) -> [ZoneDividerHandle] {
    if let cached = zoneDividerHandlesCache { return cached }

    let zoneViewports = sortedMonitors.filter { $0.zoneId != nil }
    guard zoneViewports.count > 1 else {
        zoneDividerHandlesCache = []
        return []
    }

    let grouped = Dictionary(grouping: zoneViewports) { monitor in
        "\(monitor.physicalMonitor.rect.topLeftX),\(monitor.physicalMonitor.rect.topLeftY)"
    }

    let handles = grouped.values.flatMap { viewports -> [ZoneDividerHandle] in
        let ordered = viewports.sorted { lhs, rhs in
            if lhs.rect.topLeftX == rhs.rect.topLeftX {
                lhs.rect.topLeftY < rhs.rect.topLeftY
            } else {
                lhs.rect.topLeftX < rhs.rect.topLeftX
            }
        }
        guard ordered.count > 1,
              let first = ordered.first
        else { return [] }

        let workspaceRect = ordered.dropFirst().reduce(first.rect) { acc, monitor in
            Rect(
                topLeftX: min(acc.minX, monitor.rect.minX),
                topLeftY: min(acc.minY, monitor.rect.minY),
                width: max(acc.maxX, monitor.rect.maxX) - min(acc.minX, monitor.rect.minX),
                height: max(acc.maxY, monitor.rect.maxY) - min(acc.minY, monitor.rect.minY),
            )
        }

        return ordered.indices.dropLast().compactMap { index -> ZoneDividerHandle? in
            let left = ordered[index]
            let right = ordered[index + 1]
            guard let leftZoneId = left.zoneId,
                  let rightZoneId = right.zoneId,
                  left.physicalMonitor.rect.topLeftCorner == right.physicalMonitor.rect.topLeftCorner
            else { return nil }
            return ZoneDividerHandle(
                physicalMonitor: left.physicalMonitor,
                layoutId: left.zoneLayoutId,
                leftZoneId: leftZoneId,
                leftZoneName: left.zoneName,
                rightZoneId: rightZoneId,
                rightZoneName: right.zoneName,
                boundaryX: left.rect.maxX,
                workspaceRect: workspaceRect,
                leftZoneRect: left.rect,
                rightZoneRect: right.rect,
            )
        }
    }.sorted { lhs, rhs in
        if lhs.workspaceRect.topLeftX == rhs.workspaceRect.topLeftX {
            lhs.boundaryX < rhs.boundaryX
        } else {
            lhs.workspaceRect.topLeftX < rhs.workspaceRect.topLeftX
        }
    }
    zoneDividerHandlesCache = handles
    return handles
}

@MainActor
func zoneDividerHandle(at point: CGPoint, hitSlop: CGFloat = 10) -> ZoneDividerHandle? {
    let handles = zoneDividerHandles(hitSlop: hitSlop)
    guard handles.contains(where: { $0.workspaceRect.contains(point) && abs($0.boundaryX - point.x) <= hitSlop }) else {
        return nil
    }
    return handles
        .filter { $0.hitRect(hitSlop: hitSlop).contains(point) }
        .min { lhs, rhs in
            abs(lhs.boundaryX - point.x) < abs(rhs.boundaryX - point.x)
        }
}

@MainActor
func previewZoneDividerMove(
    on physicalMonitor: Monitor,
    leftZoneId: String,
    rightZoneId: String,
    deltaPixels: CGFloat,
) -> Result<ZoneDividerWidthPreview, String> {
    calculateZoneDividerMove(
        on: physicalMonitor,
        leftZoneId: leftZoneId,
        rightZoneId: rightZoneId,
        deltaPixels: deltaPixels,
    ).map(\.preview)
}

@MainActor
func moveZoneDivider(
    on physicalMonitor: Monitor,
    leftZoneId: String,
    rightZoneId: String,
    deltaPixels: CGFloat,
) -> Result<ZoneDividerChangeResult, String> {
    switch calculateZoneDividerMove(
        on: physicalMonitor,
        leftZoneId: leftZoneId,
        rightZoneId: rightZoneId,
        deltaPixels: deltaPixels,
    ) {
        case .failure(let message):
            return .failure(message)
        case .success(let computation):
            let nextSummaries = applyZoneWidthOverrides(
                on: computation.physicalMonitor,
                layoutId: computation.layoutId,
                effectiveWidthsByZoneId: computation.nextEffectiveWidthsByZoneId,
            )
            return .success(ZoneDividerChangeResult(
                physicalMonitor: computation.physicalMonitor,
                layoutId: computation.layoutId,
                leftZoneId: computation.left.zoneId,
                leftZoneName: computation.left.zoneName,
                rightZoneId: computation.right.zoneId,
                rightZoneName: computation.right.zoneName,
                requestedDeltaPixels: computation.requestedDeltaPixels,
                appliedDeltaPixels: computation.appliedDeltaPixels,
                oldBoundaryX: computation.oldBoundaryX,
                newBoundaryX: computation.newBoundaryX,
                widths: nextSummaries,
            ))
    }
}

@MainActor
private func updateZoneWidths(
    on physicalMonitor: Monitor,
    targetZoneId: String?,
    targetZoneName: String?,
    operation: ZoneWidthOperation,
) -> Result<ZoneWidthChangeResult, String> {
    let targetPhysicalMonitor = physicalMonitor.physicalMonitor
    let configuredZones = getCurrentColumnTopologySnapshot()
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
            guard nextTargetShare >= zoneMinimumShare else {
                return .failure("Cannot resize zone '\(target.displayName)' below 5%")
            }
            guard nextTargetShare <= 1.0 - (Double(enabledZones.count - 1) * zoneMinimumShare) else {
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
        guard (nextEnabledShares[zone.zoneId] ?? 0) >= zoneMinimumShare else {
            return .failure("Cannot resize zones on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0); zone '\(zone.displayName)' would fall below 5%")
        }
    }

    let nextEffectiveWidthsByZoneId = Dictionary(uniqueKeysWithValues: enabledZones.compactMap { zone in
        nextEnabledShares[zone.zoneId].map { (zone.zoneId, $0 * enabledTotal) }
    })
    let nextSummaries = applyZoneWidthOverrides(
        on: targetPhysicalMonitor,
        layoutId: layoutId,
        effectiveWidthsByZoneId: nextEffectiveWidthsByZoneId,
    )
    return .success(ZoneWidthChangeResult(
        physicalMonitor: targetPhysicalMonitor,
        layoutId: layoutId,
        zoneId: targetZoneId,
        zoneName: targetZoneName,
        widths: nextSummaries,
    ))
}

private struct ZoneDividerMoveComputation {
    let physicalMonitor: Monitor
    let layoutId: String?
    let left: ConfiguredZoneSummary
    let right: ConfiguredZoneSummary
    let requestedDeltaPixels: CGFloat
    let appliedDeltaPixels: CGFloat
    let oldBoundaryX: CGFloat
    let newBoundaryX: CGFloat
    let enabledTotal: Double
    let nextEffectiveWidthsByZoneId: [String: Double]

    var preview: ZoneDividerWidthPreview {
        ZoneDividerWidthPreview(
            leftZoneId: left.zoneId,
            leftZoneName: left.zoneName,
            rightZoneId: right.zoneId,
            rightZoneName: right.zoneName,
            requestedDeltaPixels: requestedDeltaPixels,
            appliedDeltaPixels: appliedDeltaPixels,
            oldBoundaryX: oldBoundaryX,
            newBoundaryX: newBoundaryX,
            leftBeforeShare: left.effectiveWidth / enabledTotal,
            leftAfterShare: (nextEffectiveWidthsByZoneId[left.zoneId] ?? left.effectiveWidth) / enabledTotal,
            rightBeforeShare: right.effectiveWidth / enabledTotal,
            rightAfterShare: (nextEffectiveWidthsByZoneId[right.zoneId] ?? right.effectiveWidth) / enabledTotal,
        )
    }
}

@MainActor
private func calculateZoneDividerMove(
    on physicalMonitor: Monitor,
    leftZoneId: String,
    rightZoneId: String,
    deltaPixels: CGFloat,
) -> Result<ZoneDividerMoveComputation, String> {
    let targetPhysicalMonitor = physicalMonitor.physicalMonitor
    let configuredZones = configuredZones(on: targetPhysicalMonitor)
    guard !configuredZones.isEmpty else {
        return .failure("No zone config targets monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
    }
    let enabledZones = configuredZones.filter(\.isEnabled)
    guard enabledZones.count > 1 else {
        return .failure("Cannot drag zone dividers on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0); at least two zones must be enabled")
    }
    guard let leftIndex = enabledZones.firstIndex(where: { $0.zoneId == leftZoneId }),
          enabledZones.indices.contains(leftIndex + 1),
          enabledZones[leftIndex + 1].zoneId == rightZoneId
    else {
        return .failure("Zones '\(leftZoneId)' and '\(rightZoneId)' are not adjacent enabled zones on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
    }

    let left = enabledZones[leftIndex]
    let right = enabledZones[leftIndex + 1]
    let enabledTotal = enabledZones.reduce(0.0) { $0 + $1.effectiveWidth }
    guard enabledTotal > 0 else {
        return .failure("Cannot drag zone dividers on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0); enabled zone widths must be positive")
    }
    let pixelTotal = enabledZones.reduce(CGFloat(0)) { total, zone in
        total + (zone.pixelWidth ?? 0)
    }
    guard pixelTotal > 0 else {
        return .failure("Cannot drag zone dividers on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0); zone pixel widths are unavailable")
    }
    guard let oldBoundaryX = left.left.map({ $0 + (left.pixelWidth ?? 0) }) else {
        return .failure("Cannot drag zone divider '\(left.displayName)|\(right.displayName)'; boundary geometry is unavailable")
    }

    let requestedEffectiveDelta = Double(deltaPixels / pixelTotal) * enabledTotal
    let minimumEffectiveWidth = enabledTotal * zoneMinimumShare
    let minDelta = minimumEffectiveWidth - left.effectiveWidth
    let maxDelta = right.effectiveWidth - minimumEffectiveWidth
    let appliedEffectiveDelta = min(max(requestedEffectiveDelta, minDelta), maxDelta)
    let appliedDeltaPixels = CGFloat(appliedEffectiveDelta / enabledTotal) * pixelTotal
    let nextLeftWidth = left.effectiveWidth + appliedEffectiveDelta
    let nextRightWidth = right.effectiveWidth - appliedEffectiveDelta
    let widthTolerance = 0.0000001
    guard nextLeftWidth + widthTolerance >= minimumEffectiveWidth,
          nextRightWidth + widthTolerance >= minimumEffectiveWidth
    else {
        return .failure("Cannot drag zone divider '\(left.displayName)|\(right.displayName)' below 5%")
    }

    return .success(ZoneDividerMoveComputation(
        physicalMonitor: targetPhysicalMonitor,
        layoutId: configuredZones.first?.zoneLayoutId,
        left: left,
        right: right,
        requestedDeltaPixels: deltaPixels,
        appliedDeltaPixels: appliedDeltaPixels,
        oldBoundaryX: oldBoundaryX,
        newBoundaryX: oldBoundaryX + appliedDeltaPixels,
        enabledTotal: enabledTotal,
        nextEffectiveWidthsByZoneId: [
            left.zoneId: nextLeftWidth,
            right.zoneId: nextRightWidth,
        ],
    ))
}

@MainActor
@discardableResult
private func applyZoneWidthOverrides(
    on physicalMonitor: Monitor,
    layoutId: String?,
    effectiveWidthsByZoneId: [String: Double],
) -> [ConfiguredZoneSummary] {
    let targetPhysicalMonitor = physicalMonitor.physicalMonitor
    let physicalIdentity = zoneLayoutPhysicalIdentity(for: targetPhysicalMonitor)
    let layoutIdentity = zoneRuntimeLayoutIdentity(layoutId)
    var runtimeOverlay = zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] ?? ZoneRuntimeOverlay()
    var overrides = runtimeOverlay.widthOverridesByLayoutIdentity[layoutIdentity] ?? [:]
    for (zoneId, effectiveWidth) in effectiveWidthsByZoneId {
        overrides[zoneId] = effectiveWidth
    }
    runtimeOverlay.widthOverridesByLayoutIdentity[layoutIdentity] = overrides
    zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay

    refreshColumnTopologySnapshot()
    Workspace.reconcileWorkspaceState()

    return getCurrentColumnTopologySnapshot()
        .configuredZones(for: sortedPhysicalMonitors)
        .filter { $0.physicalMonitor.rect.topLeftCorner == targetPhysicalMonitor.rect.topLeftCorner }
}

@MainActor
private func hideActiveWorkspaceForDisabledZone(for resolved: ResolvedConfiguredZoneSelector) -> WorkspaceId? {
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
    winMuxWorkspaceState.hiddenActiveCardIdByColumnKey[columnDeckKey(for: activeMonitor)] = activeWorkspaceId
    return activeWorkspaceId
}

@MainActor
private func restoreDeckWorkspace(for resolved: ResolvedConfiguredZoneSelector) {
    guard let restoredMonitor = sortedMonitors.first(where: {
        $0.zoneId == resolved.zoneId &&
            $0.physicalMonitor.rect.topLeftCorner == resolved.physicalMonitor.rect.topLeftCorner
    }) else { return }
    let restoredViewportId = MonitorViewportId(restoredMonitor)
    let columnKey = columnDeckKey(for: restoredMonitor)
    if let hiddenCardId = winMuxWorkspaceState.hiddenActiveCardIdByColumnKey.removeValue(forKey: columnKey),
       let hiddenCard = winMuxWorkspaceState.workspaceById[hiddenCardId],
       winMuxWorkspaceState.columnDecks.columnKey(of: hiddenCardId) == columnKey,
       !winMuxWorkspaceState.isWorkspaceActive(hiddenCardId, outside: restoredViewportId)
    {
        _ = restoredMonitor.setActiveWorkspace(hiddenCard)
        return
    }
    guard let workspace = orderedDeckWorkspaces(inColumn: columnKey)
        .first(where: { !winMuxWorkspaceState.isWorkspaceActive($0.id, outside: restoredViewportId) })
    else { return }
    _ = restoredMonitor.setActiveWorkspace(workspace)
}

struct ZoneSceneActivationResult {
    let sceneId: String
    let layoutId: String
    let bindings: [(zone: String, workspace: String)]
}

struct ZoneBindingActivationResult {
    let physicalMonitor: Monitor
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
    for binding in scene.workspaces where binding.workspace?.raw == nil {
        return .failure("Zone scene '\(sceneId)' has a workspace binding without a workspace name")
    }

    let workspaceStateBefore = winMuxWorkspaceState
    let zoneRuntimeOverlaysBefore = zoneRuntimeOverlaysByPhysicalIdentity
    func rollback(_ message: String) -> Result<ZoneSceneActivationResult, String> {
        winMuxWorkspaceState = workspaceStateBefore
        zoneRuntimeOverlaysByPhysicalIdentity = zoneRuntimeOverlaysBefore
        refreshColumnTopologySnapshot()
        checkWorkspaceHierarchyInvariants()
        return .failure(message)
    }
    switch setActiveZoneLayout(layoutId, for: physicalMonitor) {
        case .success:
            break
        case .failure(let message):
            return .failure(message)
    }

    let targetPhysicalMonitor = physicalMonitor.physicalMonitor
    let targetTopLeft = targetPhysicalMonitor.rect.topLeftCorner
    let columnMonitors = sortMonitorsBySpatialOrder(monitors.filter {
        $0.zoneId != nil && $0.physicalMonitor.rect.topLeftCorner == targetTopLeft
    })

    var appliedBindings: [(zone: String, workspace: String)] = []
    for binding in scene.workspaces {
        let workspaceName = binding.workspace.orDie().raw
        guard let columnMonitor = columnMonitors.first(where: { $0.zoneId == binding.zone }) else {
            return rollback("Zone scene '\(sceneId)' references zone '\(binding.zone)' that is not active on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
        }

        let workspace = Workspace.get(byName: workspaceName)
        guard overrideWorkspaceOnMonitorBySwappingActiveViewports(workspace, targetMonitor: columnMonitor) else {
            return rollback("Can't activate workspace '\(workspaceName)' in zone '\(binding.zone)'")
        }
        appliedBindings.append((zone: binding.zone, workspace: workspaceName))
    }

    let physicalIdentity = zoneLayoutPhysicalIdentity(for: targetPhysicalMonitor)
    var runtimeOverlay = zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] ?? ZoneRuntimeOverlay()
    runtimeOverlay.activeSceneId = sceneId
    zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
    refreshColumnTopologySnapshot()
    Workspace.reconcileWorkspaceState()
    return .success(ZoneSceneActivationResult(sceneId: sceneId, layoutId: layoutId, bindings: appliedBindings))
}

@MainActor
func cycleZoneScene(_ sceneIds: [String], for physicalMonitor: Monitor) -> Result<ZoneSceneActivationResult, String> {
    guard !sceneIds.isEmpty else {
        return .failure("cycle-zone-scene requires at least one scene id")
    }
    let duplicatedIds = sceneIds.grouped { $0 }
        .filter { id, ids in !id.isEmpty && ids.count > 1 }
        .keys
        .sorted()
    guard duplicatedIds.isEmpty else {
        return .failure("cycle-zone-scene requires unique scene ids: \(duplicatedIds.joined(separator: ", "))")
    }

    var scenes: [ZoneSceneConfig] = []
    for sceneId in sceneIds {
        guard let scene = config.zoneScenes.first(where: { $0.id == sceneId }) else {
            return .failure("Unknown zone scene '\(sceneId)'")
        }
        scenes.append(scene)
    }

    let physicalIdentity = zoneLayoutPhysicalIdentity(for: physicalMonitor.physicalMonitor)
    let activeSceneId = zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity]?.activeSceneId
    let selectedIndex: Int
    if let activeSceneId,
       let activeIndex = scenes.firstIndex(where: { $0.id == activeSceneId })
    {
        selectedIndex = (activeIndex + 1) % scenes.count
    } else if let matchingIndex = scenes.firstIndex(where: { zoneSceneMatchesCurrentState($0, on: physicalMonitor) }) {
        selectedIndex = (matchingIndex + 1) % scenes.count
    } else {
        selectedIndex = 0
    }

    return setActiveZoneScene(scenes[selectedIndex].id, for: physicalMonitor)
}

@MainActor
private func zoneSceneMatchesCurrentState(_ scene: ZoneSceneConfig, on physicalMonitor: Monitor) -> Bool {
    guard let layoutPreset = scene.layoutPreset else { return false }
    let targetTopLeft = physicalMonitor.physicalMonitor.rect.topLeftCorner
    let configuredZones = getCurrentColumnTopologySnapshot()
        .configuredZones(for: sortedPhysicalMonitors)
        .filter { $0.physicalMonitor.rect.topLeftCorner == targetTopLeft }
    guard configuredZones.first?.zoneLayoutId == layoutPreset else { return false }

    let activeWorkspaceByZoneId = Dictionary(uniqueKeysWithValues: sortedMonitors.compactMap { monitor -> (String, String)? in
        guard monitor.physicalMonitor.rect.topLeftCorner == targetTopLeft,
              let zoneId = monitor.zoneId
        else { return nil }
        return (zoneId, monitor.activeWorkspace.name)
    })
    return scene.workspaces.allSatisfy { binding in
        guard let workspaceName = binding.workspace?.raw else { return false }
        return activeWorkspaceByZoneId[binding.zone] == workspaceName
    }
}

@MainActor
func applyZoneBindings(for physicalMonitor: Monitor) -> Result<ZoneBindingActivationResult, String> {
    let targetPhysicalMonitor = physicalMonitor.physicalMonitor
    let targetTopLeft = targetPhysicalMonitor.rect.topLeftCorner
    let columnMonitors = sortMonitorsBySpatialOrder(monitors.filter {
        $0.zoneId != nil && $0.physicalMonitor.rect.topLeftCorner == targetTopLeft
    })
    guard !columnMonitors.isEmpty else {
        return .failure("No active zones on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
    }

    switch resolvedZoneBindings(for: targetPhysicalMonitor) {
        case .success(let bindings):
            guard !bindings.isEmpty else {
                return .failure("No zone bindings configured for monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
            }
            return applyResolvedZoneBindings(
                bindings,
                to: columnMonitors,
                on: targetPhysicalMonitor,
            )
        case .failure(let message):
            return .failure(message)
    }
}

@MainActor
private func applyResolvedZoneBindings(
    _ bindings: [ZoneBindingConfig],
    to columnMonitors: [Monitor],
    on targetPhysicalMonitor: Monitor,
) -> Result<ZoneBindingActivationResult, String> {
    var preparedBindings: [(zone: String, workspaceName: String, columnMonitor: Monitor)] = []
    for binding in bindings {
        guard let workspaceName = binding.workspace?.raw else {
            return .failure("Zone binding for zone '\(binding.zone)' is missing a workspace name")
        }
        guard let columnMonitor = columnMonitors.first(where: { $0.zoneId == binding.zone }) else {
            return .failure("Zone binding references zone '\(binding.zone)' that is not active on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
        }
        preparedBindings.append((zone: binding.zone, workspaceName: workspaceName, columnMonitor: columnMonitor))
    }

    let workspaceStateBefore = winMuxWorkspaceState
    var appliedBindings: [(zone: String, workspace: String)] = []
    for binding in preparedBindings {
        let workspace = Workspace.get(byName: binding.workspaceName)
        guard overrideWorkspaceOnMonitorBySwappingActiveViewports(workspace, targetMonitor: binding.columnMonitor) else {
            winMuxWorkspaceState = workspaceStateBefore
            checkWorkspaceHierarchyInvariants()
            return .failure("Can't activate workspace '\(binding.workspaceName)' in zone '\(binding.zone)'")
        }
        appliedBindings.append((zone: binding.zone, workspace: binding.workspaceName))
    }

    Workspace.reconcileWorkspaceState()
    return .success(ZoneBindingActivationResult(
        physicalMonitor: targetPhysicalMonitor,
        bindings: appliedBindings,
    ))
}

@MainActor
private func resolvedZoneBindings(for targetPhysicalMonitor: Monitor) -> Result<[ZoneBindingConfig], String> {
    let targetTopLeft = targetPhysicalMonitor.rect.topLeftCorner
    let scopedBindings = config.zoneBindings.filter { binding in
        guard let monitor = binding.monitor?.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
            return false
        }
        return monitor.rect.topLeftCorner == targetTopLeft
    }
    let duplicateScopedZones = scopedBindings.map(\.zone)
        .grouped { $0 }
        .filter { zone, bindings in !zone.isEmpty && bindings.count > 1 }
        .keys
        .sorted()
    guard duplicateScopedZones.isEmpty else {
        return .failure("Multiple scoped zone bindings target monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0): \(duplicateScopedZones.joined(separator: ", "))")
    }

    let genericBindings = config.zoneBindings.filter { $0.monitor == nil }
    let duplicateGenericZones = genericBindings.map(\.zone)
        .grouped { $0 }
        .filter { zone, bindings in !zone.isEmpty && bindings.count > 1 }
        .keys
        .sorted()
    guard duplicateGenericZones.isEmpty else {
        return .failure("Multiple generic zone bindings are configured: \(duplicateGenericZones.joined(separator: ", "))")
    }

    var byZone: [String: ZoneBindingConfig] = [:]
    for binding in genericBindings {
        byZone[binding.zone] = binding
    }
    for binding in scopedBindings {
        byZone[binding.zone] = binding
    }

    let configuredZones = configuredZones(on: targetPhysicalMonitor)
    let configuredZoneIds = Set(configuredZones.map(\.zoneId))
    let missingZones = byZone.keys
        .filter { !configuredZoneIds.contains($0) }
        .sorted()
    guard missingZones.isEmpty else {
        return .failure("Zone bindings reference zones not configured on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0): \(missingZones.joined(separator: ", "))")
    }

    let ordered = configuredZones
        .compactMap { byZone[$0.zoneId] }
    let duplicateWorkspaces = ordered.compactMap { $0.workspace?.raw }
        .grouped { $0 }
        .filter { _, bindings in bindings.count > 1 }
        .keys
        .sorted()
    guard duplicateWorkspaces.isEmpty else {
        return .failure("Zone bindings assign the same workspace to multiple zones on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0): \(duplicateWorkspaces.joined(separator: ", "))")
    }

    return .success(ordered)
}

func zoneLayoutPhysicalIdentity(for monitor: Monitor) -> String {
    let topLeft = monitor.physicalMonitor.rect.topLeftCorner
    return "physical:\(topLeft.x),\(topLeft.y)"
}

func setCurrentColumnTopologySnapshot(_ snapshot: ColumnTopologySnapshot) {
    currentColumnTopologySnapshot = snapshot
    invalidateZoneDividerHandlesCache()
}

func getCurrentColumnTopologySnapshot() -> ColumnTopologySnapshot {
    currentColumnTopologySnapshot
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

@MainActor
private func resolveCurrentToggleRestoreZone(
    _ selector: ZoneSelector,
    monitorDescription: MonitorDescription?,
) -> Result<ResolvedConfiguredZoneSelector, String>? {
    guard selector.isBareCurrentZoneSelector else { return nil }

    let targetPhysicalMonitor: Monitor
    if let monitorDescription {
        guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
            return .failure("Can't resolve monitor selector for zone command")
        }
        targetPhysicalMonitor = monitor
    } else {
        targetPhysicalMonitor = focus.workspace.workspaceMonitor.physicalMonitor
    }

    let physicalIdentity = zoneLayoutPhysicalIdentity(for: targetPhysicalMonitor)
    guard let restoreZoneId = zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity]?.currentToggleRestoreZoneId,
          zoneRuntimeOverlaysByPhysicalIdentity[physicalIdentity]?.disabledZoneIds.contains(restoreZoneId) == true
    else {
        return nil
    }

    guard let zone = configuredZones(on: targetPhysicalMonitor).first(where: { $0.zoneId == restoreZoneId }) else {
        return nil
    }
    return .success(resolvedConfiguredZone(from: zone))
}
