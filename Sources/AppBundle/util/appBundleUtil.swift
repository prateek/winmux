import AppKit
import Common
import Foundation
import os

let lensOpeningRecordingGate = OSSignposter(subsystem: winMuxAppId, category: .dynamicTracing)
let lensOpeningSignposter = OSSignposter(subsystem: winMuxAppId, category: "lens-opening")

let signposter = OSSignposter(subsystem: winMuxAppId, category: .pointsOfInterest)

let myPid = NSRunningApplication.current.processIdentifier
let lockScreenAppBundleId = "com.apple.loginwindow"

@MainActor
func initTerminationHandler() {
    terminationHandler = AppServerTerminationHandler()
}

private struct AppServerTerminationHandler: TerminationHandler {
    func beforeTermination() async throws {
        try await terminationOnce.run {
            systemSymbolicHotkeys.restoreAndShutDown()
            persistFrozenWorldForRestartIfPossible()
            await restoreWindowsOnQuit()
            if await !isRelaunchingForSetup { await toggleReleaseServerIfDebug(.on) }
        }
    }
}

@MainActor
private func restoreWindowsOnQuit() async {
    let start = ContinuousClock.now
    windowFramesForTermination.freeze()
    let draggedAside = WindowMouseInteractionOpacityController.shared.endForTermination()
    // Shutdown also runs with a damaged or unbound tree.
    let windows = MacWindow.allWindowsMap
    let displays = monitors
    let main = mainMonitor
    let plans = windows.values.sorted { $0.windowId < $1.windowId }.map { window in
        QuitWindowFrame(appId: window.macApp.pid, windowId: window.windowId,
            action: quitFrameAction(record: startupWindowFrames[window.windowId], hidden: window.isHiddenInCorner,
                parkedOn: window.hiddenOnMonitorVisibleRect, draggedAsideFrom: draggedAside[window.windowId],
                lastKnownFrame: window.lastKnownActualRect ?? window.lastAppliedLayoutPhysicalRect,
                floatingSize: window.lastFloatingSize,
                restoreOriginal: config.restoreWindowsOnQuit, monitors: displays, main: main))
    }
    await restoreQuitWindowFrames(plans, write: { id, frame in
        try await windows[id]?.macApp.restoreFrameOnQuit(id, frame)
    }, failed: { plan, error in
        quitFramesLog.error("Quit frame window=\(plan.windowId) action=\(plan.action.name, privacy: .public) failed: \(String(describing: error), privacy: .public)")
    })
    let elapsed = start.duration(to: .now)
    quitFramesLog.info("Quit frames finished duration=\(String(describing: elapsed), privacy: .public) windows=\(plans.count)")
}

extension String {
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(self, forType: .string)
    }
}

func - (a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x - b.x, y: a.y - b.y)
}

func + (a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x + b.x, y: a.y + b.y)
}

extension CGPoint: ConvenienceCopyable {}

extension CGPoint {
    func distance(toOuterFrame rect: Rect) -> CGFloat {
        if rect.contains(self) {
            return 0
        }
        let list: [CGFloat] =
            (rect.minY.until(excl: rect.maxY)?.contains(y) == true ? [abs(rect.minX - x), abs(rect.maxX - x)] : []) +
            (rect.minX.until(excl: rect.maxX)?.contains(x) == true ? [abs(rect.minY - y), abs(rect.maxY - y)] : []) +
            [
                distance(to: rect.topLeftCorner),
                distance(to: rect.bottomRightCorner),
                distance(to: rect.topRightCorner),
                distance(to: rect.bottomLeftCorner),
            ]
        return list.minOrDie()
    }

    func coerce(in rect: Rect) -> CGPoint? {
        guard let xRange = rect.minX.until(incl: rect.maxX - 1) else { return nil }
        guard let yRange = rect.minY.until(incl: rect.maxY - 1) else { return nil }
        return CGPoint(x: x.coerce(in: xRange), y: y.coerce(in: yRange))
    }

    func addingXOffset(_ offset: CGFloat) -> CGPoint { CGPoint(x: x + offset, y: y) }
    func addingYOffset(_ offset: CGFloat) -> CGPoint { CGPoint(x: x, y: y + offset) }
    func addingOffset(_ orientation: Orientation, _ offset: CGFloat) -> CGPoint { orientation == .h ? addingXOffset(offset) : addingYOffset(offset) }

    func getProjection(_ orientation: Orientation) -> Double { orientation == .h ? x : y }

    var vectorLength: CGFloat { sqrt(x * x + y * y) }

    func distance(to point: CGPoint) -> Double { (self - point).vectorLength }

    var monitorApproximation: Monitor {
        monitors.first { $0.rect.contains(self) } ?? monitors.minByOrDie { distance(toOuterFrame: $0.rect) }
    }
}

extension CGFloat {
    func div(_ denominator: Int) -> CGFloat? {
        denominator == 0 ? nil : self / CGFloat(denominator)
    }

    func coerce(in range: ClosedRange<CGFloat>) -> CGFloat {
        switch true {
            case self > range.upperBound: range.upperBound
            case self < range.lowerBound: range.lowerBound
            default: self
        }
    }
}

extension CGPoint: @retroactive Hashable { // todo migrate to self written Point
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

#if DEBUG
    let isDebug = true
#else
    let isDebug = false
#endif

func debugFocusLog(_ message: @autoclosure () -> String) {
    guard isDebug else { return }
    fputs("[focus-debug] \(Date()) \(message())\n", stderr)
}

func debugWorkspaceSidebarRenameLog(_ message: @autoclosure () -> String) {
    guard isDebug else { return }
    fputs("[sidebar-rename-debug] \(Date()) \(message())\n", stderr)
}

func debugWorkspaceSidebarHoverLog(_ message: @autoclosure () -> String) {
    guard isDebug, ProcessInfo.processInfo.environment["WINMUX_DEBUG_SIDEBAR_HOVER"] == "1" else { return }
    fputs("[sidebar-hover-debug] \(Date()) \(message())\n", stderr)
}

func debugWorkspaceSidebarEdgeTrapLog(_ message: @autoclosure () -> String) {
    guard isDebug, ProcessInfo.processInfo.environment["WINMUX_DEBUG_SIDEBAR_EDGE_TRAP"] == "1" else { return }
    fputs("[sidebar-edge-trap-debug] \(Date()) \(message())\n", stderr)
}

func debugWorkspaceSidebarProjectLog(_ message: @autoclosure () -> String) {
    guard isDebug, ProcessInfo.processInfo.environment["WINMUX_DEBUG_SIDEBAR_PROJECT"] == "1" else { return }
    fputs("[sidebar-project-debug] \(Date()) \(message())\n", stderr)
}

@inlinable
func checkCancellation() throws(CancellationError) {
    if Task.isCancelled {
        throw CancellationError()
    }
}
