import AppKit

struct MiniatureTabSnapshot {
    let group: ObjectIdentifier
    let frame: CGRect
    let index: Int
    let count: Int
    let activeIndex: Int

    var depth: Int { MiniatureLayout.fanDepth(index: index, activeIndex: activeIndex) }
}

/// A window tab group fans only when every tab is a window. Accordion groups already give each
/// window a frame of its own, and a tab that is a container draws as today. The fan is drawn from
/// the active tab's frame, where the group's windows sit below its tab bar.
@MainActor
func miniatureTabSnapshot(_ window: Window) -> MiniatureTabSnapshot? {
    guard let group = window.parent as? TilingContainer, group.usesWindowTabBehavior,
          group.children.allSatisfy({ $0 is Window }),
          let index = group.children.firstIndex(of: window),
          let active = group.tabActiveWindow, let activeIndex = group.children.firstIndex(of: active) else { return nil }
    let frame = miniatureWindowFrame(active)
    return MiniatureTabSnapshot(group: ObjectIdentifier(group), frame: frame, index: index, count: group.children.count, activeIndex: activeIndex)
}

@MainActor
func miniatureWindowFrame(_ window: Window) -> CGRect {
    let source = window.nodeWorkspace?.workspaceMonitor.visibleRect.cgRect ?? focus.workspace.workspaceMonitor.visibleRect.cgRect
    return window.isFloating ? (window.miniatureFrame ?? window.lastKnownActualRect?.cgRect ?? source)
        : (window.lastAppliedLayoutPhysicalRect?.cgRect ?? window.miniatureFrame ?? window.lastKnownActualRect?.cgRect ?? source)
}
