import AppKit
import QuartzCore

/// Animates snapshots because another app's window cannot host our Core Animation layers.
@MainActor
final class DoubleSidedWindowController {
    static let shared = DoubleSidedWindowController()
    private var animationPanel: NSPanel?
    private var isCapturing = false
    private let captureTimeout: Duration = .milliseconds(500)
    private static let redrawDelay: Duration = .milliseconds(80)
    // Room for the edge that swings toward the viewer, which perspective draws outside the window's
    // frame, and for the backdrop to cover the windows' shadows.
    private let rotationPadding: CGFloat = 64

    var isAnimating: Bool { isCapturing || animationPanel != nil }

    func flip(_ window: Window) async {
        guard !isAnimating, let (other, rect) = flipTarget(of: window) else { return }
        let backId = other.windowId
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion && CGPreflightScreenCaptureAccess() {
            let frontId = window.windowId
            let workspace = focus.workspace
            isCapturing = true
            let snapshots = await firstResult(within: captureTimeout) {
                await Self.resizeHiddenWindow(other, toMatch: rect)
                return await Self.snapshots(front: frontId, back: backId, rect: rect, padding: self.rotationPadding)
            }
            isCapturing = false
            // The capture takes long enough for the pair to change or the user to move on.
            guard let current = flipTarget(of: window), current.other === other, current.rect == rect,
                  focus.workspace === workspace
            else { return }
            if let snapshots {
                animate(snapshots, rect: rect)
            }
        }
        focusWindowFromTabStrip(backId, fallbackWorkspace: focus.workspace.name)
    }

    private func flipTarget(of window: Window) -> (other: Window, rect: Rect)? {
        guard TrayMenuModel.shared.isEnabled,
              let group = window.nearestWindowTabGroup,
              group.usesDoubleSidedWindows,
              group.tabActiveWindow === window,
              let other = group.children.compactMap({ $0 as? Window }).first(where: { $0 !== window }),
              let rect = window.lastAppliedLayoutPhysicalRect
        else { return nil }
        return (other, rect)
    }

    /// A hidden tab keeps the size it had when it was parked. Its snapshot fills the visible
    /// window's frame, so it is given that size first, or the snapshot would be stretched.
    private static func resizeHiddenWindow(_ window: Window, toMatch rect: Rect) async {
        let size = CGSize(width: rect.width, height: rect.height)
        guard let window = window as? MacWindow,
              let current = try? await window.getAxSize(),
              abs(current.width - size.width) > 1 || abs(current.height - size.height) > 1
        else { return }
        try? await window.setAxFrameBlocking(nil, size)
        // The app needs a moment to draw its content at the new size.
        try? await Task.sleep(for: redrawDelay)
    }

    private struct Snapshots: Sendable {
        let front: CGImage
        let back: CGImage
        /// What is on screen under and around the pair, to cover the real windows while the
        /// snapshots rotate. Missing if it could not be captured.
        let backdrop: CGImage?
    }

    private static func snapshots(front: UInt32, back: UInt32, rect: Rect, padding: CGFloat) async -> Snapshots? {
        let area = CGRect(x: rect.topLeftX, y: rect.topLeftY, width: rect.width, height: rect.height)
            .insetBy(dx: -padding, dy: -padding)
        async let frontImage = snapshot(front)
        async let backImage = snapshot(back)
        async let backdrop = try? WindowScreenshot.captureScreen(area, excluding: [front, back])
        guard let frontImage = await frontImage, let backImage = await backImage else { return nil }
        return Snapshots(front: frontImage, back: backImage, backdrop: await backdrop)
    }

    private static func snapshot(_ id: UInt32) async -> CGImage? {
        guard let image = try? await WindowScreenshot.capture(id) else { return nil }
        // Trim the native one-point outline so it does not become a bright edge when the
        // snapshot rotates.
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        guard image.width > 2, image.height > 2 else { return image }
        return image.cropping(to: bounds.insetBy(dx: 1, dy: 1))
    }

    /// The result of `operation`, or nil if it has not finished in time. A capture that never
    /// returns must not leave the controller waiting on it.
    private func firstResult<T: Sendable>(within timeout: Duration, _ operation: @escaping @MainActor () async -> T?) async -> T? {
        var waiting: CheckedContinuation<T?, Never>?
        func finish(_ result: T?) {
            waiting?.resume(returning: result)
            waiting = nil
        }
        return await withCheckedContinuation { continuation in
            waiting = continuation
            Task { @MainActor in finish(await operation()) }
            Task { @MainActor in
                try? await Task.sleep(for: timeout)
                finish(nil)
            }
        }
    }

    private func animate(_ snapshots: Snapshots, rect: Rect) {
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
        root.contents = snapshots.backdrop
        root.contentsGravity = .resize
        view.layer = root
        panel.contentView = view
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / max(rect.width * 2, 1000)
        root.sublayerTransform = perspective
        let duration = 0.48
        for (image, start, end) in [(snapshots.front, 0.0, Double.pi), (snapshots.back, -Double.pi, 0.0)] {
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
