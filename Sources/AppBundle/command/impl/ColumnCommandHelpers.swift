import Common
import Foundation

struct ResolvedColumnSelector {
    let monitor: Monitor
}

@MainActor
func resolveColumnSelector(_ selector: ColumnSelector) -> Result<ResolvedColumnSelector, String> {
    let parsed = selector.parseForResolution()
    let columnViewports = sortedMonitors.filter { $0.columnId != nil }
    guard !columnViewports.isEmpty else {
        return .failure("No columns are configured")
    }
    let relativeSelector = RelativeColumnSelector(parsed.zoneSelector)

    let scopedViewports: [Monitor]
    if let monitorSelector = parsed.monitorSelector {
        let physicalMonitor: Monitor? = switch parseMonitorDescription(monitorSelector) {
            case .success(let description):
                description.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors)
            case .failure:
                nil
        }
        guard let physicalMonitor else {
            return .failure("Can't resolve monitor selector '\(monitorSelector)' in zone selector '\(selector.raw)'")
        }
        scopedViewports = columnViewports.filter {
            $0.physicalMonitor.rect.topLeftCorner == physicalMonitor.rect.topLeftCorner
        }
    } else if relativeSelector != nil {
        let focusedPhysicalMonitor = focusedPhysicalMonitorForColumnSelector()
        scopedViewports = columnViewports.filter {
            $0.physicalMonitor.rect.topLeftCorner == focusedPhysicalMonitor.rect.topLeftCorner
        }
    } else {
        scopedViewports = columnViewports
    }

    if let relativeSelector {
        return resolveRelativeColumnViewport(
            relativeSelector,
            rawSelector: selector.raw,
            candidates: scopedViewports,
        ).map { ResolvedColumnSelector(monitor: $0) }
    }

    let matches = scopedViewports.filter { $0.matchesColumnSelector(parsed.zoneSelector) }
    guard !matches.isEmpty else {
        if case .success(let configuredZone) = resolveConfiguredColumnSelector(selector),
           !configuredZone.isEnabled
        {
            return .failure("Column '\(configuredZone.displayName)' is disabled. Use column expand \(selector.raw) before targeting it.")
        }
        return .failure("No column matches '\(selector.raw)'")
    }
    guard matches.count == 1 else {
        let examples = matches.compactMap { monitor -> String? in
            guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
                  let columnId = monitor.columnId
            else { return nil }
            return "\(physicalId):\(columnId)"
        }
        return .failure(
            "Column selector '\(selector.raw)' is ambiguous. Use a physical monitor qualifier like \(examples.joined(separator: ", "))",
        )
    }
    return .success(ResolvedColumnSelector(monitor: matches[0]))
}

@MainActor
func resolveConfiguredColumnSelector(
    _ selector: ColumnSelector,
    monitorDescription: MonitorDescription? = nil,
) -> Result<ResolvedConfiguredColumnSelector, String> {
    let parsed = selector.parseForResolution()
    let relativeSelector = RelativeColumnSelector(parsed.zoneSelector)
    guard parsed.monitorSelector == nil || monitorDescription == nil else {
        return .failure("Use either --monitor or a physical monitor qualifier in zone selector '\(selector.raw)', not both")
    }

    let physicalScope: [Monitor]
    if let monitorDescription {
        guard let physicalMonitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
            return .failure("Can't resolve monitor selector for column command")
        }
        physicalScope = [physicalMonitor]
    } else if let monitorSelector = parsed.monitorSelector {
        let physicalMonitor: Monitor? = switch parseMonitorDescription(monitorSelector) {
            case .success(let description):
                description.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors)
            case .failure:
                nil
        }
        guard let physicalMonitor else {
            return .failure("Can't resolve monitor selector '\(monitorSelector)' in zone selector '\(selector.raw)'")
        }
        physicalScope = [physicalMonitor]
    } else if relativeSelector != nil {
        physicalScope = [focusedPhysicalMonitorForColumnSelector()]
    } else {
        physicalScope = sortedPhysicalMonitors
    }

    let scopeTopLeftCorners = Set(physicalScope.map(\.rect.topLeftCorner))
    let configuredColumns = getCurrentColumnTopologySnapshot()
        .configuredColumns(for: sortedPhysicalMonitors)
        .filter { scopeTopLeftCorners.contains($0.physicalMonitor.rect.topLeftCorner) }
    guard !configuredColumns.isEmpty else {
        return .failure("No columns are configured")
    }

    if let relativeSelector {
        return resolveRelativeConfiguredColumn(
            relativeSelector,
            rawSelector: selector.raw,
            candidates: configuredColumns,
        )
    }

    let matches = configuredColumns.filter { zone in
        zone.columnId.matchesColumnSelector(parsed.zoneSelector) || zone.columnName.matchesColumnSelector(parsed.zoneSelector)
    }
    guard !matches.isEmpty else {
        return .failure("No column matches '\(selector.raw)'")
    }
    guard matches.count == 1 else {
        let examples = matches.compactMap { zone -> String? in
            guard let physicalId = zone.physicalMonitor.monitorId_oneBased else { return nil }
            return "\(physicalId):\(zone.columnId)"
        }
        return .failure(
            "Column selector '\(selector.raw)' is ambiguous. Use a physical monitor qualifier like \(examples.joined(separator: ", "))",
        )
    }

    let match = matches[0]
    return .success(ResolvedConfiguredColumnSelector(
        physicalMonitor: match.physicalMonitor,
        columnLayoutId: match.columnLayoutId,
        columnId: match.columnId,
        columnName: match.columnName,
        isDefaultColumn: match.isDefaultColumn,
        isEnabled: match.isEnabled,
    ))
}

private enum RelativeColumnSelector: Equatable {
    case current
    case next
    case previous

    init?(_ raw: String) {
        switch raw.lowercased() {
            case "current", "focused":
                self = .current
            case "next":
                self = .next
            case "prev", "previous":
                self = .previous
            default:
                return nil
        }
    }
}

@MainActor
private func resolveRelativeColumnViewport(
    _ selector: RelativeColumnSelector,
    rawSelector: String,
    candidates: [Monitor],
) -> Result<Monitor, String> {
    guard !candidates.isEmpty else {
        return .failure("No columns are configured on the focused monitor")
    }

    let currentIndex = focusedColumnViewportIndex(in: candidates)
    switch selector {
        case .current:
            guard let currentIndex else {
                return .failure("No focused column matches '\(rawSelector)'")
            }
            return .success(candidates[currentIndex])
        case .next, .previous:
            let baseIndex = currentIndex ?? candidates.firstIndex(where: \.isDefaultColumn) ?? 0
            let offset = selector == .next ? 1 : -1
            let nextIndex = (baseIndex + offset + candidates.count) % candidates.count
            return .success(candidates[nextIndex])
    }
}

@MainActor
private func resolveRelativeConfiguredColumn(
    _ selector: RelativeColumnSelector,
    rawSelector: String,
    candidates: [ConfiguredColumnSummary],
) -> Result<ResolvedConfiguredColumnSelector, String> {
    guard !candidates.isEmpty else {
        return .failure("No columns are configured on the focused monitor")
    }

    let currentIndex = focusedConfiguredZoneIndex(in: candidates)
    switch selector {
        case .current:
            guard let currentIndex else {
                return .failure("No focused column matches '\(rawSelector)'")
            }
            return .success(resolvedConfiguredColumnSelector(from: candidates[currentIndex]))
        case .next, .previous:
            let baseIndex = currentIndex ?? candidates.firstIndex(where: \.isDefaultColumn) ?? 0
            let offset = selector == .next ? 1 : -1
            let nextIndex = (baseIndex + offset + candidates.count) % candidates.count
            return .success(resolvedConfiguredColumnSelector(from: candidates[nextIndex]))
    }
}

private func resolvedConfiguredColumnSelector(from summary: ConfiguredColumnSummary) -> ResolvedConfiguredColumnSelector {
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
private func focusedColumnViewportIndex(in candidates: [Monitor]) -> Int? {
    focusedColumnViewport(in: candidates).flatMap { focusedMonitor in
        candidates.firstIndex {
            MonitorViewportId($0).hasSameStableIdentity(as: MonitorViewportId(focusedMonitor))
        }
    }
}

@MainActor
private func focusedConfiguredZoneIndex(in candidates: [ConfiguredColumnSummary]) -> Int? {
    guard let focusedMonitor = focusedColumnViewport(in: sortedMonitors.filter { $0.columnId != nil }) else { return nil }
    guard let focusedColumnId = focusedMonitor.columnId else { return nil }
    let focusedPhysicalTopLeft = focusedMonitor.physicalMonitor.rect.topLeftCorner
    return candidates.firstIndex {
        $0.columnId == focusedColumnId &&
            $0.physicalMonitor.rect.topLeftCorner == focusedPhysicalTopLeft
    }
}

@MainActor
private func focusedPhysicalMonitorForColumnSelector() -> Monitor {
    focusedColumnViewport(in: sortedMonitors.filter { $0.columnId != nil })?.physicalMonitor
        ?? focus.workspace.workspaceMonitor.physicalMonitor
}

@MainActor
private func focusedColumnViewport(in candidates: [Monitor]) -> Monitor? {
    let focusedWorkspaceId = focus.workspace.id
    let focusedViewportIds = winMuxWorkspaceState.monitorViewportsById.compactMap { viewportId, viewport -> MonitorViewportId? in
        viewport.activeWorkspaceId == focusedWorkspaceId ? viewportId : nil
    }
    return candidates.first { candidate in
        let candidateId = MonitorViewportId(candidate)
        return focusedViewportIds.contains { $0.hasSameStableIdentity(as: candidateId) }
    }
}

extension ColumnSelector {
    func parseForResolution() -> (monitorSelector: String?, zoneSelector: String) {
        if raw.hasPrefix("zone:") {
            return (nil, String(raw.dropFirst("zone:".count)))
        }
        guard let colonIndex = raw.firstIndex(of: ":") else {
            return (nil, raw)
        }
        return (
            String(raw[..<colonIndex]),
            String(raw[raw.index(after: colonIndex)...]),
        )
    }

    var isBareCurrentColumnSelector: Bool {
        let parsed = parseForResolution()
        guard parsed.monitorSelector == nil else { return false }
        switch parsed.zoneSelector.lowercased() {
            case "current", "focused":
                return true
            default:
                return false
        }
    }
}

extension Monitor {
    func matchesColumnSelector(_ selector: String) -> Bool {
        columnId.matchesColumnSelector(selector) || columnName.matchesColumnSelector(selector)
    }
}

extension Optional where Wrapped == String {
    func matchesColumnSelector(_ selector: String) -> Bool {
        guard let value = self else { return false }
        return value == selector || value.localizedCaseInsensitiveCompare(selector) == .orderedSame
    }
}

extension String {
    func matchesColumnSelector(_ selector: String) -> Bool {
        self == selector || localizedCaseInsensitiveCompare(selector) == .orderedSame
    }
}
