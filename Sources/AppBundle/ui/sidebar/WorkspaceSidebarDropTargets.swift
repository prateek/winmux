import SwiftUI

enum WorkspaceSidebarDropTargetKind: Equatable {
    case workspace(String)
    case newWorkspace(projectId: WorkspaceProjectId, monitorScopeId: String)
    case column(monitorScopeId: String, columnId: String)
    case monitor(String)
    /// An insertion gap in a column's deck: dropping a card here reorders it within the column
    /// (same column) or transfers it into the column (different column). `index` is the gap in the
    /// rendered deck, `0...deckCount`.
    case cardSlot(monitorScopeId: String, columnId: String, index: Int)
    /// A non-active scene of a display: dropping a card here transfers it into that scene's
    /// default column (cross-scene move; the card goes offstage and focus stays behind).
    case scene(monitorScopeId: String, sceneId: String)

    /// Card-drag destinations. These live in the same drop-target registry as the window
    /// destinations but are hit-tested only by the card drag, so a window drag ignores them and a
    /// card drag ignores window destinations.
    var isCardDropKind: Bool {
        switch self {
            case .cardSlot, .scene: true
            case .workspace, .newWorkspace, .column, .monitor: false
        }
    }
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
func workspaceSidebarDropTarget(
    at mouseLocation: CGPoint,
    hitSlop: NSEdgeInsets = NSEdgeInsets(),
    matching kindFilter: (WorkspaceSidebarDropTargetKind) -> Bool = { _ in true },
) -> WorkspaceSidebarDropTarget? {
    WorkspaceSidebarPanel.panel(containing: mouseLocation)
        .flatMap { panel in
            workspaceSidebarDropTargets.last(where: { target in
                kindFilter(target.kind) &&
                    panel.visibleScreenRectNormalized()?.contains(target.rect.center) == true &&
                    target.rect.expanded(
                        left: hitSlop.left,
                        right: hitSlop.right,
                        top: hitSlop.top,
                        bottom: hitSlop.bottom
                    ).contains(mouseLocation)
            })
        }
}
