import SwiftUI

extension WorkspaceSidebarView {
    /// The panel display's column sections — its active scene's columns, in spatial order.
    var panelColumnSections: [WorkspaceSidebarColumnSectionViewModel] {
        snapshot.columnSections.filter { $0.monitorScopeId == snapshot.targetMonitorScopeId }
    }

    /// True when the panel display runs a configured scene, so the sidebar groups cards by column
    /// deck. The implicit one-column display yields a single headerless section and stays on the
    /// flat pager path, so the laptop is unchanged.
    var panelUsesColumnDeckSections: Bool {
        panelColumnSections.contains { !$0.isImplicit }
    }

    /// The scene's columns as stacked sections, each headed by the column and listing its deck's
    /// cards in deck order. Card rows reuse the flat list's `workspaceSection`, so the showing card
    /// highlights and window rows render exactly as before; only the grouping changes.
    func columnDeckSectionsContent(
        expansionProgress: CGFloat,
        leadingInset: CGFloat,
        trailingInset: CGFloat,
        topPadding: CGFloat,
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(panelColumnSections) { section in
                    columnDeckSection(section, expansionProgress: expansionProgress)
                }
            }
            .padding(.leading, leadingInset)
            .padding(.trailing, trailingInset)
            .padding(.top, topPadding)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    func columnDeckSection(
        _ section: WorkspaceSidebarColumnSectionViewModel,
        expansionProgress: CGFloat,
    ) -> some View {
        let isCompact = expansionProgress < workspaceSidebarRowsRevealProgress
        VStack(alignment: .leading, spacing: 6) {
            if !isCompact, let title = section.title {
                WorkspaceSidebarColumnSectionHeader(
                    section: section,
                    title: title,
                    dragPreview: snapshot.dropPreview,
                    expansionProgress: expansionProgress,
                    layout: snapshot.configuration,
                    actions: actions,
                )
            }
            ForEach(columnDeckSectionCards(section)) { card in
                workspaceSection(
                    workspace: card,
                    expansionProgress: expansionProgress,
                    emitsDropTarget: true,
                    allowsWorkspaceActivation: true,
                    isPinnedActiveWorkspace: false,
                )
            }
        }
    }

    /// The section's cards, resolved from the shared card view models in deck order.
    func columnDeckSectionCards(_ section: WorkspaceSidebarColumnSectionViewModel) -> [WorkspaceSidebarWorkspaceViewModel] {
        let cardsByName = Dictionary(
            snapshot.workspaces.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first },
        )
        return section.cardNames.compactMap { cardsByName[$0] }
    }
}

/// A column's header: its name tinted by the column color, and the column-level drop target that
/// sends a dropped window or tab group to the column's showing card (the promoted `.zone` drop).
private struct WorkspaceSidebarColumnSectionHeader: View {
    let section: WorkspaceSidebarColumnSectionViewModel
    let title: String
    let dragPreview: WorkspaceSidebarDropPreviewViewModel?
    let expansionProgress: CGFloat
    let layout: WorkspaceSidebarConfiguration
    let actions: WorkspaceSidebarActions

    @State private var isDropTargeted = false
    @State private var isDropSettling = false

    private var sectionWidth: CGFloat { workspaceSidebarSectionWidth(expansionProgress, layout: layout) }

    private var targetKind: WorkspaceSidebarDropTargetKind {
        .zone(monitorScopeId: section.monitorScopeId, zoneId: section.columnId)
    }

    private var isDropTarget: Bool {
        guard section.isEnabled else { return false }
        if isDropTargeted { return true }
        guard let showingCardName = section.showingCardName else { return false }
        return dragPreview?.targetWorkspaceName == showingCardName &&
            dragPreview?.targetMonitorScopeId == section.monitorScopeId
    }

    private var accent: Color {
        if let color = section.colorHex.flatMap(workspaceSidebarColor(hex:)) {
            return color
        }
        return section.isDefaultColumn ? workspaceSidebarActiveWorkspaceTint : Color(nsColor: .systemTeal)
    }

    var body: some View {
        content
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: WorkspaceSidebarDropTargetPreferenceKey.self,
                        value: section.isEnabled ? [WorkspaceSidebarDropTargetFrame(
                            kind: targetKind,
                            frame: geometry.frame(in: .named("workspaceSidebarContent")),
                        )] : [],
                    )
                }
            }
            .modifier(WorkspaceSidebarColumnSectionHeaderDrop(
                isEnabled: section.isEnabled,
                targetKind: targetKind,
                actions: actions,
                performPayloadDrop: handlePayloadDrop,
                isTargeted: $isDropTargeted,
                isSettling: $isDropSettling,
            ))
            .animation(.spring(response: 0.2, dampingFraction: 0.82), value: isDropTarget)
    }

    private var content: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(accent.opacity(section.isFocusedColumn ? 0.95 : 0.7))
                .frame(width: 3, height: 12)
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(section.isFocusedColumn ? 0.72 : 0.54))
                .lineLimit(1)
                .truncationMode(.tail)
            if !section.isEnabled {
                Text("Hidden")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(Color(nsColor: .systemOrange).opacity(0.8))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, workspaceSidebarSectionInnerHorizontalInset + workspaceSidebarHeaderRowLeadingPadding)
        .frame(width: sectionWidth, height: 18, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: workspaceSidebarRowCornerRadius, style: .continuous)
                .fill(isDropTarget ? Color.accentColor.opacity(0.13) : Color.clear)
        }
        .contentShape(Rectangle())
        .help("\(title): \(section.showingCardName.map(workspaceDisplayName) ?? "Hidden")")
    }

    @MainActor
    private func handlePayloadDrop(_ payload: WorkspaceSidebarDragPayload) {
        guard section.isEnabled else {
            actions.send(.clearDropPreview)
            return
        }
        switch payload {
            case .window(let windowId):
                actions.send(.moveWindowToZone(windowId, monitorScopeId: section.monitorScopeId, zoneId: section.columnId))
            case .tabGroup(let representativeWindowId):
                actions.send(.moveTabGroupToZone(representativeWindowId, monitorScopeId: section.monitorScopeId, zoneId: section.columnId))
        }
    }
}

/// Attaches the column drop only when the column is enabled, mirroring the workspace section's
/// drop wiring while keeping a disabled column inert.
private struct WorkspaceSidebarColumnSectionHeaderDrop: ViewModifier {
    let isEnabled: Bool
    let targetKind: WorkspaceSidebarDropTargetKind
    let actions: WorkspaceSidebarActions
    let performPayloadDrop: @MainActor (WorkspaceSidebarDragPayload) -> Void
    @Binding var isTargeted: Bool
    @Binding var isSettling: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.onDrop(of: [workspaceSidebarDragPayloadType], delegate: WorkspaceSidebarDropDelegate(
                target: targetKind,
                actions: actions,
                performPayloadDrop: performPayloadDrop,
                isTargeted: $isTargeted,
                isSettling: $isSettling,
            ))
        } else {
            content
        }
    }
}
