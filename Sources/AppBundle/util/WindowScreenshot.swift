import AppKit
import ScreenCaptureKit

/// One-shot capture of a single window. Requires the Screen Recording grant.
@MainActor
enum WindowScreenshot {
    // SCContentFilter takes an SCWindow, and listing them costs about 30 ms, so the list is
    // kept between captures and fetched again only for a window id it doesn't have.
    private static var shareableWindows: [CGWindowID: SCWindow] = [:]

    /// - Parameter pixelSize: Size of the returned image. The window's size in points gives one pixel per point.
    static func capture(_ windowId: CGWindowID, pixelSize: CGSize) async -> CGImage? {
        guard let window = await shareableWindow(windowId) else { return nil }
        let configuration = SCScreenshotConfiguration()
        configuration.width = Int(pixelSize.width.rounded(.up))
        configuration.height = Int(pixelSize.height.rounded(.up))
        configuration.showsCursor = false
        configuration.ignoreShadows = true
        configuration.includeChildWindows = false
        configuration.dynamicRange = .sdr
        do {
            return try await SCScreenshotManager.captureScreenshot(
                contentFilter: SCContentFilter(desktopIndependentWindow: window),
                configuration: configuration,
            ).sdrImage
        } catch {
            // The window may have closed since it was listed
            shareableWindows[windowId] = nil
            return nil
        }
    }

    private static func shareableWindow(_ windowId: CGWindowID) async -> SCWindow? {
        if let window = shareableWindows[windowId] { return window }
        guard let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false) else {
            return nil
        }
        shareableWindows = Dictionary(content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
        return shareableWindows[windowId]
    }
}
