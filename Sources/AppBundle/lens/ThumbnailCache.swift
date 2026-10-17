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
        /// Any capture started from this serial on was asked for after the waiter.
        let serial: Int
        let continuation: CheckedContinuation<Void, Never>
        let timeout: Task<Void, Never>
    }
    private var captureWaiters: [UInt32: [UUID: CaptureWaiter]] = [:]
    private var demands: [UInt32: [Int: CGSize]] = [:]
    private var activeCaptures: [UInt32: CGSize] = [:]
    private var nextCaptureSerial = 0
    private let scales: (CGRect) -> (CGFloat, CGFloat)
    private var nativeFocusedWindow: WeakWindow?
    private var lensStatistics: [Int: LensSessionStatistics] = [:]
    private struct WeakWindow { weak var value: Window? }
    private let capture: WindowImageCapture
    private let now: () -> TimeInterval
    private let isHidden: (Window) -> Bool

    init(now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         isHidden: @escaping (Window) -> Bool = { ($0.app as? MacApp)?.nsApp.isHidden == true },
         scales: @escaping (CGRect) -> (CGFloat, CGFloat) = { frame in
             (NSScreen.screens.map(\.backingScaleFactor).max() ?? 2, ThumbnailCache.windowScale(frame: frame))
         },
         captureWindow: @escaping WindowImageCapture = { target, size in
             try await WindowScreenshot.capture(target, pixelSize: size, cachedOnly: true)
         },
         capture: (@Sendable (UInt32, CGSize) async throws -> CGImage)? = nil) {
        self.scales = scales
        self.now = now
        self.isHidden = isHidden
        if let capture { self.capture = { try await capture($0.id, $1) } }
        else { self.capture = captureWindow }
    }

    func request(_ window: Window, lens: Int? = nil, demand: CGSize? = nil, force: Bool = false) {
        guard window.isBound, !isMinimized(window), !isUnitTest || self !== Self.shared else { return }
        if let lens { lensStatistics[lens]?.requestedCapture() }
        windows[window.windowId] = WeakWindow(value: window)
        let id = window.windowId
        if let lens, let demand, demand.width > 0, demand.height > 0 { demands[id, default: [:]][lens] = demand }
        let size = captureSize(window, outsideLens: lens == nil)
        // A window with no picture yet is not "undersized": one whose captures keep failing would
        // otherwise skip the throttle and jump the queue for good.
        let needsLarger = window.thumbnail.image.map {
            CGFloat($0.width) < size.width.rounded(.down) || CGFloat($0.height) < size.height.rounded(.down)
        } ?? false
        let recapture = activeCaptures[id].map { $0.width < size.width || $0.height < size.height } ?? false
        gate.enqueue(id, lens: lens, now: now(), force: force, needsLarger: needsLarger, recapture: recapture)
        pump()
    }

    private func isMinimized(_ window: Window) -> Bool {
        window.parent is MacosMinimizedWindowsContainer || window.lastKnownNativeMinimized == true
    }

    func captureBeforeMinimize(_ window: Window, timeout: Duration = .milliseconds(200)) async {
        guard !isMinimized(window), !isHidden(window), window.isBound, !isUnitTest || self !== Self.shared else { return }
        let token = UUID(), id = window.windowId
        let size = captureSize(window, outsideLens: true)
        await withCheckedContinuation { continuation in
            let deadline = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: timeout) } catch { return }
                self?.captureWaiters[id]?.removeValue(forKey: token)?.continuation.resume()
            }
            captureWaiters[id, default: [:]][token] = CaptureWaiter(size: size, serial: nextCaptureSerial, continuation: continuation, timeout: deadline)
            request(window, force: true)
        }
    }

    /// A capture started before the waiter completes it only when it is as large as the waiter asked for.
    private func completeWaiters(_ id: UInt32, size: CGSize? = nil, serial: Int? = nil) {
        guard let waiters = captureWaiters[id] else { return }
        for (token, waiter) in waiters {
            if let size, let serial, serial < waiter.serial, size.width < waiter.size.width || size.height < waiter.size.height { continue }
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
        var sized: [UInt32] = []
        for id in Array(demands.keys) {
            if demands[id]?.removeValue(forKey: lens) != nil { sized.append(id) }
            if demands[id]?.isEmpty == true { demands.removeValue(forKey: id) }
        }
        lensStatistics.removeValue(forKey: lens)
        gate.closeLens(lens)
        // The Lens may have left pictures below today's size, and a window hidden or minimized
        // outside WinMux freezes with whatever it has. Take them back up now.
        for id in sized {
            guard let window = windows[id]?.value, let image = window.thumbnail.image else { continue }
            let size = captureSize(window, outsideLens: true)
            if CGFloat(image.width) < size.width.rounded(.down) || CGFloat(image.height) < size.height.rounded(.down) { request(window) }
        }
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

    /// A Lens's own refresh is sized by its demand alone; any other capture never goes below
    /// today's size, so a small Presentation cannot shrink the picture a window parks with.
    static func pixelSize(frame: CGRect, demand: CGSize?, scale: CGFloat, windowScale: CGFloat, outsideLens: Bool = false) -> CGSize {
        let width = max(1, frame.width), height = max(1, frame.height)
        let today = pixelSize(frame: frame, scale: scale).width / width
        let requested = demand.map { max($0.width / width, $0.height / height) }
        let ratio = min(windowScale, outsideLens ? max(requested ?? 0, today) : requested ?? today)
        return CGSize(width: max(1, width * ratio), height: max(1, height * ratio))
    }

    static func windowScale(frame: CGRect) -> CGFloat {
        let screens = NSScreen.screens.map { (frame: $0.frame.monitorFrameNormalized().cgRect, scale: $0.backingScaleFactor) }
        let screen = screens.max { $0.frame.intersection(frame).area < $1.frame.intersection(frame).area }
        if let screen, screen.frame.intersects(frame) { return screen.scale }
        return screens.map(\.scale).max() ?? 2
    }

    private func demand(_ id: UInt32) -> CGSize? {
        guard let sizes = demands[id]?.values, !sizes.isEmpty else { return nil }
        return CGSize(width: sizes.map(\.width).max()!, height: sizes.map(\.height).max()!)
    }

    private func captureSize(_ window: Window, outsideLens: Bool) -> CGSize {
        let frame = thumbnailCaptureFrame(window)
        let (scale, windowScale) = scales(frame)
        return Self.pixelSize(frame: frame, demand: demand(window.windowId), scale: scale, windowScale: windowScale, outsideLens: outsideLens)
    }

    private func pump() {
        var ready = gate.start(now: now())
        while !ready.isEmpty {
            for id in ready {
                guard let window = windows[id]?.value, !isHidden(window), !isMinimized(window) else { gate.finish(id); completeWaiters(id); continue }
                let frame = thumbnailCaptureFrame(window)
                let size = captureSize(window, outsideLens: gate.activeLens(id) == nil)
                let serial = nextCaptureSerial
                nextCaptureSerial += 1
                activeCaptures[id] = size
                let statistics = gate.activeLens(id).flatMap { lensStatistics[$0] }
                let target = window.captureTarget
                lensLog.debug("thumbnail start id=\(id) frame=\(String(describing: frame), privacy: .public) demand=\(String(describing: self.demand(id) ?? .zero), privacy: .public) size=\(String(describing: size), privacy: .public) in-flight=\(self.gate.inFlight)")
                Task { [weak self, weak window, capture] in
                    let image = try? await capture(target, size)
                    guard let self else { return }
                    if let image {
                        lensLog.debug("thumbnail captured id=\(id) pixels=\(image.width)x\(image.height)")
                        statistics?.completedCapture()
                    }
                    if let window, self.windows[id]?.value === window, !self.isHidden(window), !self.isMinimized(window), let image { window.thumbnail.accept(image) }
                    self.activeCaptures.removeValue(forKey: id)
                    self.gate.finish(id)
                    self.completeWaiters(id, size: size, serial: serial)
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
