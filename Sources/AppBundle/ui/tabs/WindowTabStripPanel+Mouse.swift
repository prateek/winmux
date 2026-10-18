import AppKit
import SwiftUI

extension WindowTabStripPanel {
    func shouldUpdate(content: WindowTabGroupChromeContent, strip: WindowTabStripViewModel) -> Bool {
        let frameChanged = currentPanelFrame != strip.frame
        let occlusionChanged = tabStripIsOccludedByFloatingWindow != strip.tabStripIsOccludedByFloatingWindow
        if currentContent == content, !frameChanged, !occlusionChanged, isVisible {
            updateMousePolicy()
            return false
        }
        return true
    }

    func updateMousePolicy() {
        let ignoresForMouseManipulation = currentlyManipulatedWithMouseWindowId != nil &&
            shouldIgnoreWindowTabStripMouseEventsDuringDrag(detachOrigin: getCurrentMouseTabDetachOrigin())
        ignoresMouseEvents = externallyIgnoresMouseEvents ||
            ignoresForMouseManipulation ||
            tabStripIsOccludedByFloatingWindow
    }
}

final class WindowTabStripHostingView: NSHostingView<AnyView> {
    var strip: WindowTabStripViewModel?
    var tabFrames: [UInt32: CGRect] = [:]
    var tabWidth: CGFloat = 0
    var tabViewport: CGRect = .zero

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    /// A point in window coordinates, in the strip view's coordinate space, where the published tab frames live.
    func stripPoint(fromWindowLocation location: NSPoint) -> CGPoint {
        var point = convert(location, from: nil)
        if !isFlipped { point.y = bounds.height - point.y }
        return point
    }

    /// The pointer over this strip, or nil when the strip cannot take it: hidden, ignoring the
    /// mouse, or under another window.
    func livePointerInStripSpace() -> CGPoint? {
        guard let window, window.isVisible, !window.ignoresMouseEvents,
              NSWindow.windowNumber(at: NSEvent.mouseLocation, belowWindowWithWindowNumber: 0) == window.windowNumber
        else { return nil }
        return stripPoint(fromWindowLocation: window.mouseLocationOutsideOfEventStream)
    }

    override func otherMouseUp(with event: NSEvent) {
        guard event.buttonNumber == 2, let strip else {
            super.otherMouseUp(with: event)
            return
        }
        guard let windowId = windowTabAtPoint(stripPoint(fromWindowLocation: event.locationInWindow), frames: tabFrames, viewport: tabViewport),
              !isWindowTabStripDragInProgress()
        else { return }
        closeWindowFromTabStrip(windowId, fallbackWorkspace: strip.workspaceName,
            pointer: WindowTabClosePointer(stripId: strip.id,
                hold: WindowTabWidthHold(width: tabWidth, stripWidth: bounds.width, tabCount: strip.tabs.count)))
    }
}
