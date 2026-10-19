import AppKit

@MainActor
private var workspaceSidebarItemDragActiveCount = 0
@MainActor
private var activeWorkspaceSidebarDrag: ActiveWorkspaceSidebarDrag?
@MainActor
private var workspaceSidebarDragModifiers: NSEvent.ModifierFlags = []

@MainActor
var workspaceSidebarDragUsesZones: Bool { workspaceSidebarDragModifiers.contains(.option) }

@MainActor
func noteWorkspaceSidebarDragModifiers(_ flags: NSEvent.ModifierFlags) {
    workspaceSidebarDragModifiers = flags
}

@MainActor
func workspaceSidebarDragWindowZones(source: TreeNode) -> (UInt32) -> [WindowDropZone] {
    guard workspaceSidebarDragUsesZones else { return { _ in [] } }
    return { id in Window.get(byId: id).map { workspaceSidebarOfferedZones(source: source, target: $0) } ?? [] }
}

struct ActiveWorkspaceSidebarDrag: Equatable {
    let windowId: UInt32
    let subject: WindowDragSubject
    let source: WorkspaceSidebarDragSource
    let sidebarOnly: Bool
}

enum WorkspaceSidebarDragSource: Equatable {
    case window(UInt32)
    case container(UInt64)
}

@MainActor
func beginWorkspaceSidebarItemDrag() {
    workspaceSidebarItemDragActiveCount += 1
}

@MainActor
func endWorkspaceSidebarItemDrag() {
    workspaceSidebarItemDragActiveCount = max(workspaceSidebarItemDragActiveCount - 1, 0)
}

@MainActor
func resetWorkspaceSidebarItemDrag() {
    workspaceSidebarItemDragActiveCount = 0
}

@MainActor
func isWorkspaceSidebarItemDragActive() -> Bool {
    workspaceSidebarItemDragActiveCount > 0
}

@MainActor
func beginActiveWorkspaceSidebarDrag(windowId: UInt32, subject: WindowDragSubject, sidebarOnly: Bool = false) {
    if let activeWorkspaceSidebarDrag, activeWorkspaceSidebarDrag.windowId == windowId,
       activeWorkspaceSidebarDrag.subject == subject { return }
    guard let window = Window.get(byId: windowId) else { return }
    guard dragSubjectNode(for: window, subject: subject) != nil else {
        clearActiveWorkspaceSidebarDrag()
        return
    }
    let source: WorkspaceSidebarDragSource = switch subject {
        case .group(let id): .container(id)
        case .window: .window(windowId)
    }
    activeWorkspaceSidebarDrag = ActiveWorkspaceSidebarDrag(windowId: windowId, subject: subject, source: source, sidebarOnly: sidebarOnly)
}

@MainActor
func currentActiveWorkspaceSidebarDrag() -> ActiveWorkspaceSidebarDrag? {
    activeWorkspaceSidebarDrag
}

@MainActor
func clearActiveWorkspaceSidebarDrag() {
    activeWorkspaceSidebarDrag = nil
    workspaceSidebarDragModifiers = []
}

func shouldLockWorkspaceSidebarExpansion(
    hasDropPreview: Bool,
    hasPinnedDraggedWindow: Bool,
    isSidebarDragInProgress: Bool,
    hasActiveEditor: Bool,
) -> Bool {
    hasDropPreview || hasPinnedDraggedWindow || isSidebarDragInProgress || hasActiveEditor
}

func isWorkspaceSidebarDragInProgress(kind: MouseManipulationKind, startedInSidebar: Bool) -> Bool {
    kind == .move && startedInSidebar
}

@MainActor
func isWorkspaceSidebarDragInProgress() -> Bool {
    isWorkspaceSidebarItemDragActive() || isWorkspaceSidebarDragInProgress(
        kind: getCurrentMouseManipulationKind(),
        startedInSidebar: getCurrentMouseDragStartedInSidebar(),
    )
}

func shouldHandleWorkspaceSidebarActivation(isEditing: Bool, isSidebarDragInProgress: Bool) -> Bool {
    !isEditing && !isSidebarDragInProgress
}

func shouldHandleWorkspaceSidebarActivation(editingWorkspaceName: String?, isSidebarDragInProgress: Bool) -> Bool {
    shouldHandleWorkspaceSidebarActivation(
        isEditing: editingWorkspaceName != nil,
        isSidebarDragInProgress: isSidebarDragInProgress,
    )
}
