import AppKit
import SwiftUI

struct WindowTabClosePointer {
    let stripId: ObjectIdentifier
    let width: CGFloat
    let stripWidth: CGFloat
    let tabCount: Int
    let x: CGFloat
    let scrollOrigin: CGFloat
}

struct WindowTabWidthHold {
    let width: CGFloat
    let stripWidth: CGFloat
    let tabCount: Int
    let pointerX: CGFloat
    let scrollOrigin: CGFloat

    func isValid(stripWidth: CGFloat, tabCount: Int) -> Bool {
        self.stripWidth == stripWidth && tabCount <= self.tabCount
    }
}

func windowTabUnderPointer(_ x: CGFloat, order: [UInt32], width: CGFloat, scrollOrigin: CGFloat) -> UInt32? {
    let localX = x - scrollOrigin - windowTabStripContentHorizontalPadding
    guard width > 0, localX >= 0 else { return nil }
    let index = Int(localX / (width + windowTabStripTabSpacing))
    guard order.indices.contains(index), localX - CGFloat(index) * (width + windowTabStripTabSpacing) < width else { return nil }
    return order[index]
}

func windowTabHoverAfterOrderChange(_ hovered: UInt32?, order: [UInt32], hold: WindowTabWidthHold?) -> UInt32? {
    if let hold {
        return windowTabUnderPointer(hold.pointerX, order: order, width: hold.width, scrollOrigin: hold.scrollOrigin)
    }
    return hovered.flatMap { order.contains($0) ? $0 : nil }
}

@MainActor
final class WindowTabCloseModel: ObservableObject {
    static var shared = WindowTabCloseModel()

    @Published private(set) var closingWindowIds: Set<UInt32> = []
    @Published private(set) var widthHolds: [ObjectIdentifier: WindowTabWidthHold] = [:]
    var heldWidths: [ObjectIdentifier: CGFloat] { widthHolds.mapValues(\.width) }
    private(set) var backgroundCloseWindowIds: Set<UInt32> = []

    func begin(_ windowId: UInt32, pointer: WindowTabClosePointer?) -> Bool {
        guard closingWindowIds.insert(windowId).inserted else { return false }
        if focus.windowOrNil?.windowId == windowId {
            backgroundCloseWindowIds.remove(windowId)
        } else {
            backgroundCloseWindowIds.insert(windowId)
        }
        if let pointer {
            let previous = widthHolds[pointer.stripId]
            let width: CGFloat
            if let previous, previous.isValid(stripWidth: pointer.stripWidth, tabCount: pointer.tabCount) {
                width = previous.width
            } else {
                width = pointer.width
            }
            widthHolds[pointer.stripId] = WindowTabWidthHold(width: width, stripWidth: pointer.stripWidth, tabCount: pointer.tabCount,
                pointerX: pointer.x, scrollOrigin: pointer.scrollOrigin)
        }
        return true
    }

    func finish(_ windowId: UInt32) {
        closingWindowIds.remove(windowId)
    }

    func collect(_ windowId: UInt32, focusedWindowId: UInt32?) -> Bool {
        backgroundCloseWindowIds.remove(windowId) != nil && focusedWindowId != windowId
    }

    func bringForward(_ windowId: UInt32) {
        backgroundCloseWindowIds.remove(windowId)
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
                model.bringForward(windowId)
                focusWindowFromTabStrip(windowId, fallbackWorkspace: fallbackWorkspace)
            }
        }
    }
}
