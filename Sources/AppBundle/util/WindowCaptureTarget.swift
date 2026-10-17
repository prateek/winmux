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

/// The entry's own window, unless it is a sliver of the entry's frame, such as Safari's 16-point
/// strip. Then the one layer-0 window of the same app that matches the entry's frame within two
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

func isSliver(_ frame: CGRect, of entryFrame: CGRect?) -> Bool {
    guard let entryFrame, entryFrame.width > 0, entryFrame.height > 0 else { return false }
    return frame.width < entryFrame.width / 4 || frame.height < entryFrame.height / 4
}

extension Window {
    @MainActor var captureTarget: WindowCaptureTarget {
        // A move or resize clears the actual frame, so a tiled window usually has only its layout.
        WindowCaptureTarget(id: windowId, ownerPID: app.pid, entryFrame: lastKnownActualRect?.cgRect ?? thumbnailCaptureFrame(self))
    }
}
