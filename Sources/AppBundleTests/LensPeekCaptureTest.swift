@testable import AppBundle
import AppKit
import XCTest
import SwiftUI

private actor PeekCaptureReplies {
    private var replies: [UInt32: CheckedContinuation<CGImage, Error>] = [:]
    private(set) var sizes: [UInt32: CGSize] = [:]
    func capture(_ id: UInt32, size: CGSize) async throws -> CGImage {
        sizes[id] = size
        countRequest(id)
        return try await withCheckedThrowingContinuation { replies[id] = $0 }
    }
    func ready(_ id: UInt32) -> Bool { replies[id] != nil }
    func requested(_ id: UInt32) -> Bool { sizes[id] != nil }
    private(set) var count: [UInt32: Int] = [:]
    func countRequest(_ id: UInt32) { count[id, default: 0] += 1 }
    func finish(_ id: UInt32, image: CGImage) { replies.removeValue(forKey: id)?.resume(returning: image) }
    func fail(_ id: UInt32) { replies.removeValue(forKey: id)?.resume(throwing: CancellationError()) }
}

@MainActor
final class LensPeekCaptureTest: XCTestCase {
    private func image() throws -> CGImage {
        try XCTUnwrap(CGContext(data: nil, width: 8, height: 4, bitsPerComponent: 8, bytesPerRow: 32,
                               space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage())
    }

    func testOneSlotFrozenNoCaptureLateReplyDiscardedAndTiming() async throws {
        let replies = PeekCaptureReplies()
        let slot = LensPeekCapture { try await replies.capture($0, size: $1) }
        let first = try image(), second = try image()
        var times: [Double] = []; slot.completed = { times.append($0) }
        slot.select(1, pixelSize: CGSize(width: 1920, height: 1080))
        while !(await replies.ready(1)) { await Task.yield() }
        let firstCapture = slot.task
        slot.select(2, frozen: true, pixelSize: CGSize(width: 1280, height: 720))
        XCTAssertNil(slot.image)
        let frozenRequested = await replies.ready(2)
        XCTAssertFalse(frozenRequested)
        await replies.finish(1, image: first)
        await firstCapture?.value
        XCTAssertNil(slot.image)
        XCTAssertTrue(times.isEmpty)
        slot.select(3, pixelSize: CGSize(width: 1280, height: 720))
        while !(await replies.ready(3)) { await Task.yield() }
        let currentCapture = slot.task
        await replies.finish(3, image: second)
        await currentCapture?.value
        XCTAssertTrue(slot.image === second)
        XCTAssertEqual(times.count, 1)
        XCTAssertGreaterThanOrEqual(times[0], 0)
        let sizes = await replies.sizes
        XCTAssertEqual(sizes[1], CGSize(width: 1920, height: 1080))
        XCTAssertEqual(sizes[3], CGSize(width: 1280, height: 720))
        slot.select(nil)
        XCTAssertNil(slot.image)
        XCTAssertNil(slot.windowId)
    }

    func testLateReplyAfterLensCloseCannotRepopulateSlot() async throws {
        let replies = PeekCaptureReplies()
        let slot = LensPeekCapture { try await replies.capture($0, size: $1) }
        slot.select(4, pixelSize: CGSize(width: 400, height: 300))
        while !(await replies.ready(4)) { await Task.yield() }
        let pending = slot.task
        slot.select(nil)
        await replies.finish(4, image: try image())
        await pending?.value
        XCTAssertNil(slot.image)
    }

    func testOneCaptureRunsAtATimeAndOnlyTheLatestWaits() async throws {
        let replies = PeekCaptureReplies()
        let slot = LensPeekCapture { try await replies.capture($0, size: $1) }
        let picture = try image()
        slot.select(1, pixelSize: CGSize(width: 100, height: 100))
        while !(await replies.ready(1)) { await Task.yield() }
        slot.select(2, pixelSize: CGSize(width: 200, height: 200))
        slot.select(3, pixelSize: CGSize(width: 300, height: 300))
        for _ in 0 ..< 20 { await Task.yield() }
        var started = (await replies.requested(2), await replies.requested(3))
        XCTAssertFalse(started.0 || started.1, "A capture that cannot be cancelled must finish before the next starts")
        await replies.finish(1, image: try image())
        while !(await replies.ready(3)) { await Task.yield() }
        started.0 = await replies.requested(2)
        XCTAssertFalse(started.0, "A request superseded while waiting never runs")
        let current = slot.task
        await replies.finish(3, image: picture)
        await current?.value
        XCTAssertTrue(slot.image === picture)
        let sizes = await replies.sizes
        XCTAssertEqual(sizes[3], CGSize(width: 300, height: 300))
    }

    func testFailedCaptureReportsNoTime() async throws {
        let replies = PeekCaptureReplies()
        let slot = LensPeekCapture { try await replies.capture($0, size: $1) }
        var times: [Double] = []; slot.completed = { times.append($0) }
        slot.select(1, pixelSize: CGSize(width: 100, height: 100))
        while !(await replies.ready(1)) { await Task.yield() }
        let pending = slot.task
        await replies.fail(1)
        await pending?.value
        XCTAssertNil(slot.image)
        XCTAssertTrue(times.isEmpty)
    }

    func testACaptureThatNeverReturnsFreesTheSlotAtItsDeadline() async throws {
        let replies = PeekCaptureReplies()
        let slot = LensPeekCapture(capture: { try await replies.capture($0, size: $1) }, deadline: .milliseconds(50))
        let picture = try image()
        slot.select(1, pixelSize: CGSize(width: 100, height: 100))
        while !(await replies.ready(1)) { await Task.yield() }
        slot.select(2, pixelSize: CGSize(width: 100, height: 100))
        // No further selection: the waiting request starts on its own once the deadline passes.
        while !(await replies.ready(2)) { await Task.yield() }
        XCTAssertEqual(slot.outstandingCount, 2)
        let current = slot.task
        await replies.finish(2, image: picture)
        await current?.value
        XCTAssertTrue(slot.image === picture, "A stuck capture does not hold up the next picture")
        await replies.finish(1, image: try image())
        while slot.outstandingCount != 0 { await Task.yield() }
        XCTAssertTrue(slot.image === picture, "The stuck capture's late image is not drawn")
    }

    func testASlowCaptureForTheWindowStillWantedIsKept() async throws {
        let replies = PeekCaptureReplies()
        let slot = LensPeekCapture(capture: { try await replies.capture($0, size: $1) }, deadline: .milliseconds(20))
        var times: [Double] = []; slot.completed = { times.append($0) }
        let picture = try image()
        slot.select(1, pixelSize: CGSize(width: 10, height: 10))
        while !(await replies.ready(1)) { await Task.yield() }
        try await Task.sleep(for: .milliseconds(60))
        let current = slot.task
        await replies.finish(1, image: picture)
        await current?.value
        XCTAssertTrue(slot.image === picture, "A capture that outlasts its deadline still shows")
        XCTAssertEqual(times.count, 1)
        let count = await replies.count[1]
        XCTAssertEqual(count, 1, "The same window is not captured again")
    }

    func testTwoStuckCapturesStopFurtherCaptures() async throws {
        let replies = PeekCaptureReplies()
        let slot = LensPeekCapture(capture: { try await replies.capture($0, size: $1) }, deadline: .milliseconds(20))
        slot.select(1, pixelSize: CGSize(width: 10, height: 10))
        while !(await replies.ready(1)) { await Task.yield() }
        slot.select(2, pixelSize: CGSize(width: 10, height: 10))
        while !(await replies.ready(2)) { await Task.yield() }
        XCTAssertEqual(slot.outstandingCount, 2)
        slot.select(3, pixelSize: CGSize(width: 10, height: 10))
        try await Task.sleep(for: .milliseconds(60))
        let third = await replies.requested(3)
        XCTAssertFalse(third, "A wedged ScreenCaptureKit is not given more requests")
        await replies.finish(1, image: try image())
        // Once ScreenCaptureKit answers again, the window still selected is captured.
        while !(await replies.ready(3)) { await Task.yield() }
    }

    func testAFailedCaptureIsNotRetriedFastOrSlow() async throws {
        let replies = PeekCaptureReplies()
        let slot = LensPeekCapture(capture: { try await replies.capture($0, size: $1) }, deadline: .milliseconds(20))
        slot.select(1, pixelSize: CGSize(width: 10, height: 10))
        while !(await replies.ready(1)) { await Task.yield() }
        try await Task.sleep(for: .milliseconds(60))
        await replies.fail(1)
        try await Task.sleep(for: .milliseconds(60))
        let count = await replies.count[1]
        XCTAssertEqual(count, 1)
        XCTAssertNil(slot.image)
    }

    func testACaptureFromBeforeAFreezeIsNotKeptAfterTheRestore() async throws {
        let replies = PeekCaptureReplies()
        let slot = LensPeekCapture { try await replies.capture($0, size: $1) }
        slot.select(1, pixelSize: CGSize(width: 10, height: 10))
        while !(await replies.ready(1)) { await Task.yield() }
        let early = slot.task
        slot.select(1, frozen: true, pixelSize: CGSize(width: 10, height: 10))
        slot.select(1, frozen: false, pixelSize: CGSize(width: 10, height: 10))
        await replies.finish(1, image: try image())
        await early?.value
        XCTAssertNil(slot.image, "The picture from before the window was minimized is not shown")
        while !(await replies.ready(1)) { await Task.yield() }
        let count = await replies.count[1]
        XCTAssertEqual(count, 2, "The restored window is captured again")
    }

    func testAWindowThatStopsBeingFrozenIsCapturedThen() async throws {
        let replies = PeekCaptureReplies()
        let slot = LensPeekCapture { try await replies.capture($0, size: $1) }
        slot.select(1, frozen: true, pixelSize: CGSize(width: 100, height: 100))
        for _ in 0 ..< 20 { await Task.yield() }
        let frozenRequested = await replies.requested(1)
        XCTAssertFalse(frozenRequested)
        slot.select(1, frozen: false, pixelSize: CGSize(width: 100, height: 100))
        while !(await replies.ready(1)) { await Task.yield() }
        let first = slot.task
        await replies.finish(1, image: try image())
        await first?.value
        XCTAssertNotNil(slot.image)
        slot.select(1, frozen: true, pixelSize: CGSize(width: 100, height: 100))
        XCTAssertNil(slot.image, "A window minimized again shows its thumbnail, not the old capture")
        slot.select(1, frozen: false, pixelSize: CGSize(width: 100, height: 100))
        while !(await replies.ready(1)) { await Task.yield() }
    }

    func testAnImageForTheWindowSelectedAgainIsKept() async throws {
        let replies = PeekCaptureReplies()
        let slot = LensPeekCapture { try await replies.capture($0, size: $1) }
        let picture = try image()
        slot.select(1, pixelSize: CGSize(width: 100, height: 100))
        while !(await replies.ready(1)) { await Task.yield() }
        let first = slot.task
        slot.select(2, pixelSize: CGSize(width: 100, height: 100))
        slot.select(1, pixelSize: CGSize(width: 100, height: 100))
        await replies.finish(1, image: picture)
        await first?.value
        XCTAssertTrue(slot.image === picture)
        for _ in 0 ..< 20 { await Task.yield() }
        let again = await replies.ready(1)
        XCTAssertFalse(again, "The same window is not captured twice")
    }

    func testLabelStaysOnScreenUnderAFullHeightWindow() {
        XCTAssertEqual(peekLabelOffset(pictureBottom: 500, screenHeight: 720), 44)
        XCTAssertEqual(peekLabelOffset(pictureBottom: 714, screenHeight: 720), -6)
    }

    func testOriginConvertsTopLeftAndAnotherScreenFades() {
        let tile = CGRect(x: 20, y: 30, width: 100, height: 60)
        let lens = CGRect(x: 300, y: 200, width: 500, height: 300)
        let screen = CGRect(x: 0, y: 0, width: 1280, height: 720)
        XCTAssertEqual(peekTileOnScreen(tile, lensFrame: lens, screen: screen), CGRect(x: 320, y: 250, width: 100, height: 60))
        XCTAssertNil(peekTileOnScreen(tile, lensFrame: lens.offsetBy(dx: 1280, dy: 0), screen: screen))
        XCTAssertNil(peekTileOnScreen(nil, lensFrame: lens, screen: screen))
    }

    func testOpeningGrowsFromTileAndFadesWithoutOriginOrWithReduceMotion() {
        let tile = CGRect(x: 30, y: 40, width: 100, height: 60)
        let destination = CGRect(x: 100, y: 100, width: 1000, height: 600)
        let grow = PeekOpening(tile: tile, destination: destination, follow: false, reduceMotion: false)
        XCTAssertEqual(grow.rect, tile); XCTAssertEqual(grow.opacity, 1)
        let missing = PeekOpening(tile: nil, destination: destination, follow: false, reduceMotion: false)
        XCTAssertEqual(missing.rect, destination); XCTAssertEqual(missing.opacity, 0)
        let reduced = PeekOpening(tile: tile, destination: destination, follow: false, reduceMotion: true)
        XCTAssertEqual(reduced.rect, destination); XCTAssertEqual(reduced.opacity, 0)
        let follow = PeekOpening(tile: nil, destination: destination, follow: true, reduceMotion: false)
        XCTAssertEqual(follow.rect, destination); XCTAssertEqual(follow.opacity, 1, "Follow is present from its first frame")
    }

    func testLabelNamesAutomaticAndNamedWorkspacesOnce() {
        XCTAssertEqual(peekLabel(title: "Note", app: "Notes", workspace: "Workspace 1"), "Note · Notes · Workspace 1")
        XCTAssertEqual(peekLabel(title: "File", app: "Zed", workspace: "Design"), "File · Zed · Workspace Design")
    }

    private func solid(_ color: CGColor) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 64,
                                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(color); context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        return try XCTUnwrap(context.makeImage())
    }

    private func render(_ drawing: LensPeekDrawing) throws -> NSBitmapImageRep {
        let slot = LensPeekCapture()
        let view = LensPeekView(drawing: drawing, capture: slot).frame(width: 240, height: 140)
        let renderer = ImageRenderer(content: view); renderer.scale = 1
        return NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
    }

    func testMissingThumbnailDrawsAppIconOnOpaquePlainPlate() throws {
        let icon = NSImage(cgImage: try solid(CGColor(red: 1, green: 0, blue: 0, alpha: 1)), size: CGSize(width: 16, height: 16))
        for thumbnail: WindowThumbnail? in [nil, WindowThumbnail()] {
            let drawing = LensPeekDrawing()
            drawing.rect = CGRect(x: 20, y: 20, width: 200, height: 100)
            drawing.opacity = 1; drawing.follow = true; drawing.frozen = true
            drawing.thumbnail = thumbnail; drawing.icon = icon
            let bitmap = try render(drawing)
            let center = try XCTUnwrap(bitmap.colorAt(x: 120, y: 70)).usingColorSpace(.deviceRGB)!
            XCTAssertGreaterThan(center.redComponent, 0.8)
            XCTAssertGreaterThan(center.redComponent - center.greenComponent, 0.5)
            XCTAssertGreaterThan(center.redComponent - center.blueComponent, 0.5)
            let plate = try XCTUnwrap(bitmap.colorAt(x: 40, y: 70)).usingColorSpace(.deviceRGB)!
            XCTAssertEqual(plate.alphaComponent, 1, accuracy: 0.01)
            XCTAssertLessThan(plate.redComponent, 0.25)
            XCTAssertEqual(plate.redComponent, plate.greenComponent, accuracy: 0.01)
        }
    }

    func testFrozenPeekUsesItsConfiguredAppearanceOverThePlate() throws {
        let thumbnail = WindowThumbnail(); thumbnail.accept(try solid(CGColor(gray: 1, alpha: 1)))
        let drawing = LensPeekDrawing()
        drawing.rect = CGRect(x: 20, y: 20, width: 200, height: 100)
        drawing.opacity = 1; drawing.follow = true; drawing.frozen = true; drawing.thumbnail = thumbnail
        drawing.look = "plain"
        let plain = try XCTUnwrap(render(drawing).colorAt(x: 120, y: 70)).usingColorSpace(.deviceRGB)!
        drawing.look = "dimmed"
        let dimmed = try XCTUnwrap(render(drawing).colorAt(x: 120, y: 70)).usingColorSpace(.deviceRGB)!
        XCTAssertEqual(plain.alphaComponent, 1, accuracy: 0.01)
        XCTAssertEqual(dimmed.alphaComponent, 1, accuracy: 0.01)
        XCTAssertLessThan(dimmed.redComponent, plain.redComponent - 0.2)
    }

    func testPictureFitsItsOwnAspectInRealFrame() {
        let frame = CGRect(x: 100, y: 200, width: 800, height: 600)
        XCTAssertEqual(peekFittedRect(aspect: 2, in: frame), CGRect(x: 100, y: 300, width: 800, height: 400))
        XCTAssertEqual(peekFittedRect(aspect: 0.5, in: frame), CGRect(x: 350, y: 200, width: 300, height: 600))
    }
}
