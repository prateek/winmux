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
        let state = ConfigLoadState(defaultsFile: defaultConfigUrl)
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
        reload()
        openRequestId += 1
    }

    func prepareForPresentation() {
        reload()
        presentationRevision += 1
    }
}
