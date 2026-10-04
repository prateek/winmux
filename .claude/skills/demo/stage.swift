// The stage: owned windows a viewer can tell apart at a glance, on a plain dark wallpaper.
//
//   swiftc -O stage.swift -o stage
//   ./stage Red Blue Green Yellow        one window per name; a known colour name sets the tint
//   echo quit > /tmp/stage/command       also: "close <name>", "open <name>", "raise <name>"
import AppKit

let palette: [String: NSColor] = [
    "red": NSColor(srgbRed: 0.90, green: 0.28, blue: 0.30, alpha: 1),
    "blue": NSColor(srgbRed: 0.24, green: 0.52, blue: 0.96, alpha: 1),
    "green": NSColor(srgbRed: 0.19, green: 0.69, blue: 0.42, alpha: 1),
    "yellow": NSColor(srgbRed: 0.96, green: 0.74, blue: 0.18, alpha: 1),
    "violet": NSColor(srgbRed: 0.58, green: 0.40, blue: 0.92, alpha: 1),
    "orange": NSColor(srgbRed: 0.96, green: 0.52, blue: 0.20, alpha: 1),
    "teal": NSColor(srgbRed: 0.14, green: 0.67, blue: 0.70, alpha: 1),
    "pink": NSColor(srgbRed: 0.92, green: 0.38, blue: 0.64, alpha: 1),
]
let fallback = NSColor(srgbRed: 0.45, green: 0.48, blue: 0.56, alpha: 1)

final class Stage: NSObject, NSApplicationDelegate {
    var windows: [String: NSWindow] = [:]
    var lastCommand = ""
    let commandFile = "/tmp/stage/command"

    func applicationDidFinishLaunching(_: Notification) {
        setWallpaper()
        for (index, name) in CommandLine.arguments.dropFirst().enumerated() { open(name, offset: index) }
        NSApp.activate(ignoringOtherApps: true)
        try? FileManager.default.createDirectory(atPath: "/tmp/stage", withIntermediateDirectories: true)
        try? FileManager.default.removeItem(atPath: commandFile)
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [self] _ in poll() }
    }

    func tint(_ name: String) -> NSColor {
        palette[name.lowercased().split(separator: " ").first.map(String.init) ?? ""] ?? fallback
    }

    func open(_ name: String, offset: Int) {
        let window = NSWindow(
            contentRect: NSRect(x: 120 + offset * 40, y: 120 + offset * 30, width: 520, height: 360),
            styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = name
        let color = tint(name)
        let view = NSView(frame: window.contentView!.bounds)
        view.wantsLayer = true
        view.layer?.backgroundColor = color.blended(withFraction: 0.72, of: NSColor(white: 0.09, alpha: 1))?.cgColor
        let band = NSView(frame: NSRect(x: 0, y: view.bounds.height - 10, width: view.bounds.width, height: 10))
        band.wantsLayer = true
        band.layer?.backgroundColor = color.cgColor
        band.autoresizingMask = [.width, .minYMargin]
        let label = NSTextField(labelWithString: name)
        label.font = .systemFont(ofSize: 44, weight: .semibold)
        label.textColor = color.blended(withFraction: 0.35, of: .white)
        label.frame = NSRect(x: 28, y: view.bounds.height - 96, width: view.bounds.width - 56, height: 60)
        label.autoresizingMask = [.width, .minYMargin]
        view.addSubview(band)
        view.addSubview(label)
        window.contentView = view
        windows[name] = window
        window.orderFront(nil)
    }

    func poll() {
        guard let text = try? String(contentsOfFile: commandFile, encoding: .utf8), text != lastCommand else { return }
        lastCommand = text
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ", maxSplits: 1).map(String.init)
        guard let verb = parts.first else { return }
        let name = parts.count > 1 ? parts[1] : ""
        switch verb {
        case "quit": NSApp.terminate(nil)
        case "close": windows[name]?.close()
        case "open": open(name, offset: windows.count)
        case "raise":
            windows[name]?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        default: break
        }
    }

    func setWallpaper() {
        let size = NSSize(width: 64, height: 64)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(srgbRed: 0.07, green: 0.08, blue: 0.10, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        let url = URL(fileURLWithPath: "/tmp/stage-wallpaper.png")
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
        for screen in NSScreen.screens { try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:]) }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let stage = Stage()
app.delegate = stage
app.run()
