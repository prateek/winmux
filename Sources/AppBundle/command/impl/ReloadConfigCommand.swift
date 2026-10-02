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
        if trigger == .fileChange && diagnostic == notified { return false }
        notified = diagnostic
        return true
    }

    mutating func loaded() {
        notified = nil
    }
}

@MainActor var configReloadNotifications = ConfigReloadNotifications()

let configLog = Logger(subsystem: winMuxAppId, category: "config")

/// Counts reloads, so a reload that a later one overtook leaves the later one's result in effect.
@MainActor private var lastReloadStarted = 0
/// A save that arrived before startup finished, to reload once it has.
@MainActor private var saveArrivedDuringStartup = false

@MainActor func reloadConfig(forceConfigUrl: URL? = nil) async throws -> Bool {
    var devNull = ""
    return try await reloadConfig(forceConfigUrl: forceConfigUrl, stdout: &devNull)
}

/// Reloads after a save. It is the same reload `reload-config` runs.
@MainActor func reloadConfigAfterFileChange() async {
    guard isWinMuxRuntimeReady else {
        saveArrivedDuringStartup = true
        return
    }
    guard let token: RunSessionGuard = .isServerEnabled else { return }
    // Loading with no config file would put the shipped defaults in effect. A file that is moved
    // away or briefly removed, as by a checkout, should not do that.
    guard FileManager.default.fileExists(atPath: preferredEditableConfigUrl().path) else {
        configLog.notice("The config file is gone, so the config in effect stays")
        return
    }
    do {
        _ = try await runLightSession(.configAutoReload, token) {
            var devNull = ""
            return try await reloadConfig(trigger: .fileChange, stdout: &devNull)
        }
    } catch {
        configLog.error("A reload after a save failed: \(error.localizedDescription, privacy: .public)")
    }
}

/// Reloads for a save that arrived while WinMux was starting.
@MainActor func reloadConfigIfSavedDuringStartup() async {
    if !saveArrivedDuringStartup { return }
    saveArrivedDuringStartup = false
    await reloadConfigAfterFileChange()
}

@MainActor func reloadConfig(
    args: ReloadConfigCmdArgs = ReloadConfigCmdArgs(rawArgs: []),
    forceConfigUrl: URL? = nil,
    trigger: ConfigReloadTrigger = .command,
    stdout: inout String,
) async throws -> Bool {
    // A dry run changes nothing, so it neither overtakes a reload nor is overtaken.
    if !args.dryRun { lastReloadStarted += 1 }
    let thisReload = lastReloadStarted
    let read = await readConfig(forceConfigUrl: forceConfigUrl)
    if thisReload != lastReloadStarted && !args.dryRun {
        // A later reload started while this one was loading, and its result is the newer one.
        if case .success(let loaded) = read { NickelSupervisor.shared.discard(loaded.helper) }
        stdout.append("A later reload replaced this one")
        return false
    }
    var outcome = ConfigLoadOutcome.failed
    // Even when applying the config throws, its helper is in effect and its files are the ones to
    // watch.
    defer {
        if !args.dryRun { syncConfigFileWatcher(after: outcome) }
    }
    func reportFailure(_ msg: String) {
        stdout.append(msg)
        if !args.dryRun {
            NickelSupervisor.shared.recordFailedReload(msg)
            configLog.error("The config failed to load: \(msg, privacy: .public)")
        }
        if !args.noGui && configReloadNotifications.shouldNotify(msg, trigger: trigger) {
            Task { @MainActor in
                MessageModel.shared.message = Message(description: "WinMux Config Error", body: msg)
            }
        }
    }
    switch read {
        case .success(let loaded):
            if args.dryRun {
                NickelSupervisor.shared.discard(loaded.helper)
                return true
            }
            // The settings and the helper that holds the config's functions change together.
            NickelSupervisor.shared.adopt(loaded.helper)
            outcome = .loaded(imports: loaded.helper.imports, library: loaded.helper.library)
            do {
                try await applyConfig(loaded.config, url: loaded.url)
            } catch {
                reportFailure("Loaded \(loaded.url.path), but applying it failed: \(error.localizedDescription)")
                throw error
            }
            MessageModel.shared.message = nil
            configReloadNotifications.loaded()
            configLog.notice("Loaded the config from \(loaded.url.path, privacy: .public)")
            return true
        case .failure(let msg):
            reportFailure(msg)
            return false
    }
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
