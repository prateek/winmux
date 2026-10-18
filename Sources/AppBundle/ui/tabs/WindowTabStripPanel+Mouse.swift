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

    override func otherMouseUp(with event: NSEvent) {
        guard event.buttonNumber == 2, let strip else {
            super.otherMouseUp(with: event)
            return
        }
        var point = convert(event.locationInWindow, from: nil)
        if !isFlipped { point.y = bounds.height - point.y }
        guard let windowId = windowTabAtPoint(point, frames: tabFrames, viewport: tabViewport),
              !isWindowTabStripDragInProgress()
        else { return }
        let scrollOrigin = strip.tabs.first.flatMap { tabFrames[$0.windowId]?.minX }.map { $0 - windowTabStripContentHorizontalPadding } ?? tabViewport.minX
        closeWindowFromTabStrip(windowId, fallbackWorkspace: strip.workspaceName,
            pointer: WindowTabClosePointer(stripId: strip.id, width: tabWidth, stripWidth: strip.frame.width,
                tabCount: strip.tabs.count, x: point.x, scrollOrigin: scrollOrigin))
    }
}
