import AppKit
import Common
import SwiftUI

// MARK: - Monitor Selector

struct WorkspaceSidebarMonitorSelector: View {
    let scopes: [WorkspaceSidebarMonitorScopeViewModel]
    let selectedScopeId: String
    let expansionProgress: CGFloat
    let sectionWidth: CGFloat
    var onSelectScope: (String) -> Void = { selectWorkspaceSidebarMonitorScope($0) }

    private var quickScopes: [WorkspaceSidebarMonitorScopeViewModel] {
        var result = [
            scopes.first { $0.id == workspaceSidebarDefaultScopeId }
                ?? WorkspaceSidebarMonitorScopeViewModel(
                    id: workspaceSidebarDefaultScopeId,
                    displayName: "Default",
                    subtitle: nil,
                    systemImageName: "display",
                    isFocusedMonitor: false
                ),
        ]
        if let focusedScope = scopes.first(where: { $0.id == workspaceSidebarFocusedScopeId }) {
            result.append(focusedScope)
        }
        return result
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(quickScopes) { scope in
                monitorScopePill(scope)
            }
            Spacer(minLength: 0)
        }
        .frame(width: sectionWidth, alignment: .leading)
        .frame(height: workspaceSidebarDropdownHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(expansionProgress)
    }

    private func monitorScopePill(_ scope: WorkspaceSidebarMonitorScopeViewModel) -> some View {
        let isActive = scope.id == selectedScopeId
        return Button {
            onSelectScope(scope.id)
        } label: {
            Text(scope.id == workspaceSidebarFocusedScopeId ? "Focus" : scope.displayName)
                .font(.system(size: 12.5, weight: isActive ? .semibold : .medium))
                .lineLimit(1)
                .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.68))
                .modifier(WorkspaceSidebarDropdownControlStyle(isActive: isActive))
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel(scopeAccessibilityLabel(scope))
        .background {
            if workspaceSidebarMonitorScopePoint(scope.id) != nil {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: WorkspaceSidebarDropTargetPreferenceKey.self,
                        value: [WorkspaceSidebarDropTargetFrame(
                            kind: .monitor(scope.id),
                            frame: geometry.frame(in: .named("workspaceSidebarContent")),
                        )],
                    )
                }
            }
        }
    }

    private func scopeAccessibilityLabel(_ scope: WorkspaceSidebarMonitorScopeViewModel) -> String {
        if let subtitle = scope.subtitle {
            return "\(scope.displayName), \(subtitle)"
        }
        return scope.displayName
    }
}
