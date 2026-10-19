import SwiftUI

enum WorkspaceSidebarDropTargetKind: Equatable {
    case tree(WorkspaceSidebarTreeDropTarget)
    case workspace(String)
    case newWorkspace(projectId: WorkspaceProjectId, monitorScopeId: String)
    case monitor(String)
}

enum WorkspaceSidebarTreeDropTarget: Hashable, Sendable {
    case window(UInt32, after: Bool)
    case tab(UInt32, after: Bool)
    case windowZone(UInt32, zone: WindowDropZone)
    case tabGroup(UInt64, workspace: String)
    case split(UInt64, workspace: String)
    case column(String, slot: Int)
    case columnMark(String, slot: Int)
    case floatingGroup(String)
    case floatingWindow(UInt32, after: Bool)

    func resolvedHalf(after: Bool) -> Self {
        switch self {
            case .window(let id, _): .window(id, after: after)
            case .tab(let id, _): .tab(id, after: after)
            case .floatingWindow(let id, _): .floatingWindow(id, after: after)
            default: self
        }
    }

    var windowRowId: UInt32? {
        switch self {
            case .window(let id, _), .tab(let id, _), .windowZone(let id, _): id
            default: nil
        }
    }

    func matchesRow(_ other: Self) -> Bool {
        if let id = windowRowId { return id == other.windowRowId }
        return resolvedHalf(after: false) == other.resolvedHalf(after: false)
    }
}

func workspaceSidebarDropZone(at point: CGPoint, row: Rect, offered: [WindowDropZone]) -> WindowDropZone? {
    guard row.width > 0, row.contains(point) else { return nil }
    let order = WindowDropZone.sidebarOrder
    let index = min(order.count - 1, Int((point.x - row.minX) / (row.width / CGFloat(order.count))))
    let zone = order[index]
    return offered.contains(zone) ? zone : nil
}

func resolveWorkspaceSidebarDropTarget(at point: CGPoint, targets: [WorkspaceSidebarDropTarget], hitSlop: NSEdgeInsets = NSEdgeInsets(), includesTreeTargets: Bool = true, windowZones: (UInt32) -> [WindowDropZone] = { _ in [] }) -> WorkspaceSidebarDropTarget? {
    let targets = targets.filter { target in
        if case .tree = target.kind { return includesTreeTargets }
        return true
    }
    let exact = targets.filter { $0.rect.contains(point) }
    if let control = exact.first(where: {
        switch $0.kind {
            case .monitor, .newWorkspace: true
            case .workspace, .tree: false
        }
    }) { return control }
    let candidates = exact.isEmpty ? targets.filter {
        guard case .tree = $0.kind else {
            return $0.interactionRect(hitSlop: hitSlop).contains(point)
        }
        return false
    } : exact
    guard let target = candidates.min(by: { $0.rect.width * $0.rect.height < $1.rect.width * $1.rect.height }) else { return nil }
    if case .tree(let tree) = target.kind {
        let row = target.rowRect ?? target.rect
        if let id = tree.windowRowId, let zone = workspaceSidebarDropZone(at: point, row: row, offered: windowZones(id)) {
            return .init(kind: .tree(.windowZone(id, zone: zone)), rect: target.rect, rowRect: target.rowRect, viewport: target.viewport)
        }
        return .init(kind: .tree(tree.resolvedHalf(after: point.y >= row.center.y)), rect: target.rect, rowRect: target.rowRect, viewport: target.viewport)
    }
    return target
}

struct WorkspaceSidebarDropTarget {
    let kind: WorkspaceSidebarDropTargetKind
    /// Where the target takes drops, clipped to the scroll viewport for targets inside it.
    let rect: Rect
    /// The whole row, when only part of it is on screen. Its halves decide before or after.
    var rowRect: Rect? = nil
    var viewport: Rect? = nil

    func interactionRect(hitSlop: NSEdgeInsets) -> Rect {
        let expanded = rect.expanded(left: hitSlop.left, right: hitSlop.right, top: hitSlop.top, bottom: hitSlop.bottom)
        return viewport.map { expanded.intersection($0) } ?? expanded
    }
}

struct WorkspaceSidebarDropTargetFrame: Equatable {
    let kind: WorkspaceSidebarDropTargetKind
    let frame: CGRect
    var rowFrame: CGRect? = nil
    var viewport: CGRect? = nil
}

struct WorkspaceSidebarDropTargetPreferenceKey: PreferenceKey {
    static let defaultValue: [WorkspaceSidebarDropTargetFrame] = []

    static func reduce(value: inout [WorkspaceSidebarDropTargetFrame], nextValue: () -> [WorkspaceSidebarDropTargetFrame]) {
        value.append(contentsOf: nextValue())
    }
}

func workspaceSidebarVisibleTargets(_ targets: [WorkspaceSidebarDropTargetFrame], viewport: CGRect) -> [WorkspaceSidebarDropTargetFrame] {
    targets.compactMap { target in
        let visible = target.frame.intersection(viewport)
        guard !visible.isNull, visible.height > 0, visible.width > 0 else { return nil }
        let rowFrame: CGRect?
        if case .tree = target.kind {
            rowFrame = target.rowFrame ?? (visible == target.frame ? nil : target.frame)
        } else {
            rowFrame = nil
        }
        return WorkspaceSidebarDropTargetFrame(kind: target.kind, frame: visible, rowFrame: rowFrame, viewport: viewport)
    }
}

struct WorkspaceSidebarViewportModifier: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            let viewport: CGRect = geometry.frame(in: .named("workspaceSidebarContent"))
            content.transformPreference(WorkspaceSidebarDropTargetPreferenceKey.self) { targets in
                targets = workspaceSidebarVisibleTargets(targets, viewport: viewport)
            }
        }
    }
}

@MainActor
func workspaceSidebarDropTarget(at mouseLocation: CGPoint, hitSlop: NSEdgeInsets = NSEdgeInsets(), includesTreeTargets: Bool = true, arrangementSource: TreeNode? = nil) -> WorkspaceSidebarDropTarget? {
    WorkspaceSidebarPanel.panel(containing: mouseLocation)
        .flatMap { panel in
            let visibleRect = panel.visibleScreenRectNormalized()
            let targets = workspaceSidebarDropTargets.filter {
                visibleRect?.contains($0.rect.center) == true
            }
            let zones = arrangementSource.map(workspaceSidebarDragWindowZones) ?? { _ in [] }
            return resolveWorkspaceSidebarDropTarget(at: mouseLocation, targets: targets, hitSlop: hitSlop, includesTreeTargets: includesTreeTargets, windowZones: zones)
        }
}
