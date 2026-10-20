import AppKit
import Common
import os

/// Becomes true once the initial workspace model exists. Config parsing happens earlier during
/// launch, when scheduling a live layout pass would race app initialization.
@MainActor var isWinMuxRuntimeReady = false

struct ReloadConfigCommand: Command {
    let args: ReloadConfigCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        var stdout = ""
        let isOk = try await reloadConfig(args: args, stdout: &stdout)
        if !stdout.isEmpty {
            io.out(stdout)
        }
        return isOk
    }
}

enum ConfigReloadTrigger: Equatable, Sendable {
    /// `reload-config`, or WinMux starting.
    case command
    /// A save of the config file or of a file it imports.
    case fileChange
}

/// Which failures the user has been told about.
struct ConfigReloadNotifications {
    private var notified: String?

    /// Whether to notify the user of `diagnostic`. A save that fails the way the last notified
    /// failure did is not notified again.
    mutating func shouldNotify(_ diagnostic: String, trigger: ConfigReloadTrigger) -> Bool {
        let key = ConfigReloadNotifications.comparable(diagnostic)
        if trigger == .fileChange && key == notified { return false }
        notified = key
        return true
    }

    /// Nickel prints a function in the config as `%<closure@0x…>`, with an address that differs in
    /// every helper process. Two loads of the same broken file differ only there.
    private static func comparable(_ diagnostic: String) -> String {
        diagnostic.replacing(/@0x[0-9a-fA-F]+/, with: "@")
    }

    mutating func loaded() {
        notified = nil
    }
}

let configLog = Logger(subsystem: winMuxAppId, category: "config")
let urlLog = Logger(subsystem: winMuxAppId, category: "url")

extension LoadedConfig: ConfigReloadCandidate {
    var warnings: [String] { helper.warnings }
    var imports: [URL] { helper.imports }
    var library: URL? { helper.library }
}

@MainActor let configReloader = ConfigReloader<LoadedConfig>(
    load: { await readConfig(forceConfigUrl: $0) },
    helper: .init(
        adopt: { NickelSupervisor.shared.adopt($0.helper) },
        dispose: { NickelSupervisor.shared.discard($0.helper) },
        recordFailure: { NickelSupervisor.shared.recordFailedReload($0) },
    ),
    apply: { try await applyConfig($0.config, url: $0.url) },
    report: .init(
        show: { MessageModel.shared.message = Message(description: "WinMux Config Error", body: $0) },
        clear: { MessageModel.shared.message = nil },
        log: { level, text in
            switch level {
                case .notice: configLog.notice("\(text, privacy: .public)")
                case .warning: configLog.warning("\(text, privacy: .public)")
                case .error: configLog.error("\(text, privacy: .public)")
            }
        },
    ),
    watch: { syncConfigFileWatcher(after: $0) },
    emit: broadcastEvent,
    saves: .init(
        runtimeReady: { isWinMuxRuntimeReady },
        fileExists: { FileManager.default.fileExists(atPath: preferredEditableConfigUrl().path) },
        serverEnabled: { RunSessionGuard.isServerEnabled != nil },
        session: { body in
            guard let token: RunSessionGuard = .isServerEnabled else { return false }
            return try await runLightSession(.configAutoReload, token, body: body)
        },
    ),
    configPath: { preferredEditableConfigUrl().path },
    loadStateChanged: { ShortcutSettingsModel.shared.updateLoadState($0) },
    willReload: { FindFocusHighlight.shared.dismiss() },
)

@MainActor func reloadConfig(forceConfigUrl: URL? = nil) async throws -> Bool {
    var devNull = ""
    return try await reloadConfig(forceConfigUrl: forceConfigUrl, stdout: &devNull)
}

@MainActor func reloadConfigAfterFileChange() async { await configReloader.fileChanged() }

@MainActor func reloadConfigIfSavedDuringStartup() async { await configReloader.startupFinished() }

@MainActor func reloadConfig(
    args: ReloadConfigCmdArgs = ReloadConfigCmdArgs(rawArgs: []),
    forceConfigUrl: URL? = nil,
    trigger: ConfigReloadTrigger = .command,
    stdout: inout String,
) async throws -> Bool {
    let completion = await configReloader.request(forceConfigUrl: forceConfigUrl, dryRun: args.dryRun, noGui: args.noGui, trigger: trigger)
    stdout += completion.text
    return try completion.result.get()
}

@MainActor func applyConfig(
    _ newConfig: Config,
    url: URL,
    readSidebarState: () -> WorkspaceSidebarState = { readWorkspaceSidebarState() },
    synchronizeLogin: () -> Void = { syncStartAtLogin() },
) async throws {
    ColumnDropDecisionCache.shared.clear()
    clearPendingWindowDragIntent()
    resetHotKeys()
    config = newConfig
    workspaceSidebarTreeState.reload(defaults: newConfig.workspaceSidebar.tree)
    for workspace in Workspace.all { workspace.applyColumns(config.columns) }
    config.workspaceSidebar.apply(readSidebarState())
    configUrl = url
    try await activateMode(config.modeToKeep(activeMode), reenter: false)
    synchronizeLogin()
    applyReloadedConfigurationToRunningApp()
}

/// Apply a newly loaded config to all running surfaces. This is intentionally part of config
/// reload rather than individual Settings controls, so GUI edits, config-editor saves, and
/// filesystem auto-reloads share the same live-update behavior.
@MainActor private func applyReloadedConfigurationToRunningApp() {
    // Settings follows the reloader's load state, published when an applied load finishes or a load fails; a
    // dry run, or a load a later request supersedes, changes nothing Settings shows.
    WorkspaceSidebarPanel.refreshAll()
    WindowTabStripPanelController.shared.refresh()
    SecureInputPanel.shared.refresh()

    guard isWinMuxRuntimeReady else { return }
    scheduleRefreshSession(.configAutoReload)
}
