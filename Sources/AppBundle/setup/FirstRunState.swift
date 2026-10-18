import Common
import Foundation

@MainActor var mayArrangeWindows = isUnitTest

struct PermissionGrants: Equatable {
    var accessibility: Bool
    var screenRecording: Bool
    var screenRecordingAfterRelaunch = false
}

struct FirstRunState: Codable, Equatable {
    var pending = false
    var screenRecordingDeclined = false
}

enum FirstRunStep: Equatable {
    case done, permissions, relaunch, go
}

func firstRunStep(grants: PermissionGrants, state: FirstRunState, screenRecordingRequested: Bool = false) -> FirstRunStep {
    guard grants.accessibility else { return .permissions }
    if grants.screenRecording || state.screenRecordingDeclined { return state.pending ? .go : .done }
    return grants.screenRecordingAfterRelaunch || screenRecordingRequested ? .relaunch : .permissions
}

@MainActor var isRelaunchingForSetup = false

func winMuxStateDirectory() -> URL {
    let home = ProcessInfo.processInfo.environment["XDG_STATE_HOME"].map { URL(filePath: $0) }
        ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: ".local/state")
    return home.appending(path: "winmux")
}

/// The debug build has its own grants, so it keeps its own setup.
func firstRunStateUrl() -> URL {
    winMuxStateDirectory().appending(path: isDebug ? "setup-debug.json" : "setup.json")
}

/// The reset clears a stale grant left by an earlier signature. A pending setup may already have
/// registered this one, which the reset would take out of the list.
func shouldResetAccessibilityAtLaunch(trusted: Bool, setupPending: Bool) -> Bool {
    !trusted && !setupPending
}

func readFirstRunState(from url: URL = firstRunStateUrl()) -> FirstRunState {
    guard let data = try? Data(contentsOf: url), let state = try? JSONDecoder().decode(FirstRunState.self, from: data) else {
        return FirstRunState()
    }
    return state
}

func writeFirstRunState(_ state: FirstRunState, to url: URL = firstRunStateUrl()) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(state).write(to: url, options: .atomic)
}

func firstRunQuitExplanation(restore: Bool) -> String {
    restore
        ? "Quitting WinMux puts your windows back where they were before it started."
        : "Quitting WinMux centres your windows on their screens."
}

struct SetupPermissions: Encodable {
    let accessibility: String
    let screenRecording: String
    let setup: String

    enum CodingKeys: String, CodingKey {
        case accessibility, setup
        case screenRecording = "screen-recording"
    }
}
