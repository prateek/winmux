struct WorkspaceSidebarWorkspaceViewModel: Hashable, Identifiable {
    let name: String
    let projectId: WorkspaceProjectId
    let displayName: String
    let sidebarLabel: String
    let isGeneratedName: Bool
    let monitorScopeId: String
    let monitorName: String?
    let isFocused: Bool
    let isVisible: Bool
    let items: [WorkspaceSidebarItemViewModel]

    var id: String { name }
}

struct WorkspaceSidebarMonitorScopeViewModel: Hashable, Identifiable {
    let id: String
    let displayName: String
    let subtitle: String?
    let systemImageName: String
    let isFocusedMonitor: Bool
}

struct WorkspaceSidebarColumnTargetViewModel: Hashable, Identifiable {
    let id: String
    let monitorScopeId: String
    let columnId: String
    let displayName: String
    let activeWorkspaceName: String?
    let activeWorkspaceDisplayName: String
    let isFocused: Bool
    let isDefaultColumn: Bool
    let isEnabled: Bool
    let styleId: String?
    let styleColorHex: String?
}

/// A scene a display can switch to, surfaced in the sidebar's scene switcher. Non-active scenes are
/// card drop targets: dropping a card on one transfers it into that scene's default column.
struct WorkspaceSidebarSceneTargetViewModel: Hashable, Identifiable {
    let id: String
    let monitorScopeId: String
    let sceneId: String
    let displayName: String
    let isActive: Bool
}

/// One column of the focused display's active scene, rendered as a sidebar section listing its
/// deck's cards in deck order. The showing card is highlighted. A display with no configured scene
/// runs its implicit one-column scene, which produces a single `title == nil` section: it renders
/// headerless, so the laptop's flat card list is visually unchanged.
struct WorkspaceSidebarColumnSectionViewModel: Hashable, Identifiable {
    let id: String
    let monitorScopeId: String
    let columnId: String
    /// The column's display name, shown as the section header. `nil` for the single implicit
    /// column, which renders headerless for parity with the pre-scenes flat list.
    let title: String?
    /// The column's chrome tint (a `column color` runtime override or the scene column's declared
    /// `color`), used to accent the section header.
    let colorHex: String?
    let isDefaultColumn: Bool
    let isEnabled: Bool
    /// True when the column hosts the focused card.
    let isFocusedColumn: Bool
    /// The column's deck: its cards, in stable deck order.
    let cardNames: [String]
    /// The card currently showing in the column's viewport, highlighted in the section.
    let showingCardName: String?

    /// A headerless section: the single implicit column of a display with no configured scene.
    var isImplicit: Bool { title == nil }
}
