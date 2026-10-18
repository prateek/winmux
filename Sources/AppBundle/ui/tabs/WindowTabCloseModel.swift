import AppKit
import SwiftUI

@MainActor
final class WindowTabCloseModel: ObservableObject {
    static var shared = WindowTabCloseModel()

    @Published private(set) var closingWindowIds: Set<UInt32> = []
    @Published private(set) var heldWidths: [ObjectIdentifier: CGFloat] = [:]

    func begin(_ windowId: UInt32, pointer: (stripId: ObjectIdentifier, width: CGFloat)?) -> Bool {
        guard closingWindowIds.insert(windowId).inserted else { return false }
        if let pointer, heldWidths[pointer.stripId] == nil {
            heldWidths[pointer.stripId] = pointer.width
        }
        return true
    }

    func finish(_ windowId: UInt32) {
        closingWindowIds.remove(windowId)
    }

    func preservesFocus(closingWindowId: UInt32, focusedWindowId: UInt32?) -> Bool {
        closingWindowIds.contains(closingWindowId) && focusedWindowId != closingWindowId
    }

    func pointerLeftStrip(_ id: ObjectIdentifier) {
        heldWidths.removeValue(forKey: id)
    }
}

func windowTabAtPoint(_ point: CGPoint, frames: [UInt32: CGRect], viewport: CGRect = .infinite) -> UInt32? {
    guard viewport.contains(point) else { return nil }
    return frames.first { $0.value.contains(point) }?.key
}

@MainActor
func closeWindowFromTabStrip(
    _ windowId: UInt32,
    fallbackWorkspace: String,
    pointer: (stripId: ObjectIdentifier, width: CGFloat)? = nil,
) -> Task<Void, Error>? {
    guard let token: RunSessionGuard = .isServerEnabled,
          let window = Window.get(byId: windowId)
    else { return nil }
    let model = WindowTabCloseModel.shared
    guard model.begin(windowId, pointer: pointer) else { return nil }
    return Task { @MainActor in
        defer { model.finish(windowId) }
        let gone = await window.requestClose(timeout: 1, tabStripSession: token)
        guard let token: RunSessionGuard = .isServerEnabled else { return }
        try await runLightSession(.menuBarButton, token) {
            if !gone, Window.get(byId: windowId) === window {
                focusWindowFromTabStrip(windowId, fallbackWorkspace: fallbackWorkspace)
            }
            await updateWindowTabModel()
        }
        scheduleRefreshSession(.menuBarButton)
    }
}
