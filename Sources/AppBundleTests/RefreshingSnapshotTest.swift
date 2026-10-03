@testable import AppBundle
import XCTest

private actor SnapshotLoader {
    var next = 0
    var immediate: Int?
    var pending: CheckedContinuation<Int?, Never>?
    var started: CheckedContinuation<Void, Never>?
    func load() async -> Int? {
        next += 1
        if let immediate { return immediate }
        started?.resume(); started = nil
        return await withCheckedContinuation { pending = $0 }
    }
    func waitForStart() async {
        if pending != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func finish(_ value: Int, nextImmediate: Int? = nil) { immediate = nextImmediate; pending?.resume(returning: value); pending = nil }
}

final class RefreshingSnapshotTest: XCTestCase {
    @ScreenshotWorker
    func testInvalidationKeepsOldValueAndRefetchesAfterInflightLoad() async {
        let loader = SnapshotLoader()
        let snapshot = RefreshingSnapshot<Int> { await loader.load() }
        let first = Task { @ScreenshotWorker in await snapshot.refresh() }
        await loader.waitForStart(); await loader.finish(1); await first.value
        XCTAssertEqual(snapshot.value, 1)
        snapshot.invalidate()
        let second = Task { @ScreenshotWorker in await snapshot.refresh() }
        await loader.waitForStart()
        snapshot.invalidate()
        XCTAssertEqual(snapshot.value, 1)
        await loader.finish(2, nextImmediate: 3)
        await second.value
        XCTAssertEqual(snapshot.value, 3)
        let starts = await loader.next
        XCTAssertEqual(starts, 3)
    }
}
