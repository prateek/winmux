import Foundation

@MainActor
public final class ShortcutSettingsModel: ObservableObject {
    public static let shared = ShortcutSettingsModel()
    @Published public var openRequestId = 0
    @Published var settingsRevision = 0
    @Published var presentationRevision = 0
    @Published var summary: LoadedConfigSummary
    private var loadState: ConfigLoadState

    private init() {
        let state = ConfigLoadState()
        loadState = state
        summary = .build(config, load: state, workspaceNames: Workspace.all.map(\.name))
    }

    func reload() {
        summary = .build(config, load: loadState, workspaceNames: Workspace.all.map(\.name))
        settingsRevision += 1
    }

    func updateLoadState(_ state: ConfigLoadState) {
        loadState = state
        reload()
    }

    func requestWindowOpen() {
        openRequestId += 1
    }

    /// A window already shown, minimized included, keeps its pane and scroll position: the summary
    /// follows every load already, so there is nothing to rebuild.
    func prepareForPresentation(alreadyShown: Bool) {
        guard !alreadyShown else { return }
        reload()
        presentationRevision += 1
    }
}
