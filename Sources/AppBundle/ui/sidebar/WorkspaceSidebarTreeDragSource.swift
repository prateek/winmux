import Foundation

@MainActor
func workspaceSidebarDragSource(_ window: Window, subject: WindowDragSubject) -> TreeNode? {
    if let active = currentActiveWorkspaceSidebarDrag() {
        switch active.source {
            case .window(let id): return Window.get(byId: id)
            case .container(let id, let workspace): return workspaceSidebarLiveContainer(id, workspaceName: workspace)
        }
    }
    return dragSubjectNode(for: window, subject: subject)
}
