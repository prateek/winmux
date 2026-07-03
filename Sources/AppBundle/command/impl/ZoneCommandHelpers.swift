import Common
import Foundation

struct ResolvedZoneSelector {
    let monitor: Monitor
}

@MainActor
func resolveZoneSelector(_ selector: ZoneSelector) -> Result<ResolvedZoneSelector, String> {
    let parsed = selector.parseForResolution()
    let zoneViewports = sortedMonitors.filter { $0.zoneId != nil }
    guard !zoneViewports.isEmpty else {
        return .failure("No zones are configured")
    }
    let relativeSelector = RelativeZoneSelector(parsed.zoneSelector)

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
        scopedViewports = zoneViewports.filter {
            $0.physicalMonitor.rect.topLeftCorner == physicalMonitor.rect.topLeftCorner
        }
    } else if relativeSelector != nil {
        let focusedPhysicalMonitor = focusedPhysicalMonitorForZoneSelector()
        scopedViewports = zoneViewports.filter {
            $0.physicalMonitor.rect.topLeftCorner == focusedPhysicalMonitor.rect.topLeftCorner
        }
    } else {
        scopedViewports = zoneViewports
    }

    if let relativeSelector {
        return resolveRelativeZoneViewport(
            relativeSelector,
            rawSelector: selector.raw,
            candidates: scopedViewports,
        ).map { ResolvedZoneSelector(monitor: $0) }
    }

    let matches = scopedViewports.filter { $0.matchesZoneSelector(parsed.zoneSelector) }
    guard !matches.isEmpty else {
        if case .success(let configuredZone) = resolveConfiguredZoneSelector(selector),
           !configuredZone.isEnabled
        {
            return .failure("Zone '\(configuredZone.displayName)' is disabled. Use enable-zone \(selector.raw) before targeting it.")
        }
        return .failure("No zone matches '\(selector.raw)'")
    }
    guard matches.count == 1 else {
        let examples = matches.compactMap { monitor -> String? in
            guard let physicalId = monitor.physicalMonitor.monitorId_oneBased,
                  let zoneId = monitor.zoneId
            else { return nil }
            return "\(physicalId):\(zoneId)"
        }
        return .failure(
            "Zone selector '\(selector.raw)' is ambiguous. Use a physical monitor qualifier like \(examples.joined(separator: ", "))",
        )
    }
    return .success(ResolvedZoneSelector(monitor: matches[0]))
}

@MainActor
func resolveConfiguredZoneSelector(
    _ selector: ZoneSelector,
    monitorDescription: MonitorDescription? = nil,
) -> Result<ResolvedConfiguredZoneSelector, String> {
    let parsed = selector.parseForResolution()
    let relativeSelector = RelativeZoneSelector(parsed.zoneSelector)
    guard parsed.monitorSelector == nil || monitorDescription == nil else {
        return .failure("Use either --monitor or a physical monitor qualifier in zone selector '\(selector.raw)', not both")
    }

    let physicalScope: [Monitor]
    if let monitorDescription {
        guard let physicalMonitor = monitorDescription.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) else {
            return .failure("Can't resolve monitor selector for zone command")
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
        physicalScope = [focusedPhysicalMonitorForZoneSelector()]
    } else {
        physicalScope = sortedPhysicalMonitors
    }

    let scopeTopLeftCorners = Set(physicalScope.map(\.rect.topLeftCorner))
    let configuredZones = getCurrentColumnTopologySnapshot()
        .configuredZones(for: sortedPhysicalMonitors)
        .filter { scopeTopLeftCorners.contains($0.physicalMonitor.rect.topLeftCorner) }
    guard !configuredZones.isEmpty else {
        return .failure("No zones are configured")
    }

    if let relativeSelector {
        return resolveRelativeConfiguredZone(
            relativeSelector,
            rawSelector: selector.raw,
            candidates: configuredZones,
        )
    }

    let matches = configuredZones.filter { zone in
        zone.zoneId.matchesZoneSelector(parsed.zoneSelector) || zone.zoneName.matchesZoneSelector(parsed.zoneSelector)
    }
    guard !matches.isEmpty else {
        return .failure("No zone matches '\(selector.raw)'")
    }
    guard matches.count == 1 else {
        let examples = matches.compactMap { zone -> String? in
            guard let physicalId = zone.physicalMonitor.monitorId_oneBased else { return nil }
            return "\(physicalId):\(zone.zoneId)"
        }
        return .failure(
            "Zone selector '\(selector.raw)' is ambiguous. Use a physical monitor qualifier like \(examples.joined(separator: ", "))",
        )
    }

    let match = matches[0]
    return .success(ResolvedConfiguredZoneSelector(
        physicalMonitor: match.physicalMonitor,
        zoneLayoutId: match.zoneLayoutId,
        zoneId: match.zoneId,
        zoneName: match.zoneName,
        isDefaultZone: match.isDefaultZone,
        isEnabled: match.isEnabled,
    ))
}

private enum RelativeZoneSelector: Equatable {
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
private func resolveRelativeZoneViewport(
    _ selector: RelativeZoneSelector,
    rawSelector: String,
    candidates: [Monitor],
) -> Result<Monitor, String> {
    guard !candidates.isEmpty else {
        return .failure("No zones are configured on the focused monitor")
    }

    let currentIndex = focusedZoneViewportIndex(in: candidates)
    switch selector {
        case .current:
            guard let currentIndex else {
                return .failure("No focused zone matches '\(rawSelector)'")
            }
            return .success(candidates[currentIndex])
        case .next, .previous:
            let baseIndex = currentIndex ?? candidates.firstIndex(where: \.isDefaultZone) ?? 0
            let offset = selector == .next ? 1 : -1
            let nextIndex = (baseIndex + offset + candidates.count) % candidates.count
            return .success(candidates[nextIndex])
    }
}

@MainActor
private func resolveRelativeConfiguredZone(
    _ selector: RelativeZoneSelector,
    rawSelector: String,
    candidates: [ConfiguredZoneSummary],
) -> Result<ResolvedConfiguredZoneSelector, String> {
    guard !candidates.isEmpty else {
        return .failure("No zones are configured on the focused monitor")
    }

    let currentIndex = focusedConfiguredZoneIndex(in: candidates)
    switch selector {
        case .current:
            guard let currentIndex else {
                return .failure("No focused zone matches '\(rawSelector)'")
            }
            return .success(resolvedConfiguredZoneSelector(from: candidates[currentIndex]))
        case .next, .previous:
            let baseIndex = currentIndex ?? candidates.firstIndex(where: \.isDefaultZone) ?? 0
            let offset = selector == .next ? 1 : -1
            let nextIndex = (baseIndex + offset + candidates.count) % candidates.count
            return .success(resolvedConfiguredZoneSelector(from: candidates[nextIndex]))
    }
}

private func resolvedConfiguredZoneSelector(from summary: ConfiguredZoneSummary) -> ResolvedConfiguredZoneSelector {
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
private func focusedZoneViewportIndex(in candidates: [Monitor]) -> Int? {
    focusedZoneViewport(in: candidates).flatMap { focusedMonitor in
        candidates.firstIndex {
            MonitorViewportId($0).hasSameStableIdentity(as: MonitorViewportId(focusedMonitor))
        }
    }
}

@MainActor
private func focusedConfiguredZoneIndex(in candidates: [ConfiguredZoneSummary]) -> Int? {
    guard let focusedMonitor = focusedZoneViewport(in: sortedMonitors.filter { $0.zoneId != nil }) else { return nil }
    guard let focusedZoneId = focusedMonitor.zoneId else { return nil }
    let focusedPhysicalTopLeft = focusedMonitor.physicalMonitor.rect.topLeftCorner
    return candidates.firstIndex {
        $0.zoneId == focusedZoneId &&
            $0.physicalMonitor.rect.topLeftCorner == focusedPhysicalTopLeft
    }
}

@MainActor
private func focusedPhysicalMonitorForZoneSelector() -> Monitor {
    focusedZoneViewport(in: sortedMonitors.filter { $0.zoneId != nil })?.physicalMonitor
        ?? focus.workspace.workspaceMonitor.physicalMonitor
}

@MainActor
private func focusedZoneViewport(in candidates: [Monitor]) -> Monitor? {
    let focusedWorkspaceId = focus.workspace.id
    let focusedViewportIds = winMuxWorkspaceState.monitorViewportsById.compactMap { viewportId, viewport -> MonitorViewportId? in
        viewport.activeWorkspaceId == focusedWorkspaceId ? viewportId : nil
    }
    return candidates.first { candidate in
        let candidateId = MonitorViewportId(candidate)
        return focusedViewportIds.contains { $0.hasSameStableIdentity(as: candidateId) }
    }
}

extension ZoneSelector {
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

    var isBareCurrentZoneSelector: Bool {
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
    func matchesZoneSelector(_ selector: String) -> Bool {
        zoneId.matchesZoneSelector(selector) || zoneName.matchesZoneSelector(selector)
    }
}

extension Optional where Wrapped == String {
    func matchesZoneSelector(_ selector: String) -> Bool {
        guard let value = self else { return false }
        return value == selector || value.localizedCaseInsensitiveCompare(selector) == .orderedSame
    }
}

extension String {
    func matchesZoneSelector(_ selector: String) -> Bool {
        self == selector || localizedCaseInsensitiveCompare(selector) == .orderedSame
    }
}
