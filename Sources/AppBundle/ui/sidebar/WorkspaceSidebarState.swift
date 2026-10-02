import Common
import Foundation

/// The names and colours set in the sidebar. WinMux never writes to the config file, so they
/// live in a file WinMux owns. A value here overrides the config's value for the same workspace
/// or project, and deleting the file returns every name and colour to what the config declares.
struct WorkspaceSidebarState: Codable, Equatable {
    var workspaceLabels: [String: String] = [:]
    var projectLabels: [String: String] = [:]
    var projectColors: [String: String] = [:]

    enum CodingKeys: String, CodingKey {
        case workspaceLabels = "workspace-labels"
        case projectLabels = "project-labels"
        case projectColors = "project-colors"
    }

    init() {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workspaceLabels = try container.decodeIfPresent([String: String].self, forKey: .workspaceLabels) ?? [:]
        projectLabels = try container.decodeIfPresent([String: String].self, forKey: .projectLabels) ?? [:]
        projectColors = try container.decodeIfPresent([String: String].self, forKey: .projectColors) ?? [:]
    }
}

func workspaceSidebarStateUrl() -> URL {
    let stateHome = ProcessInfo.processInfo.environment["XDG_STATE_HOME"].map { URL(filePath: $0) }
        ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: ".local/state/")
    return stateHome.appending(path: "winmux").appending(path: "sidebar.json")
}

/// A missing or unreadable file means no overrides.
func readWorkspaceSidebarState(from url: URL = workspaceSidebarStateUrl()) -> WorkspaceSidebarState {
    guard let data = try? Data(contentsOf: url) else { return WorkspaceSidebarState() }
    return (try? JSONDecoder().decode(WorkspaceSidebarState.self, from: data)) ?? WorkspaceSidebarState()
}

func updateWorkspaceSidebarState(
    at url: URL = workspaceSidebarStateUrl(),
    _ change: (inout WorkspaceSidebarState) -> Void,
) throws {
    var state = readWorkspaceSidebarState(from: url)
    change(&state)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(state).write(to: url, options: .atomic)
}

extension WorkspaceSidebarConfig {
    mutating func apply(_ state: WorkspaceSidebarState) {
        workspaceLabels.merge(state.workspaceLabels) { _, override in override }
        projectLabels.merge(state.projectLabels) { _, override in override }
        projectColors.merge(state.projectColors) { _, override in override }
    }
}

/// `nil` removes the override, which leaves the name the config declares, if any.
func persistWorkspaceSidebarLabel(workspaceName: String, label: String?) throws {
    try updateWorkspaceSidebarState { $0.workspaceLabels[workspaceName] = label }
}

func persistWorkspaceSidebarProjectLabel(projectId: String, label: String?) throws {
    try updateWorkspaceSidebarState { $0.projectLabels[projectId] = label }
}

func persistWorkspaceSidebarProjectColor(projectId: String, colorHex: String?) throws {
    try updateWorkspaceSidebarState { $0.projectColors[projectId] = colorHex }
}
