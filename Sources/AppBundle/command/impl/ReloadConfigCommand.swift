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

/// What failed reloads leave to report.
struct ConfigReloadErrors {
    /// The diagnostic of the last reload, or nil if it loaded.
    private(set) var last: String?
    private var notified: String?

    mutating func failed(_ diagnostic: String) {
        last = diagnostic
    }

    /// Whether to notify the user of `diagnostic`. A save that fails the way the last notified
    /// failure did is not notified again.
    mutating func shouldNotify(_ diagnostic: String, trigger: ConfigReloadTrigger) -> Bool {
        if trigger == .fileChange && diagnostic == notified { return false }
        notified = diagnostic
        return true
    }

    mutating func loaded() {
        last = nil
        notified = nil
    }
}

@MainActor var configReloadErrors = ConfigReloadErrors()

private let configLog = Logger(subsystem: winMuxAppId, category: "config")

@MainActor func reloadConfig(forceConfigUrl: URL? = nil) async throws -> Bool {
    var devNull = ""
    return try await reloadConfig(forceConfigUrl: forceConfigUrl, stdout: &devNull)
}

/// Reloads after a save. It is the same reload `reload-config` runs.
@MainActor func reloadConfigAfterFileChange() async {
    // Until startup is done, a change is the first launch writing the starter config, which the
    // startup load has already read.
    guard isWinMuxRuntimeReady, let token: RunSessionGuard = .isServerEnabled else { return }
    do {
        _ = try await runLightSession(.configAutoReload, token) {
            var devNull = ""
            return try await reloadConfig(trigger: .fileChange, stdout: &devNull)
        }
    } catch {
        configLog.error("A reload after a save failed: \(error.localizedDescription, privacy: .public)")
    }
}

@MainActor func reloadConfig(
    args: ReloadConfigCmdArgs = ReloadConfigCmdArgs(rawArgs: []),
    forceConfigUrl: URL? = nil,
    trigger: ConfigReloadTrigger = .command,
    stdout: inout String,
) async throws -> Bool {
    let result: Bool
    var outcome = ConfigLoadOutcome.failed
    // Even when applying the config throws, its helper is in effect and its files are the ones to
    // watch.
    defer {
        if !args.dryRun { syncConfigFileWatcher(after: outcome) }
    }
    switch await readConfig(forceConfigUrl: forceConfigUrl) {
        case .success(let loaded):
            if args.dryRun {
                NickelSupervisor.shared.discard(loaded.helper)
            } else {
                // The settings and the helper that holds the config's functions change together.
                NickelSupervisor.shared.adopt(loaded.helper)
                outcome = .loaded(loaded.helper)
                MessageModel.shared.message = nil
                configReloadErrors.loaded()
                configLog.notice("Loaded the config from \(loaded.url.path, privacy: .public)")
                try await applyConfig(loaded.config, url: loaded.url)
            }
            result = true
        case .failure(let msg):
            stdout.append(msg)
            if !args.dryRun {
                configReloadErrors.failed(msg)
                configLog.error("The config failed to load and the one in effect stays: \(msg, privacy: .public)")
            }
            if !args.noGui && configReloadErrors.shouldNotify(msg, trigger: trigger) {
                Task { @MainActor in
                    MessageModel.shared.message = Message(description: "WinMux Config Error", body: msg)
                }
            }
            result = false
    }
    return result
}

@MainActor func applyConfig(_ newConfig: Config, url: URL) async throws {
    resetHotKeys()
    config = newConfig
    config.workspaceSidebar.apply(readWorkspaceSidebarState())
    configUrl = url
    try await activateMode(config.modeToKeep(activeMode))
    syncStartAtLogin()
    applyReloadedConfigurationToRunningApp()
}

/// Apply a newly loaded config to all running surfaces. This is intentionally part of config
/// reload rather than individual Settings controls, so GUI edits, config-editor saves, and
/// filesystem auto-reloads share the same live-update behavior.
@MainActor private func applyReloadedConfigurationToRunningApp() {
    WorkspaceSidebarPanel.refreshAll()
    WindowTabStripPanelController.shared.refresh()
    SecureInputPanel.shared.refresh()

    guard isWinMuxRuntimeReady else { return }
    scheduleRefreshSession(.configAutoReload)
}
