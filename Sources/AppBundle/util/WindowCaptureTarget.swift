import Foundation
import CoreGraphics

typealias WindowImageCapture = @Sendable (WindowCaptureTarget, CGSize) async throws -> CGImage

struct WindowCaptureTarget: Equatable, Sendable {
    let id: UInt32
    let ownerPID: Int32?
    /// Where the entry's window is, in top-left global points: its last known actual frame, or
    /// the frame its picture is sized from when that is unknown.
    let entryFrame: CGRect?

    init(id: UInt32, ownerPID: Int32? = nil, entryFrame: CGRect? = nil) {
        self.id = id
        self.ownerPID = ownerPID
        self.entryFrame = entryFrame
    }
}

struct WindowCaptureCandidate: Sendable {
    let id: UInt32
    let ownerPID: Int32?
    let frame: CGRect
    let layer: Int
}

/// The entry's own window, unless it is a sliver, such as Safari's 16-point strip. Then the one layer-0 window of the same app that matches the entry's frame within two
/// points, or none. A missing id has no fallback.
func chooseWindowToCapture(_ target: WindowCaptureTarget, from candidates: [WindowCaptureCandidate]) -> UInt32? {
    guard let own = candidates.first(where: { $0.id == target.id }) else { return nil }
    guard isSliver(own.frame, of: target.entryFrame), let frame = target.entryFrame else { return own.id }
    guard let pid = target.ownerPID else { return nil }
    let matches = candidates.filter {
        $0.id != own.id && $0.ownerPID == pid && $0.layer == 0 &&
            abs($0.frame.minX - frame.minX) <= 2 && abs($0.frame.minY - frame.minY) <= 2 &&
            abs($0.frame.width - frame.width) <= 2 && abs($0.frame.height - frame.height) <= 2
    }
    return matches.count == 1 ? matches[0].id : nil
}

/// Under 40 points and under a quarter of the entry's frame on the same side. The entry frame is
/// often a layout the app does not honour, so the quarter alone would catch a window that keeps a
/// fixed size in a wide tile; no window drawn for reading is 40 points thin.
func isSliver(_ frame: CGRect, of entryFrame: CGRect?) -> Bool {
    guard let entryFrame, entryFrame.width > 0, entryFrame.height > 0 else { return false }
    return frame.width < min(40, entryFrame.width / 4) || frame.height < min(40, entryFrame.height / 4)
}

/// The cached list answers when it shows the entry's own window whole. A sliver is checked again on
/// a fresh list, since cached frames go stale as windows move, and only the fresh list may choose
/// another window. A capture limited to the cached list fails on a missing id.
func resolveWindowToCapture(_ target: WindowCaptureTarget, cachedOwn: WindowCaptureCandidate?, cachedOnly: Bool,
                            fresh: () async throws -> [WindowCaptureCandidate]) async rethrows -> UInt32? {
    if let cachedOwn, !isSliver(cachedOwn.frame, of: target.entryFrame) { return cachedOwn.id }
    if cachedOwn == nil, cachedOnly { return nil }
    return chooseWindowToCapture(target, from: try await fresh())
}

extension Window {
    @MainActor var captureTarget: WindowCaptureTarget {
        // A move or resize clears the actual frame, so a tiled window usually has only its layout.
        WindowCaptureTarget(id: windowId, ownerPID: app.pid, entryFrame: lastKnownActualRect?.cgRect ?? thumbnailCaptureFrame(self))
    }
}
