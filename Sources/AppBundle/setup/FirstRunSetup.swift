import AppKit
import Common
import SwiftUI

@MainActor
final class FirstRunSetup: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = FirstRunSetup(readGrants: {
        PermissionGrants(accessibility: AXIsProcessTrusted(), screenRecording: CGPreflightScreenCaptureAccess())
    }, probeScreenRecording: { await runPermissionProcess("--permission-probe-screen-recording") })

    private let readGrants: () -> PermissionGrants
    private let probeScreenRecording: () async -> Bool
    private let stateUrl: URL
    private let present: ((FirstRunSetup) -> Void)?
    private var freshScreenGrant = false
    private var state = FirstRunState()
    private var continuation: CheckedContinuation<Void, Never>?
    private var window: NSWindow?
    private var previousActivationPolicy: NSApplication.ActivationPolicy?
    @Published private(set) var snapshot = PermissionGrants(accessibility: false, screenRecording: false)
    @Published private(set) var screenRequested = false
    @Published private(set) var error: String?
    var waiting = false

    init(readGrants: @escaping () -> PermissionGrants, stateUrl: URL = firstRunStateUrl(), present: ((FirstRunSetup) -> Void)? = nil,
         probeScreenRecording: @escaping () async -> Bool = { false }) {
        self.readGrants = readGrants
        self.probeScreenRecording = probeScreenRecording
        self.stateUrl = stateUrl
        self.present = present
    }

    private var grants: PermissionGrants {
        var value = readGrants()
        value.screenRecordingAfterRelaunch = value.screenRecordingAfterRelaunch || freshScreenGrant
        return value
    }

    var step: FirstRunStep { firstRunStep(grants: grants, state: state, screenRecordingRequested: screenRequested) }

    func refreshPermissions() async {
        if !readGrants().screenRecording { freshScreenGrant = await probeScreenRecording() }
        snapshot = grants
    }

    var permissions: SetupPermissions {
        let value = grants
        let screenRecording: String
        if value.screenRecording {
            screenRecording = "granted"
        } else if value.screenRecordingAfterRelaunch {
            screenRecording = "granted-relaunch-needed"
        } else {
            screenRecording = "missing"
        }
        let setup: String
        if !waiting {
            setup = "done"
        } else {
            switch firstRunStep(grants: value, state: state, screenRecordingRequested: screenRequested) {
                case .done, .go: setup = "waiting-for-go"
                case .permissions, .relaunch: setup = "waiting-for-permissions"
            }
        }
        return SetupPermissions(
            accessibility: value.accessibility ? "granted" : "missing",
            screenRecording: screenRecording,
            setup: setup,
        )
    }

    var refusal: String? {
        guard waiting else { return nil }
        let value = grants
        if !value.accessibility {
            return "WinMux is waiting for Accessibility (System Settings › Privacy & Security › Accessibility). Its setup window shows what to do."
        }
        if !value.screenRecording && !value.screenRecordingAfterRelaunch && !state.screenRecordingDeclined {
            return "WinMux is waiting for Screen Recording (System Settings › Privacy & Security › Screen Recording). Its setup window shows what to do."
        }
        if firstRunStep(grants: value, state: state, screenRecordingRequested: screenRequested) == .relaunch {
            return "WinMux is waiting for a relaunch to finish Screen Recording setup. Its setup window has a Relaunch WinMux button."
        }
        return "WinMux is waiting for the person to start it in its setup window."
    }

    func answerBeforeStartup(_ command: any Command) async -> CmdResult? {
        if waiting, let command = command as? ConfigCommand, case .status = command.args.mode {
            await refreshPermissions()
        }
        guard let refusal else { return nil }
        if let command = command as? ConfigCommand {
            switch command.args.mode {
                case .getKey, .majorKeys, .allKeys, .configPath, .status:
                    let io = CmdIo(stdin: .emptyStdin)
                    let success = command.run(.defaultEnv, io, permissions: { self.permissions })
                    return CmdResult(stdout: io.stdout, stderr: io.stderr, exitCode: success ? 0 : 1)
                case .check, .convert, .schema: break
            }
        }
        return CmdResult(stdout: [], stderr: [refusal], exitCode: 1)
    }

    func run() async {
        state = readFirstRunState(from: stateUrl)
        snapshot = grants
        guard step != .done else { return }
        state.pending = true
        save()
        waiting = true
        await withCheckedContinuation {
            continuation = $0
            if let present { present(self) } else { showWindow() }
        }
    }

    private func showWindow() {
        previousActivationPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: FirstRunView.contentSize), styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "WinMux Setup"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: FirstRunView(model: self))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
        Task { @MainActor in
            while waiting {
                await refreshPermissions()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { false }

    func requestAccessibility() {
        enqueueSetupPermissionRequest(request: {
            _ = await runPermissionProcess("--permission-request-accessibility")
        }, openSettings: {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        })
    }

    func requestScreenRecording() {
        screenRequested = true
        enqueueSetupPermissionRequest(request: {
            _ = CGRequestScreenCaptureAccess()
        }, openSettings: {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        })
    }

    func continueWithoutScreenRecording() {
        guard grants.accessibility else { return }
        state.screenRecordingDeclined = true
        _ = save()
        snapshot = grants
    }

    func go() {
        guard step == .go else { return }
        state.pending = false
        guard save() else { state.pending = true; return }
        waiting = false
        window?.orderOut(nil)
        window = nil
        if let previousActivationPolicy { NSApp.setActivationPolicy(previousActivationPolicy) }
        continuation?.resume()
        continuation = nil
    }

    @discardableResult private func save() -> Bool {
        do {
            try writeFirstRunState(state, to: stateUrl)
            error = nil
            return true
        } catch {
            self.error = "Could not save setup: \(error.localizedDescription)"
            return false
        }
    }

    func relaunch() {
        Task { @MainActor in
            do {
                try await relaunchFirstRunApplication(
                    bundleURL: Bundle.main.bundleURL,
                    executableURL: URL(filePath: CommandLine.arguments[0]),
                    arguments: Array(CommandLine.arguments.dropFirst()),
                    environment: ProcessInfo.processInfo.environment,
                )
            } catch {
                self.error = "Could not relaunch WinMux: \(error.localizedDescription)"
            }
        }
    }
}

@MainActor
func enqueueSetupPermissionRequest(request: @escaping @MainActor () async -> Void, openSettings: @escaping @MainActor () -> Void) {
    DispatchQueue.main.async(execute: DispatchWorkItem(flags: .detached) {
        Task { @MainActor in
            await request()
            openSettings()
        }
    })
}

private func runPermissionProcess(_ argument: String) async -> Bool {
    await withCheckedContinuation { continuation in
        let child = Process()
        child.executableURL = URL(filePath: CommandLine.arguments[0])
        child.arguments = [argument]
        child.environment = ProcessInfo.processInfo.environment
        child.standardOutput = FileHandle.nullDevice
        child.standardError = FileHandle.nullDevice
        child.terminationHandler = { process in continuation.resume(returning: process.terminationStatus == 0) }
        do { try child.run() }
        catch { continuation.resume(returning: false); return }
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            if child.isRunning { child.terminate() }
        }
    }
}
