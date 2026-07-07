import AppKit
import Common

struct DoctorCommand: Command {
    let args: DoctorCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        if args.subject == .zones, args.supportBundle {
            do {
                let bundle = try await writeSupportBundle(options: SupportBundleOptions(
                    outputPath: resolvedOutputPath(args.outputPath, clientCurrentDirectory: env.clientCurrentDirectory),
                    includeWindowTitles: args.includeWindowTitles,
                ))
                io.out("Support bundle: \(bundle.directory.path)")
                io.out("Redaction: usernames, home paths, app identifiers, and window titles are redacted by default")
                io.out("Files: \(bundle.files.joined(separator: ", "))")
                return true
            } catch {
                return io.err("Can't write support bundle: \(error.localizedDescription)")
            }
        }

        io.out("WinMux doctor — git \(gitShortHash)")
        io.out("")

        io.out("Install:")
        io.out("  app path: \(Bundle.main.bundlePath)")
        io.out("  executable: \(Bundle.main.executablePath ?? "unknown")")
        io.out("  config path: \(configUrl.absoluteURL.path)")
        io.out("")

        let configText: String?
        let configReadError: String?
        do {
            configText = try String(contentsOf: configUrl, encoding: .utf8)
            configReadError = nil
        } catch {
            configText = nil
            configReadError = error.localizedDescription
        }
        for line in renderConfigDoctorLines(
            configPath: configUrl.absoluteURL.path,
            configText: configText,
            readError: configReadError,
            runtimeOverlays: columnRuntimeOverlaysSnapshot(),
        ) {
            io.out(line)
        }
        io.out("")

        io.out("Permissions:")
        io.out("  accessibility: \(permissionStatus(AXIsProcessTrusted(), missing: "MISSING (required)"))")
        io.out("  screen recording: \(permissionStatus(CGPreflightScreenCaptureAccess(), missing: "missing (tab previews / radius estimation degraded)"))")
        io.out("  automation: macOS-managed; use System Settings > Privacy & Security > Automation when Apple Events are blocked")
        io.out("  input monitoring: macOS-managed; needed for global mouse/keyboard capture")
        io.out("")

        io.out("Permission recovery:")
        io.out("  accessibility reset: tccutil reset Accessibility com.zimengxiong.winmux")
        io.out("  screen recording reset: tccutil reset ScreenCapture com.zimengxiong.winmux")
        io.out("  automation reset: tccutil reset AppleEvents com.zimengxiong.winmux")
        io.out("  input monitoring reset: tccutil reset ListenEvent com.zimengxiong.winmux")
        io.out("")

        io.out("Monitors (system window corner radius: \(systemWindowCornerRadius())pt):")
        for monitor in sortedMonitors {
            let active = monitor.activeWorkspace.name
            io.out("  [\(monitor.monitorAppKitNsScreenScreensId)] \(monitor.name) \(Int(monitor.rect.width))x\(Int(monitor.rect.height))\(monitor.isMain ? " (main)" : "") activeWorkspace=\(active)")
        }
        io.out("")

        let workspaces = Workspace.all
        io.out("State: \(workspaces.count) workspaces, \(MacWindow.allWindows.count) windows, focus=\(focus.windowOrNil?.windowId.description ?? "none") (workspace \(focus.workspace.name))")
        io.out("")

        // Per-app AX latency: time a trivial round-trip to each app's AX thread. Apps near the
        // 1s messaging timeout are the ones that make the whole system feel slow.
        io.out("Per-app AX latency (slowest first):")
        var rows: [(name: String, ms: Double, windows: Int, benched: Bool)] = []
        for (_, app) in MacApp.allAppsMap {
            let name = app.nsApp.localizedName ?? app.rawAppBundleId ?? String(app.pid)
            let start = ContinuousClock.now
            let windowCount = (try? await app.getAxWindowsCount()) ?? -1
            let elapsed = start.duration(to: ContinuousClock.now)
            let ms = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
            let benched = app.slowAxPenaltyUntil.map { ContinuousClock.now < $0 } ?? false
            rows.append((name, ms, windowCount, benched))
        }
        for row in rows.sorted(by: { $0.ms > $1.ms }) {
            let flag = row.ms > 100 ? "  <-- SLOW" : ""
            let benched = row.benched ? "  [benched: refresh over budget, serving cached windows]" : ""
            let windows = row.windows >= 0 ? "\(row.windows)" : "error"
            io.out("  \(String(format: "%7.1f", row.ms))ms  \(row.name) (\(windows) ax windows)\(flag)\(benched)")
        }
        return true
    }

    private func permissionStatus(_ granted: Bool, missing: String) -> String {
        granted ? "granted" : missing
    }

    private func resolvedOutputPath(_ outputPath: String?, clientCurrentDirectory: String?) -> String? {
        guard let outputPath else { return nil }
        let expandedPath = (outputPath as NSString).expandingTildeInPath
        if expandedPath.hasPrefix("/") {
            return URL(fileURLWithPath: expandedPath).standardizedFileURL.path
        }

        let baseDirectory = clientCurrentDirectory ?? FileManager.default.currentDirectoryPath
        return URL(
            fileURLWithPath: expandedPath,
            relativeTo: URL(fileURLWithPath: baseDirectory, isDirectory: true),
        )
        .standardizedFileURL
        .path
    }
}
