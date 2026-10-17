import Common
import os

@MainActor var startupWindowFrames: [UInt32: Rect] = [:]
/// Open from launch until startup's discovery session ends, closed even when startup throws.
@MainActor var isRecordingStartupWindowFrames = true
let quitFramesLog = Logger(subsystem: winMuxAppId, category: "quit-frames")

@MainActor
func recordStartupWindowFrame(_ windowId: UInt32, rect: Rect?, atStartup: Bool, isPopup: Bool) {
    guard atStartup, !isPopup, let rect, startupWindowFrames[windowId] == nil else { return }
    startupWindowFrames[windowId] = rect
    quitFramesLog.info("Recorded startup frame window=\(windowId) x=\(rect.topLeftX) y=\(rect.topLeftY) width=\(rect.width) height=\(rect.height)")
}
