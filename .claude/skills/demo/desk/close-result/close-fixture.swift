import AppKit

final class NoCloseButtonWindow: NSWindow {
    override func accessibilityCloseButton() -> Any? { nil }
}

final class DisabledCloseButtonWindow: NSWindow {
    lazy var disabledCloseButton: NSButton = {
        let button = NSButton(title: "Close", target: nil, action: nil)
        button.isEnabled = false
        button.setAccessibilitySubrole(NSAccessibility.Subrole(rawValue: "AXCloseButton"))
        return button
    }()
    override func accessibilityCloseButton() -> Any? { disabledCloseButton }
}

final class CloseFixtureDelegate: NSObject, NSApplicationDelegate {
    var windows: [NSWindow] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let titles: [String]
        if CommandLine.arguments.contains("--ordinary") { titles = ["Close me"] }
        else { titles = ["Disabled close button", "No close button", "Close me"] }
        openWindows(titles)
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            let path = "/tmp/winmux-close-fixture-command"
            guard let command = try? String(contentsOfFile: path, encoding: .utf8) else { return }
            try? FileManager.default.removeItem(atPath: path)
            if command.trimmingCharacters(in: .whitespacesAndNewlines) == "ordinary" { openWindows(["Close me"]) }
        }
    }
    func openWindows(_ titles: [String]) {
        for (index, title) in titles.enumerated() {
            let type: NSWindow.Type
            switch title {
                case "No close button": type = NoCloseButtonWindow.self
                case "Disabled close button": type = DisabledCloseButtonWindow.self
                default: type = NSWindow.self
            }
            let style: NSWindow.StyleMask = title == "Close me" ? [.titled, .closable, .resizable] : [.titled]
            let window = type.init(contentRect: NSRect(x: 170 + index * 35, y: 180 + index * 30, width: 600, height: 320), styleMask: style, backing: .buffered, defer: false)
            window.title = title
            window.isReleasedWhenClosed = false
            let label = NSTextField(labelWithString: title)
            label.font = .systemFont(ofSize: 28)
            label.frame = NSRect(x: 30, y: 130, width: 540, height: 45)
            window.contentView!.addSubview(label)
            if let disabled = window as? DisabledCloseButtonWindow {
                disabled.disabledCloseButton.frame = NSRect(x: 20, y: 270, width: 70, height: 30)
                window.contentView!.addSubview(disabled.disabledCloseButton)
            }
            windows.append(window)
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

if CommandLine.arguments.count > 1, let pid = Int32(CommandLine.arguments[1]) {
    let app = AXUIElementCreateApplication(pid)
    var raw: CFTypeRef?
    AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &raw)
    for window in raw as? [AXUIElement] ?? [] {
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
        var button: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &button)
        var enabled: CFTypeRef?
        if result == .success, let button {
            AXUIElementCopyAttributeValue(button as! AXUIElement, kAXEnabledAttribute as CFString, &enabled)
        }
        print("\(title ?? "" as CFString): AXCloseButton=\(result == .success && button != nil ? "present" : "none") AXEnabled=\(enabled.map { String(describing: $0) } ?? "unreadable")")
    }
} else {
    let app = NSApplication.shared
    let delegate = CloseFixtureDelegate()
    app.delegate = delegate
    app.run()
}
