import Foundation

@MainActor
func makeWorkspaceSidebarActionsAdapter(
    viewModel: TrayMenuModel = TrayMenuModel.shared,
    targetMonitorScopeId: String? = nil,
) -> WorkspaceSidebarActions {
    WorkspaceSidebarActions(
        send: { action in
            handleWorkspaceSidebarAction(action, viewModel: viewModel, targetMonitorScopeId: targetMonitorScopeId)
        },
        setDropTargets: { targets in
            WorkspaceSidebarPanel.updateVisibleDropTargets(targets)
        },
        hoverWorkspace: { name, isHovering in
            TrayMenuModel.shared.setIfChanged(\.workspaceSidebarHoveredWorkspaceName, nextWorkspaceSidebarHoveredWorkspaceName(
                currentHoveredWorkspaceName: TrayMenuModel.shared.workspaceSidebarHoveredWorkspaceName,
                workspaceName: name,
                isHovering: isHovering,
            ))
        },
        windowDragChanged: { windowId, pointer in
            updateSidebarWindowDrag(windowId, subject: .window, pointer: pointer)
        },
        windowDragEnded: { _, pointer in
            finishSidebarWindowDrag(pointer: pointer)
        },
        tabGroupDragChanged: { containerIdentity, pointer in
            guard let window = workspaceSidebarLiveContainer(containerIdentity)?.tabRepresentativeWindow else { return }
            updateSidebarWindowDrag(window.windowId, subject: .group(containerIdentity), pointer: pointer)
        },
        tabGroupDragEnded: { _, pointer in
            finishSidebarWindowDrag(pointer: pointer)
        },
    )
}

@MainActor
func handleWorkspaceSidebarAction(
    _ action: WorkspaceSidebarAction,
    viewModel: TrayMenuModel = TrayMenuModel.shared,
    targetMonitorScopeId: String? = nil,
) {
    switch action {
        case .refuseStructuralDrag(let workspace, let target):
            var preview = WorkspaceSidebarDropPreviewViewModel(sourceWindowId: 0, label: "", appName: "", targetWorkspaceName: workspace, targetsNewWorkspace: false, isTabGroup: false, windowCount: 0)
            preview.refusalReason = "Workspaces and Columns are not windows"
            preview.treeTarget = target
            setWorkspaceSidebarDropPreviewIfChanged(preview)
        case .togglePin:
            if let scope = targetMonitorScopeId, let panel = WorkspaceSidebarPanel.panel(for: scope) {
                toggleWorkspaceSidebarPin(panel)
            }
        case .toggleSplits(let name):
            let current = workspaceSidebarTreeState.splitOverrides[name] ?? config.workspaceSidebar.tree.splits
            workspaceSidebarTreeState.splitOverrides[name] = !current
            runWorkspaceSidebarSession { await updateWorkspaceSidebarModel() }
        case .toggleColumns(let name):
            let current = workspaceSidebarTreeState.columnOverrides[name] ?? config.workspaceSidebar.tree.columns
            workspaceSidebarTreeState.columnOverrides[name] = !current
            runWorkspaceSidebarSession { await updateWorkspaceSidebarModel() }
        case .toggleDisclosure(let identity):
            if !workspaceSidebarTreeState.collapsedNodes.insert(identity).inserted {
                workspaceSidebarTreeState.collapsedNodes.remove(identity)
            }
            runWorkspaceSidebarSession { await updateWorkspaceSidebarModel() }
        case .selectWorkspace(let name):
            focusWorkspaceFromSidebar(name, targetMonitorScopeId: targetMonitorScopeId)
        case .overrideWorkspaceInUse(let name):
            overrideWorkspaceInUseFromSidebar(name, targetMonitorScopeId: targetMonitorScopeId)
        case .selectWindow(let windowId):
            focusWindowFromSidebar(windowId)
        case .selectProject(let projectId):
            debugWorkspaceSidebarProjectLog(
                "adapterSelectProject project=\(projectId.rawValue) targetScope=\(targetMonitorScopeId ?? "nil") modelActive=\(viewModel.workspaceSidebarActiveProjectId.rawValue)"
            )
            selectWorkspaceSidebarProject(projectId, viewModel: viewModel, targetMonitorScopeId: targetMonitorScopeId)
        case .createProject:
            createWorkspaceSidebarProject(viewModel: viewModel, targetMonitorScopeId: targetMonitorScopeId)
        case .renameProject(let projectId, let displayName):
            renameWorkspaceSidebarProject(projectId, displayName: displayName)
        case .setProjectColor(let projectId, let colorHex):
            if let project = workspaceSidebarProjectViewModel(projectId) {
                setWorkspaceSidebarProjectColor(project, colorHex: colorHex)
            }
        case .deleteProject(let projectId):
            if let project = workspaceSidebarProjectViewModel(projectId) {
                deleteWorkspaceSidebarProject(project, viewModel: viewModel)
            }
        case .selectMonitorScope(let scopeId):
            selectWorkspaceSidebarMonitorScope(scopeId, viewModel: viewModel)
        case .createWorkspace(let projectId, let monitorScopeId):
            createWorkspaceFromSidebarButton(projectId: projectId, monitorScopeId: monitorScopeId)
        case .renameWorkspace(let name, let displayName):
            renameWorkspaceFromSidebar(name, displayName: displayName)
        case .deleteWorkspace(let name):
            if let workspace = workspaceSidebarWorkspaceViewModel(name) {
                deleteWorkspaceFromSidebar(workspace)
            }
        case .moveWindow(let windowId, let workspaceName):
            moveWindowFromSidebar(windowId, toWorkspace: workspaceName)
        case .moveTabGroup(let containerIdentity, let workspaceName):
            moveTabGroupFromSidebar(containerIdentity, toWorkspace: workspaceName)
        case .moveWindowToNewWorkspace(let windowId, let projectId, let monitorScopeId):
            moveWindowToNewWorkspaceFromSidebar(windowId, projectId: projectId, monitorScopeId: monitorScopeId)
        case .moveTabGroupToNewWorkspace(let containerIdentity, let projectId, let monitorScopeId):
            moveTabGroupToNewWorkspaceFromSidebar(containerIdentity, projectId: projectId, monitorScopeId: monitorScopeId)
        case .previewWindowDrop(let windowId, let target):
            previewWorkspaceSidebarDrop(windowId, subject: .window, target: target)
        case .previewTabGroupDrop(let containerIdentity, let target):
            guard let window = workspaceSidebarLiveContainer(containerIdentity)?.tabRepresentativeWindow else {
                clearWorkspaceSidebarDropPreview()
                return
            }
            previewWorkspaceSidebarDrop(window.windowId, subject: .group(containerIdentity), target: target)
        case .clearDropPreview:
            clearWorkspaceSidebarDropPreview()
    }
}

@MainActor
private func workspaceSidebarProjectViewModel(_ id: WorkspaceProjectId) -> WorkspaceSidebarProjectViewModel? {
    TrayMenuModel.shared.workspaceSidebarProjects.first { $0.id == id }
}

@MainActor
private func workspaceSidebarWorkspaceViewModel(_ name: String) -> WorkspaceSidebarWorkspaceViewModel? {
    TrayMenuModel.shared.workspaceSidebarWorkspaces.first { $0.name == name }
}
