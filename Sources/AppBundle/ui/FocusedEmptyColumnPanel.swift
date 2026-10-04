import AppKit

extension Workspace {
    @MainActor var focusedEmptyColumnRect: Rect? {
        guard isVisible, focus.workspace === self, let columns,
              let slot = columns.focusedSlot, (1...columns.slotCount).contains(slot),
              !rootTilingContainer.children.contains(where: { $0.columnSlot == slot }) else { return nil }
        let rect = workspaceMonitor.visibleRectPaddedByOuterGaps
        let offset = columns.widths.prefix(slot - 1).reduce(0, +) * rect.width
        return Rect(topLeftX: rect.minX + offset, topLeftY: rect.minY,
                    width: columns.widths[slot - 1] * rect.width, height: rect.height)
    }
}

@MainActor final class FocusedEmptyColumnPanel: NSPanelHud {
    static let shared = FocusedEmptyColumnPanel()
    private let outline = NSView()

    private override init() {
        super.init()
        hasShadow = false
        ignoresMouseEvents = true
        applyWinMuxLayer(.windowChrome)
        outline.wantsLayer = true
        outline.layer?.borderWidth = 2
        outline.layer?.borderColor = NSColor.white.withAlphaComponent(0.22).cgColor
        outline.layer?.cornerRadius = 8
        contentView = outline
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func refresh() {
        guard TrayMenuModel.shared.isEnabled, let rect = focus.workspace.focusedEmptyColumnRect else { orderOut(nil); return }
        setFrame(rect.toAppKitScreenRect.insetBy(dx: 3, dy: 3), display: true)
        orderFrontRegardless()
    }
}
