import AppKit

extension Monitor {
    @MainActor
    var workspaceSidebarInset: CGFloat {
        guard columnId == nil else { return 0 }
        guard config.workspaceSidebar.enabled else { return 0 }
        return workspaceSidebarResolvedPanelMonitors().contains { $0.rect.topLeftCorner == rect.topLeftCorner }
            ? CGFloat(config.workspaceSidebar.collapsedWidth)
            : 0
    }

    @MainActor
    var visibleRectPaddedByOuterGaps: Rect {
        guard columnId == nil else { return visibleRect }
        let topLeft = visibleRect.topLeftCorner
        let gaps = ResolvedGaps(gaps: config.gaps, monitor: self)
        let leftInset = gaps.outer.left.toDouble() + workspaceSidebarInset
        return Rect(
            topLeftX: topLeft.x + leftInset,
            topLeftY: topLeft.y + gaps.outer.top.toDouble(),
            width: visibleRect.width - leftInset - gaps.outer.right.toDouble(),
            height: visibleRect.height - gaps.outer.top.toDouble() - gaps.outer.bottom.toDouble(),
        )
    }

    @MainActor
    var monitorId_oneBased: Int? {
        sortedPhysicalMonitors.firstIndex { $0.rect.topLeftCorner == physicalMonitor.rect.topLeftCorner }.map { $0 + 1 }
    }

    @MainActor
    var workspaceViewportStableIdentity: String {
        MonitorViewportId(self).stableIdentity
    }

    @MainActor
    var physicalMonitorStableIdentity: String {
        MonitorViewportId(physicalMonitor).stableIdentity
    }

    @MainActor
    func hasSameWorkspaceViewport(as other: Monitor) -> Bool {
        MonitorViewportId(self).hasSameStableIdentity(as: MonitorViewportId(other))
    }

    @MainActor
    func hasSamePhysicalMonitor(as other: Monitor) -> Bool {
        physicalMonitor.rect.topLeftCorner == other.physicalMonitor.rect.topLeftCorner
    }

    @MainActor
    var defaultWorkspaceViewport: Monitor {
        guard columnId == nil else { return self }
        let columnViewports = workspaceViewports.filter {
            $0.columnId != nil &&
                $0.physicalMonitor.rect.topLeftCorner == physicalMonitor.rect.topLeftCorner
        }
        return columnViewports.first(where: \.isDefaultColumn) ?? columnViewports.first ?? self
    }
}
