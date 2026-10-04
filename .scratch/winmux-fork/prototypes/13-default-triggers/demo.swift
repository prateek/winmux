import AppKit

final class Demo: NSObject, NSApplicationDelegate {
    let root = "/Users/Shared/winmux13-demo"
    let evidence = CommandLine.arguments.contains("evidence")
    var windows: [NSWindow] = []
    var text: NSTextView?
    var last = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        if evidence {
            let window = makeWindow(title: "Command and event evidence", index: 0)
            window.level = .floating
            window.setFrame(NSRect(x: 2650, y: 100, width: 1150, height: 900), display: true)
            let scroll = NSScrollView(frame: window.contentView!.bounds)
            scroll.autoresizingMask = [.width, .height]
            scroll.hasVerticalScroller = true
            let view = NSTextView(frame: scroll.bounds)
            view.isEditable = false
            view.font = .monospacedSystemFont(ofSize: 19, weight: .medium)
            view.textColor = .white
            view.backgroundColor = NSColor(calibratedWhite: 0.07, alpha: 1)
            view.isVerticallyResizable = true
            view.isHorizontallyResizable = false
            view.textContainer?.widthTracksTextView = true
            scroll.documentView = view
            window.contentView = scroll
            text = view
        } else {
            for index in 1...3 { _ = makeWindow(title: ["", "Amber Notes", "Blue Canvas", "Green Draft"][index], index: index) }
            windows.first?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            if evidence {
                if let value = try? String(contentsOfFile: root + "/text", encoding: .utf8), value != text?.string {
                    text?.string = value
                    text?.scrollRangeToVisible(NSRange(location: value.utf16.count, length: 0))
                }
            } else if let value = try? String(contentsOfFile: root + "/command", encoding: .utf8), value != last {
                last = value
                let parts = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
                switch parts.first {
                    case "raise":
                        if let number = parts.last.flatMap({ Int($0) }), windows.indices.contains(number - 1) {
                            windows[number - 1].makeKeyAndOrderFront(nil)
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    case "new": _ = makeWindow(title: "Violet Page", index: 4)
                    case "close": windows.last?.close()
                    case "quit": NSApp.terminate(nil)
                    default: break
                }
            }
        }
    }

    @discardableResult func makeWindow(title: String, index: Int) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 140 + index * 80, y: 240, width: 650, height: 460),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = title
        let view = NSView(frame: window.contentView!.bounds)
        view.wantsLayer = true
        view.layer?.backgroundColor = [NSColor.darkGray, .systemOrange, .systemBlue, .systemGreen, .systemPurple][index].cgColor
        let label = NSTextField(labelWithString: title + "\nOwned demo window")
        label.font = .systemFont(ofSize: 34, weight: .semibold)
        label.textColor = .white
        label.frame = NSRect(x: 24, y: 150, width: 600, height: 130)
        label.autoresizingMask = [.width, .height]
        view.addSubview(label)
        window.contentView = view
        window.orderFront(nil)
        windows.append(window)
        return window
    }
}
let app = NSApplication.shared
let delegate = Demo()
app.setActivationPolicy(delegate.evidence ? .accessory : .regular)
app.delegate = delegate
app.run()
