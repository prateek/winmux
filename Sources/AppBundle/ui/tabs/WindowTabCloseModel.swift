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
let windowTabBackgroundCloseLifetime: Duration = .seconds(5)

/// The tab under the pointer, in the strip view's coordinate space.
func windowTabHover(pointer: CGPoint?, frames: [UInt32: CGRect], viewport: CGRect) -> UInt32? {
    guard let pointer else { return nil }
    return windowTabAtPoint(pointer, frames: frames, viewport: viewport)
}

@MainActor
final class WindowTabCloseModel: ObservableObject {
    static var shared = WindowTabCloseModel()

    @Published private(set) var closingWindowIds: Set<UInt32> = []
    @Published private(set) var widthHolds: [ObjectIdentifier: WindowTabWidthHold] = [:]
    /// The tab under the pointer, per strip; kept here so hiding a strip can clear it.
    @Published private(set) var hoveredTabIds: [ObjectIdentifier: UInt32] = [:]
    /// Background closes by window id, with the time of the click on a clock that counts sleep.
    private(set) var backgroundCloses: [UInt32: ContinuousClock.Instant] = [:]

    func begin(_ windowId: UInt32, pointer: WindowTabClosePointer?, now: ContinuousClock.Instant = .now) -> Bool {
        guard closingWindowIds.insert(windowId).inserted else { return false }
        backgroundCloses = backgroundCloses.filter { $0.value.duration(to: now) < windowTabBackgroundCloseLifetime }
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
        now: ContinuousClock.Instant = .now,
    ) -> Bool {
        guard let closedAt = backgroundCloses.removeValue(forKey: windowId) else { return false }
        return closedAt.duration(to: now) < windowTabBackgroundCloseLifetime && focusedWindowId != windowId
    }

    func forgetBackgroundClose(_ windowId: UInt32) {
        backgroundCloses.removeValue(forKey: windowId)
    }

    func pointerLeftStrip(_ id: ObjectIdentifier) {
        widthHolds.removeValue(forKey: id)
        setHoveredTab(nil, stripId: id)
    }

    func setHoveredTab(_ windowId: UInt32?, stripId: ObjectIdentifier) {
        guard hoveredTabIds[stripId] != windowId else { return }
        hoveredTabIds[stripId] = windowId
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
