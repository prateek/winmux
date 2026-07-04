import AppKit
import Common
import SwiftUI

extension WorkspaceSidebarView {
    func sidebarContent(expansionProgress: CGFloat) -> some View {
        let isCompact = expansionProgress < workspaceSidebarRowsRevealProgress
        let leadingInset = workspaceSidebarOuterLeadingPadding(isCompact: isCompact)
        let trailingInset = workspaceSidebarOuterTrailingPadding(isCompact: isCompact)
        let showsMonitorSelector = !isCompact && shouldShowTopFilterBar

        return VStack(alignment: .leading, spacing: 0) {
            if showsMonitorSelector {
                monitorSelectorSection(
                    expansionProgress: expansionProgress,
                    leadingInset: leadingInset,
                    trailingInset: trailingInset,
                )
            }

            if !isCompact, !searchText.isEmpty {
                sidebarSearchSection(
                    expansionProgress: expansionProgress,
                    leadingInset: leadingInset,
                    trailingInset: trailingInset,
                )
            }

            columnDeckSectionsContent(
                expansionProgress: expansionProgress,
                leadingInset: leadingInset,
                trailingInset: trailingInset,
                topPadding: showsMonitorSelector ? 0 : snapshot.configuration.topPadding,
            )
            .frame(width: max(snapshot.visibleWidth, 0), alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .topLeading)

            statusSection(
                expansionProgress: expansionProgress,
                isCompact: isCompact,
                leadingInset: leadingInset,
                trailingInset: trailingInset,
            )
        }
        .coordinateSpace(name: "workspaceSidebarContent")
        .onPreferenceChange(WorkspaceSidebarDropTargetPreferenceKey.self) { frames in
            actions.setDropTargets(frames)
        }
        .background {
            sidebarSurface(in: sidebarShape)
        }
        .environment(\.colorScheme, .dark)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 0.5)
        }
        .clipShape(sidebarShape)
        .shadow(
            color: Color.black.opacity(0.24),
            radius: 20,
            x: 3,
            y: 0
        )
    }
}

extension WorkspaceSidebarView {
    var shouldShowTopFilterBar: Bool {
        snapshot.monitorScopes.contains { $0.id == workspaceSidebarFocusedScopeId }
    }
}
