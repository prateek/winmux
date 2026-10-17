@testable import AppBundle
import XCTest

@MainActor
final class MonitorStartupRefreshTest: XCTestCase {
    func testMonitorPreparationDoesNotRaceStartupWindowDiscovery() {
        var chromeRefreshes = 0
        var refreshes: [String] = []
        let observer = MonitorConfigurationObserver(refreshChrome: { chromeRefreshes += 1 },
            scheduleRefresh: { refreshes.append($0) })
        observer.prepareForStartup()
        XCTAssertEqual(chromeRefreshes, 1)
        XCTAssertEqual(refreshes, [])
        observer.refreshMonitorPolicy(refreshReason: "display changed")
        XCTAssertEqual(chromeRefreshes, 2)
        XCTAssertEqual(refreshes, ["display changed"])
    }
}
