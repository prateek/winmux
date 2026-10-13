import AppKit
import Common

func bindingModeHudText(mode: String?, enabled: Bool) -> String? {
    enabled && mode != mainModeId ? mode : nil
}

@MainActor final class BindingModeHud {
    static var shared = BindingModeHud(
        show: { BindingModeHudPanel.shared.show($0, visibleFrame: $1) },
        hide: { BindingModeHudPanel.shared.orderOut(nil) },
    )

    private let show: (String, NSRect) -> Void
    private let hide: () -> Void

    init(show: @escaping (String, NSRect) -> Void, hide: @escaping () -> Void) {
        self.show = show
        self.hide = hide
    }

    func refresh(mode: String?, enabled: Bool, visibleFrame: NSRect) {
        if let text = bindingModeHudText(mode: mode, enabled: enabled) {
            show(text, visibleFrame)
        } else {
            hide()
        }
    }

    func refresh() {
        refresh(mode: activeMode, enabled: TrayMenuModel.shared.isEnabled,
                visibleFrame: focus.workspace.workspaceMonitor.visibleRect.toAppKitScreenRect)
    }
}

@MainActor final class BindingModeHudPanel: NSPanelHud {
    static let shared = BindingModeHudPanel()
    private let label = NSTextField(labelWithString: "")

    override init() {
        super.init()
        ignoresMouseEvents = true
        applyWinMuxLayer(.overlay)
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.masksToBounds = true
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .labelColor
        label.alignment = .center
        background.addSubview(label)
        contentView = background
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(_ text: String, visibleFrame: NSRect) {
        label.stringValue = text
        label.sizeToFit()
        let size = NSSize(width: label.frame.width + 32, height: label.frame.height + 18)
        label.setFrameOrigin(NSPoint(x: 16, y: 9))
        setFrame(NSRect(x: visibleFrame.midX - size.width / 2, y: visibleFrame.minY + 20,
                        width: size.width, height: size.height), display: true)
        orderFrontRegardless()
    }
}
