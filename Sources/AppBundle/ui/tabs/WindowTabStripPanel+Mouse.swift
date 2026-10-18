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

    /// The pointer in the strip view's coordinate space, where the published tab frames live.
    func pointerInStripSpace(windowLocation: NSPoint? = nil) -> CGPoint? {
        guard let location = windowLocation ?? window?.mouseLocationOutsideOfEventStream else { return nil }
        var point = convert(location, from: nil)
        if !isFlipped { point.y = bounds.height - point.y }
        return point
    }

    override func otherMouseUp(with event: NSEvent) {
        guard event.buttonNumber == 2, let strip else {
            super.otherMouseUp(with: event)
            return
        }
        guard let point = pointerInStripSpace(windowLocation: event.locationInWindow),
              let windowId = windowTabAtPoint(point, frames: tabFrames, viewport: tabViewport),
              !isWindowTabStripDragInProgress()
        else { return }
        closeWindowFromTabStrip(windowId, fallbackWorkspace: strip.workspaceName,
            pointer: WindowTabClosePointer(stripId: strip.id,
                hold: WindowTabWidthHold(width: tabWidth, stripWidth: bounds.width, tabCount: strip.tabs.count)))
    }
}
