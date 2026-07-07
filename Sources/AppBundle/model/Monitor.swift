import AppKit
import Common
import CoreGraphics

private struct MonitorImpl {
    let monitorAppKitNsScreenScreensId: Int
    let name: String
    let rect: Rect
    let visibleRect: Rect
    let isMain: Bool
}

extension MonitorImpl: Monitor {
    var height: CGFloat { rect.height }
    var width: CGFloat { rect.width }
}

/// Use it instead of NSScreen because it can be mocked in tests
protocol Monitor: WinMuxAny {
    /// The index in NSScreen.screens array. 1-based index
    var monitorAppKitNsScreenScreensId: Int { get }
    var name: String { get }
    var rect: Rect { get }
    var visibleRect: Rect { get }
    var width: CGFloat { get }
    var height: CGFloat { get }
    var isMain: Bool { get }
    var columnId: String? { get }
    var columnName: String? { get }
    var columnLayoutId: String? { get }
    var zoneStyleId: String? { get }
    var columnColorHex: String? { get }
    var isDefaultColumn: Bool { get }
    var physicalMonitor: Monitor { get }
}

extension Monitor {
    var columnId: String? { nil }
    var columnName: String? { nil }
    var columnLayoutId: String? { nil }
    var zoneStyleId: String? { nil }
    var columnColorHex: String? { nil }
    var isDefaultColumn: Bool { false }
    var physicalMonitor: Monitor { self }
}

final class LazyMonitor: Monitor {
    private let screen: NSScreen
    let monitorAppKitNsScreenScreensId: Int
    let name: String
    let width: CGFloat
    let height: CGFloat
    let isMain: Bool
    private var _rect: Rect?
    private var _visibleRect: Rect?

    init(monitorAppKitNsScreenScreensId: Int, isMain: Bool, _ screen: NSScreen) {
        self.monitorAppKitNsScreenScreensId = monitorAppKitNsScreenScreensId
        self.name = screen.localizedName
        self.width = screen.frame.width // Don't call rect because it would cause recursion during mainMonitor init
        self.height = screen.frame.height // Don't call rect because it would cause recursion during mainMonitor init
        self.screen = screen
        self.isMain = isMain
    }

    var rect: Rect {
        _rect ?? screen.rect.also { _rect = $0 }
    }

    var visibleRect: Rect {
        _visibleRect ?? screen.visibleRect.also { _visibleRect = $0 }
    }
}

// Note to myself: Don't use NSScreen.main, it's garbage
// 1. The name is misleading, it's supposed to be called "focusedScreen"
// 2. It's inaccurate because NSScreen.main doesn't work correctly from NSWorkspace.didActivateApplicationNotification &
//    kAXFocusedWindowChangedNotification callbacks.
extension NSScreen {
    var displayId: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDirectDisplayID(truncating: $0) }
    }

    fileprivate func toMonitor(monitorAppKitNsScreenScreensId: Int) -> Monitor {
        MonitorImpl(
            monitorAppKitNsScreenScreensId: monitorAppKitNsScreenScreensId,
            name: localizedName,
            rect: rect,
            visibleRect: visibleRect,
            isMain: isMainScreen,
        )
    }

    fileprivate var isMainScreen: Bool {
        displayId == CGMainDisplayID()
    }

    /// The property is a replacement for Apple's crazy ``frame``
    ///
    /// - For ``MacWindow.topLeftCorner``, (0, 0) is main screen top left corner, and positive y-axis goes down.
    /// - For ``frame``, (0, 0) is main screen bottom left corner, and positive y-axis goes up (which is crazy).
    ///
    /// The property "normalizes" ``frame``
    fileprivate var rect: Rect { frame.monitorFrameNormalized() }

    /// Same as ``rect`` but for ``visibleFrame``
    fileprivate var visibleRect: Rect { visibleFrame.monitorFrameNormalized() }
}

private let testMonitorRect = Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080)
private let testMonitor = MonitorImpl(
    monitorAppKitNsScreenScreensId: 1,
    name: "Test Monitor",
    rect: testMonitorRect,
    visibleRect: testMonitorRect,
    isMain: true,
)
nonisolated(unsafe) private var monitorsOverrideForTests: [Monitor]? = nil

@MainActor
func setMonitorsForTests(_ monitors: [Monitor]?) {
    monitorsOverrideForTests = monitors
    invalidateMonitorCaches()
}

var mainMonitor: Monitor {
    if isUnitTest, let monitor = monitorsOverrideForTests?.first(where: \.isMain) ?? monitorsOverrideForTests?.first {
        return monitor
    }
    if isUnitTest { return testMonitor }
    let screens = NSScreen.screens
    // Fallback: If main screen can't be found (e.g., during display reconfiguration),
    // return screens.first or testMonitor to avoid crash
    let screen = screens.withIndex.singleOrNil(where: \.value.isMainScreen) ?? screens.first.map { (0, $0) }
    guard let screen else { return testMonitor }
    return LazyMonitor(monitorAppKitNsScreenScreensId: screen.index + 1, isMain: true, screen.value)
}

// Rebuilding the monitor list from NSScreen on every access is wasteful: `monitors` and
// `sortedMonitors` are hit on every focus change, layout pass, and pointer event. Cache the
// result and invalidate when macOS reports a screen configuration change. Main-thread only:
// NSScreen must be accessed from the main thread anyway, so off-main callers compute fresh.
nonisolated(unsafe) private var monitorsCache: [Monitor]? = nil
nonisolated(unsafe) private var sortedMonitorsCache: [Monitor]? = nil
nonisolated(unsafe) private var physicalMonitorsCache: [Monitor]? = nil
nonisolated(unsafe) private var sortedPhysicalMonitorsCache: [Monitor]? = nil
nonisolated(unsafe) private var monitorsCacheObserver: NSObjectProtocol? = nil

private func computePhysicalMonitors() -> [Monitor] {
    let screens = NSScreen.screens
    guard !screens.isEmpty else { return [mainMonitor] }
    return screens.withIndex.map { index, screen in
        screen.toMonitor(monitorAppKitNsScreenScreensId: index + 1)
    }
}

private func computeWorkspaceViewports() -> [Monitor] {
    getCurrentColumnTopologySnapshot().workspaceViewports(for: computePhysicalMonitors())
}

func invalidateMonitorCaches() {
    physicalMonitorsCache = nil
    sortedPhysicalMonitorsCache = nil
    monitorsCache = nil
    sortedMonitorsCache = nil
    invalidateColumnDividerHandlesCache()
}

var physicalMonitors: [Monitor] {
    if isUnitTest, let override = monitorsOverrideForTests {
        return override
    }
    if isUnitTest { return [mainMonitor] }
    guard Thread.isMainThread else { return computePhysicalMonitors() }
    if monitorsCacheObserver == nil {
        monitorsCacheObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main,
        ) { _ in
            invalidateMonitorCaches()
        }
    }
    if let cached = physicalMonitorsCache { return cached }
    let computed = computePhysicalMonitors()
    physicalMonitorsCache = computed
    return computed
}

var sortedPhysicalMonitors: [Monitor] {
    if Thread.isMainThread, !isUnitTest, let cached = sortedPhysicalMonitorsCache { return cached }
    let sorted = sortMonitorsBySpatialOrder(physicalMonitors)
    if Thread.isMainThread, !isUnitTest { sortedPhysicalMonitorsCache = sorted }
    return sorted
}

var workspaceViewports: [Monitor] {
    if isUnitTest {
        return getCurrentColumnTopologySnapshot().workspaceViewports(for: physicalMonitors)
    }
    guard Thread.isMainThread else { return computeWorkspaceViewports() }
    if let cached = monitorsCache { return cached }
    let computed = getCurrentColumnTopologySnapshot().workspaceViewports(for: physicalMonitors)
    monitorsCache = computed
    return computed
}

var monitors: [Monitor] { workspaceViewports }

var sortedMonitors: [Monitor] {
    if Thread.isMainThread, !isUnitTest, let cached = sortedMonitorsCache { return cached }
    let sorted = sortMonitorsBySpatialOrder(monitors)
    if Thread.isMainThread, !isUnitTest { sortedMonitorsCache = sorted }
    return sorted
}
