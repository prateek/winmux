import AppKit
import SwiftUI

struct WindowTabWidthHold {
    let width: CGFloat
    let stripWidth: CGFloat
    let tabCount: Int

    func isValid(stripWidth: CGFloat, tabCount: Int) -> Bool {
        abs(self.stripWidth - stripWidth) < 1 && tabCount <= self.tabCount
    }
}

struct WindowTabClosePointer {
    let stripId: ObjectIdentifier
    let hold: WindowTabWidthHold
}

/// How long a background close keeps focus where it was, for a window the app closes after the tab's wait.
let windowTabBackgroundCloseLifetime: TimeInterval = 5

/// The tab under the pointer, in the strip view's coordinate space; none while a drag is in progress.
func windowTabHover(pointer: CGPoint?, frames: [UInt32: CGRect], viewport: CGRect, dragging: Bool) -> UInt32? {
    guard !dragging, let pointer else { return nil }
    return windowTabAtPoint(pointer, frames: frames, viewport: viewport)
}

@MainActor
final class WindowTabCloseModel: ObservableObject {
    static var shared = WindowTabCloseModel()

    @Published private(set) var closingWindowIds: Set<UInt32> = []
    @Published private(set) var widthHolds: [ObjectIdentifier: WindowTabWidthHold] = [:]
    /// Background closes by window id, with the system uptime of the click.
    private(set) var backgroundCloses: [UInt32: TimeInterval] = [:]

    func begin(_ windowId: UInt32, pointer: WindowTabClosePointer?, now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        guard closingWindowIds.insert(windowId).inserted else { return false }
        backgroundCloses = backgroundCloses.filter { now - $0.value < windowTabBackgroundCloseLifetime }
        if focus.windowOrNil?.windowId == windowId {
            backgroundCloses.removeValue(forKey: windowId)
        } else {
            backgroundCloses[windowId] = now
        }
        if let pointer {
            let hold = pointer.hold
            let width = widthHolds[pointer.stripId].flatMap {
                $0.isValid(stripWidth: hold.stripWidth, tabCount: hold.tabCount) ? $0.width : nil
            } ?? hold.width
            widthHolds[pointer.stripId] = WindowTabWidthHold(width: width, stripWidth: hold.stripWidth, tabCount: hold.tabCount)
        }
        return true
    }

    func finish(_ windowId: UInt32) {
        closingWindowIds.remove(windowId)
    }

    /// Consumes the window's background-close record; true when its collection should leave focus alone.
    func shouldPreserveFocusOnCollection(
        _ windowId: UInt32,
        focusedWindowId: UInt32?,
        now: TimeInterval = ProcessInfo.processInfo.systemUptime,
    ) -> Bool {
        guard let closedAt = backgroundCloses.removeValue(forKey: windowId) else { return false }
        return now - closedAt < windowTabBackgroundCloseLifetime && focusedWindowId != windowId
    }

    func forgetBackgroundClose(_ windowId: UInt32) {
        backgroundCloses.removeValue(forKey: windowId)
    }

    func pointerLeftStrip(_ id: ObjectIdentifier) {
        widthHolds.removeValue(forKey: id)
    }

    func reconcileStrip(_ id: ObjectIdentifier, width: CGFloat, tabCount: Int) {
        if let hold = widthHolds[id], !hold.isValid(stripWidth: width, tabCount: tabCount) {
            pointerLeftStrip(id)
        }
    }
}

func windowTabAtPoint(_ point: CGPoint, frames: [UInt32: CGRect], viewport: CGRect = .infinite) -> UInt32? {
    guard viewport.contains(point) else { return nil }
    return frames.first { $0.value.contains(point) }?.key
}

@MainActor
@discardableResult
func closeWindowFromTabStrip(
    _ windowId: UInt32,
    fallbackWorkspace: String,
    pointer: WindowTabClosePointer? = nil,
) -> Task<Void, Error>? {
    guard let token: RunSessionGuard = .isServerEnabled,
          let window = Window.get(byId: windowId)
    else { return nil }
    let model = WindowTabCloseModel.shared
    guard model.begin(windowId, pointer: pointer) else { return nil }
    return Task { @MainActor in
        defer { model.finish(windowId) }
        let result = await window.requestClose(timeout: 1, tabStripSession: token)
        guard let token: RunSessionGuard = .isServerEnabled else { return }
        try await runLightSession(.menuBarButton, token) {
            if result == .sheetSeen, Window.get(byId: windowId) === window {
                model.forgetBackgroundClose(windowId)
                focusWindowFromTabStrip(windowId, fallbackWorkspace: fallbackWorkspace)
            }
        }
    }
}
