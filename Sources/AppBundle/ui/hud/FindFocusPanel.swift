import AppKit

func findFocusPaths(window: CGRect, screen: CGRect) -> (dim: CGPath, border: CGPath) {
    let local = window.offsetBy(dx: -screen.minX, dy: -screen.minY)
    let dim = CGMutablePath()
    dim.addRect(CGRect(origin: .zero, size: screen.size))
    dim.addRoundedRect(in: local, cornerWidth: 10, cornerHeight: 10)
    let border = CGMutablePath()
    border.addRoundedRect(in: local, cornerWidth: 10, cornerHeight: 10)
    if local.width > 8, local.height > 8 {
        border.addRoundedRect(in: local.insetBy(dx: 4, dy: 4), cornerWidth: 6, cornerHeight: 6)
    }
    return (dim, border)
}

@MainActor
final class FindFocusPanel: NSPanelHud {
    private let dim = CAShapeLayer()
    private let border = CAShapeLayer()

    override init() {
        super.init()
        ignoresMouseEvents = true
        hasShadow = false
        animationBehavior = .none
        applyWinMuxLayer(.overlay)
        let view = NSView()
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        dim.fillRule = .evenOdd
        border.fillRule = .evenOdd
        view.layer?.addSublayer(dim)
        view.layer?.addSublayer(border)
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(window: CGRect, screen: CGRect, scale: CGFloat) {
        setFrame(screen, display: true)
        let paths = findFocusPaths(window: window, screen: screen)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dim.contentsScale = scale
        border.contentsScale = scale
        dim.path = paths.dim
        dim.fillColor = NSColor.black.withAlphaComponent(0.35).cgColor
        border.path = paths.border
        border.fillColor = NSColor.controlAccentColor.cgColor
        CATransaction.commit()
        // Through the animator, so a restart during the fade replaces the fade instead of racing it.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            animator().alphaValue = 1
        }
        orderFrontRegardless()
    }

    func fade() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            animator().alphaValue = 0
        }
    }
}

@MainActor
final class FindFocusPanels {
    static let shared = FindFocusPanels()
    private var panels: [Int64: FindFocusPanel] = [:]

    func show(_ rect: Rect) {
        // A screen without a display number still gets dimmed, under a key no display id can take.
        let screens = NSScreen.screens.enumerated().map { index, screen in
            (screen.displayId.map(Int64.init) ?? -Int64(index) - 1, screen)
        }
        let ids = Set(screens.map(\.0))
        for (id, panel) in panels where !ids.contains(id) { panel.orderOut(nil) }
        panels = panels.filter { ids.contains($0.key) }
        for (id, screen) in screens {
            let panel = panels[id] ?? FindFocusPanel()
            panels[id] = panel
            panel.show(window: rect.toAppKitScreenRect, screen: screen.frame, scale: screen.backingScaleFactor)
        }
    }

    func fade() { for panel in panels.values { panel.fade() } }
    func hide() { for panel in panels.values { panel.orderOut(nil) } }
}
