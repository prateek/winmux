import AppKit
import Foundation

@MainActor
func relaunchFirstRunApplication(
    bundleURL: URL,
    executableURL: URL,
    arguments: [String],
    environment: [String: String],
    openBundle: @MainActor (URL, NSWorkspace.OpenConfiguration) async throws -> Void = { url, options in
        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: options)
    },
    runExecutable: @MainActor (URL, [String], [String: String]) throws -> Void = { url, arguments, environment in
        let child = Process()
        child.executableURL = url
        child.arguments = arguments
        child.environment = environment
        try child.run()
    },
    terminate: @MainActor () -> Void = { NSApp.terminate(nil) },
) async throws {
    guard !isRelaunchingForSetup else { return }
    isRelaunchingForSetup = true
    do {
        try await launchFirstRunReplacement(bundleURL: bundleURL, executableURL: executableURL, arguments: arguments,
                                            environment: environment, openBundle: openBundle, runExecutable: runExecutable)
    } catch {
        isRelaunchingForSetup = false
        throw error
    }
    terminate()
}

@MainActor
private func launchFirstRunReplacement(
    bundleURL: URL,
    executableURL: URL,
    arguments: [String],
    environment: [String: String],
    openBundle: @MainActor (URL, NSWorkspace.OpenConfiguration) async throws -> Void,
    runExecutable: @MainActor (URL, [String], [String: String]) throws -> Void,
) async throws {
    if bundleURL.pathExtension == "app" {
        let options = NSWorkspace.OpenConfiguration()
        options.createsNewApplicationInstance = true
        options.arguments = arguments
        options.environment = environment
        try await openBundle(bundleURL, options)
    } else {
        try runExecutable(executableURL, arguments, environment)
    }
}
