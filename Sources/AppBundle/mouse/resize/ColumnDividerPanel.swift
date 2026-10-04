import AppKit

@MainActor final class ColumnDividerResizeSession {
    let workspace: Workspace
    let slot: Int
    private let startX: CGFloat
    private let columns: ColumnState
    private let startingWidths: [CGFloat]

    init(workspace: Workspace, slot: Int, startX: CGFloat) {
        self.workspace = workspace
        self.slot = slot
        self.startX = startX
        columns = workspace.columns.orDie()
        startingWidths = columns.widths
    }

    func proposal(pointerX: CGFloat) -> WindowResizePreviewWeightMap {
        let width = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps.width
        let edge = startingWidths.prefix(slot).reduce(0, +) + (pointerX - startX) / width
        let fraction = columns.fraction(slot: slot, rightEdgeAt: edge, starting: startingWidths)
        let widths = columns.proposedWidths(slot: slot, fraction: fraction, availableWidth: width, starting: startingWidths)
        return WindowResizePreviewWeightMap(columnWidths: widths, workspace: workspace)
    }

    func commit(pointerX: CGFloat) {
        // A click that never moved must not commit: a proposal can differ from the widths it started from.
        guard workspace.columns === columns, abs(pointerX - startX) >= 1 else { return }
        columns.widths = proposal(pointerX: pointerX).columnWidths.orDie()
        workspace.enforceColumnInvariant()
    }
}

extension Workspace {
    /// The handles sit above every window, so they are left out while a fullscreen or floating
    /// window could be under one. Dragging a window's edge still resizes its Column.
    @MainActor var showsColumnDividers: Bool {
        guard let columns, columns.slotCount > 1 else { return false }
        return floatingWindows.isEmpty && !rootTilingContainer.allLeafWindowsRecursive.contains(where: \.isFullscreen)
    }
}

@MainActor final class ColumnDividerPanelController {
    static let shared = ColumnDividerPanelController()
    private var panels: [String: NSPanelHud] = [:]

    func refresh() {
        var visible: Set<String> = []
        if TrayMenuModel.shared.isEnabled {
            for workspace in Workspace.all where workspace.isVisible {
                guard let columns = workspace.columns, workspace.showsColumnDividers else { continue }
                let rect = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
                for slot in 1..<columns.slotCount {
                    let key = "\(workspace.id.rawValue):\(slot)"
                    visible.insert(key)
                    let panel: NSPanelHud
                    if let existing = panels[key] {
                        panel = existing
                    } else {
                        panel = NSPanelHud()
                        panel.hasShadow = false
                        panel.applyWinMuxLayer(.windowChrome)
                        panel.contentView = ColumnDividerView(workspace: workspace, slot: slot)
                        panels[key] = panel
                    }
                    let x = rect.minX + columns.widths.prefix(slot).reduce(0, +) * rect.width
                    panel.setFrame(Rect(topLeftX: x - 3, topLeftY: rect.minY, width: 6, height: rect.height).toAppKitScreenRect, display: true)
                    panel.contentView?.frame = CGRect(origin: .zero, size: panel.frame.size)
                    panel.orderFrontRegardless()
                }
            }
        }
        for key in panels.keys.filter({ !visible.contains($0) }) {
            panels.removeValue(forKey: key)?.close()
        }
    }
}

@MainActor private final class ColumnDividerView: NSView {
    private weak var workspace: Workspace?
    private let slot: Int
    private var session: ColumnDividerResizeSession?

    init(workspace: Workspace, slot: Int) {
        self.workspace = workspace
        self.slot = slot
        super.init(frame: .zero)
        autoresizingMask = [.width, .height]
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.04).cgColor
    }

    required init?(coder: NSCoder) { nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .resizeLeftRight) }

    override func mouseDown(with event: NSEvent) {
        guard let workspace, workspace.columns != nil else { return }
        session = ColumnDividerResizeSession(workspace: workspace, slot: slot, startX: NSEvent.mouseLocation.x)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let session else { return }
        let map = session.proposal(pointerX: NSEvent.mouseLocation.x)
        let items = windowResizePreviewItems(in: session.workspace, weightMap: map, excludingActiveWindowId: nil)
        WindowResizePreviewPanel.shared.beginStableFrame(session.workspace.workspaceMonitor.rect.toAppKitScreenRect)
        WindowResizePreviewPanel.shared.show(items, presentation: .resizeOverlay)
    }

    override func mouseUp(with event: NSEvent) {
        session?.commit(pointerX: NSEvent.mouseLocation.x)
        session = nil
        WindowResizePreviewPanel.shared.endStableFrame()
        WindowResizePreviewPanel.shared.hide(reason: "column-divider.finished")
        scheduleRefreshSession(.resetManipulatedWithMouse, optimisticallyPreLayoutWorkspaces: true)
    }
}
