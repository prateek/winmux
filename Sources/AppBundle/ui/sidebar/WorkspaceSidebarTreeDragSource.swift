import Foundation

@MainActor
var workspaceSidebarDraggedContainer: (ObjectIdentifier, String)?

@MainActor
func workspaceSidebarDragSource(_ window: Window, subject: WindowDragSubject) -> TreeNode? {
    if let (identity, workspace) = workspaceSidebarDraggedContainer {
        return workspaceSidebarLiveContainer(identity, workspaceName: workspace)
    }
    return dragSubjectNode(for: window, subject: subject)
}
