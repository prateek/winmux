import Common

struct CmdEnv: ConvenienceCopyable {
    var windowWorkspaceFallback: String?
    var windowId: UInt32?
    var workspaceName: String?
    /// A URL asked for this command. Hooks and refreshes get their own env, so this reaches only
    /// what the command itself runs, such as a binding `trigger-binding` runs.
    var isFromURL: Bool = false

    static let defaultEnv: CmdEnv = .init()
    func withFocus(_ focus: LiveFocus) -> CmdEnv {
        switch focus.asLeaf {
            case .window(let wd): .defaultEnv.copy(\.windowId, wd.windowId)
            case .emptyWorkspace(let ws): .defaultEnv.copy(\.workspaceName, ws.name)
        }
    }

    var asMap: [String: String] {
        var result = [String: String]()
        if let windowId {
            result[WINMUX_WINDOW_ID] = windowId.description
        }
        if let workspaceName {
            result[WINMUX_WORKSPACE] = workspaceName.description
        }
        return result
    }
}
