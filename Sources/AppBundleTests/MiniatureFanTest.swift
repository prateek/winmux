@testable import AppBundle
import AppKit
import XCTest

final class MiniatureFanTest: XCTestCase {
    private func frames(count: Int, active: Int, frame: CGRect = CGRect(x: 20, y: 40, width: 400, height: 300), cellWidth: CGFloat = 820) -> [CGRect] {
        (0 ..< count).map { MiniatureLayout.fan(frame, count: count, index: $0, activeIndex: active, cellWidth: cellWidth) }
    }

    func testThreeTabsKeepActiveAtOriginAndOtherTabsInOrder() {
        XCTAssertEqual(frames(count: 3, active: 0), [
            CGRect(x: 20, y: 40, width: 368, height: 268),
            CGRect(x: 36, y: 56, width: 368, height: 268),
            CGRect(x: 52, y: 72, width: 368, height: 268),
        ])
    }

    func testTwoTabsScalePrototypeOffsetWithCellWidth() {
        XCTAssertEqual(frames(count: 2, active: 0, cellWidth: 410), [
            CGRect(x: 20, y: 40, width: 392, height: 292),
            CGRect(x: 28, y: 48, width: 392, height: 292),
        ])
    }

    func testLargeGroupLimitsTotalInsetToQuarterOfSmallerSide() {
        let source = CGRect(x: 20, y: 40, width: 400, height: 120)
        let result = frames(count: 11, active: 0, frame: source)
        XCTAssertEqual(result[0], CGRect(x: 20, y: 40, width: 370, height: 90))
        XCTAssertEqual(result[1].minX - result[0].minX, 3)
        XCTAssertEqual(result.last?.maxX, source.maxX)
        XCTAssertEqual(result.last?.maxY, source.maxY)
        XCTAssertTrue(result.allSatisfy { source.contains($0) })
    }

    func testActiveTabInMiddleMovesToFrontWithoutReorderingOthers() {
        XCTAssertEqual(frames(count: 3, active: 1), [
            CGRect(x: 36, y: 56, width: 368, height: 268),
            CGRect(x: 20, y: 40, width: 368, height: 268),
            CGRect(x: 52, y: 72, width: 368, height: 268),
        ])
    }

    func testNearestReachesTabsEvenWhenOffsetIsLessThanOnePoint() {
        let rects = frames(count: 3, active: 0, frame: CGRect(x: 0, y: 0, width: 10, height: 10), cellWidth: 20)
        let geometry = Dictionary(uniqueKeysWithValues: rects.enumerated().map { (UInt32($0.offset + 1), $0.element) })
        XCTAssertEqual(MiniatureLayout.nearest(from: 1, direction: .right, frames: geometry, matches: [1, 2, 3]), 2)
        XCTAssertEqual(MiniatureLayout.nearest(from: 2, direction: .down, frames: geometry, matches: [1, 2, 3]), 3)
    }

    func testSingleWindowBesideGroupKeepsItsFrame() {
        let source = CGRect(x: 430, y: 40, width: 300, height: 300)
        XCTAssertEqual(MiniatureLayout.fan(source, count: 1, index: 0, activeIndex: 0, cellWidth: 820), source)
        XCTAssertEqual(frames(count: 3, active: 0).last?.maxX, 420)
    }
}

@MainActor
final class MiniatureTabSnapshotTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSnapshotUsesNearestGroupFrameAndActiveTabWhenInactiveFrameIsMissing() throws {
        let root = Workspace.get(byName: "1").rootTilingContainer
        let group = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .h, .tabGroup, index: INDEX_BIND_LAST)
        let windows = (1 ... 3).map { TestWindow.new(id: UInt32($0), parent: group) }
        group.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 40, topLeftY: 60, width: 400, height: 300)
        windows[1].markAsMostRecentChild()
        XCTAssertNil(windows[0].lastAppliedLayoutPhysicalRect)
        for (index, window) in windows.enumerated() {
            let tab = try XCTUnwrap(miniatureTabSnapshot(window, tray: false))
            XCTAssertEqual(tab.group, ObjectIdentifier(group))
            XCTAssertEqual(tab.frame, CGRect(x: 40, y: 60, width: 400, height: 300))
            XCTAssertEqual(tab.index, index)
            XCTAssertEqual(tab.activeIndex, 1)
            XCTAssertEqual(tab.count, 3)
        }
        let frozenSnapshot = try XCTUnwrap(miniatureTabSnapshot(windows[0], tray: false))
        windows[2].markAsMostRecentChild()
        XCTAssertEqual(frozenSnapshot.activeIndex, 1)
        XCTAssertEqual(miniatureTabSnapshot(windows[0], tray: false)?.activeIndex, 2)
        XCTAssertNil(miniatureTabSnapshot(windows[0], tray: true))
        let floating = TestWindow.new(id: 4, parent: Workspace.get(byName: "1"))
        XCTAssertNil(miniatureTabSnapshot(floating, tray: false))
        let beside = TestWindow.new(id: 5, parent: root)
        XCTAssertNil(miniatureTabSnapshot(beside, tray: false))
    }

    func testNestedGroupsKeepDistinctIdentitiesAndUseNearestFrame() throws {
        let root = Workspace.get(byName: "1").rootTilingContainer
        let outer = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .h, .tabGroup, index: INDEX_BIND_LAST)
        let inner = TilingContainer(parent: outer, adaptiveWeight: WEIGHT_AUTO, .v, .tabGroup, index: INDEX_BIND_LAST)
        let first = TestWindow.new(id: 1, parent: inner)
        _ = TestWindow.new(id: 2, parent: inner)
        let beside = TestWindow.new(id: 3, parent: outer)
        inner.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 40, topLeftY: 60, width: 400, height: 300)
        outer.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 20, topLeftY: 20, width: 600, height: 400)
        let innerTab = try XCTUnwrap(miniatureTabSnapshot(first, tray: false))
        let outerTab = try XCTUnwrap(miniatureTabSnapshot(beside, tray: false))
        XCTAssertNotEqual(innerTab.group, outerTab.group)
        XCTAssertEqual(innerTab.frame, CGRect(x: 40, y: 60, width: 400, height: 300))
        XCTAssertEqual(outerTab.frame, CGRect(x: 20, y: 20, width: 600, height: 400))
    }

    func testSingleChildTabContainerDoesNotFan() {
        let root = Workspace.get(byName: "1").rootTilingContainer
        root.layout = .tabGroup
        let window = TestWindow.new(id: 1, parent: root)
        root.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 400, height: 300)
        XCTAssertNil(miniatureTabSnapshot(window, tray: false))
    }
}
