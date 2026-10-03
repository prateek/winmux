import AppKit

extension Workspace {
    @MainActor var focusedEmptyColumnRect: Rect? {
        guard isVisible, focus.workspace === self, let columns,
              let slot = columns.focusedSlot, (1...columns.count).contains(slot),
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
    #if DEBUG
    private var lastDebugFocus: String?
    #endif

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
        #if DEBUG
        if let path = ProcessInfo.processInfo.environment["WINMUX_DEBUG_COLUMN_FOCUS_FILE"],
           let value = try? String(contentsOfFile: path, encoding: .utf8), value != lastDebugFocus {
            lastDebugFocus = value
            let fields = value.split(whereSeparator: \.isWhitespace)
            if fields.count == 2, let slot = Int(fields[1]),
               let workspace = Workspace.existing(byName: String(fields[0])),
               let columns = workspace.columns, (1...columns.count).contains(slot),
               workspace.isVisible {
                columns.focusedSlot = slot
            }
        }
        if let path = ProcessInfo.processInfo.environment["WINMUX_DEBUG_COLUMN_TREE_FILE"],
           let columns = focus.workspace.columns {
            let root = focus.workspace.rootTilingContainer
            let lines = ["root: \(root.orientation.rawValue)/\(root.layout.rawValue); count: \(columns.count)",
                "widths: \(columns.widths.map { String(format: "%.4f", Double($0)) }.joined(separator: ", "))"] +
                root.children.map { "slot \($0.columnSlot ?? 0): windows \($0.allLeafWindowsRecursive.map { String($0.windowId) }.joined(separator: ", "))" }
            try? lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
        }
        #endif
        guard let rect = focus.workspace.focusedEmptyColumnRect else { orderOut(nil); return }
        setFrame(rect.toAppKitScreenRect.insetBy(dx: 3, dy: 3), display: true)
        orderFrontRegardless()
    }
}
