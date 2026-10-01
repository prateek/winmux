import AppKit
import QuartzCore

/// Animates snapshots because another app's window cannot host our Core Animation layers.
@MainActor
final class DoubleSidedWindowController {
    static let shared = DoubleSidedWindowController()
    private var animationPanel: NSPanel?
    private var isCapturing = false
    // Room for the edge that swings toward the viewer, which perspective draws outside the window's frame.
    private let rotationPadding: CGFloat = 64

    var isAnimating: Bool { isCapturing || animationPanel != nil }

    func flip(_ window: Window) async {
        guard !isAnimating, TrayMenuModel.shared.isEnabled,
              let group = window.nearestWindowTabGroup,
              group.usesDoubleSidedWindows,
              group.tabActiveWindow === window,
              let other = group.children.compactMap({ $0 as? Window }).first(where: { $0 !== window }),
              let rect = window.lastAppliedLayoutPhysicalRect
        else { return }
        let frontId = window.windowId
        let backId = other.windowId
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion && CGPreflightScreenCaptureAccess() {
            isCapturing = true
            let size = CGSize(width: rect.width, height: rect.height)
            async let front = snapshot(frontId, size: size)
            async let back = snapshot(backId, size: size)
            let (frontImage, backImage) = await (front, back)
            isCapturing = false
            if let frontImage, let backImage {
                animate(front: frontImage, back: backImage, rect: rect)
            }
        }
        focusWindowFromTabStrip(backId, fallbackWorkspace: focus.workspace.name)
    }

    private func snapshot(_ id: UInt32, size: CGSize) async -> CGImage? {
        guard let image = await WindowScreenshot.capture(id, pixelSize: size) else { return nil }
        // Trim the native one-point outline so it does not become a bright edge when the
        // snapshot rotates.
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        guard image.width > 2, image.height > 2 else { return image }
        return image.cropping(to: bounds.insetBy(dx: 1, dy: 1))
    }

    private func animate(front: CGImage, back: CGImage, rect: Rect) {
        let frame = CGRect(x: rect.topLeftX, y: mainMonitor.height - rect.topLeftY - rect.height,
                           width: rect.width, height: rect.height)
            .insetBy(dx: -rotationPadding, dy: -rotationPadding)
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let view = NSView(frame: CGRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        let root = CALayer()
        view.layer = root
        panel.contentView = view
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / max(rect.width * 2, 1000)
        root.sublayerTransform = perspective
        let duration = 0.48
        for (image, start, end) in [(front, 0.0, Double.pi), (back, -Double.pi, 0.0)] {
            let face = CALayer()
            face.frame = view.bounds.insetBy(dx: rotationPadding, dy: rotationPadding)
            face.contents = image
            face.contentsGravity = .resize
            face.isDoubleSided = false
            face.allowsEdgeAntialiasing = true
            root.addSublayer(face)
            face.transform = CATransform3DMakeRotation(CGFloat(end), 0, 1, 0)
            let rotation = CABasicAnimation(keyPath: "transform.rotation.y")
            rotation.fromValue = start
            rotation.toValue = end
            rotation.duration = duration
            rotation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            face.add(rotation, forKey: "flip")
        }
        animationPanel = panel
        CATransaction.commit()
        panel.orderFrontRegardless()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            panel.orderOut(nil)
            if animationPanel === panel { animationPanel = nil }
        }
    }
}
