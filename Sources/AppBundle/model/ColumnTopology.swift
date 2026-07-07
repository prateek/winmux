import AppKit
import Common

struct ColumnTopologySnapshot: Sendable {
    static let empty = ColumnTopologySnapshot(
        zones: [],
        columnLayouts: [],
        gaps: .zero,
        workspaceSidebar: WorkspaceSidebarConfig(),
        runtimeOverlaysByPhysicalIdentity: [:],
    )

    let zones: [DisplayLayoutConfig]
    let columnLayouts: [ColumnLayoutConfig]
    let gaps: Gaps
    let workspaceSidebar: WorkspaceSidebarConfig
    let runtimeOverlaysByPhysicalIdentity: [String: ColumnRuntimeOverlay]

    init(
        _ config: Config,
        runtimeOverlaysByPhysicalIdentity: [String: ColumnRuntimeOverlay] = columnRuntimeOverlaysSnapshot(),
    ) {
        self.init(
            zones: config.zones,
            columnLayouts: config.columnLayouts,
            gaps: config.gaps,
            workspaceSidebar: config.workspaceSidebar,
            runtimeOverlaysByPhysicalIdentity: runtimeOverlaysByPhysicalIdentity,
        )
    }

    init(
        zones: [DisplayLayoutConfig],
        columnLayouts: [ColumnLayoutConfig],
        gaps: Gaps,
        workspaceSidebar: WorkspaceSidebarConfig,
        runtimeOverlaysByPhysicalIdentity: [String: ColumnRuntimeOverlay],
    ) {
        self.zones = zones
        self.columnLayouts = columnLayouts
        self.gaps = gaps
        self.workspaceSidebar = workspaceSidebar
        self.runtimeOverlaysByPhysicalIdentity = runtimeOverlaysByPhysicalIdentity
    }

    var isEmpty: Bool { zones.isEmpty }

    func workspaceViewports(for physicalMonitors: [Monitor]) -> [Monitor] {
        guard !zones.isEmpty else { return physicalMonitors }

        let sortedPhysicalMonitors = sortMonitorsBySpatialOrder(physicalMonitors)
        return physicalMonitors.flatMap { physicalMonitor -> [Monitor] in
            guard let displayLayoutConfig = zones.first(where: { zone in
                guard let monitorDescription = zone.monitor else { return false }
                return resolvePhysicalMonitor(monitorDescription, sortedPhysicalMonitors: sortedPhysicalMonitors)?.rect.topLeftCorner == physicalMonitor.rect.topLeftCorner
            }) else {
                return [physicalMonitor]
            }
            return columnMonitors(for: physicalMonitor, displayLayoutConfig: displayLayoutConfig, sortedPhysicalMonitors: sortedPhysicalMonitors)
        }
    }

    private func columnMonitors(
        for physicalMonitor: Monitor,
        displayLayoutConfig: DisplayLayoutConfig,
        sortedPhysicalMonitors: [Monitor],
    ) -> [Monitor] {
        guard let columnLayout = resolvedColumnLayout(for: physicalMonitor, displayLayoutConfig: displayLayoutConfig),
              columnLayout.layout == .columns,
              !columnLayout.columns.isEmpty
        else { return [physicalMonitor] }

        let effectiveColumns = resolvedEffectiveColumns(for: physicalMonitor, columnLayout: columnLayout)
        let disabledColumnIds = disabledColumnIds(for: physicalMonitor)
        let enabledColumns = effectiveColumns.filter { !disabledColumnIds.contains($0.column.id) }
        guard !enabledColumns.isEmpty else { return [physicalMonitor] }

        let baseRect = physicalWorkspaceRect(for: physicalMonitor, sortedPhysicalMonitors: sortedPhysicalMonitors)
        let defaultColumnId = effectiveDefaultColumnId(columnLayout: columnLayout, enabledColumns: enabledColumns)
        let enabledWidthTotal = enabledColumns.reduce(0.0) { $0 + $1.effectiveWidth }
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
                columnLayoutId: columnLayout.id,
                columnId: column.id,
                columnName: column.name,
                zoneStyleId: nil,
                columnColorHex: colorHex,
                rect: rect,
                visibleRect: rect,
                isDefaultColumn: column.id == defaultColumnId,
            )
        }
    }

    func configuredColumns(for physicalMonitors: [Monitor]) -> [ConfiguredColumnSummary] {
        guard !zones.isEmpty else { return [] }
        let sortedPhysicalMonitors = sortMonitorsBySpatialOrder(physicalMonitors)
        return physicalMonitors.flatMap { physicalMonitor -> [ConfiguredColumnSummary] in
            guard let displayLayoutConfig = zones.first(where: { zone in
                guard let monitorDescription = zone.monitor else { return false }
                return resolvePhysicalMonitor(monitorDescription, sortedPhysicalMonitors: sortedPhysicalMonitors)?.rect.topLeftCorner == physicalMonitor.rect.topLeftCorner
            }),
                  let columnLayout = resolvedColumnLayout(for: physicalMonitor, displayLayoutConfig: displayLayoutConfig),
                  columnLayout.layout == .columns
            else { return [] }

            let disabledColumnIds = disabledColumnIds(for: physicalMonitor)
            let effectiveColumns = resolvedEffectiveColumns(for: physicalMonitor, columnLayout: columnLayout)
            let enabledColumns = effectiveColumns.filter { !disabledColumnIds.contains($0.column.id) }
            let activeColumnMonitors = columnMonitors(for: physicalMonitor, displayLayoutConfig: displayLayoutConfig, sortedPhysicalMonitors: sortedPhysicalMonitors)
            let defaultColumnId = effectiveDefaultColumnId(columnLayout: columnLayout, enabledColumns: enabledColumns)
            return effectiveColumns.map { effectiveColumn in
                let column = effectiveColumn.column
                let activeColumnMonitor = activeColumnMonitors.first { $0.columnId == column.id }
                let colorHex = columnColorHex(for: physicalMonitor, column: column)
                return ConfiguredColumnSummary(
                    physicalMonitor: physicalMonitor,
                    columnLayoutId: columnLayout.id,
                    columnId: column.id,
                    columnName: column.name,
                    zoneStyleId: nil,
                    columnColorHex: colorHex,
                    configuredWidth: column.width,
                    effectiveWidth: effectiveColumn.effectiveWidth,
                    runtimeWidthOverride: effectiveColumn.runtimeWidthOverride,
                    left: activeColumnMonitor?.rect.topLeftX,
                    top: activeColumnMonitor?.rect.topLeftY,
                    pixelWidth: activeColumnMonitor?.rect.width,
                    pixelHeight: activeColumnMonitor?.rect.height,
                    isDefaultColumn: column.id == defaultColumnId,
                    isEnabled: !disabledColumnIds.contains(column.id),
                )
            }
        }
    }

    private func effectiveDefaultColumnId(
        columnLayout: ResolvedColumnLayout,
        enabledColumns: [EffectiveColumn],
    ) -> String? {
        columnLayout.defaultZone.flatMap { defaultColumnId in
            enabledColumns.contains { $0.column.id == defaultColumnId } ? defaultColumnId : nil
        } ?? enabledColumns.first?.column.id
    }

    /// Resolves a column's chrome tint: a `column color` runtime override wins, otherwise the
    /// scene column's declared `color`. Zone-styles are dead at config v3, so the color is a plain
    /// hex string, not a style-id lookup.
    private func columnColorHex(for physicalMonitor: Monitor, column: ColumnConfig) -> String? {
        runtimeOverlay(for: physicalMonitor).styleOverridesByColumnId[column.id] ?? column.color
    }

    private func disabledColumnIds(for physicalMonitor: Monitor) -> Set<String> {
        runtimeOverlay(for: physicalMonitor).disabledColumnIds
    }

    private func runtimeOverlay(for physicalMonitor: Monitor) -> ColumnRuntimeOverlay {
        runtimeOverlaysByPhysicalIdentity[columnLayoutPhysicalIdentity(for: physicalMonitor)] ?? ColumnRuntimeOverlay()
    }

    private func resolvedColumnLayout(for physicalMonitor: Monitor, displayLayoutConfig: DisplayLayoutConfig) -> ResolvedColumnLayout? {
        let physicalIdentity = columnLayoutPhysicalIdentity(for: physicalMonitor)
        let runtimeOverlay = runtimeOverlaysByPhysicalIdentity[physicalIdentity]
        let candidateIds = [
            runtimeOverlay?.activeLayoutId,
            displayLayoutConfig.layoutPreset,
        ].compactMap { $0 }

        for id in candidateIds {
            if let layout = columnLayouts.first(where: { $0.id == id }) {
                return ResolvedColumnLayout(
                    id: id,
                    layout: layout.layout,
                    defaultZone: layout.defaultZone,
                    columns: layout.columns,
                )
            }
        }
        return nil
    }

    private func resolvedEffectiveColumns(
        for physicalMonitor: Monitor,
        columnLayout: ResolvedColumnLayout,
    ) -> [EffectiveColumn] {
        let physicalIdentity = columnLayoutPhysicalIdentity(for: physicalMonitor)
        let layoutIdentity = zoneRuntimeLayoutIdentity(columnLayout.id)
        let overrides = runtimeOverlaysByPhysicalIdentity[physicalIdentity]?
            .widthOverridesByLayoutIdentity[layoutIdentity] ?? [:]
        return columnLayout.columns.map { column in
            let runtimeWidthOverride = overrides[column.id]
            return EffectiveColumn(
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
    let columnLayoutId: String?
    let columnId: String?
    let columnName: String?
    let zoneStyleId: String?
    let columnColorHex: String?
    let rect: Rect
    let visibleRect: Rect
    let isDefaultColumn: Bool

    var monitorAppKitNsScreenScreensId: Int { physicalMonitor.monitorAppKitNsScreenScreensId }
    var name: String { "\(physicalMonitor.name) / \(columnName ?? columnId ?? "Zone")" }
    var width: CGFloat { rect.width }
    var height: CGFloat { rect.height }
    var isMain: Bool { physicalMonitor.isMain && isDefaultColumn }
}

private struct ResolvedColumnLayout {
    let id: String?
    let layout: ColumnLayoutKind?
    let defaultZone: String?
    let columns: [ColumnConfig]
}

private struct EffectiveColumn {
    let column: ColumnConfig
    let effectiveWidth: Double
    let runtimeWidthOverride: Double?
}

struct ConfiguredColumnSummary {
    let physicalMonitor: Monitor
    let columnLayoutId: String?
    let columnId: String
    let columnName: String?
    let zoneStyleId: String?
    let columnColorHex: String?
    let configuredWidth: Double
    let effectiveWidth: Double
    let runtimeWidthOverride: Double?
    let left: CGFloat?
    let top: CGFloat?
    let pixelWidth: CGFloat?
    let pixelHeight: CGFloat?
    let isDefaultColumn: Bool
    let isEnabled: Bool

    var runtimeWidthOverrideState: String {
        runtimeWidthOverride == nil ? "configured" : "runtime"
    }

    var displayName: String { columnName ?? columnId }
}

struct ResolvedConfiguredColumnSelector {
    let physicalMonitor: Monitor
    let columnLayoutId: String?
    let columnId: String
    let columnName: String?
    let isDefaultColumn: Bool
    let isEnabled: Bool

    var displayName: String { columnName ?? columnId }
}

struct ColumnRuntimeOverlay: Sendable, Equatable {
    var activeLayoutId: String?
    var activeSceneId: String?
    var columnSnapPolicyOverride: ColumnSnapPolicy?
    var disabledColumnIds: Set<String> = []
    var widthOverridesByLayoutIdentity: [String: [String: Double]] = [:]
    var styleOverridesByColumnId: [String: String] = [:]
    var currentToggleRestoreColumnId: String?
}

nonisolated(unsafe) private var columnRuntimeOverlaysByPhysicalIdentity: [String: ColumnRuntimeOverlay] = [:]
nonisolated(unsafe) private var currentColumnTopologySnapshot: ColumnTopologySnapshot = .empty

func columnRuntimeOverlaysSnapshot() -> [String: ColumnRuntimeOverlay] {
    columnRuntimeOverlaysByPhysicalIdentity
}

func activeColumnLayoutSelectionsSnapshot() -> [String: String] {
    columnRuntimeOverlaysByPhysicalIdentity.compactMapValues(\.activeLayoutId)
}

func activeZoneDisabledSelectionsSnapshot() -> [String: Set<String>] {
    columnRuntimeOverlaysByPhysicalIdentity
        .mapValues(\.disabledColumnIds)
        .filter { !$0.value.isEmpty }
}

/// The named scene currently active on a display, the authoritative scene selector that also
/// scopes the display's column decks. `nil` means the display runs its implicit scene.
func activeSceneId(for physicalMonitor: Monitor) -> String? {
    columnRuntimeOverlaysByPhysicalIdentity[columnLayoutPhysicalIdentity(for: physicalMonitor.physicalMonitor)]?.activeSceneId
}

/// Points a display at a scene's backing layout and marks the scene active in one step, so the
/// column viewports and the deck-key scene namespace change together.
@MainActor
func applySceneRuntimeOverlay(sceneId: String, layoutId: String, for physicalMonitor: Monitor) {
    let physicalIdentity = columnLayoutPhysicalIdentity(for: physicalMonitor.physicalMonitor)
    var runtimeOverlay = columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity] ?? ColumnRuntimeOverlay()
    runtimeOverlay.activeLayoutId = layoutId
    runtimeOverlay.activeSceneId = sceneId
    columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
    refreshColumnTopologySnapshot()
}

/// Drops a display back to its implicit scene: clears the active scene and its backing layout so
/// deck keys revert to display identity. Used when the last scene on a display is removed.
@MainActor
func clearActiveSceneOverlay(for physicalMonitor: Monitor) {
    let physicalIdentity = columnLayoutPhysicalIdentity(for: physicalMonitor.physicalMonitor)
    guard var runtimeOverlay = columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity] else { return }
    runtimeOverlay.activeSceneId = nil
    runtimeOverlay.activeLayoutId = nil
    columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
    refreshColumnTopologySnapshot()
}

@MainActor
func restoreColumnRuntimeOverlaysAfterRollback(_ snapshot: [String: ColumnRuntimeOverlay]) {
    columnRuntimeOverlaysByPhysicalIdentity = snapshot
    refreshColumnTopologySnapshot()
}

func activeColumnSnapPolicyOverridesSnapshot() -> [String: ColumnSnapPolicy] {
    columnRuntimeOverlaysByPhysicalIdentity.compactMapValues(\.columnSnapPolicyOverride)
}

@MainActor
func effectiveColumnSnapConfig(for monitor: Monitor) -> ColumnSnapConfig {
    var snapConfig = config.mouse.columnSnap
    let physicalIdentity = columnLayoutPhysicalIdentity(for: monitor.physicalMonitor)
    if let runtimePolicy = columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity]?.columnSnapPolicyOverride {
        snapConfig.policy = runtimePolicy
    }
    return snapConfig
}

func zoneRuntimeLayoutIdentity(_ layoutId: String?) -> String {
    layoutId ?? "__inline__"
}

@MainActor
func resetActiveColumnLayoutSelectionsForTests() {
    columnRuntimeOverlaysByPhysicalIdentity = [:]
    refreshColumnTopologySnapshot()
}

@MainActor
func refreshColumnTopologySnapshot() {
    setCurrentColumnTopologySnapshot(ColumnTopologySnapshot(config))
    invalidateMonitorCaches()
}

@MainActor
func setActiveColumnLayout(_ layoutId: String, for physicalMonitor: Monitor) -> Result<Void, String> {
    guard config.columnLayouts.contains(where: { $0.id == layoutId }) else {
        return .failure("Unknown zone layout preset '\(layoutId)'")
    }

    let physicalCandidates = sortMonitorsBySpatialOrder(physicalMonitors)
    let targetPhysical = physicalMonitor.physicalMonitor
    let targetTopLeft = targetPhysical.rect.topLeftCorner
    let hasDisplayLayoutConfig = config.zones.contains { zone in
        guard let monitorDescription = zone.monitor,
              let resolved = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: physicalCandidates)
        else { return false }
        return resolved.rect.topLeftCorner == targetTopLeft
    }
    guard hasDisplayLayoutConfig else {
        return .failure("No zone config targets monitor \(targetPhysical.monitorId_oneBased ?? 0)")
    }

    let physicalIdentity = columnLayoutPhysicalIdentity(for: targetPhysical)
    var runtimeOverlay = columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity] ?? ColumnRuntimeOverlay()
    runtimeOverlay.activeLayoutId = layoutId
    runtimeOverlay.activeSceneId = nil
    columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
    refreshColumnTopologySnapshot()
    Workspace.reconcileWorkspaceState()
    return .success(())
}

enum ColumnVisibilityOperation {
    case enable
    case disable
    case toggle
}

struct ColumnVisibilityChange {
    let columnId: String
    let columnName: String?
    let physicalMonitor: Monitor
    let isEnabled: Bool
    let changed: Bool
}

struct ColumnWidthChangeResult {
    let physicalMonitor: Monitor
    let layoutId: String?
    let columnId: String?
    let columnName: String?
    let widths: [ConfiguredColumnSummary]
}

struct ColumnDividerChangeResult {
    let physicalMonitor: Monitor
    let layoutId: String?
    let leftColumnId: String
    let leftColumnName: String?
    let rightColumnId: String
    let rightColumnName: String?
    let requestedDeltaPixels: CGFloat
    let appliedDeltaPixels: CGFloat
    let oldBoundaryX: CGFloat
    let newBoundaryX: CGFloat
    let widths: [ConfiguredColumnSummary]
}

struct ColumnDividerWidthPreview {
    let leftColumnId: String
    let leftColumnName: String?
    let rightColumnId: String
    let rightColumnName: String?
    let requestedDeltaPixels: CGFloat
    let appliedDeltaPixels: CGFloat
    let oldBoundaryX: CGFloat
    let newBoundaryX: CGFloat
    let leftBeforeShare: Double
    let leftAfterShare: Double
    let rightBeforeShare: Double
    let rightAfterShare: Double
}

struct ColumnDividerHandle {
    let physicalMonitor: Monitor
    let layoutId: String?
    let leftColumnId: String
    let leftColumnName: String?
    let rightColumnId: String
    let rightColumnName: String?
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
    let columnId: String
    let columnName: String?
    let colorHex: String
}

struct ColumnSnapPolicyChangeResult {
    let physicalMonitor: Monitor
    let policy: ColumnSnapPolicy
}

@MainActor
func setColumnVisibility(
    _ operation: ColumnVisibilityOperation,
    selector: ColumnSelector,
    monitorDescription: MonitorDescription? = nil,
) -> Result<ColumnVisibilityChange, String> {
    let resolved: ResolvedConfiguredColumnSelector
    let isCurrentToggle = operation == .toggle && selector.isBareCurrentColumnSelector
    let currentToggleRestoreColumn = isCurrentToggle
        ? resolveCurrentToggleRestoreColumn(selector, monitorDescription: monitorDescription)
        : nil
    switch currentToggleRestoreColumn ?? resolveConfiguredColumnSelector(selector, monitorDescription: monitorDescription) {
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
        return .success(ColumnVisibilityChange(
            columnId: resolved.columnId,
            columnName: resolved.columnName,
            physicalMonitor: resolved.physicalMonitor,
            isEnabled: resolved.isEnabled,
            changed: false,
        ))
    }

    let physicalIdentity = columnLayoutPhysicalIdentity(for: resolved.physicalMonitor)
    var runtimeOverlay = columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity] ?? ColumnRuntimeOverlay()
    if !isCurrentToggle {
        runtimeOverlay.currentToggleRestoreColumnId = nil
    }

    if shouldEnable {
        runtimeOverlay.disabledColumnIds.remove(resolved.columnId)
        if runtimeOverlay.currentToggleRestoreColumnId == resolved.columnId {
            runtimeOverlay.currentToggleRestoreColumnId = nil
        }
        columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
        refreshColumnTopologySnapshot()
        restoreDeckWorkspace(for: resolved)
        Workspace.reconcileWorkspaceState()
    } else {
        let enabledColumnsOnMonitor = getCurrentColumnTopologySnapshot()
            .configuredColumns(for: sortedPhysicalMonitors)
            .filter {
                $0.physicalMonitor.rect.topLeftCorner == resolved.physicalMonitor.rect.topLeftCorner &&
                    $0.isEnabled
            }
        guard enabledColumnsOnMonitor.count > 1 else {
            return .failure("Cannot disable zone '\(resolved.displayName)'; at least one zone must stay enabled on monitor \(resolved.physicalMonitor.monitorId_oneBased ?? 0)")
        }
        let hiddenWorkspaceId = hideActiveWorkspaceForDisabledZone(for: resolved)
        runtimeOverlay.disabledColumnIds.insert(resolved.columnId)
        if isCurrentToggle {
            runtimeOverlay.currentToggleRestoreColumnId = resolved.columnId
        }
        columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
        refreshColumnTopologySnapshot()
        Workspace.reconcileWorkspaceState()
        if let hiddenWorkspaceId, focus.workspace.id == hiddenWorkspaceId {
            _ = resolved.physicalMonitor.activeWorkspace.focusWorkspace()
        }
    }

    return .success(ColumnVisibilityChange(
        columnId: resolved.columnId,
        columnName: resolved.columnName,
        physicalMonitor: resolved.physicalMonitor,
        isEnabled: shouldEnable,
        changed: true,
    ))
}

/// `column color <hex>` — stores the hex tint directly on the column runtime overlay. Zone-styles
/// are dead at config v3, so there is no style-id lookup: the color synthesis reads this hex.
@MainActor
func setColumnColor(
    selector: ColumnSelector,
    colorHex: String,
    monitorDescription: MonitorDescription? = nil,
) -> Result<ColumnColorChange, String> {
    let resolved: ResolvedConfiguredColumnSelector
    switch resolveConfiguredColumnSelector(selector, monitorDescription: monitorDescription) {
        case .success(let zone):
            resolved = zone
        case .failure(let message):
            return .failure(message)
    }

    guard resolved.isEnabled else {
        return .failure("Column '\(resolved.displayName)' is collapsed. Use column expand \(selector.raw) before coloring it.")
    }

    let physicalIdentity = columnLayoutPhysicalIdentity(for: resolved.physicalMonitor)
    var runtimeOverlay = columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity] ?? ColumnRuntimeOverlay()
    runtimeOverlay.styleOverridesByColumnId[resolved.columnId] = colorHex
    columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
    refreshColumnTopologySnapshot()
    Workspace.reconcileWorkspaceState()

    return .success(ColumnColorChange(
        physicalMonitor: resolved.physicalMonitor,
        columnId: resolved.columnId,
        columnName: resolved.columnName,
        colorHex: colorHex,
    ))
}

@MainActor
func resizeColumnWidth(
    selector: ColumnSelector,
    amount: ColumnWidthAmount,
    monitorDescription: MonitorDescription? = nil,
) -> Result<ColumnWidthChangeResult, String> {
    let resolved: ResolvedConfiguredColumnSelector
    switch resolveConfiguredColumnSelector(selector, monitorDescription: monitorDescription) {
        case .success(let zone):
            resolved = zone
        case .failure(let message):
            return .failure(message)
    }

    guard resolved.isEnabled else {
        return .failure("Column '\(resolved.displayName)' is disabled. Use column expand \(selector.raw) before resizing it.")
    }

    return updateColumnWidths(
        on: resolved.physicalMonitor,
        targetColumnId: resolved.columnId,
        targetColumnName: resolved.columnName,
        operation: .resize(amount),
    )
}

@MainActor
func balanceColumnWidths(monitorDescription: MonitorDescription? = nil) -> Result<ColumnWidthChangeResult, String> {
    let targetPhysicalMonitor: Monitor
    if let monitorDescription {
        guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
            return .failure("Can't resolve monitor selector for balance-columns")
        }
        targetPhysicalMonitor = monitor
    } else {
        targetPhysicalMonitor = focus.workspace.workspaceMonitor.physicalMonitor
    }

    return updateColumnWidths(
        on: targetPhysicalMonitor,
        targetColumnId: nil,
        targetColumnName: nil,
        operation: .balance,
    )
}

@MainActor
func setColumnSnapPolicy(_ policyId: String, for physicalMonitor: Monitor) -> Result<ColumnSnapPolicyChangeResult, String> {
    guard let policy = ColumnSnapPolicy.fromConfigIdentifier(policyId) else {
        return .failure("Unknown column snap policy '\(policyId)'. Expected one of: \(ColumnSnapPolicy.unionLiteral)")
    }
    return setColumnSnapPolicy(policy, for: physicalMonitor)
}

@MainActor
func setColumnSnapPolicy(_ policy: ColumnSnapPolicy, for physicalMonitor: Monitor) -> Result<ColumnSnapPolicyChangeResult, String> {
    let targetPhysicalMonitor = physicalMonitor.physicalMonitor
    guard !configuredColumns(on: targetPhysicalMonitor).isEmpty else {
        return .failure("No zone config targets monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
    }

    let physicalIdentity = columnLayoutPhysicalIdentity(for: targetPhysicalMonitor)
    var runtimeOverlay = columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity] ?? ColumnRuntimeOverlay()
    runtimeOverlay.columnSnapPolicyOverride = policy
    columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay
    refreshColumnTopologySnapshot()

    return .success(ColumnSnapPolicyChangeResult(
        physicalMonitor: targetPhysicalMonitor,
        policy: policy,
    ))
}

@MainActor
func cycleColumnSnapPolicy(_ policyIds: [String], for physicalMonitor: Monitor) -> Result<ColumnSnapPolicyChangeResult, String> {
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

    var policies: [ColumnSnapPolicy] = []
    for policyId in policyIds {
        guard let policy = ColumnSnapPolicy.fromConfigIdentifier(policyId) else {
            return .failure("Unknown column snap policy '\(policyId)'. Expected one of: \(ColumnSnapPolicy.unionLiteral)")
        }
        policies.append(policy)
    }

    let currentPolicy = effectiveColumnSnapConfig(for: physicalMonitor).policy
    let selectedPolicy: ColumnSnapPolicy
    if let currentIndex = policies.firstIndex(of: currentPolicy) {
        selectedPolicy = policies[(currentIndex + 1) % policies.count]
    } else {
        selectedPolicy = policies[0]
    }

    return setColumnSnapPolicy(selectedPolicy, for: physicalMonitor)
}

private enum ColumnWidthOperation {
    case resize(ColumnWidthAmount)
    case balance
}

private let columnMinimumShare = 0.05
nonisolated(unsafe) private var columnDividerHandlesCache: [ColumnDividerHandle]? = nil

func invalidateColumnDividerHandlesCache() {
    columnDividerHandlesCache = nil
}

@MainActor
private func configuredColumns(on physicalMonitor: Monitor) -> [ConfiguredColumnSummary] {
    let targetTopLeft = physicalMonitor.physicalMonitor.rect.topLeftCorner
    return getCurrentColumnTopologySnapshot()
        .configuredColumns(for: sortedPhysicalMonitors)
        .filter { $0.physicalMonitor.rect.topLeftCorner == targetTopLeft }
}

private func resolvedConfiguredColumn(from summary: ConfiguredColumnSummary) -> ResolvedConfiguredColumnSelector {
    ResolvedConfiguredColumnSelector(
        physicalMonitor: summary.physicalMonitor,
        columnLayoutId: summary.columnLayoutId,
        columnId: summary.columnId,
        columnName: summary.columnName,
        isDefaultColumn: summary.isDefaultColumn,
        isEnabled: summary.isEnabled,
    )
}

@MainActor
func columnDividerHandles(hitSlop _: CGFloat = 10) -> [ColumnDividerHandle] {
    if let cached = columnDividerHandlesCache { return cached }

    let columnViewports = sortedMonitors.filter { $0.columnId != nil }
    guard columnViewports.count > 1 else {
        columnDividerHandlesCache = []
        return []
    }

    let grouped = Dictionary(grouping: columnViewports) { monitor in
        "\(monitor.physicalMonitor.rect.topLeftX),\(monitor.physicalMonitor.rect.topLeftY)"
    }

    let handles = grouped.values.flatMap { viewports -> [ColumnDividerHandle] in
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

        return ordered.indices.dropLast().compactMap { index -> ColumnDividerHandle? in
            let left = ordered[index]
            let right = ordered[index + 1]
            guard let leftColumnId = left.columnId,
                  let rightColumnId = right.columnId,
                  left.physicalMonitor.rect.topLeftCorner == right.physicalMonitor.rect.topLeftCorner
            else { return nil }
            return ColumnDividerHandle(
                physicalMonitor: left.physicalMonitor,
                layoutId: left.columnLayoutId,
                leftColumnId: leftColumnId,
                leftColumnName: left.columnName,
                rightColumnId: rightColumnId,
                rightColumnName: right.columnName,
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
    columnDividerHandlesCache = handles
    return handles
}

@MainActor
func columnDividerHandle(at point: CGPoint, hitSlop: CGFloat = 10) -> ColumnDividerHandle? {
    let handles = columnDividerHandles(hitSlop: hitSlop)
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
func previewColumnDividerMove(
    on physicalMonitor: Monitor,
    leftColumnId: String,
    rightColumnId: String,
    deltaPixels: CGFloat,
) -> Result<ColumnDividerWidthPreview, String> {
    calculateColumnDividerMove(
        on: physicalMonitor,
        leftColumnId: leftColumnId,
        rightColumnId: rightColumnId,
        deltaPixels: deltaPixels,
    ).map(\.preview)
}

@MainActor
func moveColumnDivider(
    on physicalMonitor: Monitor,
    leftColumnId: String,
    rightColumnId: String,
    deltaPixels: CGFloat,
) -> Result<ColumnDividerChangeResult, String> {
    switch calculateColumnDividerMove(
        on: physicalMonitor,
        leftColumnId: leftColumnId,
        rightColumnId: rightColumnId,
        deltaPixels: deltaPixels,
    ) {
        case .failure(let message):
            return .failure(message)
        case .success(let computation):
            let nextSummaries = applyColumnWidthOverrides(
                on: computation.physicalMonitor,
                layoutId: computation.layoutId,
                effectiveWidthsByColumnId: computation.nextEffectiveWidthsByColumnId,
            )
            return .success(ColumnDividerChangeResult(
                physicalMonitor: computation.physicalMonitor,
                layoutId: computation.layoutId,
                leftColumnId: computation.left.columnId,
                leftColumnName: computation.left.columnName,
                rightColumnId: computation.right.columnId,
                rightColumnName: computation.right.columnName,
                requestedDeltaPixels: computation.requestedDeltaPixels,
                appliedDeltaPixels: computation.appliedDeltaPixels,
                oldBoundaryX: computation.oldBoundaryX,
                newBoundaryX: computation.newBoundaryX,
                widths: nextSummaries,
            ))
    }
}

@MainActor
private func updateColumnWidths(
    on physicalMonitor: Monitor,
    targetColumnId: String?,
    targetColumnName: String?,
    operation: ColumnWidthOperation,
) -> Result<ColumnWidthChangeResult, String> {
    let targetPhysicalMonitor = physicalMonitor.physicalMonitor
    let configuredColumns = getCurrentColumnTopologySnapshot()
        .configuredColumns(for: sortedPhysicalMonitors)
        .filter { $0.physicalMonitor.rect.topLeftCorner == targetPhysicalMonitor.rect.topLeftCorner }
    guard !configuredColumns.isEmpty else {
        return .failure("No zone config targets monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
    }
    let enabledColumns = configuredColumns.filter(\.isEnabled)
    guard enabledColumns.count > 1 else {
        return .failure("Cannot resize zones on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0); at least two zones must be enabled")
    }

    let layoutId = configuredColumns.first?.columnLayoutId
    let enabledTotal = enabledColumns.reduce(0.0) { $0 + $1.effectiveWidth }
    guard enabledTotal > 0 else {
        return .failure("Cannot resize zones on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0); enabled zone widths must be positive")
    }

    let nextEnabledShares: [String: Double]
    switch operation {
        case .balance:
            let balancedShare = 1.0 / Double(enabledColumns.count)
            nextEnabledShares = Dictionary(uniqueKeysWithValues: enabledColumns.map { ($0.columnId, balancedShare) })
        case .resize(let amount):
            guard let targetColumnId,
                  let target = enabledColumns.first(where: { $0.columnId == targetColumnId })
            else {
                return .failure("No enabled zone matches resize target")
            }
            let oldTargetShare = target.effectiveWidth / enabledTotal
            let nextTargetShare = switch amount {
                case .set(let percent): percent
                case .add(let percent): oldTargetShare + percent
                case .subtract(let percent): oldTargetShare - percent
            }
            guard nextTargetShare >= columnMinimumShare else {
                return .failure("Cannot resize zone '\(target.displayName)' below 5%")
            }
            guard nextTargetShare <= 1.0 - (Double(enabledColumns.count - 1) * columnMinimumShare) else {
                return .failure("Cannot resize zone '\(target.displayName)'; sibling zones would fall below 5%")
            }
            let oldSiblingTotalShare = 1.0 - oldTargetShare
            let nextSiblingTotalShare = 1.0 - nextTargetShare
            nextEnabledShares = Dictionary(uniqueKeysWithValues: enabledColumns.map { zone in
                if zone.columnId == target.columnId {
                    return (zone.columnId, nextTargetShare)
                }
                let oldShare = zone.effectiveWidth / enabledTotal
                let nextShare = oldSiblingTotalShare > 0
                    ? oldShare / oldSiblingTotalShare * nextSiblingTotalShare
                    : nextSiblingTotalShare / Double(enabledColumns.count - 1)
                return (zone.columnId, nextShare)
            })
    }

    for zone in enabledColumns {
        guard (nextEnabledShares[zone.columnId] ?? 0) >= columnMinimumShare else {
            return .failure("Cannot resize zones on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0); zone '\(zone.displayName)' would fall below 5%")
        }
    }

    let nextEffectiveWidthsByColumnId = Dictionary(uniqueKeysWithValues: enabledColumns.compactMap { zone in
        nextEnabledShares[zone.columnId].map { (zone.columnId, $0 * enabledTotal) }
    })
    let nextSummaries = applyColumnWidthOverrides(
        on: targetPhysicalMonitor,
        layoutId: layoutId,
        effectiveWidthsByColumnId: nextEffectiveWidthsByColumnId,
    )
    return .success(ColumnWidthChangeResult(
        physicalMonitor: targetPhysicalMonitor,
        layoutId: layoutId,
        columnId: targetColumnId,
        columnName: targetColumnName,
        widths: nextSummaries,
    ))
}

private struct ColumnDividerMoveComputation {
    let physicalMonitor: Monitor
    let layoutId: String?
    let left: ConfiguredColumnSummary
    let right: ConfiguredColumnSummary
    let requestedDeltaPixels: CGFloat
    let appliedDeltaPixels: CGFloat
    let oldBoundaryX: CGFloat
    let newBoundaryX: CGFloat
    let enabledTotal: Double
    let nextEffectiveWidthsByColumnId: [String: Double]

    var preview: ColumnDividerWidthPreview {
        ColumnDividerWidthPreview(
            leftColumnId: left.columnId,
            leftColumnName: left.columnName,
            rightColumnId: right.columnId,
            rightColumnName: right.columnName,
            requestedDeltaPixels: requestedDeltaPixels,
            appliedDeltaPixels: appliedDeltaPixels,
            oldBoundaryX: oldBoundaryX,
            newBoundaryX: newBoundaryX,
            leftBeforeShare: left.effectiveWidth / enabledTotal,
            leftAfterShare: (nextEffectiveWidthsByColumnId[left.columnId] ?? left.effectiveWidth) / enabledTotal,
            rightBeforeShare: right.effectiveWidth / enabledTotal,
            rightAfterShare: (nextEffectiveWidthsByColumnId[right.columnId] ?? right.effectiveWidth) / enabledTotal,
        )
    }
}

@MainActor
private func calculateColumnDividerMove(
    on physicalMonitor: Monitor,
    leftColumnId: String,
    rightColumnId: String,
    deltaPixels: CGFloat,
) -> Result<ColumnDividerMoveComputation, String> {
    let targetPhysicalMonitor = physicalMonitor.physicalMonitor
    let configuredColumns = configuredColumns(on: targetPhysicalMonitor)
    guard !configuredColumns.isEmpty else {
        return .failure("No zone config targets monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
    }
    let enabledColumns = configuredColumns.filter(\.isEnabled)
    guard enabledColumns.count > 1 else {
        return .failure("Cannot drag zone dividers on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0); at least two zones must be enabled")
    }
    guard let leftIndex = enabledColumns.firstIndex(where: { $0.columnId == leftColumnId }),
          enabledColumns.indices.contains(leftIndex + 1),
          enabledColumns[leftIndex + 1].columnId == rightColumnId
    else {
        return .failure("Zones '\(leftColumnId)' and '\(rightColumnId)' are not adjacent enabled zones on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0)")
    }

    let left = enabledColumns[leftIndex]
    let right = enabledColumns[leftIndex + 1]
    let enabledTotal = enabledColumns.reduce(0.0) { $0 + $1.effectiveWidth }
    guard enabledTotal > 0 else {
        return .failure("Cannot drag zone dividers on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0); enabled zone widths must be positive")
    }
    let pixelTotal = enabledColumns.reduce(CGFloat(0)) { total, zone in
        total + (zone.pixelWidth ?? 0)
    }
    guard pixelTotal > 0 else {
        return .failure("Cannot drag zone dividers on monitor \(targetPhysicalMonitor.monitorId_oneBased ?? 0); zone pixel widths are unavailable")
    }
    guard let oldBoundaryX = left.left.map({ $0 + (left.pixelWidth ?? 0) }) else {
        return .failure("Cannot drag zone divider '\(left.displayName)|\(right.displayName)'; boundary geometry is unavailable")
    }

    let requestedEffectiveDelta = Double(deltaPixels / pixelTotal) * enabledTotal
    let minimumEffectiveWidth = enabledTotal * columnMinimumShare
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

    return .success(ColumnDividerMoveComputation(
        physicalMonitor: targetPhysicalMonitor,
        layoutId: configuredColumns.first?.columnLayoutId,
        left: left,
        right: right,
        requestedDeltaPixels: deltaPixels,
        appliedDeltaPixels: appliedDeltaPixels,
        oldBoundaryX: oldBoundaryX,
        newBoundaryX: oldBoundaryX + appliedDeltaPixels,
        enabledTotal: enabledTotal,
        nextEffectiveWidthsByColumnId: [
            left.columnId: nextLeftWidth,
            right.columnId: nextRightWidth,
        ],
    ))
}

@MainActor
@discardableResult
private func applyColumnWidthOverrides(
    on physicalMonitor: Monitor,
    layoutId: String?,
    effectiveWidthsByColumnId: [String: Double],
) -> [ConfiguredColumnSummary] {
    let targetPhysicalMonitor = physicalMonitor.physicalMonitor
    let physicalIdentity = columnLayoutPhysicalIdentity(for: targetPhysicalMonitor)
    let layoutIdentity = zoneRuntimeLayoutIdentity(layoutId)
    var runtimeOverlay = columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity] ?? ColumnRuntimeOverlay()
    var overrides = runtimeOverlay.widthOverridesByLayoutIdentity[layoutIdentity] ?? [:]
    for (columnId, effectiveWidth) in effectiveWidthsByColumnId {
        overrides[columnId] = effectiveWidth
    }
    runtimeOverlay.widthOverridesByLayoutIdentity[layoutIdentity] = overrides
    columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity] = runtimeOverlay

    refreshColumnTopologySnapshot()
    Workspace.reconcileWorkspaceState()

    return getCurrentColumnTopologySnapshot()
        .configuredColumns(for: sortedPhysicalMonitors)
        .filter { $0.physicalMonitor.rect.topLeftCorner == targetPhysicalMonitor.rect.topLeftCorner }
}

@MainActor
private func hideActiveWorkspaceForDisabledZone(for resolved: ResolvedConfiguredColumnSelector) -> WorkspaceId? {
    guard let activeMonitor = sortedMonitors.first(where: {
        $0.columnId == resolved.columnId &&
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
private func restoreDeckWorkspace(for resolved: ResolvedConfiguredColumnSelector) {
    guard let restoredMonitor = sortedMonitors.first(where: {
        $0.columnId == resolved.columnId &&
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

func columnLayoutPhysicalIdentity(for monitor: Monitor) -> String {
    let topLeft = monitor.physicalMonitor.rect.topLeftCorner
    return "physical:\(topLeft.x),\(topLeft.y)"
}

func setCurrentColumnTopologySnapshot(_ snapshot: ColumnTopologySnapshot) {
    currentColumnTopologySnapshot = snapshot
    invalidateColumnDividerHandlesCache()
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
private func resolveCurrentToggleRestoreColumn(
    _ selector: ColumnSelector,
    monitorDescription: MonitorDescription?,
) -> Result<ResolvedConfiguredColumnSelector, String>? {
    guard selector.isBareCurrentColumnSelector else { return nil }

    let targetPhysicalMonitor: Monitor
    if let monitorDescription {
        guard let monitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
            return .failure("Can't resolve monitor selector for zone command")
        }
        targetPhysicalMonitor = monitor
    } else {
        targetPhysicalMonitor = focus.workspace.workspaceMonitor.physicalMonitor
    }

    let physicalIdentity = columnLayoutPhysicalIdentity(for: targetPhysicalMonitor)
    guard let restoreColumnId = columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity]?.currentToggleRestoreColumnId,
          columnRuntimeOverlaysByPhysicalIdentity[physicalIdentity]?.disabledColumnIds.contains(restoreColumnId) == true
    else {
        return nil
    }

    guard let zone = configuredColumns(on: targetPhysicalMonitor).first(where: { $0.columnId == restoreColumnId }) else {
        return nil
    }
    return .success(resolvedConfiguredColumn(from: zone))
}
