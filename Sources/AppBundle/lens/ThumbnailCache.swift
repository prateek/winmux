import AppKit
import Common

@MainActor
final class WindowThumbnail: ObservableObject {
    @Published private(set) var image: CGImage?
    private(set) var capturedAt: Date?

    func accept(_ image: CGImage, at date: Date = Date()) {
        self.image = image
        capturedAt = date
    }
    func clear() { image = nil; capturedAt = nil }
}

@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private var gate = ThumbnailCaptureGate()
    private var idleWaiters: [CheckedContinuation<Void, Never>] = []
    private var windows: [UInt32: WeakWindow] = [:]
    private struct CaptureWaiter {
        let size: CGSize
        let continuation: CheckedContinuation<Void, Never>
        let timeout: Task<Void, Never>
    }
    private var captureWaiters: [UInt32: [UUID: CaptureWaiter]] = [:]
    private var demands: [UInt32: [Int: CGSize]] = [:]
    private struct InFlightCapture {
        let size: CGSize
        let demand: CGSize

        func needsRecapture(size: CGSize, demand: CGSize) -> Bool {
            let targetShortfall = self.size.width < size.width || self.size.height < size.height
            let largerDemand = self.demand.width < demand.width || self.demand.height < demand.height
            let demandShortfall = self.size.width < demand.width || self.size.height < demand.height
            return targetShortfall || (largerDemand && demandShortfall)
        }
    }
    private var activeCaptures: [UInt32: InFlightCapture] = [:]
    private let scales: (CGRect) -> (CGFloat, CGFloat)
    private var nativeFocusedWindow: WeakWindow?
    private var lensStatistics: [Int: LensSessionStatistics] = [:]
    private struct WeakWindow { weak var value: Window? }
    private let capture: @Sendable (UInt32, CGSize) async throws -> CGImage
    private let now: () -> TimeInterval
    private let isHidden: (Window) -> Bool

    init(now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         isHidden: @escaping (Window) -> Bool = { ($0.app as? MacApp)?.nsApp.isHidden == true },
         scales: @escaping (CGRect) -> (CGFloat, CGFloat) = { frame in
             (NSScreen.screens.map(\.backingScaleFactor).max() ?? 2, ThumbnailCache.windowScale(frame: frame))
         },
         capture: @escaping @Sendable (UInt32, CGSize) async throws -> CGImage = { id, size in
             try await WindowScreenshot.capture(id, pixelSize: size, cachedOnly: true)
         }) {
        self.scales = scales
        self.now = now
        self.isHidden = isHidden
        self.capture = capture
    }

    func request(_ window: Window, lens: Int? = nil, demand: CGSize? = nil, force: Bool = false) {
        guard window.isBound, !isMinimized(window), !isUnitTest || self !== Self.shared else { return }
        if let lens { lensStatistics[lens]?.requestedCapture() }
        windows[window.windowId] = WeakWindow(value: window)
        let id = window.windowId
        if let lens, let demand, demand.width > 0, demand.height > 0 { demands[id, default: [:]][lens] = demand }
        let size = captureSize(window)
        let required = self.demand(id) ?? size
        let needsLarger = window.thumbnail.image.map {
            CGFloat($0.width) < required.width || CGFloat($0.height) < required.height
        } ?? true
        let recapture = activeCaptures[id]?.needsRecapture(size: size, demand: required) ?? false
        gate.enqueue(id, lens: lens, now: now(), force: force, needsLarger: needsLarger, recapture: recapture)
        pump()
    }

    private func isMinimized(_ window: Window) -> Bool {
        window.parent is MacosMinimizedWindowsContainer || window.lastKnownNativeMinimized == true
    }

    func captureBeforeMinimize(_ window: Window, timeout: Duration = .milliseconds(200)) async {
        guard !isMinimized(window), !isHidden(window), window.isBound, !isUnitTest || self !== Self.shared else { return }
        let token = UUID(), id = window.windowId
        let size = captureSize(window)
        await withCheckedContinuation { continuation in
            let deadline = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: timeout) } catch { return }
                self?.captureWaiters[id]?.removeValue(forKey: token)?.continuation.resume()
            }
            captureWaiters[id, default: [:]][token] = CaptureWaiter(size: size, continuation: continuation, timeout: deadline)
            request(window, force: true)
        }
    }

    private func completeWaiters(_ id: UInt32, size: CGSize? = nil) {
        guard let waiters = captureWaiters[id] else { return }
        for (token, waiter) in waiters {
            if let size, size.width < waiter.size.width || size.height < waiter.size.height { continue }
            captureWaiters[id]?.removeValue(forKey: token)
            waiter.timeout.cancel()
            waiter.continuation.resume()
        }
        if captureWaiters[id]?.isEmpty == true { captureWaiters.removeValue(forKey: id) }
    }

    func recordNativeFocus(_ window: Window?) {
        guard nativeFocusedWindow?.value?.windowId != window?.windowId else { return }
        if let previous = nativeFocusedWindow?.value { request(previous) }
        nativeFocusedWindow = window.map { WeakWindow(value: $0) }
    }

    func observeLens(_ lens: Int, statistics: LensSessionStatistics) { lensStatistics[lens] = statistics }
    func closeLens(_ lens: Int) {
        for id in Array(demands.keys) { demands[id]?.removeValue(forKey: lens) }
        lensStatistics.removeValue(forKey: lens)
        gate.closeLens(lens)
    }
    func closeWindow(_ window: Window) {
        if nativeFocusedWindow?.value === window { nativeFocusedWindow = nil }
        demands.removeValue(forKey: window.windowId)
        gate.closeWindow(window.windowId)
        windows.removeValue(forKey: window.windowId)
        window.thumbnail.clear()
        completeWaiters(window.windowId)
    }

    func waitUntilIdle() async {
        if gate.isIdle { return }
        await withCheckedContinuation { idleWaiters.append($0) }
    }

    /// The frame whose shape a capture takes. A floating window keeps the layout rect of the tile
    /// it last had, which nothing updates while it floats.
    nonisolated static func captureFrame(floating: Bool, layout: CGRect?, parked: CGRect?, actual: CGRect?) -> CGRect {
        (floating ? actual ?? parked : layout ?? parked ?? actual) ?? CGRect(x: 0, y: 0, width: 800, height: 600)
    }

    static func pixelSize(frame: CGRect, scale: CGFloat) -> CGSize {
        let ratio = min(1, (560 * 1.04) / max(frame.width, 1)) * scale
        return CGSize(width: max(1, frame.width * ratio), height: max(1, frame.height * ratio))
    }

    static func pixelSize(frame: CGRect, demand: CGSize?, scale: CGFloat, windowScale: CGFloat) -> CGSize {
        let width = max(1, frame.width), height = max(1, frame.height)
        let requested = demand.map { max($0.width / width, $0.height / height) }
            ?? (pixelSize(frame: frame, scale: scale).width / width)
        let ratio = min(windowScale, requested)
        return CGSize(width: max(1, width * ratio), height: max(1, height * ratio))
    }

    static func windowScale(frame: CGRect) -> CGFloat {
        let screens = NSScreen.screens
        let screen = screens.max { a, b in
            let left = a.frame.monitorFrameNormalized().cgRect.intersection(frame)
            let right = b.frame.monitorFrameNormalized().cgRect.intersection(frame)
            return (left.isNull ? 0 : left.width * left.height) < (right.isNull ? 0 : right.width * right.height)
        }
        if let screen, screen.frame.monitorFrameNormalized().cgRect.intersects(frame) { return screen.backingScaleFactor }
        return screens.map(\.backingScaleFactor).max() ?? 2
    }

    private func demand(_ id: UInt32) -> CGSize? {
        guard let sizes = demands[id]?.values, !sizes.isEmpty else { return nil }
        return CGSize(width: sizes.map(\.width).max()!, height: sizes.map(\.height).max()!)
    }

    private func captureSize(_ window: Window) -> CGSize {
        let frame = thumbnailCaptureFrame(window)
        let (scale, windowScale) = scales(frame)
        return Self.pixelSize(frame: frame, demand: demand(window.windowId), scale: scale, windowScale: windowScale)
    }

    private func pump() {
        var ready = gate.start(now: now())
        while !ready.isEmpty {
            for id in ready {
                guard let window = windows[id]?.value, !isHidden(window), !isMinimized(window) else { gate.finish(id); completeWaiters(id); continue }
                let frame = thumbnailCaptureFrame(window)
                let size = captureSize(window)
                let requested = demand(id)
                activeCaptures[id] = InFlightCapture(size: size, demand: requested ?? size)
                let demand = requested ?? .zero
                let statistics = gate.activeLens(id).flatMap { lensStatistics[$0] }
                lensLog.debug("thumbnail start id=\(id) frame=\(String(describing: frame), privacy: .public) demand=\(String(describing: demand), privacy: .public) size=\(String(describing: size), privacy: .public) in-flight=\(self.gate.inFlight)")
                Task { [weak self, weak window, capture] in
                    let image = try? await capture(id, size)
                    guard let self else { return }
                    if let image {
                        lensLog.debug("thumbnail captured id=\(id) pixels=\(image.width)x\(image.height)")
                        statistics?.completedCapture()
                    }
                    if let window, self.windows[id]?.value === window, !self.isHidden(window), !self.isMinimized(window), let image { window.thumbnail.accept(image) }
                    self.activeCaptures.removeValue(forKey: id)
                    self.gate.finish(id)
                    self.completeWaiters(id, size: size)
                    self.pump()
                }
            }
            ready = gate.start(now: now())
        }
        if gate.isIdle {
            let waiters = idleWaiters
            idleWaiters.removeAll()
            for waiter in waiters { waiter.resume() }
        }
    }
}

extension Rect {
    var cgRect: CGRect { CGRect(x: topLeftX, y: topLeftY, width: width, height: height) }
}

@MainActor
func thumbnailCaptureFrame(_ window: Window) -> CGRect {
    ThumbnailCache.captureFrame(floating: window.isFloating, layout: window.lastAppliedLayoutPhysicalRect?.cgRect,
                                parked: window.miniatureFrame, actual: window.lastKnownActualRect?.cgRect)
}
