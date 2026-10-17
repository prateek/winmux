@testable import AppBundle
import AppKit
import XCTest

private actor CaptureRequests {
    private(set) var targets: [WindowCaptureTarget] = []
    private(set) var sizes: [CGSize] = []

    func capture(_ target: WindowCaptureTarget, size: CGSize = .zero) -> CGImage {
        targets.append(target)
        sizes.append(size)
        return CGContext(data: nil, width: 10, height: 10, bitsPerComponent: 8, bytesPerRow: 40,
                         space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
    }
}

@MainActor
final class WindowCaptureRoutingTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    private func window() -> TestWindow {
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer,
                                    rect: Rect(topLeftX: 100, topLeftY: 80, width: 913, height: 700))
        window.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 200, topLeftY: 180, width: 813, height: 600)
        return window
    }

    func testThumbnailCarriesEntryOwnerAndActualFrameRatherThanLayoutFrame() async {
        let requests = CaptureRequests(), window = window()
        let cache = ThumbnailCache(scales: { _ in (1, 1) }, captureWindow: { await requests.capture($0, size: $1) })
        cache.request(window)
        await cache.waitUntilIdle()
        let targets = await requests.targets, sizes = await requests.sizes
        XCTAssertEqual(targets, [window.captureTarget], "Thumbnail capture needs the entry's owner and actual frame")
        XCTAssertEqual(targets.first?.entryFrame, CGRect(x: 100, y: 80, width: 913, height: 700))
        XCTAssertEqual(sizes, [ThumbnailCache.pixelSize(frame: thumbnailCaptureFrame(window), scale: 1)], "Identity checking must not change pixel demand")
        XCTAssertNotNil(window.thumbnail.image)
    }

    func testTiledWindowWhoseActualFrameWasClearedCarriesItsLayoutFrame() {
        let window = window()
        window.invalidateLastKnownNativeState()
        XCTAssertEqual(window.captureTarget.entryFrame, CGRect(x: 200, y: 180, width: 813, height: 600))
        XCTAssertEqual(window.captureTarget.ownerPID, window.app.pid)
    }

    func testPeekCarriesEntryIdentityAndKeepsRequestedPixels() async {
        let requests = CaptureRequests(), window = window()
        let slot = LensPeekCapture(captureWindow: { await requests.capture($0, size: $1) })
        let size = CGSize(width: 1826, height: 1400)
        slot.select(window.windowId, pixelSize: size, target: window.captureTarget)
        await slot.task?.value
        let targets = await requests.targets, sizes = await requests.sizes
        XCTAssertEqual(targets, [window.captureTarget], "Peek must check the same identity as the Tile")
        XCTAssertEqual(sizes, [size])
        XCTAssertNotNil(slot.image)
    }

    func testFlipSnapshotCarriesActualIdentityAndRetainsOutlineCrop() async {
        let requests = CaptureRequests(), window = window()
        let image = await DoubleSidedWindowController.snapshot(window.captureTarget, capture: { await requests.capture($0) })
        let targets = await requests.targets
        XCTAssertEqual(targets, [window.captureTarget], "Flip must check the window it pictures")
        XCTAssertEqual(image?.width, 8)
        XCTAssertEqual(image?.height, 8)
    }

    func testFailedChoiceKeepsLastGoodThumbnailAndOtherwiseUsesNoPicture() async {
        let window = window()
        let saved = await CaptureRequests().capture(window.captureTarget)
        window.thumbnail.accept(saved)
        let cache = ThumbnailCache(captureWindow: { target, _ in
            let helper = WindowCaptureCandidate(id: target.id, ownerPID: target.ownerPID,
                                                frame: CGRect(x: 0, y: 0, width: 913, height: 16), layer: 0)
            guard chooseWindowToCapture(target, from: [helper]) != nil else { throw WindowScreenshotError.windowNotFound(target.id) }
            return saved.copy()!
        })
        cache.request(window, force: true)
        await cache.waitUntilIdle()
        XCTAssertTrue(window.thumbnail.image === saved)
        window.thumbnail.clear()
        cache.request(window, force: true)
        await cache.waitUntilIdle()
        XCTAssertNil(window.thumbnail.image)
    }
}
