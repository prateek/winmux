import Foundation

@MainActor
final class LensSessionStatistics {
    typealias Tick = (Double, Double) -> Void
    typealias TickSource = (@escaping Tick) -> (() -> Void)

    private let stamp: () -> Double
    private var startedAt: Double?
    private var stoppedAt: Double?
    private var stopFrames: (() -> Void)?
    private var previousFrame: Double?
    private(set) var capturesRequested = 0
    private(set) var capturesCompleted = 0
    private(set) var droppedFrames: Int?
    private(set) var longestFrameIntervalMs: Double?

    init(stamp: @escaping () -> Double) { self.stamp = stamp }

    private var stopped: Bool { stoppedAt != nil }

    var presentedMs: Double {
        guard let startedAt else { return 0 }
        return max(0, (stoppedAt ?? stamp()) - startedAt) * 1000
    }
    func presented() {
        guard !stopped, startedAt == nil else { return }
        startedAt = stamp()
    }
    func requestedCapture() {
        guard startedAt != nil, !stopped else { return }
        capturesRequested += 1
    }
    func completedCapture() {
        guard startedAt != nil, !stopped else { return }
        capturesCompleted += 1
    }
    func observeFrames(enabled: Bool = true, using source: TickSource) {
        guard enabled, startedAt != nil, !stopped, stopFrames == nil else { return }
        droppedFrames = 0
        longestFrameIntervalMs = 0
        stopFrames = source { [weak self] timestamp, refresh in
            guard let self, !self.stopped, timestamp.isFinite, refresh.isFinite, refresh > 0 else { return }
            guard let previous = self.previousFrame else { self.previousFrame = timestamp; return }
            guard timestamp > previous else { return }
            self.previousFrame = timestamp
            let interval = timestamp - previous
            self.longestFrameIntervalMs = max(self.longestFrameIntervalMs ?? 0, interval * 1000)
            if interval > refresh * 1.5 { self.droppedFrames? += 1 }
        }
    }
    func stop() {
        guard !stopped else { return }
        stoppedAt = stamp()
        stopFrames?()
        stopFrames = nil
    }
}
