import AppKit

/// Overlay chrome follows every Space without becoming a window in Mission Control or Exposé.
let winMuxOverlayCollectionBehavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

open class NSPanelHud: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false,
        )
        self.level = .floating
        self.collectionBehavior = winMuxOverlayCollectionBehavior
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = false
        self.alphaValue = 1
        self.hasShadow = true
        self.isOpaque = false
        self.backgroundColor = .clear
    }
}
