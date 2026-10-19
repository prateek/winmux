import SwiftUI

extension WorkspaceSidebarWorkspaceSection {
    func treeToggle(_ label: String, systemImage: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10))
                .frame(width: 18, height: 18)
                .background(selected ? Color.white.opacity(0.20) : .clear, in: RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityValue(selected ? "Shown" : "Hidden")
    }

    @ViewBuilder
    var columnMarks: some View {
        if !workspace.columnWidths.isEmpty {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(Array(workspace.columnWidths.enumerated()), id: \.offset) { index, width in
                        columnMark(slot: index + 1, fraction: width, totalWidth: geometry.size.width)
                    }
                }
            }
            .frame(width: 45, height: 7)
        }
    }

    // CI's compiler cannot type-check this body inline within its time limit.
    func columnMark(slot: Int, fraction: Double, totalWidth: CGFloat) -> some View {
        let gaps: CGFloat = CGFloat(workspace.columnWidths.count - 1) * 2
        let markWidth: CGFloat = max(1, (totalWidth - gaps) * CGFloat(fraction))
        let fill: Color = workspace.focusedColumn == slot ? Color.white.opacity(0.8) : Color.white.opacity(0.15)
        let isHovered: Bool = workspace.columnSlot(for: hoveredWindowId) == slot
        let stroke: Color = isHovered ? Color.accentColor : Color.white.opacity(0.4)
        let percent: Int = Int((fraction * 100).rounded())
        return RoundedRectangle(cornerRadius: 1.5)
            .fill(fill)
            .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(stroke, lineWidth: 1))
            .frame(width: markWidth, height: 7)
            .modifier(WorkspaceSidebarTreeTargetModifier(target: .columnMark(workspace.name, slot: slot), preview: dragPreview, enabled: emitsDropTarget))
            .help("Column \(slot) · \(percent)%")
    }

    func disclosureButton(_ identity: WorkspaceSidebarNodeIdentity, isOpen: Bool) -> some View {
        Button { actions.send(.toggleDisclosure(identity)) } label: {
            Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .frame(width: 12, height: rowHeight)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOpen ? "Collapse" : "Expand")
    }

    func treeItemView(_ item: WorkspaceSidebarItemViewModel, isTab: Bool = false) -> AnyView {
        let open = item.isSearchRevealed || !workspace.collapsedNodes.contains(item.identity)
        if case .window(let window) = item.kind {
            let target: WorkspaceSidebarTreeDropTarget = item.isFloating ? .floatingWindow(window.windowId, after: false) :
                (isTab ? .tab(window.windowId, after: false) : .window(window.windowId, after: false))
            return AnyView(HStack(spacing: 0) {
                if item.isFloating { Image(systemName: "rectangle.on.rectangle").font(.system(size: 8)).frame(width: 12).help("Floating window") }
                workspaceWindowButton(window, allowsDrag: true, isTabChild: isTab)
                    .help(window.title ?? window.appName)
            }.modifier(WorkspaceSidebarTreeTargetModifier(target: target, preview: dragPreview, enabled: emitsDropTarget)))
        }
        let header: AnyView
        let target: WorkspaceSidebarTreeDropTarget
        let childIsTab: Bool
        switch item.kind {
            case .tabGroup(let group):
                guard let identity = group.containerIdentity else { return AnyView(workspaceTabGroupView(group)) }
                header = AnyView(tabGroupHeaderButton(group))
                target = .tabGroup(identity, workspace: workspace.name)
                childIsTab = true
            case .split(let identity, let orientation, let layout):
                header = AnyView(Button { actions.send(.toggleDisclosure(item.identity)) } label: {
                    Text("\(orientation == "vertical" ? "↕" : "↔") \(orientation.capitalized) \(layout)")
                        .font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading).frame(height: rowHeight)
                        .contentShape(Rectangle())
                }
                    .buttonStyle(.plain)
                    .modifier(WorkspaceSidebarOptionalDragModifier(isEnabled: true, onChanged: { point in
                        workspaceSidebarDraggedContainer = (identity, workspace.name)
                        if let container = workspaceSidebarLiveContainer(identity, workspaceName: workspace.name), let window = container.anyLeafWindowRecursive {
                            updateSidebarWindowDrag(window.windowId, subject: .group, pointer: point)
                        }
                    }, onEnded: { point in finishSidebarWindowDrag(pointer: point) })))
                target = .split(identity, workspace: workspace.name)
                childIsTab = false
            case .column(_, let slot, let width):
                header = AnyView(Button { actions.send(.toggleDisclosure(item.identity)) } label: {
                    Text("Column \(slot) · \(Int((width * 100).rounded()))%")
                        .font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading).frame(height: rowHeight)
                        .contentShape(Rectangle())
                }
                    .buttonStyle(.plain)
                    .modifier(WorkspaceSidebarOptionalDragModifier(isEnabled: true,
                        onChanged: { _ in actions.send(.refuseStructuralDrag(workspace.name, target: .column(workspace.name, slot: slot))) },
                        onEnded: { _ in actions.send(.clearDropPreview) })))
                target = .column(workspace.name, slot: slot)
                childIsTab = false
            case .floating:
                header = AnyView(Label("Floating", systemImage: "rectangle.on.rectangle").font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading).frame(height: rowHeight))
                target = .floatingGroup(workspace.name)
                childIsTab = false
            case .window: return AnyView(EmptyView())
        }
        return AnyView(VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 0) {
                disclosureButton(item.identity, isOpen: open)
                header
            }
            .opacity(item.isSearchAncestor ? 0.55 : 1)
            .modifier(WorkspaceSidebarTreeTargetModifier(target: target, preview: dragPreview, enabled: emitsDropTarget))
            if open {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(item.children) { child in treeItemView(child, isTab: childIsTab) }
                }
                .padding(.leading, 18)
                .overlay(alignment: .leading) {
                    if childIsTab { Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1).padding(.leading, 6) }
                }
            }
        })
    }
}

struct WorkspaceSidebarTreeTargetModifier: ViewModifier {
    let target: WorkspaceSidebarTreeDropTarget
    let preview: WorkspaceSidebarDropPreviewViewModel?
    let enabled: Bool

    func body(content: Content) -> some View {
        let active = preview?.treeTarget.map { $0.resolvedHalf(after: false) == target.resolvedHalf(after: false) } == true
        let refused = preview?.refusalReason != nil
        return content.background {
            GeometryReader { geometry in
                Color.clear.preference(key: WorkspaceSidebarDropTargetPreferenceKey.self, value: enabled ? [
                    .init(kind: .tree(target), frame: geometry.frame(in: .named("workspaceSidebarContent"))),
                ] : [])
            }
        }.overlay {
            if active {
                if refused {
                    RoundedRectangle(cornerRadius: 4).stroke(Color.orange, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                } else {
                    switch preview?.treeTarget {
                        case .window(_, let after), .tab(_, let after), .floatingWindow(_, let after):
                            VStack { if after { Spacer(minLength: 0) }; Rectangle().fill(Color.accentColor).frame(height: 2); if !after { Spacer(minLength: 0) } }
                        default: RoundedRectangle(cornerRadius: 4).stroke(Color.accentColor, lineWidth: 1.5)
                    }
                }
            }
        }
    }
}
