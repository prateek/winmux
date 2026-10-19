import Foundation

public struct CommandURLRefusal: Error, Equatable, CustomStringConvertible {
    public let description: String
    public init(_ description: String) { self.description = description }
}

public func parseCommandURL(_ url: URL) -> Result<[String], CommandURLRefusal> {
    guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return .failure(CommandURLRefusal("Malformed URL"))
    }
    guard parts.scheme?.lowercased() == "winmux" else { return .failure(CommandURLRefusal("Expected winmux scheme")) }
    guard parts.host?.lowercased() == "run" else { return .failure(CommandURLRefusal("Expected run host")) }
    guard parts.user == nil, parts.password == nil, parts.port == nil, parts.query == nil, parts.fragment == nil else {
        return .failure(CommandURLRefusal("User, password, port, query and fragment are not allowed"))
    }
    let path = parts.percentEncodedPath
    guard path.hasPrefix("/") else { return .failure(CommandURLRefusal("Missing command arguments")) }
    let segments = path.dropFirst().split(separator: "/", omittingEmptySubsequences: false)
    var arguments: [String] = []
    for segment in segments {
        guard !segment.isEmpty else { return .failure(CommandURLRefusal("Empty argument segment")) }
        guard let word = String(segment).removingPercentEncoding else {
            return .failure(CommandURLRefusal("Argument is not percent-encoded UTF-8"))
        }
        arguments.append(word)
    }
    return .success(arguments)
}

public func urlCommandRefusal(kind: CmdKind, args: (any CmdArgs)?) -> String? {
    let prints = "\(kind.rawValue) is refused in a URL: it prints a result"
    func readsStdin(_ form: String) -> String { "\(kind.rawValue) \(form) is refused in a URL: it reads stdin" }
    switch kind {
        case .subscribe, .listWindows, .listWorkspaces, .listApps, .listMonitors, .listModes,
             .listExecEnvVars, .listLenses, .listColumns, .debugWindows, .debugLensTrace, .debugHooks, .doctor, .config, .agent, .place:
            return prints
        case .execAndForget:
            return "exec-and-forget is refused in a URL: it runs a shell command"
        case .workspace:
            return (args as? WorkspaceCmdArgs)?.useStdin == true ? readsStdin("--stdin") : nil
        case .moveNodeToWorkspace:
            return (args as? MoveNodeToWorkspaceCmdArgs)?.useStdin == true ? readsStdin("--stdin") : nil
        case .lens:
            return (args as? LensCmdArgs)?.filter == "-" ? readsStdin("--filter -") : nil
        case .reloadConfig:
            return (args as? ReloadConfigCmdArgs)?.dryRun == true ? "reload-config --dry-run is refused in a URL: it prints a result" : nil
        case .focusColumn, .moveNodeToColumn, .columnWidth, .compact, .columnCount, .balanceSizes,
             .close, .closeAllWindowsButCurrent, .enable, .flattenWorkspaceTree, .findFocus,
             .focus, .focusBackAndForth, .focusMonitor, .fullscreen, .joinWith, .layout,
             .macosNativeFullscreen, .macosNativeMinimize, .mode, .move, .moveMouse, .moveNodeToMonitor,
             .moveNodeToProject, .moveWorkspaceToMonitor, .openSidebar, .palette, .project,
             .resize, .split, .stackWith, .sections, .summon, .summonWorkspace, .swap, .triggerBinding,
             .volume, .workspaceBackAndForth:
            return nil
    }
}
