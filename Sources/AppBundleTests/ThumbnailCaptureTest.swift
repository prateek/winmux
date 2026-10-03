@testable import AppBundle
import XCTest
import AppKit

final class ThumbnailCaptureTest: XCTestCase {
    func testFiftyRequestsStartOnlyTwoAndClosingLensDropsWaitingWork() {
        var gate = ThumbnailCaptureGate()
        for id in 1 ... 50 { gate.enqueue(UInt32(id), lens: 1, now: 0) }
        XCTAssertEqual(gate.start(now: 0), [1, 2])
        XCTAssertEqual(gate.start(now: 0), [])
        gate.closeLens(1)
        gate.finish(1)
        gate.finish(2)
        XCTAssertEqual(gate.start(now: 1), [])
    }

    func testThrottleDoesNotApplyToLiveRefreshAndWindowCloseRemovesWork() {
        var gate = ThumbnailCaptureGate()
        gate.enqueue(1, now: 0)
        XCTAssertEqual(gate.start(now: 0), [1])
        gate.finish(1)
        gate.enqueue(1, now: 0.799)
        XCTAssertEqual(gate.start(now: 0.799), [])
        gate.enqueue(1, now: 0.8)
        XCTAssertEqual(gate.start(now: 0.8), [1])
        gate.finish(1)
        gate.enqueue(1, lens: 1, now: 0.9)
        XCTAssertEqual(gate.start(now: 0.9), [1])
        gate.enqueue(2, now: 1)
        gate.closeWindow(2)
        gate.finish(1)
        XCTAssertEqual(gate.start(now: 1), [])
    }

    func testParkRequestSurvivesDismissalWhenTheSameWindowWasQueuedForRefresh() {
        var gate = ThumbnailCaptureGate()
        gate.enqueue(1, now: 0)
        gate.enqueue(2, now: 0)
        XCTAssertEqual(gate.start(now: 0), [1, 2])
        gate.enqueue(3, lens: 1, now: 1)
        gate.enqueue(3, now: 1)
        gate.closeLens(1)
        gate.finish(1)
        XCTAssertEqual(gate.start(now: 1), [3])
    }

    func testParkHasPriorityWithoutDuplicatingInflightWindow() {
        var gate = ThumbnailCaptureGate()
        gate.enqueue(1, now: 0)
        gate.enqueue(2, now: 0)
        gate.enqueue(3, lens: 1, now: 0)
        XCTAssertEqual(gate.start(now: 0), [1, 2])
        gate.enqueue(1, lens: 1, now: 0)
        gate.finish(1)
        XCTAssertEqual(gate.start(now: 0), [3])
    }
}

private actor ControlledCapture {
    private var pending: [UInt32: CheckedContinuation<CGImage, Error>] = [:]
    private(set) var started: [UInt32] = []
    private(set) var sizes: [CGSize] = []
    private var waiting: [(Int, CheckedContinuation<Void, Never>)] = []
    private var immediateImage: CGImage?
    func completeFutureCaptures(with image: CGImage) { immediateImage = image }
    func capture(_ id: UInt32, size: CGSize? = nil) async throws -> CGImage {
        if let size { sizes.append(size) }
        if let immediateImage { started.append(id); return immediateImage }
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            started.append(id)
            waiting.removeAll { count, ready in
                if started.count >= count { ready.resume(); return true }
                return false
            }
        }
    }
    func waitForStarts(_ count: Int) async {
        if started.count >= count { return }
        await withCheckedContinuation { waiting.append((count, $0)) }
    }
    func finish(_ id: UInt32, image: CGImage?) {
        let continuation = pending.removeValue(forKey: id)
        if let image { continuation?.resume(returning: image) }
        else { continuation?.resume(throwing: NSError(domain: "capture", code: 1)) }
    }
}

@MainActor
final class ThumbnailCacheTest: XCTestCase {
    private func image() -> CGImage {
        CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
    }
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testResizeCapturesAtCurrentLayoutAspectInsteadOfPreviousParkAspect() async {
        let capture = ControlledCapture()
        await capture.completeFutureCaptures(with: image())
        let cache = ThumbnailCache(capture: { id, size in try await capture.capture(id, size: size) })
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        window.miniatureFrame = CGRect(x: 0, y: 0, width: 600, height: 1000)
        window.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 1800, height: 1000)
        cache.request(window)
        await cache.waitUntilIdle()
        let size = await capture.sizes.first!
        XCTAssertEqual(size.width / size.height, 1.8, accuracy: 0.001)
    }

    func testThumbnailPixelsCoverPortraitFramesAtBackingScale() {
        XCTAssertEqual(ThumbnailCache.pixelSize(frame: CGRect(x: 0, y: 0, width: 400, height: 1200), scale: 2), CGSize(width: 800, height: 2400))
        XCTAssertEqual(ThumbnailCache.pixelSize(frame: CGRect(x: 0, y: 0, width: 1200, height: 600), scale: 2), CGSize(width: 1164.8, height: 582.4))
    }

    func testWindowOwnsLastGoodImageFailureKeepsItAndCloseRejectsLateResult() async {
        let capture = ControlledCapture()
        var time = 0.0
        let cache = ThumbnailCache(now: { time }, capture: { id, _ in try await capture.capture(id) })
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        XCTAssertNil(window.thumbnail.image)
        let first = image()
        cache.request(window)
        await capture.waitForStarts(1)
        await capture.finish(1, image: first)
        await cache.waitUntilIdle()
        XCTAssertTrue(window.thumbnail.image === first)
        time = 1
        cache.request(window)
        await capture.waitForStarts(2)
        await capture.finish(1, image: nil)
        await cache.waitUntilIdle()
        XCTAssertTrue(window.thumbnail.image === first)
        time = 2
        cache.request(window)
        await capture.waitForStarts(3)
        cache.closeWindow(window)
        XCTAssertNil(window.thumbnail.image)
        await capture.finish(1, image: image())
        await cache.waitUntilIdle()
        XCTAssertNil(window.thumbnail.image)
    }

    func testHidingAppDuringCaptureKeepsLastGoodFrameAndSkipsQueuedHiddenWindows() async {
        let capture = ControlledCapture()
        var hidden = false
        var time = 0.0
        let cache = ThumbnailCache(now: { time }, isHidden: { _ in hidden }, capture: { id, _ in try await capture.capture(id) })
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        let first = image()
        window.thumbnail.accept(first)
        cache.request(window)
        await capture.waitForStarts(1)
        hidden = true
        await capture.finish(1, image: image())
        await cache.waitUntilIdle()
        XCTAssertTrue(window.thumbnail.image === first)
        time = 1
        await capture.completeFutureCaptures(with: image())
        cache.request(window)
        await cache.waitUntilIdle()
        let started = await capture.started
        XCTAssertEqual(started, [1])
        XCTAssertTrue(window.thumbnail.image === first)
    }

    func testNativeFocusLossCapturesEvenWhenTheNewWindowIsAPopup() async {
        let capture = ControlledCapture()
        await capture.completeFutureCaptures(with: image())
        let cache = ThumbnailCache(capture: { id, _ in try await capture.capture(id) })
        let first = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        let second = TestWindow.new(id: 2, parent: focus.workspace.rootTilingContainer)
        let popup = TestWindow.new(id: 3, parent: macosPopupWindowsContainer)
        cache.recordNativeFocus(first)
        cache.recordNativeFocus(second)
        await cache.waitUntilIdle()
        cache.recordNativeFocus(popup)
        await cache.waitUntilIdle()
        cache.recordNativeFocus(popup)
        await cache.waitUntilIdle()
        let ids = await capture.started
        XCTAssertEqual(ids, [1, 2])
    }

    func testFiftyRealRequestsAreBoundedAndDismissalDropsQueuedRefreshes() async {
        let capture = ControlledCapture()
        let cache = ThumbnailCache(capture: { id, _ in try await capture.capture(id) })
        let windows = (1 ... 50).map { TestWindow.new(id: UInt32($0), parent: focus.workspace.rootTilingContainer) }
        for window in windows { cache.request(window, lens: 1) }
        await capture.waitForStarts(2)
        let started = await capture.started
        XCTAssertEqual(Set(started), [1, 2])
        cache.closeLens(1)
        for id in started { await capture.finish(id, image: image()) }
        await cache.waitUntilIdle()
        let final = await capture.started
        XCTAssertEqual(Set(final), [1, 2])
        XCTAssertNotNil(windows[0].thumbnail.image)
        XCTAssertNil(windows[49].thumbnail.image)
    }
}


final class ThumbnailAppearanceTest: XCTestCase {
    func testLiveThumbnailsAreNeverMarkedAndFrozenLooksUseCaptureAge() {
        let captured = Date(timeIntervalSince1970: 100)
        let now = Date(timeIntervalSince1970: 142)
        for look in ["plain", "dimmed", "age-badge", "pause-badge"] {
            let live = ThumbnailAppearance(frozen: false, look: look, capturedAt: captured, now: now)
            XCTAssertEqual(live.opacity, 1)
            XCTAssertEqual(live.saturation, 1)
            XCTAssertEqual(live.brightness, 1)
            XCTAssertNil(live.badge)
        }
        XCTAssertEqual(ThumbnailAppearance(frozen: true, look: "dimmed", capturedAt: captured, now: now).opacity, 0.5)
        let age = ThumbnailAppearance(frozen: true, look: "age-badge", capturedAt: captured, now: now)
        XCTAssertEqual(age.saturation, 0.35)
        XCTAssertEqual(age.brightness, 0.85)
        XCTAssertEqual(age.badge, "42s")
        XCTAssertEqual(ThumbnailAppearance(frozen: true, look: "pause-badge", capturedAt: captured, now: now).badge, "pause")
        XCTAssertNil(ThumbnailAppearance(frozen: true, look: "age-badge", capturedAt: nil, now: now).badge)
    }
}

@MainActor
final class MinimizeThumbnailRegressionTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }
    func testAlreadyMinimizedWindowKeepsLastGoodFrame() async {
        let capture = ControlledCapture()
        let image = CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        await capture.completeFutureCaptures(with: image)
        let cache = ThumbnailCache(capture: { id, _ in try await capture.capture(id) })
        let window = TestWindow.new(id: 1, parent: macosMinimizedWindowsContainer)
        window.thumbnail.accept(image)
        cache.request(window)
        await cache.waitUntilIdle()
        let started = await capture.started
        XCTAssertEqual(started, [])
        XCTAssertTrue(window.thumbnail.image === image)
    }
    func testMinimizeDeadlineReturnsAndLateMinimizedCaptureKeepsGoodFrame() async {
        let capture = ControlledCapture()
        let first = CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        let cache = ThumbnailCache(capture: { id, _ in try await capture.capture(id) })
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        window.thumbnail.accept(first)
        let waiting = Task { await cache.captureBeforeMinimize(window, timeout: .zero) }
        await capture.waitForStarts(1)
        await waiting.value
        window.bind(to: macosMinimizedWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        await capture.finish(1, image: first.copy()!)
        await cache.waitUntilIdle()
        XCTAssertTrue(window.thumbnail.image === first)
    }

    func testMinimizeCaptureFinishesEvenInsideEventThrottle() async {
        let capture = ControlledCapture()
        let image = CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        await capture.completeFutureCaptures(with: image)
        let cache = ThumbnailCache(now: { 0 }, capture: { id, _ in try await capture.capture(id) })
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        cache.request(window)
        await cache.waitUntilIdle()
        await cache.captureBeforeMinimize(window)
        let started = await capture.started
        XCTAssertEqual(started, [1, 1])
        XCTAssertNotNil(window.thumbnail.image)
    }
}
