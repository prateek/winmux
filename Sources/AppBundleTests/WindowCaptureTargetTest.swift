@testable import AppBundle
import XCTest

final class WindowCaptureTargetTest: XCTestCase {
    private let page = CGRect(x: 100, y: 80, width: 913, height: 700)

    private func candidate(_ id: UInt32, pid: Int32? = 42, frame: CGRect? = nil, layer: Int = 0, onScreen: Bool = true) -> WindowCaptureCandidate {
        WindowCaptureCandidate(id: id, ownerPID: pid, frame: frame ?? page, layer: layer, onScreen: onScreen)
    }

    private var strip: CGRect { CGRect(x: 0, y: 1080, width: 913, height: 16) }

    private func choose(_ candidates: [WindowCaptureCandidate], frame: CGRect? = nil) -> UInt32? {
        chooseWindowToCapture(WindowCaptureTarget(id: 1, ownerPID: 42, actualFrame: frame ?? page), from: candidates)
    }

    func testOwnContentIdWinsEvenWhenAnotherWindowAgrees() {
        XCTAssertEqual(choose([candidate(2), candidate(1)]), 1)
    }

    func testThinHelperFallsBackToItsOwnersPage() {
        XCTAssertEqual(choose([candidate(1, frame: CGRect(x: 0, y: 1080, width: 913, height: 16)), candidate(2)]), 2)
    }

    func testSameSizedPagesAreDisambiguatedByPosition() {
        let elsewhere = page.offsetBy(dx: 950, dy: 0)
        XCTAssertEqual(choose([candidate(1, frame: strip), candidate(2, frame: elsewhere), candidate(3)]), 3)
    }

    func testDisagreeingHelperWithNoMatchingPageFailsClosed() {
        XCTAssertNil(choose([candidate(1, frame: strip), candidate(2, frame: page.offsetBy(dx: 40, dy: 0))]))
    }

    func testOtherOwnersPageIsNeverTheFallback() {
        XCTAssertNil(choose([candidate(1, frame: strip), candidate(2, pid: 99)]))
        XCTAssertNil(choose([candidate(1, pid: 99), candidate(2)]), "A wrong owner on the id is not grounds for substituting a different window")
    }

    func testNonContentIdStillAllowsOnlyItsEntryOwnersMatchingPage() {
        XCTAssertEqual(choose([candidate(1, pid: 99, frame: strip), candidate(2)]), 2)
    }

    func testOwnDialogAboveLayerZeroKeepsItsId() {
        let dialog = CGRect(x: 740, y: 400, width: 440, height: 202)
        let bar = CGRect(x: 0, y: 0, width: 1920, height: 30)
        XCTAssertEqual(choose([candidate(1, frame: dialog, layer: 3), candidate(2, frame: bar)], frame: dialog), 1)
    }

    func testOwnWindowWithUnknownOwnerKeepsItsId() {
        XCTAssertEqual(choose([candidate(1, pid: nil), candidate(2)]), 1)
    }

    func testOwnLayerZeroWindowKeepsIdDuringResizeOrMinimumSizeRefusal() {
        let resized = CGRect(x: 0, y: 40, width: page.width + 100, height: page.height + 100)
        XCTAssertEqual(choose([candidate(1, frame: resized), candidate(2)]), 1)
    }

    func testMissingIdNeedsExactlyOneMatchingContentWindow() {
        XCTAssertEqual(choose([candidate(2)]), 2)
        XCTAssertNil(choose([candidate(2), candidate(3)]))
        XCTAssertNil(choose([candidate(2, layer: 3)]))
    }

    func testToleranceIsTwoPointsOnEachFrameComponent() {
        let close = CGRect(x: page.minX + 2, y: page.minY - 2, width: page.width + 2, height: page.height - 2)
        XCTAssertEqual(choose([candidate(2, frame: close)]), 2)
        for frame in [page.offsetBy(dx: 2.1, dy: 0), page.offsetBy(dx: 0, dy: 2.1),
                      CGRect(x: page.minX, y: page.minY, width: page.width + 2.1, height: page.height),
                      CGRect(x: page.minX, y: page.minY, width: page.width, height: page.height + 2.1)] {
            XCTAssertNil(choose([candidate(2, frame: frame)]))
        }
    }

    func testDegenerateWidthAndHeightUseStrictQuarterThreshold() {
        for size in [CGSize(width: page.width / 4 - 1, height: page.height), CGSize(width: page.width, height: page.height / 4 - 1)] {
            XCTAssertEqual(choose([candidate(1, frame: CGRect(origin: page.origin, size: size)), candidate(2)]), 2)
        }
        XCTAssertEqual(choose([candidate(1, frame: CGRect(x: 100, y: 80, width: page.width / 4, height: page.height / 4)), candidate(2)]), 1)
    }

    func testOffscreenContentIsStillCapturable() {
        XCTAssertEqual(choose([candidate(2, onScreen: false)]), 2)
        XCTAssertEqual(choose([candidate(1, onScreen: false)]), 1)
    }

    func testUnknownActualFrameKeepsLegacyIdLookup() {
        let target = WindowCaptureTarget(id: 1, ownerPID: 42)
        XCTAssertEqual(chooseWindowToCapture(target, from: [candidate(1, pid: 99, layer: 3)]), 1)
        XCTAssertNil(chooseWindowToCapture(target, from: [candidate(2)]))
    }
}
