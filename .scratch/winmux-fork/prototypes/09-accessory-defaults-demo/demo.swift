import AppKit

class CloseButtonlessWindow: NSWindow {
    override func accessibilityCloseButton() -> Any? { nil }
}

final class UnconventionalPopupWindow: CloseButtonlessWindow {
    override func accessibilitySubrole() -> NSAccessibility.Subrole? { NSAccessibility.Subrole(rawValue: "AXUnknown") }
}

final class DemoDelegate: NSObject, NSApplicationDelegate {
    var windows: [NSWindow] = []
    var lastCommand = ""
    let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/winmux10-demo"
    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.setActivationPolicy(.regular)
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [self] _ in
            let path = root + "/command"
            guard let command = try? String(contentsOfFile: path, encoding: .utf8), command != lastCommand else { return }
            lastCommand = command
            run(command.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        run("standard")
    }
    func run(_ command: String) {
        if command == "quit" { NSApp.terminate(nil); return }
        if command == "accessory" { NSApp.setActivationPolicy(.accessory); return }
        if command == "regular" { NSApp.setActivationPolicy(.regular); return }
        if command == "raise" { windows.last?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        if command == "background" {
            let window = makeWindow(title: "Backdrop", close: true, color: .darkGray)
            windows.append(window); window.makeKeyAndOrderFront(nil); return
        }
        for window in windows { window.close() }; windows = []
        let accessory = command == "popup"
        NSApp.setActivationPolicy(accessory ? .accessory : .regular)
        let title = command == "standard" ? "Accessory document" : (accessory ? "Accessory popup" : (command == "app-popup" ? "App popup" : "Answer required"))
        let window = makeWindow(title: title, close: command == "standard", color: .systemTeal, unconventional: command == "app-popup")
        windows.append(window)
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func makeWindow(title: String, close: Bool, color: NSColor, unconventional: Bool = false) -> NSWindow {
        var style: NSWindow.StyleMask = [.titled, .resizable, .miniaturizable]
        if close { style.insert(.closable) }
        let windowType = unconventional ? UnconventionalPopupWindow.self : (close ? NSWindow.self : CloseButtonlessWindow.self)
        let window = windowType.init(contentRect: NSRect(x: 240, y: 280, width: 620, height: 340), styleMask: style, backing: .buffered, defer: false)
        if !close { window.standardWindowButton(.closeButton)?.isHidden = true }
        window.isReleasedWhenClosed = false
        window.title = title; window.collectionBehavior = [.fullScreenPrimary]
        let view = NSView(frame: window.contentView!.bounds)
        view.wantsLayer = true; view.layer?.backgroundColor = color.cgColor
        let label = NSTextField(labelWithString: title + "\n\n" + (Bundle.main.object(forInfoDictionaryKey: "LSUIElement") == nil ? "Owned Dock app demo" : "Owned LSUIElement demo") + "\n" + (unconventional ? "Non-standard AX popup" : "Standard window • fullscreen enabled") + (close ? "" : "\nNo close button"))
        label.frame = NSRect(x: 36, y: 100, width: 550, height: 150)
        label.font = .systemFont(ofSize: 22); label.textColor = .white
        view.addSubview(label); window.contentView = view
        return window
    }
}
let app = NSApplication.shared
let delegate = DemoDelegate(); app.delegate = delegate; app.run()
