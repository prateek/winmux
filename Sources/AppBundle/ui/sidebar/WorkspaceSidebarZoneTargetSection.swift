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
        guard target.isEnabled else { return false }
        if isDropTargeted {
            return true
        }
        guard let activeWorkspaceName = target.activeWorkspaceName else { return false }
        return dragPreview?.targetWorkspaceName == activeWorkspaceName &&
            dragPreview?.targetMonitorScopeId == target.monitorScopeId
    }

    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: workspaceSidebarRowCornerRadius, style: .continuous)
    }

    @ViewBuilder
    var body: some View {
        if target.isEnabled {
            rowContent
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
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 7) {
            Image(systemName: target.isDefaultZone ? "rectangle.center.inset.filled" : "rectangle.split.3x1.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(zoneTint.opacity(isDropTarget ? 0.98 : 0.76))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(target.displayName)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(target.isEnabled ? (isDropTarget ? 0.92 : 0.78) : 0.50))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    statusChips
                }
                Text(targetSubtitle)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(target.isEnabled ? 0.42 : 0.34))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            styleChip

            if target.isFocused {
                Circle()
                    .fill(workspaceSidebarActiveWorkspaceTint.opacity(0.86))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, workspaceSidebarSectionInnerHorizontalInset + workspaceSidebarHeaderRowLeadingPadding)
        .frame(width: sectionWidth, height: 42, alignment: .leading)
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
        .animation(.spring(response: 0.2, dampingFraction: 0.82), value: isDropTarget)
    }

    private var styleColor: Color? {
        target.styleColorHex.flatMap(workspaceSidebarColor(hex:))
    }

    private var zoneTint: Color {
        if let color = styleColor {
            return color
        }
        return target.isDefaultZone ? workspaceSidebarActiveWorkspaceTint : Color(nsColor: .systemTeal)
    }

    private var rowFill: Color {
        if isDropTarget {
            return Color.accentColor.opacity(0.13)
        }
        if !target.isEnabled {
            return Color.white.opacity(0.015)
        }
        if target.styleColorHex != nil {
            return zoneTint.opacity(target.isFocused ? 0.16 : 0.10)
        }
        if target.isFocused {
            return workspaceSidebarActiveWorkspaceTint.opacity(0.075)
        }
        return Color.white.opacity(0.025)
    }

    private var targetSubtitle: String {
        var parts = [target.activeWorkspaceDisplayName]
        if let availabilitySetId = target.availabilitySetId {
            parts.append("profile \(availabilitySetId)")
        }
        return parts.joined(separator: " | ")
    }

    @ViewBuilder
    private var statusChips: some View {
        if !target.isEnabled {
            zoneStateChip("Hidden", color: Color(nsColor: .systemOrange))
        }
        if target.isFocused {
            zoneStateChip("Focused", color: workspaceSidebarActiveWorkspaceTint)
        }
    }

    @ViewBuilder
    private var styleChip: some View {
        if let styleId = target.styleId {
            HStack(spacing: 4) {
                if let styleColor {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(styleColor)
                        .frame(width: 11, height: 11)
                        .overlay {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.7)
                        }
                }
                Text(styleId)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(target.isEnabled ? 0.62 : 0.42))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: 68, alignment: .trailing)
        }
    }

    private func zoneStateChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 8.5, weight: .bold))
            .foregroundStyle(color.opacity(target.isEnabled ? 0.88 : 0.70))
            .lineLimit(1)
            .padding(.horizontal, 4)
            .frame(height: 14)
            .background {
                Capsule(style: .continuous)
                    .fill(color.opacity(target.isEnabled ? 0.13 : 0.08))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(color.opacity(target.isEnabled ? 0.25 : 0.15), lineWidth: 0.5)
            }
    }

    @MainActor
    private func handlePayloadDrop(_ payload: WorkspaceSidebarDragPayload) {
        guard target.isEnabled else {
            actions.send(.clearDropPreview)
            return
        }
        switch payload {
            case .window(let windowId):
                actions.send(.moveWindowToZone(windowId, monitorScopeId: target.monitorScopeId, zoneId: target.zoneId))
            case .tabGroup(let representativeWindowId):
                actions.send(.moveTabGroupToZone(representativeWindowId, monitorScopeId: target.monitorScopeId, zoneId: target.zoneId))
        }
    }
}
