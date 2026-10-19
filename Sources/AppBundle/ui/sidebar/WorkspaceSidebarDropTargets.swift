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
}

func resolveWorkspaceSidebarDropTarget(at point: CGPoint, targets: [WorkspaceSidebarDropTarget], hitSlop: NSEdgeInsets = NSEdgeInsets(), includesTreeTargets: Bool = true) -> WorkspaceSidebarDropTarget? {
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
            return $0.rect.expanded(left: hitSlop.left, right: hitSlop.right, top: hitSlop.top, bottom: hitSlop.bottom).contains(point)
        }
        return false
    } : exact
    guard let target = candidates.min(by: { $0.rect.width * $0.rect.height < $1.rect.width * $1.rect.height }) else { return nil }
    if case .tree(let tree) = target.kind {
        let row = target.rowRect ?? target.rect
        return .init(kind: .tree(tree.resolvedHalf(after: point.y >= row.center.y)), rect: target.rect, rowRect: target.rowRect)
    }
    return target
}

struct WorkspaceSidebarDropTarget {
    let kind: WorkspaceSidebarDropTargetKind
    /// Where the target takes drops. A tree row's is the part of it on screen; other targets are not clipped.
    let rect: Rect
    /// The whole row, when only part of it is on screen. Its halves decide before or after.
    var rowRect: Rect? = nil
}

struct WorkspaceSidebarDropTargetFrame: Equatable {
    let kind: WorkspaceSidebarDropTargetKind
    let frame: CGRect
    var rowFrame: CGRect? = nil
}

struct WorkspaceSidebarDropTargetPreferenceKey: PreferenceKey {
    static let defaultValue: [WorkspaceSidebarDropTargetFrame] = []

    static func reduce(value: inout [WorkspaceSidebarDropTargetFrame], nextValue: () -> [WorkspaceSidebarDropTargetFrame]) {
        value.append(contentsOf: nextValue())
    }
}

func workspaceSidebarVisibleTreeTargets(_ targets: [WorkspaceSidebarDropTargetFrame], viewport: CGRect) -> [WorkspaceSidebarDropTargetFrame] {
    // A row takes drops only where it is on screen, and its halves stay where it is drawn.
    targets.compactMap { target in
        guard case .tree = target.kind else { return target }
        let visible = target.frame.intersection(viewport)
        guard !visible.isNull, visible.height > 0, visible.width > 0 else { return nil }
        if visible == target.frame { return target }
        return WorkspaceSidebarDropTargetFrame(kind: target.kind, frame: visible, rowFrame: target.frame)
    }
}

struct WorkspaceSidebarViewportModifier: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            let viewport: CGRect = geometry.frame(in: .named("workspaceSidebarContent"))
            content.transformPreference(WorkspaceSidebarDropTargetPreferenceKey.self) { targets in
                targets = workspaceSidebarVisibleTreeTargets(targets, viewport: viewport)
            }
        }
    }
}

@MainActor
func workspaceSidebarDropTarget(at mouseLocation: CGPoint, hitSlop: NSEdgeInsets = NSEdgeInsets(), includesTreeTargets: Bool = true) -> WorkspaceSidebarDropTarget? {
    WorkspaceSidebarPanel.panel(containing: mouseLocation)
        .flatMap { panel in
            let visibleRect = panel.visibleScreenRectNormalized()
            return resolveWorkspaceSidebarDropTarget(at: mouseLocation, targets: workspaceSidebarDropTargets.filter {
                visibleRect?.contains($0.rect.center) == true
            }, hitSlop: hitSlop, includesTreeTargets: includesTreeTargets)
        }
}
