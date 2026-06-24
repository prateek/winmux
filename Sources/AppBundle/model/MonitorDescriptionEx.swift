import Common

extension MonitorDescription {
    func resolveMonitor(sortedMonitors: [Monitor]) -> Monitor? {
        return switch self {
            case .sequenceNumber(let number): sortedMonitors.getOrNil(atIndex: number - 1)
            case .main: mainMonitor
            case .pattern(_, let regex): sortedMonitors.first { monitor in monitor.name.contains(regex.val) }
            case .secondary:
                sortedMonitors.takeIf { $0.count == 2 }?
                    .first { $0.rect.topLeftCorner != mainMonitor.rect.topLeftCorner }
        }
    }

    func resolvePhysicalMonitor(sortedPhysicalMonitors: [Monitor]) -> Monitor? {
        switch self {
            case .sequenceNumber(let number):
                sortedPhysicalMonitors.getOrNil(atIndex: number - 1)
            case .main:
                sortedPhysicalMonitors.first(where: \.isMain) ?? sortedPhysicalMonitors.first
            case .pattern(_, let regex):
                sortedPhysicalMonitors.first { monitor in monitor.name.contains(regex.val) }
            case .secondary:
                sortedPhysicalMonitors.takeIf { $0.count == 2 }?
                    .first { !$0.isMain }
        }
    }
}
