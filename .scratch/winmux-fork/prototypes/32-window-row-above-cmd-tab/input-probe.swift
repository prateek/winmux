import AppKit
import Carbon

func write(_ value: String) { print("\(ProcessInfo.processInfo.systemUptime) \(value)"); fflush(stdout) }
final class InputWindow: NSWindow {
    override func sendEvent(_ event: NSEvent) {
        if [.keyDown, .keyUp, .flagsChanged].contains(event.type) {
            write("front-event type=\(event.type.rawValue) code=\(event.keyCode) flags=\(event.modifierFlags.rawValue)")
        }
        super.sendEvent(event)
    }
}
final class Delegate: NSObject, NSWindowDelegate {
    var enabled = false
    func windowDidBecomeKey(_ notification: Notification) {
        if CommandLine.arguments.contains("--secure"), !enabled {
            write("EnableSecureEventInput status=\(EnableSecureEventInput())")
            enabled = true
        }
        write("key secure=\(IsSecureEventInputEnabled())")
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = Delegate()
let window = InputWindow(contentRect: NSRect(x: 250, y: 200, width: 700, height: 260), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
window.title = "Input canary — owned probe"
window.delegate = delegate
let text = NSTextView(frame: NSRect(x: 20, y: 20, width: 660, height: 220))
text.string = "Owned input canary. Select-all outside the switcher must reach this field.\nInside the switcher, Cmd-A belongs to the row."
text.font = .systemFont(ofSize: 20)
window.contentView?.addSubview(text)
window.makeKeyAndOrderFront(nil)
window.makeFirstResponder(text)
app.activate(ignoringOtherApps: true)
let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
    write("state front=\(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0) self=\(getpid()) secure=\(IsSecureEventInputEnabled()) selection=\(text.selectedRange())")
}
app.run()
