@testable import AppBundle
import XCTest
import AppKit
import ConcurrencyExtras

final class ThumbnailCaptureTest: XCTestCase {
    func testUndersizedPicturesGoAfterDeparturesAndBeforeOrdinaryLensRefreshes() {
        var gate = ThumbnailCaptureGate()
        gate.enqueue(1, lens: 1, now: 0)
        gate.enqueue(2, lens: 1, now: 0, needsLarger: true)
        gate.enqueue(3, now: 0)
        gate.enqueue(4, now: 0, force: true)
        XCTAssertEqual(gate.start(now: 0), [4, 3])
        gate.finish(4); gate.finish(3)
        XCTAssertEqual(gate.start(now: 0), [2, 1])
    }

    func testQueuedRefreshCanBePromotedAndFollowUpCannotRunAlongsideItsWindow() {
        var gate = ThumbnailCaptureGate()
        gate.enqueue(1, lens: 1, now: 0)
        gate.enqueue(2, lens: 1, now: 0)
        XCTAssertEqual(gate.start(now: 0), [1, 2])
        gate.enqueue(3, lens: 1, now: 0)
        gate.enqueue(4, lens: 1, now: 0)
        gate.enqueue(4, lens: 1, now: 0, needsLarger: true)
        gate.enqueue(1, lens: 1, now: 0, needsLarger: true, recapture: true)
        gate.finish(2)
        XCTAssertEqual(gate.start(now: 0), [4], "The larger queued Tile goes first; window 1 is still in flight")
        gate.finish(4)
        XCTAssertEqual(gate.start(now: 0), [3])
        gate.finish(1)
        XCTAssertEqual(gate.start(now: 0), [1], "The follow-up starts only after its earlier capture finishes")
    }

    func testDeparturePromotesAlreadyQueuedRefreshEvenInsideThrottle() {
        var gate = ThumbnailCaptureGate()
        gate.enqueue(1, now: 0)
        XCTAssertEqual(gate.start(now: 0), [1])
        gate.finish(1)
        gate.enqueue(2, now: 0.1); gate.enqueue(3, now: 0.1)
        XCTAssertEqual(gate.start(now: 0.1), [2, 3])
        gate.enqueue(1, lens: 1, now: 0.2)
        gate.enqueue(1, now: 0.3)
        gate.closeLens(1)
        gate.finish(2)
        XCTAssertEqual(gate.start(now: 0.3), [1], "Eligible queued work must survive the Lens closing")
    }

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
    private func image(width: Int = 2, height: Int = 2) -> CGImage {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
    }
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testCaptureSizeCoversDemandPreservesAspectAndCapsAtWindowScreenPixels() {
        let frame = CGRect(x: 0, y: 0, width: 1200, height: 600)
        XCTAssertEqual(ThumbnailCache.pixelSize(frame: frame, demand: CGSize(width: 900, height: 600), scale: 2, windowScale: 1), CGSize(width: 1200, height: 600))
        XCTAssertEqual(ThumbnailCache.pixelSize(frame: frame, demand: CGSize(width: 300, height: 150), scale: 2, windowScale: 1), CGSize(width: 300, height: 150))
        XCTAssertEqual(ThumbnailCache.pixelSize(frame: frame, demand: CGSize(width: 3000, height: 1500), scale: 1, windowScale: 2), CGSize(width: 2400, height: 1200))
        XCTAssertEqual(ThumbnailCache.pixelSize(frame: frame, demand: nil, scale: 2, windowScale: 1), ThumbnailCache.pixelSize(frame: frame, scale: 2))
        XCTAssertEqual(ThumbnailCache.pixelSize(frame: CGRect(x: 0, y: 0, width: 400, height: 1200), demand: nil, scale: 2, windowScale: 1), CGSize(width: 400, height: 1200), "Another display's scale cannot oversample this window")
    }

    func testNoDemandKeepsTodaysCaptureSizeOutsideALens() async {
        let capture = ControlledCapture()
        await capture.completeFutureCaptures(with: image())
        let cache = ThumbnailCache(capture: { id, size in try await capture.capture(id, size: size) })
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        let frame = CGRect(x: 0, y: 0, width: 10000, height: 5000)
        window.miniatureFrame = frame
        cache.request(window)
        await cache.waitUntilIdle()
        let sizes = await capture.sizes
        let scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
        XCTAssertEqual(sizes, [ThumbnailCache.pixelSize(frame: frame, scale: scale)])
    }

    func testOpenLensDemandsChooseLargestAndCloseRestoresOutsideSize() async {
        let capture = ControlledCapture()
        await capture.completeFutureCaptures(with: image())
        let cache = ThumbnailCache(scales: { _ in (1, 1) }, capture: { id, size in try await capture.capture(id, size: size) })
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        window.miniatureFrame = CGRect(x: 0, y: 0, width: 1600, height: 800)
        cache.request(window, lens: 1, demand: CGSize(width: 300, height: 150))
        await cache.waitUntilIdle()
        cache.request(window, lens: 2, demand: CGSize(width: 900, height: 450))
        await cache.waitUntilIdle()
        cache.request(window, lens: 1, demand: CGSize(width: 400, height: 200))
        await cache.waitUntilIdle()
        cache.closeLens(2)
        cache.request(window, force: true)
        await cache.waitUntilIdle()
        cache.closeLens(1)
        cache.request(window, force: true)
        await cache.waitUntilIdle()
        let sizes = await capture.sizes
        XCTAssertEqual(sizes.map(\.width), [300, 900, 900, 582.4, 582.4], "A capture outside a Lens never goes below today's size")
        cache.closeWindow(window)
        cache.request(window, force: true)
        await cache.waitUntilIdle()
        let final = await capture.sizes
        XCTAssertEqual(final.last?.width, 582.4, "Closing a window clears all its demands")
    }

    func testLargerDemandDuringFlightCapturesAgainAndKeepsSavedPicture() async {
        for nativeWidth: CGFloat in [1600, 600] {
            let capture = ControlledCapture()
            let cache = ThumbnailCache(scales: { _ in (1, 1) }, capture: { id, size in try await capture.capture(id, size: size) })
            let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
            window.miniatureFrame = CGRect(x: 0, y: 0, width: nativeWidth, height: nativeWidth / 2)
            let saved = image(); window.thumbnail.accept(saved)
            cache.request(window, lens: 1, demand: CGSize(width: 300, height: 150))
            await capture.waitForStarts(1)
            cache.request(window, lens: 1, demand: CGSize(width: 900, height: 450))
            XCTAssertTrue(window.thumbnail.image === saved)
            await capture.finish(1, image: image())
            await capture.waitForStarts(2)
            cache.request(window, lens: 1, demand: CGSize(width: 900, height: 450))
            await capture.finish(1, image: image())
            await cache.waitUntilIdle()
            let sizes = await capture.sizes
            XCTAssertEqual(sizes.map(\.width), [min(300, nativeWidth), min(900, nativeWidth)])
        }
    }

    func testClosingOneLensKeepsAnotherLensCoalescedQueuedDemand() async {
        let capture = ControlledCapture()
        let cache = ThumbnailCache(scales: { _ in (1, 1) }, capture: { id, size in try await capture.capture(id, size: size) })
        let windows = (1...3).map { TestWindow.new(id: UInt32($0), parent: focus.workspace.rootTilingContainer) }
        for window in windows { window.miniatureFrame = CGRect(x: 0, y: 0, width: 1600, height: 800) }
        cache.request(windows[0], lens: 9)
        cache.request(windows[1], lens: 9)
        await capture.waitForStarts(2)
        cache.request(windows[2], lens: 1, demand: CGSize(width: 900, height: 450))
        cache.request(windows[2], lens: 2, demand: CGSize(width: 300, height: 150))
        cache.closeLens(1)
        await capture.finish(1, image: image())
        await capture.waitForStarts(3)
        await capture.finish(2, image: image())
        await capture.finish(3, image: image())
        await cache.waitUntilIdle()
        let sizes = await capture.sizes
        XCTAssertEqual(sizes.last, CGSize(width: 300, height: 150))
        XCTAssertNotNil(windows[2].thumbnail.image)
    }

    func testCacheRefreshesAnUndersizedSavedPictureBeforeOneThatAlreadyCoversItsDemand() async {
        for nativeSize in [CGSize(width: 1600, height: 800), CGSize(width: 200, height: 100)] {
            let capture = ControlledCapture()
            let cache = ThumbnailCache(scales: { _ in (1, 1) }, capture: { id, size in try await capture.capture(id, size: size) })
            let windows = (1...4).map { TestWindow.new(id: UInt32($0), parent: focus.workspace.rootTilingContainer) }
            for window in windows { window.miniatureFrame = CGRect(x: 0, y: 0, width: 1600, height: 800) }
            windows[3].miniatureFrame = CGRect(origin: .zero, size: nativeSize)
            windows[2].thumbnail.accept(image(width: 600, height: 300))
            windows[3].thumbnail.accept(image(width: 100, height: 50))
            cache.request(windows[0], force: true)
            cache.request(windows[1], force: true)
            await capture.waitForStarts(2)
            cache.request(windows[2], lens: 1, demand: CGSize(width: 300, height: 150))
            cache.request(windows[3], lens: 1, demand: CGSize(width: 500, height: 250))
            await capture.finish(1, image: image())
            await capture.waitForStarts(3)
            let started = await capture.started
            XCTAssertEqual(started[2], 4)
            await capture.finish(2, image: image())
            await capture.waitForStarts(4)
            await capture.finish(3, image: image())
            await capture.finish(4, image: image())
            await cache.waitUntilIdle()
        }
    }

    func testCaptureOutsideALensKeepsTodaysSizeWhileASmallLensIsOpen() async {
        let capture = ControlledCapture()
        await capture.completeFutureCaptures(with: image())
        let cache = ThumbnailCache(scales: { _ in (1, 1) }, capture: { id, size in try await capture.capture(id, size: size) })
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        window.miniatureFrame = CGRect(x: 0, y: 0, width: 1600, height: 800)
        cache.request(window, lens: 1, demand: CGSize(width: 200, height: 100))
        await cache.waitUntilIdle()
        cache.request(window, force: true)
        await cache.waitUntilIdle()
        await cache.captureBeforeMinimize(window, timeout: .seconds(30))
        let sizes = await capture.sizes
        XCTAssertEqual(sizes.map(\.width), [200, 582.4, 582.4])
    }

    func testDepartureRightAfterASmallLensCaptureIsNotThrottled() async {
        for inFlight in [false, true] {
            let capture = ControlledCapture()
            var time = 0.0
            let cache = ThumbnailCache(now: { time }, scales: { _ in (1, 1) }, capture: { id, size in try await capture.capture(id, size: size) })
            let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
            window.miniatureFrame = CGRect(x: 0, y: 0, width: 1600, height: 800)
            cache.request(window, lens: 1, demand: CGSize(width: 200, height: 100))
            await capture.waitForStarts(1)
            if !inFlight { await capture.finish(1, image: image(width: 200, height: 100)) }
            cache.closeLens(1)
            time = 0.3
            cache.request(window)
            if inFlight { await capture.finish(1, image: image(width: 200, height: 100)) }
            await capture.waitForStarts(2)
            await capture.finish(1, image: image(width: 583, height: 292))
            await cache.waitUntilIdle()
            let sizes = await capture.sizes
            XCTAssertEqual(sizes.map(\.width), [200, 582.4], inFlight ? "in flight" : "just finished")
        }
    }

    func testAWindowCappedBelowItsDemandIsNotUndersizedOnceCapturedAtItsCap() async {
        let capture = ControlledCapture()
        let cache = ThumbnailCache(scales: { _ in (1, 1) }, capture: { id, size in try await capture.capture(id, size: size) })
        let windows = (1...4).map { TestWindow.new(id: UInt32($0), parent: focus.workspace.rootTilingContainer) }
        for window in windows { window.miniatureFrame = CGRect(x: 0, y: 0, width: 1600, height: 800) }
        windows[2].miniatureFrame = CGRect(x: 0, y: 0, width: 300, height: 150)
        windows[2].thumbnail.accept(image(width: 300, height: 150))
        windows[3].thumbnail.accept(image(width: 100, height: 50))
        cache.request(windows[0], force: true)
        cache.request(windows[1], force: true)
        await capture.waitForStarts(2)
        cache.request(windows[2], lens: 1, demand: CGSize(width: 900, height: 450))
        cache.request(windows[3], lens: 1, demand: CGSize(width: 500, height: 250))
        await capture.finish(1, image: image())
        await capture.waitForStarts(3)
        let started = await capture.started
        XCTAssertEqual(started[2], 4, "A picture already at its window's size does not jump the queue")
        for id: UInt32 in [2, 4] { await capture.finish(id, image: image()) }
        await capture.waitForStarts(4)
        await capture.finish(3, image: image())
        await cache.waitUntilIdle()
    }

    func testAGrowingDemandOnACappedWindowStartsNoFollowUp() async {
        let capture = ControlledCapture()
        let cache = ThumbnailCache(scales: { _ in (1, 1) }, capture: { id, size in try await capture.capture(id, size: size) })
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        window.miniatureFrame = CGRect(x: 0, y: 0, width: 300, height: 150)
        cache.request(window, lens: 1, demand: CGSize(width: 900, height: 450))
        await capture.waitForStarts(1)
        cache.request(window, lens: 1, demand: CGSize(width: 1200, height: 600))
        await capture.finish(1, image: image())
        await cache.waitUntilIdle()
        let sizes = await capture.sizes
        XCTAssertEqual(sizes, [CGSize(width: 300, height: 150)])
    }

    func testSessionCountersCountRequestsAndSuccessfulCapturesWithTheirOriginalOwner() async {
        let capture = ControlledCapture()
        let cache = ThumbnailCache(capture: { id, _ in try await capture.capture(id) })
        let first = LensSessionStatistics(stamp: { 0 })
        let second = LensSessionStatistics(stamp: { 0 })
        first.presented(); second.presented()
        cache.observeLens(1, statistics: first)
        cache.observeLens(2, statistics: second)
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        cache.request(window, lens: 1)
        await capture.waitForStarts(1)
        cache.request(window, lens: 1)
        cache.request(window, lens: 2)
        await capture.finish(1, image: image())
        await cache.waitUntilIdle()
        XCTAssertEqual(first.capturesRequested, 2)
        XCTAssertEqual(first.capturesCompleted, 1)
        XCTAssertEqual(second.capturesRequested, 1)
        XCTAssertEqual(second.capturesCompleted, 0, "A coalesced request must not claim another session's capture")
        cache.request(window, lens: 2)
        await capture.waitForStarts(2)
        await capture.finish(1, image: nil)
        await cache.waitUntilIdle()
        XCTAssertEqual(second.capturesCompleted, 0, "Failed captures are not completed pictures")
        cache.request(window, lens: 2)
        await capture.waitForStarts(3)
        cache.closeLens(2); second.stop()
        await capture.finish(1, image: image())
        await cache.waitUntilIdle()
        XCTAssertEqual(second.capturesCompleted, 0, "Dismissed session totals are final")
        cache.request(window, force: true)
        await capture.waitForStarts(4)
        await capture.finish(1, image: image())
        await cache.waitUntilIdle()
        XCTAssertEqual(first.capturesCompleted, 1, "Departure captures are not Lens refreshes")
        cache.closeLens(1)
    }

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


@MainActor
final class ThumbnailMinimizeCaptureTest: SerialClockTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testMinimizeWaitsForTheRequestedSizeInsteadOfAnOlderSmallCapture() async {
        let image = CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        let capture = ControlledCapture()
        let cache = ThumbnailCache(scales: { _ in (1, 1) }, capture: { id, size in try await capture.capture(id, size: size) })
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        window.miniatureFrame = CGRect(x: 0, y: 0, width: 1600, height: 800)
        cache.request(window, lens: 1, demand: CGSize(width: 100, height: 50))
        await capture.waitForStarts(1)
        cache.closeLens(1)
        var started = false, finished = false
        let minimizing = Task { @MainActor in
            started = true
            await cache.captureBeforeMinimize(window, timeout: .seconds(30))
            finished = true
        }
        await Task.megaYield()
        XCTAssertTrue(started)
        await capture.finish(1, image: image)
        await capture.waitForStarts(2)
        await Task.megaYield()
        XCTAssertFalse(finished, "The old 100-pixel capture cannot complete the requested departure capture")
        await capture.finish(1, image: image)
        await minimizing.value
        await cache.waitUntilIdle()
        XCTAssertTrue(finished)
        let sizes = await capture.sizes
        XCTAssertEqual(sizes.map(\.width), [100, 582.4])
    }

    func testMinimizeFinishesOnACaptureStartedAfterItEvenWhenTheSizeDropped() async {
        let image = CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        let capture = ControlledCapture()
        let cache = ThumbnailCache(scales: { _ in (1, 1) }, capture: { id, size in try await capture.capture(id, size: size) })
        let windows = (1...3).map { TestWindow.new(id: UInt32($0), parent: focus.workspace.rootTilingContainer) }
        for window in windows { window.miniatureFrame = CGRect(x: 0, y: 0, width: 1600, height: 800) }
        cache.request(windows[1], force: true)
        cache.request(windows[2], force: true)
        await capture.waitForStarts(2)
        cache.request(windows[0], lens: 1, demand: CGSize(width: 900, height: 450))
        var finished = false
        let minimizing = Task { @MainActor in
            await cache.captureBeforeMinimize(windows[0], timeout: .seconds(30))
            finished = true
        }
        await Task.megaYield()
        cache.closeLens(1)
        await capture.finish(2, image: image)
        await capture.waitForStarts(3)
        await capture.finish(1, image: image)
        await Task.megaYield()
        XCTAssertTrue(finished, "The capture started after the waiter completes it at the size it now has")
        await capture.finish(3, image: image)
        await minimizing.value
        await cache.waitUntilIdle()
        let sizes = await capture.sizes
        XCTAssertEqual(sizes.last?.width, 582.4)
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
