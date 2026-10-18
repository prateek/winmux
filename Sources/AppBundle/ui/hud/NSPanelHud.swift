import AppKit

/// `.transient` excludes normal-level panels already on screen when Mission Control or App Exposé opens.
/// Panels ordered in during those views are hidden by MissionControlState. Above-normal panels
/// are already transient in AppKit; a HUD or Lens summoned during a view may still draw above it.
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
