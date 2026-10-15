import AppKit
let app = NSApplication.shared
app.setActivationPolicy(.regular)
var windows: [NSWindow] = []
for (index, title) in ["Garden plan", "Reading notes", "Travel list", "Weekend projects"].enumerated() {
    let window = NSWindow(contentRect: NSRect(x: 100 + index * 80, y: 150 + index * 35, width: 640, height: 400), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
    window.title = title
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: 38, weight: .medium)
    label.frame = NSRect(x: 40, y: 250, width: 560, height: 70)
    window.contentView?.addSubview(label)
    window.backgroundColor = [.systemMint, .systemBlue, .systemOrange, .systemPurple][index]
    window.makeKeyAndOrderFront(nil)
    windows.append(window)
}
app.activate(ignoringOtherApps: true)
app.run()
