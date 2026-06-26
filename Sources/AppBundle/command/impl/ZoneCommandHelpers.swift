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
    } else {
        scopedViewports = zoneViewports
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
    } else {
        physicalScope = sortedPhysicalMonitors
    }

    let scopeTopLeftCorners = Set(physicalScope.map(\.rect.topLeftCorner))
    let configuredZones = getCurrentZoneTopologySnapshot()
        .configuredZones(for: sortedPhysicalMonitors)
        .filter { scopeTopLeftCorners.contains($0.physicalMonitor.rect.topLeftCorner) }
    guard !configuredZones.isEmpty else {
        return .failure("No zones are configured")
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
