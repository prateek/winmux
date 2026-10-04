import AppKit

final class Delegate: NSObject, NSApplicationDelegate {
    var windows: [String: NSWindow] = [:]
    var labels: [String: NSTextField] = [:]
    var clocks: [NSTextField] = []
    var last = ""
    var backdrop: NSWindow?
    let root = CommandLine.arguments.dropFirst().first ?? "/Users/Shared/column-hooks-demo"

    func applicationDidFinishLaunching(_ notification: Notification) {
        if root.hasSuffix("ColumnEvidence"), let screen = NSScreen.main {
            let panel = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            panel.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 1)
            panel.level = .normal
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            panel.ignoresMouseEvents = true
            panel.orderFront(nil)
            backdrop = panel
        }
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            if let input = try? String(contentsOfFile: root + "/command", encoding: .utf8), input != last {
                last = input
                guard let data = input.data(using: .utf8), let command = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return }
                let name = command["name"] ?? "Demo"
                switch command["action"] {
                    case "new": create(name, text: command["text"] ?? "Owned neutral window", hue: Double(command["hue"] ?? "0.55") ?? 0.55)
                    case "close": windows[name]?.close(); windows.removeValue(forKey: name); labels.removeValue(forKey: name)
                    case "raise": windows[name]?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
                    case "text": labels[name]?.stringValue = command["text"] ?? ""
                    case "frame":
                        let numbers = (command["frame"] ?? "").split(separator: ",").compactMap { Double($0) }
                        if numbers.count == 4 { windows[name]?.setFrame(NSRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3]), display: true) }
                    case "hide": NSApp.hide(nil)
                    case "show": NSApp.unhide(nil)
                    case "quit": NSApp.terminate(nil)
                    default: break
                }
            }
            if let text = try? String(contentsOfFile: root + "/evidence.txt", encoding: .utf8) { labels["Evidence"]?.stringValue = text }
            for clock in clocks { clock.stringValue = Date().formatted(date: .omitted, time: .standard) }
        }
    }

    func create(_ name: String, text: String, hue: Double) {
        let window = NSWindow(contentRect: NSRect(x: 80, y: 150, width: 520, height: 440), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = name
        let content = NSView(frame: window.contentView!.bounds)
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor(calibratedHue: hue, saturation: 0.55, brightness: 0.42, alpha: 1).cgColor
        let label = NSTextField(wrappingLabelWithString: name + "\n" + text)
        label.font = .monospacedSystemFont(ofSize: name == "Evidence" ? 15 : 28, weight: .medium)
        label.textColor = .white
        label.frame = content.bounds.insetBy(dx: 18, dy: 22)
        label.autoresizingMask = [.width, .height]
        content.addSubview(label)
        let clock = NSTextField(labelWithString: "Live")
        clock.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        clock.textColor = .white
        clock.frame = NSRect(x: 18, y: 0, width: 200, height: 20)
        content.addSubview(clock)
        clocks.append(clock)
        window.contentView = content
        windows[name] = window
        labels[name] = label
        window.orderFront(nil)
    }
}
let application = NSApplication.shared
application.setActivationPolicy(.regular)
let delegate = Delegate()
application.delegate = delegate
application.run()
