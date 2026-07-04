import AppKit
import Common
import SwiftUI

struct WorkspaceSidebarView: View {
    let snapshot: WorkspaceSidebarSnapshot
    let actions: WorkspaceSidebarActions
    @State var activeInUseOverrideWorkspaceName: String? = nil
    @State var isSidebarCollapsing = false
    @State var isSidebarExpanding = false
    @State var renamingWorkspaceName: String? = nil
    @State var renamingWorkspaceText = ""
    @State var searchText = ""
    @State var isSearchEditing = false
    @State var searchEditingPanel: WorkspaceSidebarPanel? = nil
    @State var selectedSearchTarget: WorkspaceSidebarSearchSelection? = nil

    init(snapshot: WorkspaceSidebarSnapshot, actions: WorkspaceSidebarActions = WorkspaceSidebarActions()) {
        self.snapshot = snapshot
        self.actions = actions
    }

    var body: some View {
        let collapsedWidth = snapshot.configuration.collapsedWidth
        let expandedWidth = snapshot.configuration.expandedWidth
        let expansionProgress = max(
            0,
            min(1, (snapshot.visibleWidth - collapsedWidth) / max(expandedWidth - collapsedWidth, 1)),
        )
        
        ZStack(alignment: .leading) {
            sidebarContent(expansionProgress: expansionProgress)
                .frame(width: max(snapshot.visibleWidth, 0), alignment: .leading)
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: max(snapshot.visibleWidth, 0))
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.clear)
        .onChange(of: snapshot.visibleWidth) { visibleWidth in
            if visibleWidth <= collapsedWidth + 0.5 {
                resetTransientSidebarState()
                finishSidebarSearch(clearText: true)
            } else if visibleWidth >= collapsedWidth + 8 {
                isSidebarCollapsing = false
            }
            if visibleWidth >= expandedWidth - 0.5 {
                isSidebarExpanding = false
                beginSidebarSearchIfNeeded()
            }
        }
        .onChange(of: snapshot.workspaces) { _ in
            if let renamingWorkspaceName, !snapshot.workspaces.contains(where: { $0.name == renamingWorkspaceName }) {
                finishWorkspaceRename(cancelled: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: workspaceSidebarWillCollapseNotification)) { notification in
            guard notificationPanel(from: notification)?.monitorScopeId == snapshot.targetMonitorScopeId else { return }
            guard snapshot.visibleWidth > collapsedWidth + 0.5 else {
                isSidebarCollapsing = false
                return
            }
            finishSidebarSearch(clearText: true)
            withAnimation(.easeOut(duration: 0.08)) {
                isSidebarCollapsing = true
                isSidebarExpanding = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: workspaceSidebarWillExpandNotification)) { notification in
            guard notificationPanel(from: notification)?.monitorScopeId == snapshot.targetMonitorScopeId else { return }
            isSidebarCollapsing = false
            isSidebarExpanding = true
            let panel = notificationPanel(from: notification)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                beginSidebarSearchIfNeeded(panel: panel)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: workspaceSidebarCommandSearchKeyNotification)) { notification in
            guard let panel = notificationPanel(from: notification),
                  panel.monitorScopeId == snapshot.targetMonitorScopeId
            else { return }
            adoptCommandSidebarSearchIfNeeded(panel: panel)
        }
    }

    func beginWorkspaceRename(_ workspace: WorkspaceSidebarWorkspaceViewModel) {
        debugWorkspaceSidebarRenameLog("beginWorkspaceRename workspace=\(workspace.name) displayName=\(workspace.displayName) targetScope=\(snapshot.targetMonitorScopeId) visibleWidth=\(snapshot.visibleWidth)")
        finishSidebarSearch(clearText: false)
        renamingWorkspaceName = workspace.name
        renamingWorkspaceText = workspace.displayName
        currentPanel()?.prepareForInlineTextEditing()
    }

    func finishWorkspaceRename(cancelled: Bool = false) {
        guard let workspaceName = renamingWorkspaceName else { return }
        let displayName = renamingWorkspaceText.trimmingCharacters(in: .whitespacesAndNewlines)
        debugWorkspaceSidebarRenameLog("finishWorkspaceRename workspace=\(workspaceName) cancelled=\(cancelled) raw=\(renamingWorkspaceText) trimmed=\(displayName) targetScope=\(snapshot.targetMonitorScopeId)")
        renamingWorkspaceName = nil
        renamingWorkspaceText = ""
        currentPanel()?.endInlineTextEditing()
        guard !cancelled, !displayName.isEmpty else { return }
        actions.send(.renameWorkspace(workspaceName, displayName: displayName))
    }

    func currentPanel() -> WorkspaceSidebarPanel? {
        WorkspaceSidebarPanel.panel(for: snapshot.targetMonitorScopeId)
    }

    func beginSidebarSearchIfNeeded(panel: WorkspaceSidebarPanel? = nil) {
        guard renamingWorkspaceName == nil, !isSearchEditing else { return }
        guard snapshot.visibleWidth > snapshot.configuration.collapsedWidth + 0.5 || isSidebarExpanding else { return }
        let editingPanel = panel ?? currentPanel() ?? WorkspaceSidebarPanel.shared
        adoptCommandSidebarSearchIfNeeded(panel: editingPanel)
    }

    func adoptCommandSidebarSearchIfNeeded(panel editingPanel: WorkspaceSidebarPanel) {
        guard renamingWorkspaceName == nil else { return }
        if !isSearchEditing {
            isSearchEditing = true
            searchEditingPanel = editingPanel
            selectFirstSearchTarget()
        }
        let locksExpansion = editingPanel.commandExpansionLocksCollapse || editingPanel.shouldLockNextSidebarSearchExpansion
        editingPanel.shouldLockNextSidebarSearchExpansion = false
        editingPanel.beginInlineTextEditing(
            locksExpansion: locksExpansion,
            cancelsOnPointerExit: false,
            onCancel: {
                finishSidebarSearch(clearText: true)
            },
            onKeyDown: { key in
                handleSidebarSearchKey(key)
            },
        )
        let bufferedKeys = editingPanel.bufferedCommandSidebarSearchKeys
        editingPanel.bufferedCommandSidebarSearchKeys = []
        for key in bufferedKeys {
            handleSidebarSearchKey(key)
        }
    }

    func finishSidebarSearch(clearText: Bool) {
        let panel = searchEditingPanel
        if isSearchEditing {
            isSearchEditing = false
            (panel ?? currentPanel() ?? WorkspaceSidebarPanel.shared).endInlineTextEditing()
            searchEditingPanel = nil
        }
        if clearText {
            searchText = ""
        }
        selectedSearchTarget = nil
    }

    func handleSidebarSearchKey(_ key: WorkspaceSidebarInlineTextKey) {
        switch key {
            case .text(let inserted):
                searchText += inserted
                selectFirstSearchTarget()
            case .deleteBackward:
                if !searchText.isEmpty {
                    searchText.removeLast()
                }
                selectFirstSearchTarget()
            case .deleteWordBackward:
                searchText.deleteLastWord()
                selectFirstSearchTarget()
            case .deleteToBeginningOfLine:
                searchText = ""
                selectedSearchTarget = nil
            case .deleteForward:
                break
            case .commit:
                activateSelectedSearchTarget()
            case .cancel:
                let panel = searchEditingPanel ?? WorkspaceSidebarPanel.shared
                finishSidebarSearch(clearText: true)
                closeWorkspaceSidebarFromCommand(panel)
            case .moveUp:
                moveSearchSelection(delta: -1)
            case .moveDown:
                moveSearchSelection(delta: 1)
            case .ignored:
                break
        }
    }

    func selectFirstSearchTarget() {
        selectedSearchTarget = searchText.isEmpty ? nil : currentSearchSelections().first
    }

    func moveSearchSelection(delta: Int) {
        let selections = currentSearchSelections()
        guard !selections.isEmpty else {
            selectedSearchTarget = nil
            return
        }
        guard let selectedSearchTarget,
              let index = selections.firstIndex(of: selectedSearchTarget)
        else {
            self.selectedSearchTarget = selections.first
            return
        }
        let nextIndex = max(0, min(selections.count - 1, index + delta))
        self.selectedSearchTarget = selections[nextIndex]
    }

    func activateSelectedSearchTarget() {
        guard let selectedSearchTarget else { return }
        let panel = searchEditingPanel ?? WorkspaceSidebarPanel.shared
        switch selectedSearchTarget {
            case .workspace(let workspaceName):
                actions.send(.selectWorkspace(workspaceName))
            case .window(let windowId):
                actions.send(.selectWindow(windowId))
        }
        finishSidebarSearch(clearText: true)
        closeWorkspaceSidebarFromCommand(panel)
    }

    func currentSearchSelections() -> [WorkspaceSidebarSearchSelection] {
        let workspaces = currentFilteredWorkspaces()
        return workspaceSidebarSearchSelections(workspaces: workspaces)
    }

    func currentFilteredWorkspaces() -> [WorkspaceSidebarWorkspaceViewModel] {
        let visible = snapshot.workspaces.filter {
            workspaceSidebarWorkspaceMatchesScope(
                $0,
                selectedScopeId: snapshot.selectedMonitorScopeId,
                focusedMonitorScopeId: snapshot.focusedMonitorScopeId,
            )
        }
        return workspaceSidebarFilteredWorkspaces(visible, query: searchText)
    }
}

private func notificationPanel(from notification: Notification) -> WorkspaceSidebarPanel? {
    notification.object as? WorkspaceSidebarPanel
}

struct WorkspaceSidebarContainerView: View {
    @ObservedObject var viewModel: TrayMenuModel
    let actions: WorkspaceSidebarActions

    var body: some View {
        WorkspaceSidebarView(
            snapshot: workspaceSidebarSnapshot(from: viewModel),
            actions: actions
        )
    }
}
extension WorkspaceSidebarView {
    func resetTransientSidebarState() {
        activeInUseOverrideWorkspaceName = nil
        isSidebarCollapsing = false
        isSidebarExpanding = false
        finishWorkspaceRename(cancelled: true)
    }
}
extension WorkspaceSidebarView {
    func monitorSelectorSection(
        expansionProgress: CGFloat,
        leadingInset: CGFloat,
        trailingInset: CGFloat,
    ) -> some View {
        WorkspaceSidebarMonitorSelector(
            scopes: snapshot.monitorScopes,
            selectedScopeId: snapshot.selectedMonitorScopeId,
            expansionProgress: expansionProgress,
            sectionWidth: workspaceSidebarSectionWidth(expansionProgress, layout: snapshot.configuration),
            onSelectScope: { scopeId in
                actions.send(.selectMonitorScope(scopeId))
            },
        )
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .padding(.top, snapshot.configuration.topPadding)
        .padding(.bottom, workspaceSidebarSectionGap)
        .zIndex(100)
    }

    func statusSection(
        expansionProgress: CGFloat,
        isCompact: Bool,
        leadingInset: CGFloat,
        trailingInset: CGFloat,
    ) -> some View {
        WorkspaceSidebarStatusView(
            sectionWidth: workspaceSidebarSectionWidth(expansionProgress, layout: snapshot.configuration),
            isCompact: isCompact,
            showsDate: snapshot.configuration.showsDate,
        )
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .padding(.top, 4)
        .padding(.bottom, workspaceSidebarStatusBottomPadding(isCompact: isCompact) + 4)
    }

    func sidebarSearchSection(
        expansionProgress: CGFloat,
        leadingInset: CGFloat,
        trailingInset: CGFloat,
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.66))
                .frame(width: 14)

            Text(searchText)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(Color.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                finishSidebarSearch(clearText: true)
                beginSidebarSearchIfNeeded()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Clear search")
        }
        .padding(.horizontal, 8)
        .frame(width: workspaceSidebarSectionWidth(expansionProgress, layout: snapshot.configuration), height: workspaceSidebarSearchHeight)
        .background {
            RoundedRectangle(cornerRadius: workspaceSidebarDropdownCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.11))
        }
        .overlay {
            RoundedRectangle(cornerRadius: workspaceSidebarDropdownCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .padding(.bottom, workspaceSidebarSectionGap)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
extension WorkspaceSidebarView {
    var sidebarShape: some Shape {
        WorkspaceSidebarPanelShape(rightCornerRadius: workspaceSidebarPanelRightCornerRadius)
    }

    func sidebarSurface<S: Shape>(in shape: S) -> some View {
        GlassSurface(shape: shape)
            .ignoresSafeArea()
    }
}

private struct WorkspaceSidebarPanelShape: Shape {
    let rightCornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(rightCornerRadius, rect.width / 2, rect.height / 2)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
extension WorkspaceSidebarView {
    @ViewBuilder
    func workspaceSection(
        workspace: WorkspaceSidebarWorkspaceViewModel,
        expansionProgress: CGFloat,
        emitsDropTarget: Bool,
        allowsWorkspaceActivation: Bool,
        isPinnedActiveWorkspace: Bool,
    ) -> some View {
        let isInUseOnOtherDisplay = allowsWorkspaceActivation &&
            !isPinnedActiveWorkspace &&
            workspaceSidebarWorkspaceIsInUseOnOtherDisplay(
                workspace,
                selectedScopeId: snapshot.targetMonitorScopeId
            )
        WorkspaceSidebarWorkspaceSection(
            workspace: workspace,
            dragPreview: snapshot.dropPreview,
            expansionProgress: expansionProgress,
            layout: snapshot.configuration,
            emitsDropTarget: emitsDropTarget,
            isFromOtherDisplay: false,
            isInUseOnOtherDisplay: isInUseOnOtherDisplay,
            isOnFocusedMonitor: workspace.monitorScopeId == snapshot.focusedMonitorScopeId,
            allowsWorkspaceActivation: allowsWorkspaceActivation,
            isPinnedActiveWorkspace: isPinnedActiveWorkspace,
            isActiveOnTargetMonitor: workspace.monitorScopeId == snapshot.targetMonitorScopeId && workspace.isVisible,
            renamingWorkspaceName: $renamingWorkspaceName,
            renamingWorkspaceText: $renamingWorkspaceText,
            onBeginRenameWorkspace: {
                beginWorkspaceRename(workspace)
            },
            onCommitRenameWorkspace: {
                finishWorkspaceRename()
            },
            onCancelRenameWorkspace: {
                finishWorkspaceRename(cancelled: true)
            },
            selectedSearchTarget: searchText.isEmpty ? nil : selectedSearchTarget,
            isSearchFiltering: !searchText.isEmpty,
            activeInUseOverrideWorkspaceName: $activeInUseOverrideWorkspaceName,
            actions: actions,
        )
    }
}
