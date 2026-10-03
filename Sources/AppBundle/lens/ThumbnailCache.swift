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
    private var captureWaiters: [UInt32: [UUID: CheckedContinuation<Void, Never>]] = [:]
    private var nativeFocusedWindow: WeakWindow?
    private struct WeakWindow { weak var value: Window? }
    private let capture: @Sendable (UInt32, CGSize) async throws -> CGImage
    private let now: () -> TimeInterval
    private let isHidden: (Window) -> Bool

    init(now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         isHidden: @escaping (Window) -> Bool = { ($0.app as? MacApp)?.nsApp.isHidden == true },
         capture: @escaping @Sendable (UInt32, CGSize) async throws -> CGImage = { id, size in
             try await WindowScreenshot.capture(id, pixelSize: size, cachedOnly: true)
         }) {
        self.now = now
        self.isHidden = isHidden
        self.capture = capture
    }

    func request(_ window: Window, lens: Int? = nil, force: Bool = false) {
        guard window.isBound, !isMinimized(window), !isUnitTest || self !== Self.shared else { return }
        windows[window.windowId] = WeakWindow(value: window)
        gate.enqueue(window.windowId, lens: lens, now: now(), force: force)
        pump()
    }

    private func isMinimized(_ window: Window) -> Bool {
        window.parent is MacosMinimizedWindowsContainer || window.lastKnownNativeMinimized == true
    }

    func captureBeforeMinimize(_ window: Window, timeout: Duration = .milliseconds(200)) async {
        guard !isMinimized(window), !isHidden(window), window.isBound, !isUnitTest || self !== Self.shared else { return }
        let token = UUID()
        await withCheckedContinuation { continuation in
            captureWaiters[window.windowId, default: [:]][token] = continuation
            request(window, force: true)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: timeout)
                self?.captureWaiters[window.windowId]?.removeValue(forKey: token)?.resume()
            }
        }
    }

    private func completeWaiters(_ id: UInt32) {
        let waiters = captureWaiters.removeValue(forKey: id) ?? [:]
        for waiter in waiters.values { waiter.resume() }
    }

    func recordNativeFocus(_ window: Window?) {
        guard nativeFocusedWindow?.value?.windowId != window?.windowId else { return }
        if let previous = nativeFocusedWindow?.value { request(previous) }
        nativeFocusedWindow = window.map { WeakWindow(value: $0) }
    }

    func closeLens(_ lens: Int) { gate.closeLens(lens) }
    func closeWindow(_ window: Window) {
        if nativeFocusedWindow?.value === window { nativeFocusedWindow = nil }
        gate.closeWindow(window.windowId)
        windows.removeValue(forKey: window.windowId)
        window.thumbnail.clear()
        completeWaiters(window.windowId)
    }

    func waitUntilIdle() async {
        if gate.isIdle { return }
        await withCheckedContinuation { idleWaiters.append($0) }
    }

    static func pixelSize(frame: CGRect, scale: CGFloat) -> CGSize {
        let ratio = min(1, (560 * 1.04) / max(frame.width, 1)) * scale
        return CGSize(width: max(1, frame.width * ratio), height: max(1, frame.height * ratio))
    }

    private func pump() {
        var ready = gate.start(now: now())
        while !ready.isEmpty {
            for id in ready {
                guard let window = windows[id]?.value, !isHidden(window), !isMinimized(window) else { gate.finish(id); completeWaiters(id); continue }
                let frame = window.lastAppliedLayoutPhysicalRect?.cgRect ?? window.miniatureFrame ?? window.lastKnownActualRect?.cgRect ?? CGRect(x: 0, y: 0, width: 800, height: 600)
                let scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
                let size = Self.pixelSize(frame: frame, scale: scale)
                #if DEBUG
                if ProcessInfo.processInfo.environment["WINMUX_THUMBNAIL_TRACE"] == "1" {
                    print("[thumbnail] start id=\(id) in-flight=\(gate.inFlight)")
                }
                #endif
                Task { [weak self, weak window, capture] in
                    let image = try? await capture(id, size)
                    guard let self else { return }
                    if let window, self.windows[id]?.value === window, !self.isHidden(window), !self.isMinimized(window), let image { window.thumbnail.accept(image) }
                    self.gate.finish(id)
                    self.completeWaiters(id)
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
