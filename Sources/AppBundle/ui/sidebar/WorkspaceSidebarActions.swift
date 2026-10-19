import AppKit
import Common
import SwiftUI

@MainActor
func focusWorkspaceFromSidebar(_ workspaceName: String, targetMonitorScopeId: String? = nil) {
    WorkspaceSidebarPanel.suppressEdgeTrapForWorkspaceActivation()
    optimisticallyMarkWorkspaceFocusedInSidebar(workspaceName)
    runWorkspaceSidebarSession {
        guard let workspace = Workspace.existing(byName: workspaceName) else { return }
        _ = focusWorkspaceFromSidebar(workspace, targetMonitorScopeId: targetMonitorScopeId)
    }
}

/// Perceived responsiveness: flip the sidebar's focused/visible highlight to the clicked
/// workspace on the same frame as the click. The session that follows rebuilds the real model
/// (after an AX round-trip and title fetches) and corrects any difference.
@MainActor
private func optimisticallyMarkWorkspaceFocusedInSidebar(_ workspaceName: String) {
    let workspaces = TrayMenuModel.shared.workspaceSidebarWorkspaces
    guard let target = workspaces.first(where: { $0.name == workspaceName }), !target.isFocused else { return }
    TrayMenuModel.shared.workspaceSidebarWorkspaces = workspaces.map { w in
        let isFocused = w.name == workspaceName
        let isVisible = w.monitorScopeId == target.monitorScopeId ? isFocused : w.isVisible
        if isFocused == w.isFocused, isVisible == w.isVisible { return w }
        var result = w
        result.isFocused = isFocused
        result.isVisible = isVisible
        return result
    }
    WorkspaceSidebarPanel.syncVisiblePanelModelsFromShared()
}

@MainActor
func focusWorkspaceFromSidebar(_ workspace: Workspace, targetMonitorScopeId: String? = nil) -> Bool {
    guard let targetMonitorScopeId,
          let targetMonitor = workspaceSidebarMonitor(forScopeId: targetMonitorScopeId)
    else {
        return workspace.focusWorkspace()
    }

    if workspace.isVisible {
        guard workspace.workspaceMonitor.rect.topLeftCorner == targetMonitor.rect.topLeftCorner else {
            return false
        }
        return workspace.focusWorkspace()
    }

    guard targetMonitor.setActiveWorkspace(workspace) else { return false }
    return workspace.focusWorkspace()
}

@MainActor
func overrideWorkspaceInUseFromSidebar(_ workspaceName: String, targetMonitorScopeId: String? = nil) {
    WorkspaceSidebarPanel.suppressEdgeTrapForWorkspaceActivation()
    runWorkspaceSidebarSession {
        guard let workspace = Workspace.existing(byName: workspaceName),
              let targetMonitorScopeId,
              let targetMonitor = workspaceSidebarMonitor(forScopeId: targetMonitorScopeId)
        else { return }
        _ = overrideWorkspaceOnMonitorBySwappingActiveViewports(workspace, targetMonitor: targetMonitor)
        _ = workspace.focusWorkspace()
    }
}

@MainActor
func runWorkspaceSidebarSession(_ body: @escaping @MainActor () async throws -> Void) {
    guard let token: RunSessionGuard = .isServerEnabled else { return }
    Task { @MainActor in
        do {
            try await runLightSession(.menuBarButton, token) {
                try await body()
            }
        } catch {
            showWorkspaceSidebarError(error.localizedDescription)
        }
    }
}

@MainActor
func showWorkspaceSidebarError(_ body: String) {
    MessageModel.shared.message = Message(
        description: "Workspace Sidebar Error",
        body: body,
    )
}

@MainActor
func sidebarWorkspaceTargetMonitor(fallbackWindow: Window? = nil, fallbackPoint: CGPoint? = nil) -> Monitor {
    workspaceSidebarTargetMonitor(
        selectedMonitor: selectedWorkspaceSidebarMonitorScope(),
        fallbackPoint: fallbackPoint,
        fallbackWindowMonitor: fallbackWindow?.nodeMonitor,
        focusedMonitor: focus.workspace.workspaceMonitor,
    )
}

@MainActor
func workspaceSidebarTargetMonitor(
    selectedMonitor: Monitor?,
    fallbackPoint: CGPoint?,
    fallbackWindowMonitor: Monitor?,
    focusedMonitor: Monitor,
) -> Monitor {
    selectedMonitor ??
        fallbackPoint?.monitorApproximation ??
        fallbackWindowMonitor ??
        focusedMonitor
}

@MainActor
func selectedWorkspaceSidebarMonitorScope() -> Monitor? {
    let selectedScopeId = TrayMenuModel.shared.workspaceSidebarSelectedMonitorScopeId
    guard selectedScopeId != workspaceSidebarDefaultScopeId,
          selectedScopeId != workspaceSidebarFocusedScopeId
    else {
        return nil
    }
    return sortedMonitors.first { workspaceSidebarMonitorScopeId(for: $0) == selectedScopeId }
}

@MainActor
func workspaceSidebarTargetMonitor(
    scopeId: String,
    fallbackWindow: Window? = nil,
    fallbackPoint: CGPoint? = nil,
) -> Monitor {
    let selectedMonitor = workspaceSidebarMonitorForScopeId(scopeId)
    return workspaceSidebarTargetMonitor(
        selectedMonitor: selectedMonitor,
        fallbackPoint: fallbackPoint,
        fallbackWindowMonitor: fallbackWindow?.nodeMonitor,
        focusedMonitor: focus.workspace.workspaceMonitor,
    )
}

@MainActor
private func workspaceSidebarMonitorForScopeId(_ scopeId: String) -> Monitor? {
    guard scopeId != workspaceSidebarDefaultScopeId,
          scopeId != workspaceSidebarFocusedScopeId
    else {
        return nil
    }
    return sortedMonitors.first { workspaceSidebarMonitorScopeId(for: $0) == scopeId }
}

func workspaceSidebarWorkspaceCreateScope(
    selectedScopeId: String,
    targetMonitorScopeId: String,
    focusedScopeId: String,
) -> String {
    switch selectedScopeId {
        case workspaceSidebarDefaultScopeId:
            targetMonitorScopeId
        case workspaceSidebarFocusedScopeId:
            focusedScopeId
        default:
            selectedScopeId
    }
}

@MainActor
func selectWorkspaceSidebarMonitorScope(_ scopeId: String, viewModel: TrayMenuModel = TrayMenuModel.shared) {
    guard viewModel.workspaceSidebarMonitorScopes.contains(where: { $0.id == scopeId }) else { return }
    guard viewModel.workspaceSidebarSelectedMonitorScopeId != scopeId else { return }
    viewModel.workspaceSidebarSelectedMonitorScopeId = scopeId
    let visibleWorkspaceNames = Set(viewModel.visibleWorkspaceSidebarWorkspaces.map(\.name))
    let sanitizedHoveredWorkspaceName = sanitizedWorkspaceSidebarHoveredWorkspaceName(
        visibleWorkspaceNames: visibleWorkspaceNames,
        hoveredWorkspaceName: viewModel.workspaceSidebarHoveredWorkspaceName,
    )
    if viewModel.workspaceSidebarHoveredWorkspaceName != sanitizedHoveredWorkspaceName {
        viewModel.workspaceSidebarHoveredWorkspaceName = sanitizedHoveredWorkspaceName
    }
}

@MainActor
func createWorkspaceFromSidebarButton() {
    let targetMonitor = sidebarWorkspaceTargetMonitor()
    createWorkspaceFromSidebarButton(
        projectId: activeWorkspaceProjectId(for: targetMonitor),
        monitorScopeId: TrayMenuModel.shared.workspaceSidebarSelectedMonitorScopeId,
    )
}

@MainActor
func createWorkspaceFromSidebarButton(projectId: WorkspaceProjectId, monitorScopeId: String) {
    runWorkspaceSidebarSession {
        let targetMonitor = workspaceSidebarTargetMonitor(scopeId: monitorScopeId)
        let workspace = getOrCreateAdjacentBlankWorkspace(projectId: projectId, monitor: targetMonitor)
        _ = workspace.focusWorkspace()
    }
}

@MainActor
func createWorkspaceFromSidebarDrag(sourceNode: TreeNode, sourceWindow: Window) -> Bool {
    createWorkspaceFromSidebarDrag(sourceNode: sourceNode, sourceWindow: sourceWindow, projectId: nil, monitorScopeId: nil)
}

@MainActor
func createWorkspaceFromSidebarDrag(
    sourceNode: TreeNode,
    sourceWindow: Window,
    projectId: WorkspaceProjectId?,
    monitorScopeId: String?,
) -> Bool {
    let targetMonitor = monitorScopeId.map {
        workspaceSidebarTargetMonitor(
            scopeId: $0,
            fallbackWindow: sourceWindow,
            fallbackPoint: mouseLocation,
        )
    } ?? sidebarWorkspaceTargetMonitor(fallbackWindow: sourceWindow, fallbackPoint: mouseLocation)
    let projectId = projectId ?? activeWorkspaceProjectId(for: targetMonitor)
    let workspace = getOrCreateAdjacentBlankWorkspace(projectId: projectId, monitor: targetMonitor)
    let targetContainer: NonLeafTreeNodeObject
    if sourceNode is Window, sourceWindow.isFloating {
        targetContainer = workspace
    } else {
        targetContainer = workspace.rootTilingContainer
    }
    sourceNode.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    return true
}

@MainActor
func moveWindowFromSidebar(_ windowId: UInt32, toWorkspace workspaceName: String) {
    moveSidebarSource(windowId, subject: .window, toWorkspace: workspaceName)
}

@MainActor
func moveTabGroupFromSidebar(_ windowId: UInt32, toWorkspace workspaceName: String) {
    moveSidebarSource(windowId, subject: .group, toWorkspace: workspaceName)
}

@MainActor
func moveWindowToNewWorkspaceFromSidebar(_ windowId: UInt32, projectId: WorkspaceProjectId, monitorScopeId: String) {
    moveSidebarSourceToNewWorkspace(windowId, subject: .window, projectId: projectId, monitorScopeId: monitorScopeId)
}

@MainActor
func moveTabGroupToNewWorkspaceFromSidebar(_ windowId: UInt32, projectId: WorkspaceProjectId, monitorScopeId: String) {
    moveSidebarSourceToNewWorkspace(windowId, subject: .group, projectId: projectId, monitorScopeId: monitorScopeId)
}

@MainActor
private func moveSidebarSource(_ windowId: UInt32, subject: WindowDragSubject, toWorkspace workspaceName: String, explicitSource: TreeNode? = nil) {
    runWorkspaceSidebarSession {
        guard let sourceWindow = Window.get(byId: windowId),
              let targetWorkspace = Workspace.existing(byName: workspaceName)
        else { return }
        guard let sourceNode = explicitSource ?? workspaceSidebarDragSource(sourceWindow, subject: subject), sourceNode.isBound else { return }
        syncClosedWindowsCacheToCurrentWorld()
        suppressPostDragAxObserverEvents(for: sourceNode.allLeafWindowsRecursive.map(\.windowId))
        applySidebarWorkspaceMove(sourceNode: sourceNode, sourceWindow: sourceWindow, targetWorkspace: targetWorkspace)
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
private func moveSidebarSourceToNewWorkspace(
    _ windowId: UInt32,
    subject: WindowDragSubject,
    projectId: WorkspaceProjectId,
    monitorScopeId: String,
    explicitSource: TreeNode? = nil,
) {
    runWorkspaceSidebarSession {
        guard let sourceWindow = Window.get(byId: windowId) else { return }
        guard let sourceNode = explicitSource ?? workspaceSidebarDragSource(sourceWindow, subject: subject), sourceNode.isBound else { return }
        let targetMonitor = workspaceSidebarTargetMonitor(
            scopeId: monitorScopeId,
            fallbackWindow: sourceWindow,
            fallbackPoint: mouseLocation,
        )
        let workspace = getOrCreateAdjacentBlankWorkspace(projectId: projectId, monitor: targetMonitor)
        let targetContainer: NonLeafTreeNodeObject = sourceNode is Window && sourceWindow.isFloating
            ? workspace
            : workspace.rootTilingContainer
        syncClosedWindowsCacheToCurrentWorld()
        suppressPostDragAxObserverEvents(for: sourceNode.allLeafWindowsRecursive.map(\.windowId))
        sourceNode.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
func previewWorkspaceSidebarDrop(_ windowId: UInt32, subject: WindowDragSubject, target: WorkspaceSidebarDropTargetKind) {
    guard let sourceWindow = Window.get(byId: windowId) else {
        clearWorkspaceSidebarDropPreview()
        return
    }
    if case .tree(let treeTarget) = target {
        guard let source = workspaceSidebarDragSource(sourceWindow, subject: subject) else { clearWorkspaceSidebarDropPreview(); return }
        var preview = workspaceSidebarSourcePreview(sourceWindow: sourceWindow, subject: subject)
        let destination = workspaceSidebarTreeDestination(treeTarget)
        preview.treeTarget = treeTarget
        if workspaceSidebarDragUsesZones, let targetWindow = destination?.node as? Window {
            preview.offeredZones = workspaceSidebarOfferedZones(source: source, target: targetWindow)
        }
        preview.destinationDescription = workspaceSidebarTreeDropDescription(treeTarget, destination: destination)
        preview.refusalReason = workspaceSidebarTreeRefusal(source: source, destination: destination)
        preview.targetWorkspaceName = destination?.workspace.name
        setWorkspaceSidebarDropPreviewIfChanged(preview)
        return
    }
    if case .workspace(let name) = target, sourceWindow.nodeWorkspace?.name == name {
        setWorkspaceSidebarDropPreviewIfChanged(workspaceSidebarDropPreview(sourceWindow: sourceWindow, subject: subject, targetWorkspaceName: name, targetsNewWorkspace: false))
        return
    }
    guard isActionableSidebarDropTarget(sourceWindow: sourceWindow, subject: subject, target: target) else {
        clearWorkspaceSidebarDropPreview()
        return
    }
    if case .monitor(let scope) = target, let monitor = workspaceSidebarMonitor(forScopeId: scope) {
        setWorkspaceSidebarDropPreviewIfChanged(workspaceSidebarDropPreview(
            sourceWindow: sourceWindow, subject: subject,
            targetWorkspaceName: monitor.activeWorkspace.name, targetsNewWorkspace: false
        ))
        return
    }
    guard case .workspace(let workspaceName) = target else {
        if case .newWorkspace(let projectId, let monitorScopeId) = target {
            setWorkspaceSidebarDropPreviewIfChanged(workspaceSidebarDropPreview(
                sourceWindow: sourceWindow,
                subject: subject,
                targetWorkspaceName: nil,
                targetsNewWorkspace: true,
                targetProjectId: projectId,
                targetMonitorScopeId: monitorScopeId,
            ))
        } else {
            clearWorkspaceSidebarDropPreview()
        }
        return
    }
    setWorkspaceSidebarDropPreviewIfChanged(workspaceSidebarDropPreview(
        sourceWindow: sourceWindow,
        subject: subject,
        targetWorkspaceName: workspaceName,
        targetsNewWorkspace: false,
        targetProjectId: nil,
    ))
}

@MainActor
func clearWorkspaceSidebarDropPreview() {
    setWorkspaceSidebarDropPreviewIfChanged(nil)
}

@MainActor
func workspaceSidebarSourcePreview(sourceWindow: Window, subject: WindowDragSubject) -> WorkspaceSidebarDropPreviewViewModel {
    workspaceSidebarDropPreview(
        sourceWindow: sourceWindow,
        subject: subject,
        targetWorkspaceName: nil,
        targetsNewWorkspace: false,
    )
}

@MainActor
func showWorkspaceSidebarDragCursorPreview(sourceWindow: Window, subject: WindowDragSubject, point: CGPoint) {
    WindowDragCursorProxyPanel.shared.show(
        preview: workspaceSidebarSourcePreview(sourceWindow: sourceWindow, subject: subject),
        mouseScreenPoint: denormalizedAppKitScreenPoint(point),
    )
}

func denormalizedAppKitScreenPoint(_ point: CGPoint) -> CGPoint {
    normalizeAppKitScreenPoint(point)
}

@MainActor
private func isActionableSidebarDropTarget(
    sourceWindow: Window,
    subject: WindowDragSubject,
    target: WorkspaceSidebarDropTargetKind,
) -> Bool {
    let sourceWorkspaceName = workspaceSidebarDragSource(sourceWindow, subject: subject)?.nodeWorkspace?.name
    return isActionableSidebarWorkspaceDropTarget(sourceWorkspaceName: sourceWorkspaceName, targetKind: target)
}

@MainActor
private func workspaceSidebarDropPreview(
    sourceWindow: Window,
    subject: WindowDragSubject,
    targetWorkspaceName: String?,
    targetsNewWorkspace: Bool,
    targetProjectId: WorkspaceProjectId? = nil,
    targetMonitorScopeId: String? = nil,
) -> WorkspaceSidebarDropPreviewViewModel {
    let moveNode = workspaceSidebarDragSource(sourceWindow, subject: subject)
    let isTabGroup = moveNode is TilingContainer
    let sourceLabel = if let container = moveNode as? TilingContainer, container.layout == .tiles {
        "\(container.orientation == .v ? "Vertical" : "Horizontal") tiles"
    } else { sidebarDragSourceTitle(for: sourceWindow, subject: subject) }
    let appName = sourceWindow.app.name ?? sourceWindow.app.rawAppBundleId ?? "Window"
    return WorkspaceSidebarDropPreviewViewModel(
        sourceWindowId: sourceWindow.windowId,
        label: sourceLabel,
        appName: appName,
        appBundleIdentifier: sourceWindow.app.rawAppBundleId,
        appBundlePath: sourceWindow.app.bundlePath,
        targetWorkspaceName: targetWorkspaceName,
        targetsNewWorkspace: targetsNewWorkspace,
        targetProjectId: targetProjectId,
        targetMonitorScopeId: targetMonitorScopeId,
        isTabGroup: isTabGroup,
        windowCount: max(moveNode?.allLeafWindowsRecursive.count ?? 0, 1),
        tabItems: moveNode.map { workspaceSidebarDropPreviewTabs(for: $0, isTabGroup: isTabGroup) } ?? [],
    )
}

@MainActor
private func workspaceSidebarDropPreviewTabs(
    for moveNode: TreeNode,
    isTabGroup: Bool,
) -> [WorkspaceSidebarDropPreviewTabItem] {
    guard isTabGroup else { return [] }
    return moveNode.allLeafWindowsRecursive.map { window in
        let appName = window.app.name ?? window.app.rawAppBundleId ?? "Window"
        return WorkspaceSidebarDropPreviewTabItem(
            title: cachedWindowTitle(for: window)?.takeIf { $0 != appName } ?? appName,
            appName: appName,
            appBundleIdentifier: window.app.rawAppBundleId,
            appBundlePath: window.app.bundlePath,
        )
    }
}

@MainActor
func selectWorkspaceSidebarProject(
    _ projectId: WorkspaceProjectId,
    viewModel: TrayMenuModel = TrayMenuModel.shared,
    targetMonitorScopeId: String? = nil,
) {
    let knownProjects = workspaceProjects()
    let resolvedTargetScopeId = targetMonitorScopeId ?? viewModel.workspaceSidebarTargetMonitorScopeId
    debugWorkspaceSidebarProjectLog(
        "selectProjectBegin project=\(projectId.rawValue) known=\(knownProjects.map(\.id.rawValue)) targetScope=\(resolvedTargetScopeId) activeBefore=\(viewModel.workspaceSidebarActiveProjectId.rawValue)"
    )
    guard knownProjects.contains(where: { $0.id == projectId }) else {
        debugWorkspaceSidebarProjectLog("selectProjectAbort unknownProject=\(projectId.rawValue)")
        return
    }
    runWorkspaceSidebarSession {
        let monitor = workspaceSidebarTargetMonitor(
            scopeId: targetMonitorScopeId ?? viewModel.workspaceSidebarTargetMonitorScopeId
        )
        debugWorkspaceSidebarProjectLog(
            "selectProjectSession project=\(projectId.rawValue) monitor=\(monitor.monitorAppKitNsScreenScreensId) visibleBefore=\(monitor.activeWorkspace.name) activeProjectBefore=\(activeWorkspaceProjectId(for: monitor).rawValue)"
        )
        if let workspace = switchWorkspaceProject(projectId, on: monitor) {
            debugWorkspaceSidebarProjectLog(
                "selectProjectSwitchResult project=\(projectId.rawValue) workspace=\(workspace.name) workspaceProject=\(workspace.projectId.rawValue)"
            )
            _ = workspace.focusWorkspace()
            viewModel.workspaceSidebarActiveProjectId = projectId
        } else {
            debugWorkspaceSidebarProjectLog("selectProjectSwitchResult project=\(projectId.rawValue) workspace=nil")
        }
        await updateWorkspaceSidebarModel()
        debugWorkspaceSidebarProjectLog(
            "selectProjectEnd project=\(projectId.rawValue) activeAfter=\(viewModel.workspaceSidebarActiveProjectId.rawValue)"
        )
    }
}

@MainActor
func createWorkspaceSidebarProject(
    viewModel: TrayMenuModel = TrayMenuModel.shared,
    targetMonitorScopeId: String? = nil,
) {
    runWorkspaceSidebarSession {
        let project = createWorkspaceProject()
        let monitor = workspaceSidebarTargetMonitor(
            scopeId: targetMonitorScopeId ?? viewModel.workspaceSidebarTargetMonitorScopeId
        )
        if let workspace = switchWorkspaceProject(project.id, on: monitor) {
            _ = workspace.focusWorkspace()
            viewModel.workspaceSidebarActiveProjectId = project.id
        }
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
func renameWorkspaceSidebarProject(_ projectId: WorkspaceProjectId, displayName: String) {
    runWorkspaceSidebarSession {
        try renameWorkspaceProject(projectId, displayName: displayName)
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
func setWorkspaceSidebarProjectColor(_ project: WorkspaceSidebarProjectViewModel, colorHex: String?) {
    runWorkspaceSidebarSession {
        let normalizedColorHex = colorHex.flatMap(normalizedWorkspaceSidebarColorHex)
        if let normalizedColorHex {
            config.workspaceSidebar.projectColors[project.id.rawValue] = normalizedColorHex
        } else {
            config.workspaceSidebar.projectColors.removeValue(forKey: project.id.rawValue)
        }
        if !isUnitTest {
            try persistWorkspaceSidebarProjectColor(projectId: project.id.rawValue, colorHex: normalizedColorHex)
        }
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
func deleteWorkspaceSidebarProject(
    _ project: WorkspaceSidebarProjectViewModel,
    viewModel: TrayMenuModel = TrayMenuModel.shared,
) {
    guard canDeleteWorkspaceProject(project.id) else { return }
    guard confirmWorkspaceSidebarProjectDeletion(project) else { return }
    runWorkspaceSidebarSession {
        try await deleteWorkspaceProjectFromSidebar(project.id)
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
private func confirmWorkspaceSidebarProjectDeletion(_ project: WorkspaceSidebarProjectViewModel) -> Bool {
    let windowCount = windowsInWorkspaceProject(project.id).count
    guard windowCount > 0 else { return true }

    let alert = NSAlert()
    switch config.workspaceSidebar.projectDeletionAction {
        case .closeWindows:
            alert.messageText = "Close Project Windows?"
            alert.informativeText = """
            WinMux will ask macOS to close \(windowCount) window\(windowCount == 1 ? "" : "s") in “\(project.displayName)”. Apps may show their own confirmation dialogs for unsaved work. If any window stays open, WinMux will keep the project.
            """
            alert.addButton(withTitle: "Close Project")
        case .moveWindowsToFallback:
            alert.messageText = "Delete Project?"
            alert.informativeText = """
            WinMux will delete “\(project.displayName)” and move \(windowCount) window\(windowCount == 1 ? "" : "s") to another project.
            """
            alert.addButton(withTitle: "Delete Project")
    }
    alert.addButton(withTitle: "Cancel")
    alert.alertStyle = .warning
    return alert.runModal() == .alertFirstButtonReturn
}

@MainActor
func renameWorkspaceFromSidebar(_ workspaceName: String, displayName: String) {
    debugWorkspaceSidebarRenameLog("renameWorkspaceFromSidebar workspace=\(workspaceName) displayName=\(displayName)")
    runWorkspaceSidebarSession {
        try renameWorkspaceForSidebar(workspaceName: workspaceName, displayName: displayName)
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
func deleteWorkspaceFromSidebar(_ workspace: WorkspaceSidebarWorkspaceViewModel) {
    runWorkspaceSidebarSession {
        try deleteWorkspaceForSidebar(workspaceName: workspace.name)
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
func focusWindowFromSidebar(_ windowId: UInt32) {
    WorkspaceSidebarPanel.suppressEdgeTrapForWorkspaceActivation()
    runWorkspaceSidebarSession {
        guard let window = Window.get(byId: windowId),
              let liveFocus = window.toLiveFocusOrNil()
        else {
            if let fallbackWorkspace = workspaceSidebarFallbackWorkspaceName(for: windowId) {
                _ = Workspace.existing(byName: fallbackWorkspace)?.focusWorkspace()
            }
            return
        }
        _ = setFocus(to: liveFocus)
        window.nativeFocus()
    }
}

@MainActor
func workspaceSidebarFallbackWorkspaceName(for windowId: UInt32) -> String? {
    for workspace in TrayMenuModel.shared.workspaceSidebarWorkspaces {
        for item in workspace.items.flatMap(\.descendantItems) {
            switch item.kind {
                case .window(let window) where window.windowId == windowId:
                    return window.workspaceName
                case .tabGroup(let group) where group.representativeWindowId == windowId:
                    return group.workspaceName
                case .tabGroup(let group):
                    if group.tabs.contains(where: { $0.windowId == windowId }) {
                        return group.workspaceName
                    }
                case .window, .split, .column, .floating:
                    continue
            }
        }
    }
    return nil
}

@MainActor
func updateSidebarWindowDrag(_ windowId: UInt32, subject: WindowDragSubject = .window, pointer: CGPoint? = nil, container: TilingContainer? = nil, sidebarOnly: Bool = false) {
    if let pointer {
        MousePointerTracker.shared.note(point: pointer)
        postWorkspaceSidebarDragPointerNotification(workspaceSidebarDragPointerChangedNotification, pointer: pointer)
    }
    guard let window = Window.get(byId: windowId) else {
        clearWorkspaceSidebarDropPreview()
        clearPendingWindowDragIntent()
        WindowDragCursorProxyPanel.shared.hide()
        clearActiveWorkspaceSidebarDrag()
        return
    }
    beginActiveWorkspaceSidebarDrag(windowId: window.windowId, subject: subject, container: container, sidebarOnly: sidebarOnly)
    let point = MousePointerTracker.shared.currentSample.point
    updateActiveWorkspaceSidebarDragPreview(sourceWindow: window, subject: subject)
    if sidebarOnly {
        clearPendingWindowDragIntent()
        return
    }
    beginWindowMoveWithMouseSessionIfNeeded(
        windowId: window.windowId,
        subject: subject,
        detachOrigin: .window,
        startedInSidebar: true,
        anchorRect: resolvedDraggedWindowAnchorRect(for: window, subject: subject),
        refreshActualRects: true,
    )
    WindowMouseInteractionDriver.shared.startMove(
        windowId: window.windowId,
        subject: subject,
        detachOrigin: .window,
        startedInSidebar: true,
    )
    _ = updatePendingWindowDragIntent(
        sourceWindow: window,
        mouseLocation: point,
        subject: subject,
        detachOrigin: .window,
    )
}

@MainActor
func finishSidebarWindowDrag(pointer: CGPoint? = nil) {
    if let pointer {
        MousePointerTracker.shared.note(point: pointer)
        postWorkspaceSidebarDragPointerNotification(workspaceSidebarDragPointerEndedNotification, pointer: pointer)
    }
    let sidebarOnly = currentActiveWorkspaceSidebarDrag()?.sidebarOnly == true
    let didCommitSidebarDrop = commitActiveWorkspaceSidebarDragIfPossible()
    clearActiveWorkspaceSidebarDrag()
    if didCommitSidebarDrop || sidebarOnly {
        clearPendingWindowDragIntent()
        cancelManipulatedWithMouseState()
        scheduleRefreshSession(.resetManipulatedWithMouse, optimisticallyPreLayoutWorkspaces: true)
        return
    }
    Task { @MainActor in
        try? await resetManipulatedWithMouseIfPossible()
    }
    clearWorkspaceSidebarDropPreview()
    WindowDragCursorProxyPanel.shared.hide()
}

@MainActor
func finishWorkspaceSidebarDragAfterGlobalMouseUp() {
    let hasSidebarDragState = currentActiveWorkspaceSidebarDrag() != nil || isWorkspaceSidebarItemDragActive()
    let hasCursorProxy = WindowDragCursorProxyPanel.shared.currentContent != nil || WindowDragCursorProxyPanel.shared.isVisible
    guard hasSidebarDragState || hasCursorProxy else { return }
    finishSidebarWindowDrag()
    resetWorkspaceSidebarItemDrag()
}

@MainActor
private func postWorkspaceSidebarDragPointerNotification(_ name: Notification.Name, pointer: CGPoint) {
    NotificationCenter.default.post(
        name: name,
        object: nil,
        userInfo: [workspaceSidebarDragPointerUserInfoKey: NSValue(point: pointer)]
    )
}

@MainActor
func workspaceSidebarTreeAcceptsTarget(sourceWorkspaceName: String?, target: WorkspaceSidebarDropTargetKind) -> Bool {
    if currentActiveWorkspaceSidebarDrag()?.sidebarOnly == true {
        switch target {
            case .tree, .workspace: break
            case .monitor, .newWorkspace: return false
        }
    }
    if case .workspace(let name) = target, name == sourceWorkspaceName { return true }
    if case .tree = target { return true }
    return isActionableSidebarWorkspaceDropTarget(sourceWorkspaceName: sourceWorkspaceName, targetKind: target)
}

@MainActor
private func workspaceSidebarDragTarget(for sourceWindow: Window, subject: WindowDragSubject) -> WorkspaceSidebarDropTargetKind? {
    let point = MousePointerTracker.shared.currentSample.point
    guard WorkspaceSidebarPanel.panel(containing: point) != nil else { return nil }
    let source = workspaceSidebarDragUsesZones ? workspaceSidebarDragSource(sourceWindow, subject: subject) : nil
    guard let target = workspaceSidebarDropTarget(at: point, arrangementSource: source)?.kind else { return nil }
    guard workspaceSidebarTreeAcceptsTarget(sourceWorkspaceName: sourceWindow.nodeWorkspace?.name, target: target) else { return nil }
    return target
}

@MainActor
func refreshActiveWorkspaceSidebarDragPreviewIfNeeded() {
    guard let activeDrag = currentActiveWorkspaceSidebarDrag(),
          let sourceWindow = Window.get(byId: activeDrag.windowId)
    else { return }
    updateActiveWorkspaceSidebarDragPreview(sourceWindow: sourceWindow, subject: activeDrag.subject)
}

@MainActor
private func updateActiveWorkspaceSidebarDragPreview(sourceWindow: Window, subject: WindowDragSubject) {
    showWorkspaceSidebarDragCursorPreview(
        sourceWindow: sourceWindow,
        subject: subject,
        point: MousePointerTracker.shared.currentSample.point
    )
    guard let target = workspaceSidebarDragTarget(for: sourceWindow, subject: subject) else {
        clearWorkspaceSidebarDropPreview()
        return
    }
    previewWorkspaceSidebarDrop(sourceWindow.windowId, subject: subject, target: target)
}

@MainActor
private func commitActiveWorkspaceSidebarDragIfPossible() -> Bool {
    guard let activeDrag = currentActiveWorkspaceSidebarDrag(),
          let sourceWindow = Window.get(byId: activeDrag.windowId),
          let target = workspaceSidebarDragTarget(for: sourceWindow, subject: activeDrag.subject)
    else {
        clearWorkspaceSidebarDropPreview()
        WindowDragCursorProxyPanel.shared.hide()
        return false
    }
    clearWorkspaceSidebarDropPreview()
    WindowDragCursorProxyPanel.shared.hide()
    switch target {
        case .tree(let treeTarget):
            guard let source = workspaceSidebarDragSource(sourceWindow, subject: activeDrag.subject) else { return true }
            guard workspaceSidebarTreeRefusal(source: source, destination: workspaceSidebarTreeDestination(treeTarget)) == nil else { return true }
            runWorkspaceSidebarSession {
                syncClosedWindowsCacheToCurrentWorld()
                suppressPostDragAxObserverEvents(for: source.allLeafWindowsRecursive.map(\.windowId))
                _ = try await applyWorkspaceSidebarTreeDrop(source: source, target: treeTarget)
                await updateWorkspaceSidebarModel()
            }
            return true
        case .workspace(let workspaceName):
            if sourceWindow.nodeWorkspace?.name == workspaceName { return true }
            guard let source = workspaceSidebarDragSource(sourceWindow, subject: activeDrag.subject) else { return true }
            moveSidebarSource(sourceWindow.windowId, subject: activeDrag.subject, toWorkspace: workspaceName, explicitSource: source)
            return true
        case .newWorkspace(let projectId, let monitorScopeId):
            guard let source = workspaceSidebarDragSource(sourceWindow, subject: activeDrag.subject) else { return true }
            moveSidebarSourceToNewWorkspace(sourceWindow.windowId, subject: activeDrag.subject, projectId: projectId, monitorScopeId: monitorScopeId, explicitSource: source)
            return true
        case .monitor:
            return false
    }
}
