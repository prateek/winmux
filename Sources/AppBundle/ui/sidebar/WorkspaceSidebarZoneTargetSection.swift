import SwiftUI

struct WorkspaceSidebarZoneTargetSection: View {
    let targets: [WorkspaceSidebarZoneTargetViewModel]
    let dragPreview: WorkspaceSidebarDropPreviewViewModel?
    let expansionProgress: CGFloat
    let layout: WorkspaceSidebarConfiguration
    let actions: WorkspaceSidebarActions

    private var sectionWidth: CGFloat { workspaceSidebarSectionWidth(expansionProgress, layout: layout) }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.split.3x1")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.48))
                    .frame(width: 14)
                Text("Zones")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.54))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, workspaceSidebarSectionInnerHorizontalInset + workspaceSidebarHeaderRowLeadingPadding)
            .frame(width: sectionWidth, height: 18, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(targets) { target in
                    WorkspaceSidebarZoneTargetRow(
                        target: target,
                        dragPreview: dragPreview,
                        sectionWidth: sectionWidth,
                        actions: actions,
                    )
                }
            }
        }
        .frame(width: sectionWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(expansionProgress)
    }
}

private struct WorkspaceSidebarZoneTargetRow: View {
    let target: WorkspaceSidebarZoneTargetViewModel
    let dragPreview: WorkspaceSidebarDropPreviewViewModel?
    let sectionWidth: CGFloat
    let actions: WorkspaceSidebarActions

    @State private var isDropTargeted = false
    @State private var isDropSettling = false

    private var targetKind: WorkspaceSidebarDropTargetKind {
        .zone(monitorScopeId: target.monitorScopeId, zoneId: target.zoneId)
    }

    private var isDropTarget: Bool {
        isDropTargeted ||
            (
                dragPreview?.targetWorkspaceName == target.activeWorkspaceName &&
                    dragPreview?.targetMonitorScopeId == target.monitorScopeId
            )
    }

    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: workspaceSidebarRowCornerRadius, style: .continuous)
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: target.isDefaultZone ? "rectangle.center.inset.filled" : "rectangle.split.3x1.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(zoneTint.opacity(isDropTarget ? 0.98 : 0.76))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(target.displayName)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(isDropTarget ? 0.92 : 0.78))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(target.activeWorkspaceDisplayName)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            if target.isFocused {
                Circle()
                    .fill(workspaceSidebarActiveWorkspaceTint.opacity(0.86))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, workspaceSidebarSectionInnerHorizontalInset + workspaceSidebarHeaderRowLeadingPadding)
        .frame(width: sectionWidth, height: 36, alignment: .leading)
        .background {
            rowShape.fill(rowFill)
        }
        .overlay {
            rowShape.strokeBorder(
                isDropTarget ? Color.accentColor.opacity(0.40) : Color.white.opacity(0.055),
                lineWidth: isDropTarget ? 0.9 : 0.5
            )
        }
        .contentShape(Rectangle())
        .help("\(target.displayName): \(target.activeWorkspaceDisplayName)")
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: WorkspaceSidebarDropTargetPreferenceKey.self,
                    value: [WorkspaceSidebarDropTargetFrame(
                        kind: targetKind,
                        frame: geometry.frame(in: .named("workspaceSidebarContent")),
                    )],
                )
            }
        }
        .onDrop(of: [workspaceSidebarDragPayloadType], delegate: WorkspaceSidebarDropDelegate(
            target: targetKind,
            actions: actions,
            performPayloadDrop: handlePayloadDrop,
            isTargeted: $isDropTargeted,
            isSettling: $isDropSettling,
        ))
        .animation(.spring(response: 0.2, dampingFraction: 0.82), value: isDropTarget)
    }

    private var zoneTint: Color {
        target.isDefaultZone ? workspaceSidebarActiveWorkspaceTint : Color(nsColor: .systemTeal)
    }

    private var rowFill: Color {
        if isDropTarget {
            return Color.accentColor.opacity(0.13)
        }
        if target.isFocused {
            return workspaceSidebarActiveWorkspaceTint.opacity(0.075)
        }
        return Color.white.opacity(0.025)
    }

    @MainActor
    private func handlePayloadDrop(_ payload: WorkspaceSidebarDragPayload) {
        switch payload {
            case .window(let windowId):
                actions.send(.moveWindowToZone(windowId, monitorScopeId: target.monitorScopeId, zoneId: target.zoneId))
            case .tabGroup(let representativeWindowId):
                actions.send(.moveTabGroupToZone(representativeWindowId, monitorScopeId: target.monitorScopeId, zoneId: target.zoneId))
        }
    }
}
