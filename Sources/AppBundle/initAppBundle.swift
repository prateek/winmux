import AppKit
import Common
import Foundation

@MainActor public func initAppBundle() {
    Task {
        traceE2EStartup("initAppBundle task started")
        initTerminationHandler()
        traceE2EStartup("termination handler initialized")
        isCli = false
        initServerArgs()
        traceE2EStartup("server args initialized")
        var bootstrappedConfigUrl: URL? = nil
        if isDebug {
            traceE2EStartup("debug release-server toggle off started")
            await toggleReleaseServerIfDebug(.off)
            traceE2EStartup("debug release-server toggle off finished")
            interceptTermination(SIGINT)
            interceptTermination(SIGKILL)
        }
        do {
            traceE2EStartup("bootstrap config check started")
            bootstrappedConfigUrl = try ensureBootstrapConfigExistsIfNeeded()
            traceE2EStartup("bootstrap config check finished")
        } catch {
            MessageModel.shared.message = Message(
                description: "Config Bootstrap Error",
                body: error.localizedDescription,
            )
            traceE2EStartup("bootstrap config check failed: \(error.localizedDescription)")
        }
        traceE2EStartup("config reload started")
        if try await !reloadConfig(forceConfigUrl: bootstrappedConfigUrl) {
            var out = ""
            check(
                try await reloadConfig(forceConfigUrl: defaultConfigUrl, stdout: &out),
                """
                Can't load default config. Your installation is probably corrupted.
                Please don't modify '\(defaultConfigUrl)'

                \(out)
                """,
            )
        }
        traceE2EStartup("config reload finished")
        MonitorConfigurationObserver.shared.prepareForStartup()

        traceE2EStartup("accessibility permission check started")
        checkAccessibilityPermissions()
        traceE2EStartup("accessibility permission check finished")
        traceE2EStartup("screen recording permission check started")
        requestScreenRecordingPermissionsIfNeeded()
        traceE2EStartup("screen recording permission check finished")
        traceE2EStartup("unix socket server start requested")
        startUnixSocketServer()
        traceE2EStartup("unix socket server started")
        GlobalObserver.initObserver()
        MonitorConfigurationObserver.shared.startObserving()
        Workspace.reconcileWorkspaceState() // init workspaces
        _ = Workspace.all.first?.focusWorkspace()
        let didLoadPersistedFrozenWorld = loadPersistedFrozenWorldForStartupIfPresent()
        traceE2EStartup("startup refresh started")
        try await runRefreshSessionBlocking(.startup, layoutWorkspaces: false)
        traceE2EStartup("startup refresh finished")
        try await runLightSession(.startup, .forceRun) {
            if !didLoadPersistedFrozenWorld {
                smartLayoutAtStartup()
            }
            _ = try await config.afterStartupCommand.runCmdSeq(.defaultEnv, .emptyStdin)
        }
        traceE2EStartup("startup light session finished")
        if bootstrappedConfigUrl != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                ShortcutSettingsModel.shared.requestWindowOpen()
            }
        }
        traceE2EStartup("initAppBundle task finished")
    }
}

private func traceE2EStartup(_ event: String) {
    guard let path = ProcessInfo.processInfo.environment["WINMUX_E2E_STARTUP_TRACE"], !path.isEmpty else { return }
    let url = URL(filePath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let line = "\(Date.now.ISO8601Format()) \(event)\n"
    guard let data = line.data(using: .utf8) else { return }
    if !FileManager.default.fileExists(atPath: url.path) {
        FileManager.default.createFile(atPath: url.path, contents: nil)
    }
    guard let handle = try? FileHandle(forWritingTo: url) else { return }
    defer { try? handle.close() }
    _ = try? handle.seekToEnd()
    try? handle.write(contentsOf: data)
}

@MainActor
private func smartLayoutAtStartup() {
    let workspace = focus.workspace
    let root = workspace.rootTilingContainer
    if root.children.count <= 3 {
        root.layout = .tiles
    } else {
        root.layout = .tabGroup
    }
}

@TaskLocal
var _isStartup: Bool? = false
var isStartup: Bool { _isStartup ?? dieT("isStartup is not initialized") }

struct ServerArgs: Sendable {
    var configLocation: String? = nil
    var isReadOnly: Bool = false
}

private let serverHelp = """
    USAGE: \(CommandLine.arguments.first ?? "WinMux.app/Contents/MacOS/WinMux") [<options>]

    OPTIONS:
      -h, --help              Print help
      -v, --version           Print WinMux.app version
      --config-path <path>    Config path. It will take priority over ~/.config/winmux/winmux.toml,
                              ~/.winmux.toml and ${XDG_CONFIG_HOME}/winmux/winmux.toml
      --read-only             Run without mutating macOS windows.
                              Useful if you want to use only debug-windows or other query commands.
    """

nonisolated(unsafe) private var _serverArgs = ServerArgs()
var serverArgs: ServerArgs { _serverArgs }
private func initServerArgs() {
    let args = CommandLine.arguments.slice(1...) ?? []
    if args.contains(where: { $0 == "-h" || $0 == "--help" }) {
        exit(0, out: serverHelp)
    }
    var index = 0
    while index < args.count {
        let current = args[index]
        index += 1
        switch current {
            case "--version", "-v":
                exit(0, out: "\(winMuxAppVersion) \(gitHash)")
            case "--config-path":
                if let arg = args.getOrNil(atIndex: index) {
                    _serverArgs.configLocation = arg
                } else {
                    exit(1, err: "Missing <path> in --config-path flag")
                }
                index += 1
            case "--read-only": // todo rename to '--disabled' and unite with disabled feature
                _serverArgs.isReadOnly = true
            case "-NSDocumentRevisionsDebugMode" where isDebug:
                // Skip Xcode CLI args.
                // Usually it's '-NSDocumentRevisionsDebugMode NO'/'-NSDocumentRevisionsDebugMode YES'
                while args.getOrNil(atIndex: index)?.starts(with: "-") == false { index += 1 }
            default:
                exit(1, err: "Unrecognized flag '\(args.first.orDie())'")
        }
    }
    if let path = serverArgs.configLocation, !FileManager.default.fileExists(atPath: path) {
        exit(1, err: "\(path) doesn't exist")
    }
}
