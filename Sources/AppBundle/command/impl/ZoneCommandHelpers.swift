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

private extension ZoneSelector {
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

private extension Monitor {
    func matchesZoneSelector(_ selector: String) -> Bool {
        zoneId.matchesZoneSelector(selector) || zoneName.matchesZoneSelector(selector)
    }
}

private extension Optional where Wrapped == String {
    func matchesZoneSelector(_ selector: String) -> Bool {
        guard let value = self else { return false }
        return value == selector || value.localizedCaseInsensitiveCompare(selector) == .orderedSame
    }
}
