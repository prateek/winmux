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

    /// The panel display's scenes. Non-active ones are the cross-scene card drop targets.
    var panelSceneSwitchTargets: [WorkspaceSidebarSceneTargetViewModel] {
        snapshot.sceneSwitchTargets.filter { $0.monitorScopeId == snapshot.targetMonitorScopeId }
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
        let isCompact = expansionProgress < workspaceSidebarRowsRevealProgress
        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(panelColumnSections) { section in
                    columnDeckSection(section, expansionProgress: expansionProgress)
                }
                if !isCompact {
                    workspaceSidebarSceneSwitcherRow(targets: panelSceneSwitchTargets)
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
        // Card rows drag and reorder only in expanded, configured, enabled columns. The implicit
        // laptop list is never here (it stays on the pager), but the guard keeps the intent local.
        let allowsCardDrag = !isCompact && !section.isImplicit && section.isEnabled
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
            columnDeckSectionCardList(
                section,
                cards: columnDeckSectionCards(section),
                allowsCardDrag: allowsCardDrag,
                expansionProgress: expansionProgress,
            )
        }
    }

    @ViewBuilder
    func columnDeckSectionCardList(
        _ section: WorkspaceSidebarColumnSectionViewModel,
        cards: [WorkspaceSidebarWorkspaceViewModel],
        allowsCardDrag: Bool,
        expansionProgress: CGFloat,
    ) -> some View {
        if allowsCardDrag {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    WorkspaceSidebarCardReorderSlot(
                        monitorScopeId: section.monitorScopeId,
                        columnId: section.columnId,
                        index: index,
                        actions: actions,
                    )
                    workspaceSection(
                        workspace: card,
                        expansionProgress: expansionProgress,
                        emitsDropTarget: true,
                        allowsWorkspaceActivation: true,
                        isPinnedActiveWorkspace: false,
                    )
                    .workspaceSidebarCardDrag(enabled: true, cardName: card.name)
                }
                WorkspaceSidebarCardReorderSlot(
                    monitorScopeId: section.monitorScopeId,
                    columnId: section.columnId,
                    index: cards.count,
                    actions: actions,
                )
            }
        } else {
            ForEach(cards) { card in
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

    /// Non-active scenes of the panel display, rendered as card drop targets. Dropping a card on a
    /// chip transfers it into that scene's default column (offstage: focus stays behind).
    @ViewBuilder
    func workspaceSidebarSceneSwitcherRow(targets: [WorkspaceSidebarSceneTargetViewModel]) -> some View {
        let nonActive = targets.filter { !$0.isActive }
        if !nonActive.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text("Send to scene")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.38))
                HStack(spacing: 6) {
                    ForEach(nonActive) { target in
                        WorkspaceSidebarSceneDropChip(target: target, actions: actions)
                    }
                }
            }
            .padding(.top, 4)
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
            case .card(let cardName):
                // Dropping a card on a column header transfers it into that column (append).
                actions.send(.moveCard(cardName, target: .cardSlot(
                    monitorScopeId: section.monitorScopeId,
                    columnId: section.columnId,
                    index: Int.max,
                )))
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

/// A thin insertion gap between two cards of a column's deck. Dropping a card here reorders it
/// within the column (same column) or transfers it into the column (different column). The gap
/// grows and shows an insertion line while a card hovers it.
private struct WorkspaceSidebarCardReorderSlot: View {
    let monitorScopeId: String
    let columnId: String
    let index: Int
    let actions: WorkspaceSidebarActions

    @State private var isTargeted = false
    @State private var isSettling = false

    private var target: WorkspaceSidebarDropTargetKind {
        .cardSlot(monitorScopeId: monitorScopeId, columnId: columnId, index: index)
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: isTargeted ? 16 : 6)
            .overlay(alignment: .center) {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Color.accentColor.opacity(0.9))
                        .frame(height: 2)
                        .padding(.horizontal, 6)
                }
            }
            .contentShape(Rectangle())
            .onDrop(of: [workspaceSidebarDragPayloadType], delegate: WorkspaceSidebarDropDelegate(
                target: target,
                actions: actions,
                performPayloadDrop: handleDrop,
                isTargeted: $isTargeted,
                isSettling: $isSettling,
            ))
            .animation(.spring(response: 0.2, dampingFraction: 0.82), value: isTargeted)
    }

    @MainActor
    private func handleDrop(_ payload: WorkspaceSidebarDragPayload) {
        guard case .card(let cardName) = payload else {
            actions.send(.clearDropPreview)
            return
        }
        actions.send(.moveCard(cardName, target: target))
    }
}

/// A non-active scene chip that accepts a dropped card, sending it into that scene's default
/// column. Card-only: a window drag never resolves to it.
private struct WorkspaceSidebarSceneDropChip: View {
    let target: WorkspaceSidebarSceneTargetViewModel
    let actions: WorkspaceSidebarActions

    @State private var isTargeted = false
    @State private var isSettling = false

    private var dropKind: WorkspaceSidebarDropTargetKind {
        .scene(monitorScopeId: target.monitorScopeId, sceneId: target.sceneId)
    }

    var body: some View {
        Text(target.displayName)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.white.opacity(isTargeted ? 0.95 : 0.7))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background {
                Capsule(style: .continuous)
                    .fill(isTargeted ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.06))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(isTargeted ? 0.3 : 0.12), lineWidth: 0.6)
            }
            .contentShape(Capsule())
            .onDrop(of: [workspaceSidebarDragPayloadType], delegate: WorkspaceSidebarDropDelegate(
                target: dropKind,
                actions: actions,
                performPayloadDrop: handleDrop,
                isTargeted: $isTargeted,
                isSettling: $isSettling,
            ))
            .animation(.spring(response: 0.2, dampingFraction: 0.82), value: isTargeted)
            .help("Drop a card here to send it to the \"\(target.displayName)\" scene")
    }

    @MainActor
    private func handleDrop(_ payload: WorkspaceSidebarDragPayload) {
        guard case .card(let cardName) = payload else {
            actions.send(.clearDropPreview)
            return
        }
        actions.send(.moveCard(cardName, target: dropKind))
    }
}
