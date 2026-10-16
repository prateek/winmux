import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let window = NSWindow(contentRect: NSRect(x: 110, y: 90, width: 1060, height: 540), styleMask: [.titled, .closable], backing: .buffered, defer: false)
window.title = "Close command checks"
let text = NSTextView(frame: window.contentView!.bounds)
text.autoresizingMask = [.width, .height]
text.isEditable = false
text.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
text.textContainerInset = NSSize(width: 20, height: 18)
text.string = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
window.contentView = text
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
app.run()
