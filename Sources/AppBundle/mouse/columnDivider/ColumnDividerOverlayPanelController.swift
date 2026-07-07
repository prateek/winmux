import AppKit
import SwiftUI

enum ColumnDividerOverlayState {
    case hover
    case dragging
    case committed
}

struct ColumnDividerOverlayModel {
    let workspaceRect: Rect
    let boundaryX: CGFloat
    let leftName: String
    let rightName: String
    let leftShare: Double?
    let rightShare: Double?
    let state: ColumnDividerOverlayState

    var localBoundaryX: CGFloat {
        boundaryX - workspaceRect.topLeftX
    }
}

@MainActor
final class ColumnDividerOverlayPanelController {
    static let shared = ColumnDividerOverlayPanelController()

    private let panel = NSPanelHud()
    private let hitPanel = ColumnDividerHitPanel()
    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private var pendingHide: DispatchWorkItem?

    private init() {
        panel.identifier = NSUserInterfaceItemIdentifier("WinMux.columnDividerOverlay")
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.isExcludedFromWindowsMenu = true
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = true
        panel.backgroundColor = .clear
        panel.applyWinMuxLayer(.overlay)
        panel.contentView = hostingView
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        hitPanel.identifier = NSUserInterfaceItemIdentifier("WinMux.columnDividerHitBand")
        hitPanel.hasShadow = false
        hitPanel.isFloatingPanel = true
        hitPanel.isExcludedFromWindowsMenu = true
        hitPanel.animationBehavior = .none
        hitPanel.ignoresMouseEvents = false
        hitPanel.backgroundColor = .clear
        hitPanel.applyWinMuxLayer(.overlay)
        hitPanel.contentView = ColumnDividerHitView(frame: .zero)
    }

    func show(_ model: ColumnDividerOverlayModel) {
        pendingHide?.cancel()
        pendingHide = nil
        let frame = model.workspaceRect.toAppKitScreenRect.alignedToBackingPixels()
        if panel.frame.size == frame.size {
            panel.setFrameOrigin(frame.origin)
        } else {
            panel.setFrame(frame, display: false, animate: false)
        }
        hostingView.frame = CGRect(origin: .zero, size: frame.size)
        hostingView.rootView = AnyView(ColumnDividerOverlayView(model: model))
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
        showHitPanel(for: model)
    }

    func hide(after delay: TimeInterval = 0) {
        pendingHide?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingHide = nil
            self.hostingView.rootView = AnyView(EmptyView())
            if self.panel.isVisible {
                self.panel.orderOut(nil)
            }
            self.hideHitPanel()
        }
        pendingHide = workItem
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        } else {
            workItem.perform()
        }
    }

    private func showHitPanel(for model: ColumnDividerOverlayModel) {
        guard model.state != .committed else {
            hideHitPanel()
            return
        }
        hitPanel.workspaceRect = model.workspaceRect
        let workspaceFrame = model.workspaceRect.toAppKitScreenRect.alignedToBackingPixels()
        let hitBandWidth = columnDividerChromeHitBandWidth(for: model.state)
        let frame = CGRect(
            x: model.boundaryX - hitBandWidth / 2,
            y: workspaceFrame.minY,
            width: hitBandWidth,
            height: workspaceFrame.height,
        ).alignedToBackingPixels()
        if hitPanel.frame.size == frame.size {
            hitPanel.setFrameOrigin(frame.origin)
        } else {
            hitPanel.setFrame(frame, display: false, animate: false)
        }
        if !hitPanel.isVisible {
            hitPanel.orderFrontRegardless()
        }
    }

    private func hideHitPanel() {
        hitPanel.workspaceRect = nil
        if hitPanel.isVisible {
            hitPanel.orderOut(nil)
        }
    }
}

private final class ColumnDividerHitPanel: NSPanelHud {
    var workspaceRect: Rect?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        guard columnDividerHitPanelHandlesEvent(type: event.type, buttonNumber: event.buttonNumber) else {
            forwardUnhandledEventBelow(event)
            return
        }
        super.sendEvent(event)
    }

    override func mouseDown(with event: NSEvent) {
        Task { @MainActor in
            _ = ColumnDividerDragController.shared.handleMouseDown(
                at: self.normalizedPoint(for: event),
                source: .dividerChrome,
            )
        }
    }

    override func mouseDragged(with event: NSEvent) {
        Task { @MainActor in
            _ = ColumnDividerDragController.shared.handleMouseDragged(at: self.normalizedPoint(for: event))
        }
    }

    override func mouseUp(with event: NSEvent) {
        Task { @MainActor in
            _ = ColumnDividerDragController.shared.handleMouseUp(at: self.normalizedPoint(for: event))
        }
    }

    private func normalizedPoint(for event: NSEvent) -> CGPoint {
        guard let workspaceRect else {
            return normalizeAppKitScreenPoint(NSEvent.mouseLocation)
        }
        return CGPoint(
            x: frame.minX + event.locationInWindow.x,
            y: workspaceRect.topLeftY + workspaceRect.height - event.locationInWindow.y,
        )
    }

    private func forwardUnhandledEventBelow(_ event: NSEvent) {
        guard let cgEvent = event.cgEvent else { return }
        ignoresMouseEvents = true
        defer { ignoresMouseEvents = false }
        cgEvent.post(tap: .cghidEventTap)
    }
}

private final class ColumnDividerHitView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.001).cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.001).cgColor
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override var acceptsFirstResponder: Bool { false }
}

func columnDividerChromeHitBandWidth(for state: ColumnDividerOverlayState) -> CGFloat {
    guard state != .committed else { return 0 }
    return 32
}

func columnDividerVisibleBandWidth(for state: ColumnDividerOverlayState) -> CGFloat {
    switch state {
        case .hover:
            8
        case .dragging, .committed:
            14
    }
}

func columnDividerHitPanelHandlesEvent(type: NSEvent.EventType, buttonNumber: Int) -> Bool {
    buttonNumber == 0 && [NSEvent.EventType.leftMouseDown, .leftMouseDragged, .leftMouseUp].contains(type)
}
