import Foundation

@MainActor
func workspaceSidebarDragSource(_ window: Window, subject: WindowDragSubject) -> TreeNode? {
    if let active = currentActiveWorkspaceSidebarDrag(), active.windowId == window.windowId, active.subject == subject {
        switch active.source {
            case .window(let id): return Window.get(byId: id)
            case .container(let id, _): return workspaceSidebarLiveContainer(id)
        }
    }
    return dragSubjectNode(for: window, subject: subject)
}
