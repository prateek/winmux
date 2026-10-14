import AppKit

struct MiniatureTabSnapshot {
    let group: ObjectIdentifier
    let frame: CGRect
    let index: Int
    let count: Int
    let activeIndex: Int

    var depth: Int { MiniatureLayout.fanDepth(index: index, activeIndex: activeIndex) }
}

@MainActor
func miniatureTabSnapshot(_ window: Window, tray: Bool) -> MiniatureTabSnapshot? {
    guard !tray, !window.isFloating, let group = window.nearestWindowTabGroup,
          group.nodeWorkspace === window.nodeWorkspace else { return nil }
    let tabs = group.allLeafWindowsRecursive
    guard let frame = miniatureTabGroupFrame(group),
          let index = tabs.firstIndex(of: window),
          let active = group.tabActiveWindow, let activeIndex = tabs.firstIndex(of: active) else { return nil }
    return MiniatureTabSnapshot(group: ObjectIdentifier(group), frame: frame, index: index, count: tabs.count, activeIndex: activeIndex)
}

@MainActor
private func miniatureTabGroupFrame(_ group: TilingContainer) -> CGRect? {
    if let frame = group.lastAppliedLayoutPhysicalRect?.cgRect ?? group.lastAppliedLayoutVirtualRect?.cgRect { return frame }
    guard let workspace = group.nodeWorkspace else { return nil }
    var frame = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps.cgRect
    var path = Array(group.parentsWithSelf.compactMap { $0 as? TilingContainer }.reversed())
    if let fullscreen = workspace.rootTilingContainer.allTabbedContainersRecursive.first(where: \.hasFullscreenTab),
       let index = path.firstIndex(where: { $0 === fullscreen }) {
        path = Array(path.dropFirst(index))
    } else { frame.size.height -= 1 }
    var parent: TilingContainer?
    for container in path {
        if let parent, let index = parent.children.firstIndex(of: container) {
            if parent.layout == .tiles {
                let gaps = ResolvedGaps(gaps: config.gaps, monitor: workspace.workspaceMonitor)
                if parent.isRootContainer, let columns = workspace.columns, let slot = container.columnSlot {
                    frame = ColumnState.frame(slot: slot, widths: columns.widths, in: frame, gap: gaps.inner.get(.h).toDouble())
                } else {
                    frame = tilingSplitFrames(in: frame, virtual: frame, weights: parent.children.map { $0.getWeight(parent.orientation) },
                                              orientation: parent.orientation, gap: gaps.inner.get(parent.orientation).toDouble())[index].physical
                }
            } else if parent.usesWindowTabBehavior {
                let horizontal = parent.showsWindowTabs ? windowTabGroupShellHorizontalInset() : 0
                let top = parent.showsWindowTabs ? min(resolvedWindowTabBarHeight(), frame.height) + windowTabGroupShellTopInset() : 0
                let bottom = parent.showsWindowTabs ? windowTabGroupShellBottomInset() : 0
                frame = CGRect(x: frame.minX + horizontal, y: frame.minY + top,
                               width: max(0, frame.width - 2 * horizontal), height: max(0, frame.height - top - bottom))
            } else {
                let padding = CGFloat(config.tabGroupPadding)
                let activeIndex = parent.mostRecentChild?.ownIndex ?? 0
                let before: CGFloat
                let after: CGFloat
                switch index {
                    case 0 where parent.children.count == 1: (before, after) = (0, 0)
                    case 0: (before, after) = (0, padding)
                    case parent.children.count - 1: (before, after) = (padding, 0)
                    case activeIndex - 1: (before, after) = (0, 2 * padding)
                    case activeIndex + 1: (before, after) = (2 * padding, 0)
                    default: (before, after) = (padding, padding)
                }
                if parent.orientation == .h { frame.origin.x += before; frame.size.width -= before + after }
                else { frame.origin.y += before; frame.size.height -= before + after }
            }
        }
        parent = container
    }
    return frame
}

