@testable import AppBundle
import XCTest

final class WindowCaptureTargetTest: XCTestCase {
    private let page = CGRect(x: 100, y: 80, width: 913, height: 700)
    private var strip: CGRect { CGRect(x: 0, y: 1080, width: 913, height: 16) }

    private func candidate(_ id: UInt32, pid: Int32? = 42, frame: CGRect? = nil, layer: Int = 0) -> WindowCaptureCandidate {
        WindowCaptureCandidate(id: id, ownerPID: pid, frame: frame ?? page, layer: layer)
    }

    private func choose(_ candidates: [WindowCaptureCandidate], frame: CGRect? = nil) -> UInt32? {
        chooseWindowToCapture(WindowCaptureTarget(id: 1, ownerPID: 42, entryFrame: frame ?? page), from: candidates)
    }

    func testOwnWindowWinsEvenWhenAnotherWindowAgrees() {
        XCTAssertEqual(choose([candidate(2), candidate(1)]), 1)
    }

    func testThinHelperFallsBackToItsOwnersPage() {
        XCTAssertEqual(choose([candidate(1, frame: strip), candidate(2)]), 2)
    }

    func testSameSizedPagesAreToldApartByPosition() {
        let elsewhere = page.offsetBy(dx: 950, dy: 0)
        XCTAssertEqual(choose([candidate(1, frame: strip), candidate(2, frame: elsewhere), candidate(3)]), 3)
    }

    func testSliverWithNoMatchingPageFailsClosed() {
        XCTAssertNil(choose([candidate(1, frame: strip), candidate(2, frame: page.offsetBy(dx: 40, dy: 0))]))
        XCTAssertNil(choose([candidate(1, frame: strip), candidate(2), candidate(3)]), "Two matches are no choice")
        XCTAssertNil(choose([candidate(1, frame: strip), candidate(2, layer: 3)]), "A fallback must be layer 0")
    }

    func testOtherAppsPageIsNeverTheFallback() {
        XCTAssertNil(choose([candidate(1, frame: strip), candidate(2, pid: 99)]))
    }

    func testOwnWindowOfAnotherProcessKeepsItsId() {
        // A sandboxed app's open panel is drawn by an XPC service.
        XCTAssertEqual(choose([candidate(1, pid: 99), candidate(2)]), 1)
        XCTAssertEqual(choose([candidate(1, pid: nil), candidate(2)]), 1)
    }

    func testOwnDialogAboveLayerZeroKeepsItsId() {
        let dialog = CGRect(x: 740, y: 400, width: 440, height: 202)
        let bar = CGRect(x: 0, y: 0, width: 1920, height: 30)
        XCTAssertEqual(choose([candidate(1, frame: dialog, layer: 3), candidate(2, frame: bar)], frame: dialog), 1)
    }

    func testOwnWindowKeepsItsIdThroughResizeOrMinimumSizeRefusal() {
        let resized = CGRect(x: 0, y: 40, width: page.width + 100, height: page.height + 100)
        XCTAssertEqual(choose([candidate(1, frame: resized), candidate(2)]), 1)
        let refused = CGRect(x: page.minX, y: page.minY, width: 574, height: page.height)
        XCTAssertEqual(choose([candidate(1, frame: refused), candidate(2, frame: refused)], frame: CGRect(origin: page.origin, size: CGSize(width: 400, height: 700))), 1)
    }

    func testMissingIdHasNoFallback() {
        XCTAssertNil(choose([candidate(2)]))
    }

    func testFallbackAgainstALayoutFrameReachesOnlyAPageThatHonoursIt() {
        let layout = CGRect(x: 960, y: 40, width: 640, height: 1000)
        XCTAssertEqual(choose([candidate(1, frame: strip), candidate(2, frame: layout)], frame: layout), 2)
        let narrower = CGRect(x: 960, y: 40, width: 620, height: 1000)
        XCTAssertNil(choose([candidate(1, frame: strip), candidate(2, frame: narrower)], frame: layout))
    }

    func testToleranceIsTwoPointsOnEachFrameComponent() {
        let close = CGRect(x: page.minX + 2, y: page.minY - 2, width: page.width + 2, height: page.height - 2)
        XCTAssertEqual(choose([candidate(1, frame: strip), candidate(2, frame: close)]), 2)
        for frame in [page.offsetBy(dx: 2.1, dy: 0), page.offsetBy(dx: 0, dy: 2.1),
                      CGRect(x: page.minX, y: page.minY, width: page.width + 2.1, height: page.height),
                      CGRect(x: page.minX, y: page.minY, width: page.width, height: page.height + 2.1)] {
            XCTAssertNil(choose([candidate(1, frame: strip), candidate(2, frame: frame)]))
        }
    }

    func testSliverIsUnderFortyPointsAndAQuarterOnTheSameSide() {
        for size in [CGSize(width: 39, height: page.height), CGSize(width: page.width, height: 39)] {
            XCTAssertEqual(choose([candidate(1, frame: CGRect(origin: page.origin, size: size)), candidate(2)]), 2)
        }
        XCTAssertEqual(choose([candidate(1, frame: CGRect(x: 100, y: 80, width: 40, height: 40)), candidate(2)]), 1)
        let small = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertEqual(choose([candidate(1, frame: CGRect(x: 0, y: 0, width: 24, height: 100)), candidate(2, frame: small)], frame: small), 2)
        XCTAssertEqual(choose([candidate(1, frame: CGRect(x: 0, y: 0, width: 25, height: 100)), candidate(2, frame: small)], frame: small), 1)
    }

    func testWindowKeepingAFixedSizeInAWideTileIsNotASliver() {
        let tile = CGRect(x: 0, y: 40, width: 3440, height: 1400)
        XCTAssertEqual(choose([candidate(1, frame: CGRect(x: 0, y: 40, width: 800, height: 600))], frame: tile), 1)
        let unknown = CGRect(x: 0, y: 0, width: 800, height: 600)
        XCTAssertEqual(choose([candidate(1, frame: CGRect(x: 500, y: 300, width: 180, height: 60))], frame: unknown), 1, "A mini player against the default frame")
    }

    func testUnknownEntryFrameKeepsTheIdLookup() {
        let target = WindowCaptureTarget(id: 1, ownerPID: 42)
        XCTAssertEqual(chooseWindowToCapture(target, from: [candidate(1, frame: strip), candidate(2)]), 1)
        XCTAssertNil(chooseWindowToCapture(target, from: [candidate(2)]))
    }

    private func resolve(cachedOwn: WindowCaptureCandidate?, cachedOnly: Bool = true, fresh: [WindowCaptureCandidate]) async -> (UInt32?, Bool) {
        var refreshed = false
        let id = await resolveWindowToCapture(WindowCaptureTarget(id: 1, ownerPID: 42, entryFrame: page), cachedOwn: cachedOwn, cachedOnly: cachedOnly) {
            refreshed = true
            return fresh
        }
        return (id, refreshed)
    }

    func testCachedWholeOwnWindowAnswersWithoutAFreshList() async {
        let (id, refreshed) = await resolve(cachedOwn: candidate(1), fresh: [])
        XCTAssertEqual(id, 1)
        XCTAssertFalse(refreshed)
    }

    func testCachedSliverIsCheckedAgainOnAFreshList() async {
        var (id, refreshed) = await resolve(cachedOwn: candidate(1, frame: strip), fresh: [candidate(1), candidate(2)])
        XCTAssertEqual(id, 1, "The fresh list shows the own window whole")
        XCTAssertTrue(refreshed)
        (id, refreshed) = await resolve(cachedOwn: candidate(1, frame: strip), fresh: [candidate(1, frame: strip), candidate(2)])
        XCTAssertEqual(id, 2)
        (id, refreshed) = await resolve(cachedOwn: candidate(1, frame: strip), fresh: [candidate(1, frame: strip), candidate(2, frame: page.offsetBy(dx: 300, dy: 0))])
        XCTAssertNil(id, "Only the fresh list's frames choose another window")
    }

    func testMissingIdFailsOnTheCacheAndOtherwiseLooksOnAFreshList() async {
        var (id, refreshed) = await resolve(cachedOwn: nil, fresh: [candidate(1)])
        XCTAssertNil(id)
        XCTAssertFalse(refreshed)
        (id, refreshed) = await resolve(cachedOwn: nil, cachedOnly: false, fresh: [candidate(1)])
        XCTAssertEqual(id, 1)
        XCTAssertTrue(refreshed)
    }
}
