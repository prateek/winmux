import AppKit
import ScreenCaptureKit

enum WindowScreenshotError: LocalizedError {
    case screenRecordingNotGranted
    case windowNotFound(CGWindowID)
    case captureFailed(String)

    var errorDescription: String? {
        switch self {
            case .screenRecordingNotGranted:
                "Capturing a window needs the Screen Recording permission. Grant it to this app, or to the terminal it runs in, under System Settings > Privacy & Security."
            case .windowNotFound(let id):
                "No window with id \(id) can be captured."
            case .captureFailed(let reason):
                "ScreenCaptureKit could not capture the window: \(reason)"
        }
    }
}

@globalActor
actor ScreenshotWorker { static let shared = ScreenshotWorker() }

/// One-shot captures through ScreenCaptureKit. They need the Screen Recording grant, even for a
/// window of this process.
@ScreenshotWorker
enum WindowScreenshot {
    // Listing shareable content costs about 30 ms; Lens captures use only this cached list.
    private static let snapshot = RefreshingSnapshot<SCShareableContent> {
        try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
    }
    private static var content: SCShareableContent? { snapshot.value }

    nonisolated static func invalidateWindowList() {
        Task { @ScreenshotWorker in
            snapshot.invalidate()
            guard CGPreflightScreenCaptureAccess() else { return }
            await refreshWindowList()
        }
    }

    /// - Parameter pixelSize: Size of the returned image. `nil` gives one pixel per point of the
    ///   window's own size.
    static func capture(_ windowId: CGWindowID, pixelSize: CGSize? = nil, cachedOnly: Bool = false) async throws -> CGImage {
        let window: SCWindow
        if cachedOnly {
            guard let cached = content?.windows.first(where: { $0.windowID == windowId }) else { throw WindowScreenshotError.windowNotFound(windowId) }
            window = cached
        } else { window = try await shareableWindow(windowId) }
        let configuration = baseConfiguration()
        if let pixelSize {
            configuration.width = Int(pixelSize.width.rounded(.up))
            configuration.height = Int(pixelSize.height.rounded(.up))
        }
        configuration.ignoreShadows = true
        configuration.includeChildWindows = false
        return try await screenshot(SCContentFilter(desktopIndependentWindow: window), configuration)
    }

    /// What the screen shows in `rect` with the given windows left out, at one pixel per point.
    /// - Parameter rect: In global display coordinates, origin at the top left of the main display.
    static func captureScreen(_ rect: CGRect, excluding windowIds: [CGWindowID]) async throws -> CGImage {
        var excluded: [SCWindow] = []
        for id in windowIds {
            excluded.append(try await shareableWindow(id))
        }
        guard let display = content?.displays.first(where: { $0.frame.contains(CGPoint(x: rect.midX, y: rect.midY)) }) else {
            throw WindowScreenshotError.captureFailed("no display contains the requested area")
        }
        let configuration = baseConfiguration()
        configuration.sourceRect = rect.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
        configuration.width = Int(rect.width.rounded(.up))
        configuration.height = Int(rect.height.rounded(.up))
        return try await screenshot(SCContentFilter(display: display, excludingWindows: excluded), configuration)
    }

    private static func baseConfiguration() -> SCScreenshotConfiguration {
        let configuration = SCScreenshotConfiguration()
        configuration.showsCursor = false
        configuration.dynamicRange = .sdr
        return configuration
    }

    private static func screenshot(_ filter: SCContentFilter, _ configuration: SCScreenshotConfiguration) async throws -> CGImage {
        let output: SCScreenshotOutput
        do {
            output = try await SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: configuration)
        } catch {
            throw WindowScreenshotError.captureFailed(error.localizedDescription)
        }
        guard let image = output.sdrImage else {
            throw WindowScreenshotError.captureFailed("no image was returned")
        }
        return image
    }

    private static func shareableWindow(_ windowId: CGWindowID) async throws -> SCWindow {
        if let window = content?.windows.first(where: { $0.windowID == windowId }) { return window }
        guard CGPreflightScreenCaptureAccess() else { throw WindowScreenshotError.screenRecordingNotGranted }
        await refreshWindowList()
        guard let content else { throw WindowScreenshotError.captureFailed("the window list is unavailable") }
        guard let window = content.windows.first(where: { $0.windowID == windowId }) else {
            throw WindowScreenshotError.windowNotFound(windowId)
        }
        return window
    }

    private static func refreshWindowList() async {
        await snapshot.refresh()
    }
}
