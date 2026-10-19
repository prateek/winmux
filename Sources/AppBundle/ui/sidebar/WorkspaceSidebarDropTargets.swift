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
    case tabGroup(ObjectIdentifier, workspace: String)
    case split(ObjectIdentifier, workspace: String)
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
    let candidates = exact.isEmpty ? targets.filter {
        guard case .tree = $0.kind else {
            return $0.rect.expanded(left: hitSlop.left, right: hitSlop.right, top: hitSlop.top, bottom: hitSlop.bottom).contains(point)
        }
        return false
    } : exact
    guard let target = candidates.min(by: { $0.rect.width * $0.rect.height < $1.rect.width * $1.rect.height }) else { return nil }
    if case .tree(let tree) = target.kind {
        return .init(kind: .tree(tree.resolvedHalf(after: point.y >= target.rect.center.y)), rect: target.rect)
    }
    return target
}

struct WorkspaceSidebarDropTarget {
    let kind: WorkspaceSidebarDropTargetKind
    let rect: Rect
}

struct WorkspaceSidebarDropTargetFrame: Equatable {
    let kind: WorkspaceSidebarDropTargetKind
    let frame: CGRect
}

struct WorkspaceSidebarDropTargetPreferenceKey: PreferenceKey {
    static let defaultValue: [WorkspaceSidebarDropTargetFrame] = []

    static func reduce(value: inout [WorkspaceSidebarDropTargetFrame], nextValue: () -> [WorkspaceSidebarDropTargetFrame]) {
        value.append(contentsOf: nextValue())
    }
}

@MainActor
func workspaceSidebarDropTarget(at mouseLocation: CGPoint, hitSlop: NSEdgeInsets = NSEdgeInsets(), includesTreeTargets: Bool = true) -> WorkspaceSidebarDropTarget? {
    WorkspaceSidebarPanel.panel(containing: mouseLocation)
        .flatMap { panel in
            resolveWorkspaceSidebarDropTarget(at: mouseLocation, targets: workspaceSidebarDropTargets.filter {
                panel.visibleScreenRectNormalized()?.contains($0.rect.center) == true
            }, hitSlop: hitSlop, includesTreeTargets: includesTreeTargets)
        }
}
