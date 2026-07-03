import Foundation

/// Sparkle links into the WinMuxApp executable only (the CLI shares AppBundle and must not
/// require the framework at launch), so the app wires its updater in through this seam at
/// startup. When the closures are unset (CLI, tests, xcode builds without the package) the
/// menu item is hidden and config changes are no-ops.
@MainActor
public final class UpdaterBridge {
    public static let shared = UpdaterBridge()
    private init() {}

    public var checkForUpdates: (() -> Void)?
    public var setAutomaticChecksEnabled: ((Bool) -> Void)?

    public func applyConfig() {
        setAutomaticChecksEnabled?(config.updates.automaticCheck)
    }
}
