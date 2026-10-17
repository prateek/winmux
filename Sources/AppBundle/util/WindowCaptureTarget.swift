import Foundation
import CoreGraphics

typealias WindowImageCapture = @Sendable (WindowCaptureTarget, CGSize) async throws -> CGImage

struct WindowCaptureTarget: Equatable, Sendable {
    let id: UInt32
    let ownerPID: Int32?
    let actualFrame: CGRect?

    init(id: UInt32, ownerPID: Int32? = nil, actualFrame: CGRect? = nil) {
        self.id = id
        self.ownerPID = ownerPID
        self.actualFrame = actualFrame
    }
}

struct WindowCaptureCandidate: Sendable {
    let id: UInt32
    let ownerPID: Int32?
    let frame: CGRect
    let layer: Int
    let onScreen: Bool
}

func chooseWindowToCapture(_ target: WindowCaptureTarget, from candidates: [WindowCaptureCandidate]) -> UInt32? {
    let own = candidates.first { $0.id == target.id }
    guard let actual = target.actualFrame, actual.width > 0, actual.height > 0, let pid = target.ownerPID else {
        return own?.id
    }
    // Any layer: an app's real dialog can sit above layer 0. Only a sliver of the entry's
    // frame, such as Safari's 16-point strip, is not the window the entry stands for.
    if let own, own.frame.width >= actual.width / 4, own.frame.height >= actual.height / 4 {
        return own.ownerPID == nil || own.ownerPID == pid ? own.id : nil
    }
    // Parked windows are capturable too. On-screen state must not decide their identity.
    let matches = candidates.filter {
        $0.id != target.id && $0.ownerPID == pid && $0.layer == 0 &&
            abs($0.frame.minX - actual.minX) <= 2 && abs($0.frame.minY - actual.minY) <= 2 &&
            abs($0.frame.width - actual.width) <= 2 && abs($0.frame.height - actual.height) <= 2
    }
    return matches.count == 1 ? matches[0].id : nil
}

extension Window {
    @MainActor var captureTarget: WindowCaptureTarget {
        WindowCaptureTarget(id: windowId, ownerPID: app.pid, actualFrame: lastKnownActualRect?.cgRect)
    }
}
